import { and, desc, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { vitals } from '../../db/schema.js';
import { assertCanActForPatient } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { parse, zIso, zUuid, zVitalType } from '../../lib/validate.js';
import { evaluateVitals } from '../programs/service.js';
import { toVital } from './service.js';

export async function vitalRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/vitals', async (req) => {
    const q = parse(z.object({ patientId: zUuid, type: z.string().max(30).optional() }), req.query);
    const page = pageFromQuery(req.query);
    await assertCanActForPatient(db, req.ctx, q.patientId, 'view_records', 'vital.list');
    const conds = [eq(vitals.patientId, q.patientId)];
    if (q.type) conds.push(eq(vitals.type, q.type));
    const rows = await db
      .select()
      .from(vitals)
      .where(and(...conds))
      .orderBy(desc(vitals.measuredAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toVital), page);
  });

  app.post('/vitals', async (req, reply) => {
    const body = parse(
      z.object({ patientId: zUuid, type: zVitalType, value: z.number().finite(), unit: z.string().min(1).max(20), measuredAt: zIso }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, body.patientId, 'manage_care', 'vital.create');
    const [row] = await db
      .insert(vitals)
      .values({
        patientId: body.patientId,
        type: body.type,
        value: body.value,
        unit: body.unit,
        measuredAt: new Date(body.measuredAt),
        source: 'patient_entered',
        recordedByUserId: req.ctx.user.id,
        recordedByName: req.ctx.user.name,
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'vital.create', entityType: 'vital', entityId: row.id, metadata: { patientId: body.patientId, type: body.type } });
    // Contract section 42: every new reading is evaluated against active program enrollments.
    await evaluateVitals(svc, body.patientId, [row]);
    return reply.code(201).send(toVital(row));
  });
}
