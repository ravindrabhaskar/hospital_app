import { desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { appointments, medicalRecords, patients, prescriptions, products, providers } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { errors } from '../../lib/errors.js';
import { list, envelope, pageFromQuery } from '../../lib/pagination.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { issuePrescription, matchProduct, toPrescription } from './service.js';

const zTime = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected HH:MM');
export const zRxItem = z.object({
  drugName: z.string().trim().min(1).max(100),
  strength: z.string().trim().min(1).max(40).optional(),
  form: z.enum(['tablet', 'capsule', 'syrup', 'injection', 'ointment', 'drops', 'inhaler', 'other']),
  dose: z.string().trim().min(1).max(60),
  frequency: z.string().trim().min(1).max(60),
  timing: z.string().trim().min(1).max(60).optional(),
  durationDays: z.number().int().min(1).max(365),
  times: z.array(zTime).max(8),
  instructions: z.string().trim().max(300).optional(),
});

/** Contract section 31: e-prescriptions. */
export async function prescriptionRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.post('/clinician/prescriptions', { preHandler: requireRoles(svc, 'doctor') }, async (req, reply) => {
    const body = parse(
      z.object({
        appointmentId: zUuid,
        clinicalNote: z.string().trim().max(4000).optional(),
        items: z.array(zRxItem).min(1).max(20),
        advice: z.string().trim().max(2000).optional(),
        followUpInDays: z.number().int().min(1).max(365).optional(),
      }),
      req.body,
    );
    const [a] = await db.select().from(appointments).where(eq(appointments.id, body.appointmentId));
    if (!a) throw errors.notFound('Appointment');
    if (!req.ctx.user.providerId || a.doctorId !== req.ctx.user.providerId) {
      await audit(db, req.ctx.actor, { action: 'prescription.create', entityType: 'appointment', entityId: a.id, outcome: 'denied' });
      throw errors.forbidden('Only the appointment doctor can prescribe');
    }
    if (a.status !== 'in_progress' && a.status !== 'completed') {
      throw errors.conflict('Prescriptions can be issued only for an in-progress or completed consultation', { status: a.status });
    }
    const [doctor] = await db.select().from(providers).where(eq(providers.id, a.doctorId));
    const [patient] = await db.select().from(patients).where(eq(patients.id, a.patientId));
    const row = await db.transaction(async (tx) => {
      const r = await issuePrescription(tx, svc.storage, {
        appointment: a,
        doctor,
        doctorUserId: req.ctx.user.id,
        patient,
        input: { clinicalNote: body.clinicalNote, items: body.items, advice: body.advice, followUpInDays: body.followUpInDays },
        actor: req.ctx.actor,
      });
      await audit(tx, req.ctx.actor, { action: 'prescription.create', entityType: 'prescription', entityId: r.id, metadata: { appointmentId: a.id, itemCount: body.items.length } });
      return r;
    });
    await svc.notify.notifyPatient(a.patientId, {
      template: 'prescription_issued',
      params: { doctor: doctor.name },
      category: 'record',
      deepLink: `/prescriptions/${row.id}`,
      dedupeKey: `prescription:${row.id}`,
    });
    return reply.code(201).send(toPrescription(row));
  });

  app.get('/prescriptions', async (req) => {
    const q = parse(z.object({ patientId: zUuid }), req.query);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, 'view_records', 'prescription.list');
    const rows = await db
      .select()
      .from(prescriptions)
      .where(eq(prescriptions.patientId, q.patientId))
      .orderBy(desc(prescriptions.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toPrescription), page);
  });

  const load = async (id: string) => {
    const [p] = await db.select().from(prescriptions).where(eq(prescriptions.id, id));
    if (!p) throw errors.notFound('Prescription');
    return p;
  };

  app.get('/prescriptions/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const p = await load(id);
    await assertCanActForPatient(db, req.ctx, p.patientId, 'view_records', 'prescription.read');
    await audit(db, req.ctx.actor, { action: 'prescription.read', entityType: 'prescription', entityId: id });
    return toPrescription(p);
  });

  app.get('/prescriptions/:id/pdf', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const p = await load(id);
    await assertCanActForPatient(db, req.ctx, p.patientId, 'view_records', 'prescription.download');
    const [rec] = await db.select().from(medicalRecords).where(eq(medicalRecords.id, p.recordId));
    if (!rec?.storageKey) throw errors.notFound('File');
    const data = await svc.storage.get(rec.storageKey);
    await audit(db, req.ctx.actor, { action: 'prescription.download', entityType: 'prescription', entityId: id });
    return reply
      .header('content-type', 'application/pdf')
      .header('content-disposition', `inline; filename="${rec.fileName.replace(/["\r\n]/g, '')}"`)
      .header('cache-control', 'private, no-store')
      .header('x-content-type-options', 'nosniff')
      .send(data);
  });

  app.get('/prescriptions/:id/pharmacy-match', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const p = await load(id);
    await assertCanActForPatient(db, req.ctx, p.patientId, ['view_records', 'book'], 'prescription.pharmacy_match');
    const catalogue = await db.select().from(products);
    return list(
      p.items.map((it, itemIndex) => {
        const prod = matchProduct(it, catalogue);
        return {
          itemIndex,
          drugName: it.drugName,
          product: prod
            ? {
                id: prod.id,
                name: prod.name,
                packSize: prod.packSize,
                mrp: prod.mrp,
                price: prod.price,
                category: prod.category,
                requiresPrescription: prod.requiresPrescription,
                imageUrl: prod.imageUrl,
                inStock: prod.inStock,
              }
            : null,
        };
      }),
    );
  });
}
