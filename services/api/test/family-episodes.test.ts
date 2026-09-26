import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { TRANSITIONS, canTransition, EPISODE_STATUSES } from '../src/modules/episodes/service.js';
import { SEED_PHONES, idem, rameshId, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let lakshmi: string;
let ramesh: string;
beforeAll(async () => {
  t = await setup();
  vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
  lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
  ramesh = await rameshId(t, vaibhav);
});
afterAll(async () => t.close());

describe('family access', () => {
  it('seeded grant allows only the listed permissions', async () => {
    const list = await t.req(lakshmi, 'GET', '/patients');
    const r = list.body.items.find((p: any) => p.id === ramesh);
    expect(r).toMatchObject({ relation: 'daughter-in-law', isSelf: false });
    expect(r.permissions.sort()).toEqual(['receive_alerts', 'view_records']);
    // view_records: allowed
    expect((await t.req(lakshmi, 'GET', `/records?patientId=${ramesh}`)).status).toBe(200);
    expect((await t.req(lakshmi, 'GET', `/timeline?patientId=${ramesh}`)).status).toBe(200);
    // manage_care: denied
    const ep = await t.req(lakshmi, 'POST', '/care-episodes', { patientId: ramesh, title: 'x', concern: 'y' }, idem());
    expect(ep.status).toBe(403);
    expect((await t.req(lakshmi, 'POST', '/vitals', { patientId: ramesh, type: 'pulse', value: 70, unit: 'bpm', measuredAt: new Date().toISOString() })).status).toBe(403);
    // book: denied
    expect((await t.req(lakshmi, 'GET', `/payments?patientId=${ramesh}`)).status).toBe(403);
    // owner-only: denied
    expect((await t.req(lakshmi, 'GET', `/patients/${ramesh}/family-access`)).status).toBe(403);
  });

  it('owner grants new access, grantee is auto-created, revoke takes effect immediately', async () => {
    const g = await t.req(vaibhav, 'POST', `/patients/${ramesh}/family-access`, {
      granteePhone: '+919866666666',
      relation: 'nephew',
      permissions: ['book'],
    });
    expect(g.status).toBe(201);
    expect(g.body).toMatchObject({ patientId: ramesh, relation: 'nephew', permissions: ['book'], status: 'active', granteePhone: '+919866666666' });
    const nephew = (await t.login('+919866666666')).accessToken;
    expect((await t.req(nephew, 'GET', `/payments?patientId=${ramesh}`)).status).toBe(200);
    expect((await t.req(nephew, 'GET', `/records?patientId=${ramesh}`)).status).toBe(403);

    const rv = await t.req(vaibhav, 'POST', `/family-access/${g.body.id}/revoke`);
    expect(rv.status).toBe(200);
    expect(rv.body.status).toBe('revoked');
    expect((await t.req(nephew, 'GET', `/payments?patientId=${ramesh}`)).status).toBe(403);
    const pl = await t.req(nephew, 'GET', '/patients');
    expect(pl.body.items.some((p: any) => p.id === ramesh)).toBe(false);
  });

  it('dependent creation gives the caller all permissions', async () => {
    const r = await t.req(vaibhav, 'POST', '/patients', { name: 'Saroja Kumar', dob: '1962-04-02', gender: 'female', relation: 'mother' });
    expect(r.status).toBe(201);
    expect(r.body.permissions.sort()).toEqual(['book', 'manage_care', 'receive_alerts', 'view_records']);
    expect(r.body.relation).toBe('mother');
  });
});

describe('care episode state machine', () => {
  it('unit: every listed transition is allowed; terminal states have none', () => {
    for (const from of EPISODE_STATUSES) {
      for (const to of EPISODE_STATUSES) {
        const expected = TRANSITIONS[from].includes(to) || (from === 'RESOLVED' && to === 'FOLLOW_UP' && false);
        expect(canTransition(from, to, ['patient']), `${from}->${to}`).toBe(expected);
      }
    }
    expect(canTransition('RESOLVED', 'FOLLOW_UP', ['doctor'])).toBe(true);
    expect(canTransition('RESOLVED', 'FOLLOW_UP', ['patient'])).toBe(false);
    expect(TRANSITIONS.CANCELLED).toEqual([]);
    expect(TRANSITIONS.TRANSFERRED).toEqual([]);
  });

  it('API: happy path through every main state appends events; invalid ones fail', async () => {
    const c = await t.req(vaibhav, 'POST', '/care-episodes', { patientId: ramesh, title: 'Knee pain', concern: 'Knee pain for 2 weeks' }, idem());
    expect(c.status).toBe(201);
    expect(c.body.status).toBe('NEW');
    const id = c.body.id;
    const path = ['INTAKE', 'AWAITING_CARE', 'CARE_SCHEDULED', 'UNDER_CARE', 'FOLLOW_UP', 'ESCALATED', 'EMERGENCY', 'UNDER_CARE', 'RESOLVED'];
    for (const to of path) {
      const r = await t.req(vaibhav, 'POST', `/care-episodes/${id}/transition`, { to, reason: `move to ${to}` });
      expect(r.status, to).toBe(200);
      expect(r.body.status).toBe(to);
    }
    // invalid: RESOLVED is terminal for patients
    const bad = await t.req(vaibhav, 'POST', `/care-episodes/${id}/transition`, { to: 'FOLLOW_UP', reason: 'x' });
    expect(bad.status).toBe(409);
    expect(bad.body.error.code).toBe('INVALID_STATE_TRANSITION');
    // doctor may re-open RESOLVED -> FOLLOW_UP (needs a relationship: Ananya owns Ramesh's seeded episode)
    const ananya = (await t.login(SEED_PHONES.ananya)).accessToken;
    const reopen = await t.req(ananya, 'POST', `/care-episodes/${id}/transition`, { to: 'FOLLOW_UP', reason: 'review' });
    expect(reopen.status).toBe(200);

    const d = await t.req(vaibhav, 'GET', `/care-episodes/${id}`);
    const changes = d.body.events.filter((e: any) => e.type === 'status_changed' || e.type === 'escalated');
    expect(changes).toHaveLength(path.length + 1);
    expect(d.body.events[0].type).toBe('created');
  });

  it('API: a sample of invalid transitions fail', async () => {
    const samples: Array<[string[], string]> = [
      [[], 'UNDER_CARE'],
      [[], 'RESOLVED'],
      [['CANCELLED'], 'NEW'],
      [['AWAITING_CARE'], 'FOLLOW_UP'],
      [['CARE_SCHEDULED'], 'RESOLVED'],
      [['EMERGENCY'], 'CANCELLED'],
    ];
    for (const [setupPath, to] of samples) {
      const c = await t.req(vaibhav, 'POST', '/care-episodes', { patientId: ramesh, title: 't', concern: 'c' }, idem());
      for (const s of setupPath) expect((await t.req(vaibhav, 'POST', `/care-episodes/${c.body.id}/transition`, { to: s, reason: 'r' })).status).toBe(200);
      const r = await t.req(vaibhav, 'POST', `/care-episodes/${c.body.id}/transition`, { to, reason: 'r' });
      expect(r.status, `${setupPath.join('>')}->${to}`).toBe(409);
      expect(r.body.error.code).toBe('INVALID_STATE_TRANSITION');
    }
  });

  it('seeded episode detail has care plan, appointment and home visit', async () => {
    const list = await t.req(vaibhav, 'GET', `/care-episodes?patientId=${ramesh}&active=true`);
    const seeded = list.body.items.find((e: any) => e.title === 'Blood pressure & diabetes follow-up');
    expect(seeded).toMatchObject({ status: 'FOLLOW_UP', ownerName: 'Dr. Ananya Rao' });
    const d = await t.req(vaibhav, 'GET', `/care-episodes/${seeded.id}`);
    expect(d.body.carePlans[0].medications.map((m: any) => m.name).sort()).toEqual(['Amlodipine', 'Metformin']);
    expect(d.body.appointments[0].status).toBe('completed');
    expect(d.body.homeVisits[0].status).toBe('completed');
    expect(d.body.homeVisits[0].visitCode).toBe('4821'); // family view
  });
});
