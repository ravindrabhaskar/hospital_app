import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { auditLogs, devices, emergencyContacts, familyAccessGrants, patients, users } from '../src/db/schema.js';
import { SEED_PHONES, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

describe('account deletion (contract section 23)', () => {
  it('schedule -> get -> cancel -> reschedule is idempotent', async () => {
    const s = await t.login('+919822200001');
    expect((await t.req(s.accessToken, 'GET', '/me/deletion-request')).status).toBe(404);
    const r = await t.req(s.accessToken, 'POST', '/me/deletion-request', { reason: 'Not using the app' });
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ status: 'scheduled', reason: 'Not using the app', completedAt: null });
    const days = (new Date(r.body.scheduledFor).getTime() - new Date(r.body.requestedAt).getTime()) / 86400_000;
    expect(Math.round(days)).toBe(7);
    const again = await t.req(s.accessToken, 'POST', '/me/deletion-request', {});
    expect(again.status).toBe(200);
    expect(again.body.id).toBe(r.body.id);
    expect((await t.req(s.accessToken, 'GET', '/me/deletion-request')).body.id).toBe(r.body.id);
    const c = await t.req(s.accessToken, 'POST', '/me/deletion-request/cancel');
    expect(c.status).toBe(200);
    expect(c.body.status).toBe('cancelled');
    expect((await t.req(s.accessToken, 'POST', '/me/deletion-request/cancel')).status).toBe(409);
    // Cancelled: the worker must not delete anything.
    await t.scheduler.tick(new Date(Date.now() + 8 * 86400_000));
    expect((await t.req(s.accessToken, 'GET', '/me')).status).toBe(200);
  });

  it('staff cannot self-delete (403, audited)', async () => {
    for (const phone of [SEED_PHONES.ananya, SEED_PHONES.sunita, SEED_PHONES.admin]) {
      const s = await t.login(phone);
      const r = await t.req(s.accessToken, 'POST', '/me/deletion-request', {});
      expect(r.status).toBe(403);
    }
    const denied = await t.svc.db.select().from(auditLogs).where(eq(auditLogs.action, 'account.deletion_request'));
    expect(denied.filter((a) => a.outcome === 'denied').length).toBeGreaterThanOrEqual(3);
  });

  it('worker completes the deletion after the grace period: anonymised, revoked, retention hold respected', async () => {
    const phone = '+919822200002';
    const s = await t.login(phone);
    const tok = s.accessToken;
    await t.req(tok, 'PATCH', '/me', { name: 'Delete Me' });
    const dep = await t.req(tok, 'POST', '/patients', { name: 'Dependent One', dob: '1950-01-01', gender: 'female', relation: 'mother' });
    const held = await t.req(tok, 'POST', '/patients', { name: 'Held Dependent', dob: '1948-01-01', gender: 'male', relation: 'father' });
    expect(dep.status).toBe(201);
    await t.req(tok, 'POST', `/patients/${dep.body.id}/emergency-contacts`, { name: 'Neighbour', phone: '+919822299999', relation: 'neighbour' });
    await t.req(tok, 'POST', `/patients/${dep.body.id}/family-access`, { granteePhone: '+919822200003', relation: 'sibling', permissions: ['view_records'] });
    await t.req(tok, 'POST', '/devices', { pushToken: 'device-token-delete-me', platform: 'android' });
    await t.svc.db.update(patients).set({ retentionHold: true }).where(eq(patients.id, held.body.id));

    const r = await t.req(tok, 'POST', '/me/deletion-request', {});
    expect(r.status).toBe(201);
    // Not yet due
    expect((await t.scheduler.tick(new Date())).accountDeletions).toBe(0);
    const res = await t.scheduler.tick(new Date(Date.now() + 8 * 86400_000));
    expect(res.accountDeletions).toBe(1);

    expect((await t.req(tok, 'GET', '/me')).status).toBe(401);
    const [u] = await t.svc.db.select().from(users).where(eq(users.id, s.user.id));
    expect(u).toMatchObject({ name: null, email: null, status: 'deleted', selfPatientId: null });
    expect(u.phone).toBe(`deleted:${s.user.id}`);
    expect(await t.svc.db.select().from(devices).where(eq(devices.userId, s.user.id))).toHaveLength(0);
    const [d] = await t.svc.db.select().from(patients).where(eq(patients.id, dep.body.id));
    expect(d).toMatchObject({ name: 'Deleted patient', dob: null, ownerUserId: null });
    expect(d.anonymisedAt).toBeTruthy();
    expect(await t.svc.db.select().from(emergencyContacts).where(eq(emergencyContacts.patientId, dep.body.id))).toHaveLength(0);
    const [h] = await t.svc.db.select().from(patients).where(eq(patients.id, held.body.id));
    expect(h.name).toBe('Held Dependent'); // legal hold: retained, but detached
    expect(h.ownerUserId).toBeNull();
    const grants = await t.svc.db.select().from(familyAccessGrants).where(eq(familyAccessGrants.patientId, dep.body.id));
    expect(grants.every((g) => g.status === 'revoked')).toBe(true);
    const done = await t.svc.db.select().from(auditLogs).where(eq(auditLogs.action, 'account.deletion_completed'));
    expect(done.some((a) => a.entityId === s.user.id)).toBe(true);

    // The phone number can sign up again as a brand-new account.
    const fresh = await t.login(phone);
    expect(fresh.user.id).not.toBe(s.user.id);
  });
});

describe('data export (contract section 23)', () => {
  it('generates a JSON export with the managed patients data; only the owner can download it', async () => {
    const v = await t.login(SEED_PHONES.vaibhav);
    const r = await t.req(v.accessToken, 'POST', '/me/data-export');
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ status: 'ready' });
    expect(r.body.sizeBytes).toBeGreaterThan(100);
    expect(new Date(r.body.expiresAt).getTime()).toBeGreaterThan(Date.now());

    const file = await t.req(v.accessToken, 'GET', `/me/data-export/${r.body.id}/file`);
    expect(file.status).toBe(200);
    expect(file.headers['content-type']).toContain('application/json');
    expect(file.headers['content-disposition']).toMatch(/^attachment; filename="carecompanion-export-/);
    const doc = file.body;
    expect(doc.profile).toMatchObject({ phone: SEED_PHONES.vaibhav });
    expect(doc.consents.length).toBeGreaterThanOrEqual(3);
    const rk = doc.patients.find((p: any) => p.profile.name === 'Ramesh Kumar');
    expect(rk.records.length).toBeGreaterThanOrEqual(4);
    expect(rk.records[0].storageKey).toBeUndefined();
    expect(rk.medications.map((m: any) => m.name)).toEqual(expect.arrayContaining(['Metformin', 'Amlodipine']));
    expect(rk.allergies[0].substance).toMatch(/penicillin/i);
    for (const k of ['careEpisodes', 'appointments', 'homeVisits', 'carePlans', 'vitals']) expect(Array.isArray(rk[k])).toBe(true);
    expect(rk.homeVisits.every((hv: any) => hv.visitCode === undefined)).toBe(true);
    expect(Array.isArray(doc.aiConversations)).toBe(true);

    const l = await t.login(SEED_PHONES.lakshmi);
    expect((await t.req(l.accessToken, 'GET', `/me/data-export/${r.body.id}/file`)).status).toBe(404);
    expect((await t.req(null, 'GET', `/me/data-export/${r.body.id}/file`)).status).toBe(401);

    // Expired exports are purged by the worker.
    const res = await t.scheduler.tick(new Date(Date.now() + 4 * 86400_000));
    expect(res.expireDataExports).toBeGreaterThanOrEqual(1);
    expect((await t.req(v.accessToken, 'GET', `/me/data-export/${r.body.id}/file`)).status).toBe(404);
  });
});
