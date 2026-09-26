import { and, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { allergies, conditions, emergencyContacts, patients } from '../../db/schema.js';
import { ALL_FAMILY_PERMISSIONS, assertCanActForPatient, listActablePatients } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { hasRole } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { pageFromQuery, paginateArray } from '../../lib/pagination.js';
import { parse, zDate, zPhone, zUuid } from '../../lib/validate.js';
import { ABDM_PENDING_MESSAGE, NotConnectedAbdmGateway, normaliseAbhaAddress, normaliseAbhaNumber } from '../abdm/gateway.js';
import { toAllergy, toCondition, toEmergencyContact, toPatientProfile, toPatientSummary, viewFromAccess } from './service.js';

const zGender = z.enum(['male', 'female', 'other']);

export async function patientRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/patients', async (req) => {
    const page = pageFromQuery(req.query);
    const actable = await listActablePatients(db, req.ctx.user);
    const rows = actable.length ? await db.select().from(patients).where(inArray(patients.id, actable.map((a) => a.patientId))) : [];
    const byId = new Map(rows.map((r) => [r.id, r]));
    const items = actable
      .filter((a) => byId.has(a.patientId))
      .map((a) => toPatientSummary(byId.get(a.patientId)!, { relation: a.relation, isSelf: a.isSelf, permissions: a.permissions }));
    return paginateArray(items, page);
  });

  app.post('/patients', async (req, reply) => {
    const body = parse(
      z.object({
        name: z.string().trim().min(1).max(100),
        dob: zDate,
        gender: zGender,
        relation: z.string().trim().min(1).max(40),
        bloodGroup: z.string().max(5).optional(),
      }),
      req.body,
    );
    if (body.relation.toLowerCase() === 'self') throw errors.validation("relation cannot be 'self'");
    const [p] = await db
      .insert(patients)
      .values({
        name: body.name,
        dob: body.dob,
        gender: body.gender,
        bloodGroup: body.bloodGroup ?? null,
        ownerUserId: req.ctx.user.id,
        ownerRelation: body.relation,
      })
      .returning();
    await audit(db, req.ctx.actor, { action: 'patient.create_dependent', entityType: 'patient', entityId: p.id });
    return reply.code(201).send(await toPatientProfile(db, p, { relation: body.relation, isSelf: false, permissions: [...ALL_FAMILY_PERMISSIONS] }));
  });

  app.get('/patients/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const access = await assertCanActForPatient(db, req.ctx, id, 'any', 'patient.read');
    const [p] = await db.select().from(patients).where(eq(patients.id, id));
    await audit(db, req.ctx.actor, { action: 'patient.read', entityType: 'patient', entityId: id });
    return toPatientProfile(db, p, viewFromAccess(access));
  });

  app.patch('/patients/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({
        name: z.string().trim().min(1).max(100).optional(),
        dob: zDate.optional(),
        gender: zGender.optional(),
        bloodGroup: z.string().max(5).nullable().optional(),
        heightCm: z.number().positive().max(300).nullable().optional(),
        weightKg: z.number().positive().max(500).nullable().optional(),
        abhaNumber: z.string().max(40).nullable().optional(),
        abhaAddress: z.string().max(60).nullable().optional(),
      }),
      req.body,
    );
    const { abhaNumber, abhaAddress, ...fields } = body;
    const abha: Partial<typeof patients.$inferInsert> = {};
    if (abhaNumber !== undefined) {
      const v = abhaNumber === null || abhaNumber.trim() === '' ? null : normaliseAbhaNumber(abhaNumber);
      if (abhaNumber && !v) throw errors.validation('abhaNumber must have 14 digits', { field: 'abhaNumber' });
      abha.abhaNumber = v;
    }
    if (abhaAddress !== undefined) {
      const v = abhaAddress === null || abhaAddress.trim() === '' ? null : normaliseAbhaAddress(abhaAddress);
      if (abhaAddress && !v) throw errors.validation('abhaAddress must look like name@abdm or name@sbx', { field: 'abhaAddress' });
      abha.abhaAddress = v;
    }
    // Any change to the ABHA identifiers needs a fresh verification.
    if (Object.keys(abha).length) abha.abhaStatus = 'unverified';
    const access = await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'patient.update');
    const [p] = await db
      .update(patients)
      .set({ ...fields, ...abha, updatedAt: new Date() })
      .where(eq(patients.id, id))
      .returning();
    await audit(db, req.ctx.actor, { action: 'patient.update', entityType: 'patient', entityId: id, metadata: { fields: Object.keys(body) } });
    return toPatientProfile(db, p, viewFromAccess(access));
  });

  const provenanceFor = (roles: string[]) => (hasRole({ roles: roles as never }, 'doctor') ? 'clinician_verified' : 'patient_entered') as
    | 'clinician_verified'
    | 'patient_entered';

  app.post('/patients/:id/allergies', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({ substance: z.string().trim().min(1).max(100), reaction: z.string().max(200).optional(), severity: z.enum(['mild', 'moderate', 'severe']).optional() }),
      req.body,
    );
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'allergy.create');
    const [row] = await db
      .insert(allergies)
      .values({ patientId: id, substance: body.substance, reaction: body.reaction ?? null, severity: body.severity ?? null, source: provenanceFor(req.ctx.user.roles) })
      .returning();
    await audit(db, req.ctx.actor, { action: 'allergy.create', entityType: 'allergy', entityId: row.id, metadata: { patientId: id } });
    return reply.code(201).send(toAllergy(row));
  });

  app.delete('/patients/:id/allergies/:allergyId', async (req, reply) => {
    const { id, allergyId } = parse(z.object({ id: zUuid, allergyId: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'allergy.delete');
    const del = await db.delete(allergies).where(and(eq(allergies.id, allergyId), eq(allergies.patientId, id))).returning({ id: allergies.id });
    if (!del.length) throw errors.notFound('Allergy');
    await audit(db, req.ctx.actor, { action: 'allergy.delete', entityType: 'allergy', entityId: allergyId, metadata: { patientId: id } });
    return reply.code(204).send();
  });

  app.post('/patients/:id/conditions', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ name: z.string().trim().min(1).max(100), since: z.string().max(40).optional() }), req.body);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'condition.create');
    const [row] = await db
      .insert(conditions)
      .values({ patientId: id, name: body.name, since: body.since ?? null, source: provenanceFor(req.ctx.user.roles) })
      .returning();
    await audit(db, req.ctx.actor, { action: 'condition.create', entityType: 'condition', entityId: row.id, metadata: { patientId: id } });
    return reply.code(201).send(toCondition(row));
  });

  app.delete('/patients/:id/conditions/:conditionId', async (req, reply) => {
    const { id, conditionId } = parse(z.object({ id: zUuid, conditionId: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'condition.delete');
    const del = await db.delete(conditions).where(and(eq(conditions.id, conditionId), eq(conditions.patientId, id))).returning({ id: conditions.id });
    if (!del.length) throw errors.notFound('Condition');
    await audit(db, req.ctx.actor, { action: 'condition.delete', entityType: 'condition', entityId: conditionId, metadata: { patientId: id } });
    return reply.code(204).send();
  });

  app.post('/patients/:id/emergency-contacts', async (req, reply) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ name: z.string().trim().min(1).max(100), phone: zPhone, relation: z.string().trim().min(1).max(40) }), req.body);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'emergency_contact.create');
    const [row] = await db.insert(emergencyContacts).values({ patientId: id, ...body }).returning();
    await audit(db, req.ctx.actor, { action: 'emergency_contact.create', entityType: 'emergency_contact', entityId: row.id, metadata: { patientId: id } });
    return reply.code(201).send(toEmergencyContact(row));
  });

  app.delete('/patients/:id/emergency-contacts/:contactId', async (req, reply) => {
    const { id, contactId } = parse(z.object({ id: zUuid, contactId: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'emergency_contact.delete');
    const del = await db
      .delete(emergencyContacts)
      .where(and(eq(emergencyContacts.id, contactId), eq(emergencyContacts.patientId, id)))
      .returning({ id: emergencyContacts.id });
    if (!del.length) throw errors.notFound('Emergency contact');
    await audit(db, req.ctx.actor, { action: 'emergency_contact.delete', entityType: 'emergency_contact', entityId: contactId, metadata: { patientId: id } });
    return reply.code(204).send();
  });

  // Contract section 39: ABHA verification is an adapter stub until ABDM sandbox certification.
  const abdm = new NotConnectedAbdmGateway();
  app.post('/patients/:id/abha/verify', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    await assertCanActForPatient(db, req.ctx, id, 'manage_care', 'patient.abha_verify');
    if (!svc.config.ABDM_ENABLED) throw errors.dependency(ABDM_PENDING_MESSAGE);
    const [p] = await db.select().from(patients).where(eq(patients.id, id));
    if (!p.abhaNumber && !p.abhaAddress) throw errors.validation('Add an ABHA number or address first');
    await abdm.verifyAbha({ abhaNumber: p.abhaNumber, abhaAddress: p.abhaAddress });
    throw errors.dependency(ABDM_PENDING_MESSAGE);
  });
}
