import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  careEpisodes,
  doctorLeaves,
  facilities,
  payments,
  prescriptions,
  providerApplicationDocuments,
  providerApplications,
  referrals,
  reviews,
  schemes,
} from '../src/db/schema.js';
import { addDays, istDate } from '../src/lib/time.js';
import { SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

/**
 * v1.2 authorization matrix: every new endpoint answers 401 without a token, 403 for a role that must not use it,
 * and is reachable (not 401/403) for a role that may.
 */
let t: TestCtx;
const tok: Record<string, string> = {};
const ids: Record<string, string> = {};

beforeAll(async () => {
  t = await setup();
  for (const [k, phone] of Object.entries({
    vaibhav: SEED_PHONES.vaibhav,
    lakshmi: SEED_PHONES.lakshmi,
    ananya: SEED_PHONES.ananya,
    priya: SEED_PHONES.priya,
    sunita: SEED_PHONES.sunita,
    meera: SEED_PHONES.meera,
    ops: SEED_PHONES.ops,
    admin: SEED_PHONES.admin,
    kavya: SEED_PHONES.kavya,
    stranger: '+919844400001',
  })) {
    tok[k] = (await t.login(phone)).accessToken;
  }
  ids.ramesh = await rameshId(t, tok.vaibhav);
  ids.ananyaDoctor = (await t.login(SEED_PHONES.ananya)).user.providerId;
  [{ id: ids.episode }] = await t.svc.db.select({ id: careEpisodes.id }).from(careEpisodes).where(eq(careEpisodes.patientId, ids.ramesh));
  [{ id: ids.application }] = await t.svc.db.select({ id: providerApplications.id }).from(providerApplications);
  [{ id: ids.appDoc }] = await t.svc.db.select({ id: providerApplicationDocuments.id }).from(providerApplicationDocuments);
  [{ id: ids.rx }] = await t.svc.db.select({ id: prescriptions.id }).from(prescriptions);
  [{ id: ids.payment }] = await t.svc.db.select({ id: payments.id }).from(payments).where(eq(payments.status, 'succeeded'));
  [{ id: ids.review }] = await t.svc.db.select({ id: reviews.id }).from(reviews).where(eq(reviews.status, 'pending'));
  [{ id: ids.referral }] = await t.svc.db.select({ id: referrals.id }).from(referrals);
  [{ id: ids.scheme }] = await t.svc.db.select({ id: schemes.id }).from(schemes);
  [{ id: ids.facility }] = await t.svc.db.select({ id: facilities.id }).from(facilities);
  const [leave] = await t.svc.db.insert(doctorLeaves).values({ doctorId: ids.ananyaDoctor, date: addDays(istDate(), 40) }).returning();
  ids.leave = leave.id;
});
afterAll(async () => t.close());

type Case = { name: string; method: string; url: () => string; body?: () => unknown; allow: string; deny: string[] };
const weekly = { weekly: [{ weekday: 1, start: '09:00', end: '10:00', slotMins: 30, modes: ['video'] }] };

const CASES: Case[] = [
  // section 29
  { name: 'doctor profile read', method: 'GET', url: () => '/doctor/me/profile', allow: 'ananya', deny: ['vaibhav', 'sunita', 'ops'] },
  { name: 'doctor profile update', method: 'PATCH', url: () => '/doctor/me/profile', body: () => ({ bio: 'x' }), allow: 'ananya', deny: ['vaibhav', 'sunita', 'admin'] },
  { name: 'doctor schedule read', method: 'GET', url: () => '/doctor/me/schedule', allow: 'ananya', deny: ['vaibhav', 'meera'] },
  { name: 'doctor schedule write', method: 'PUT', url: () => '/doctor/me/schedule', body: () => weekly, allow: 'priya', deny: ['vaibhav', 'ops'] },
  { name: 'doctor leave create', method: 'POST', url: () => '/doctor/me/leaves', body: () => ({ date: addDays(istDate(), 30) }), allow: 'ananya', deny: ['vaibhav', 'sunita'] },
  { name: 'doctor leave delete', method: 'DELETE', url: () => `/doctor/me/leaves/${ids.leave}`, allow: 'ananya', deny: ['vaibhav', 'ops'] },
  { name: 'admin schedule read', method: 'GET', url: () => `/admin/doctors/${ids.ananyaDoctor}/schedule`, allow: 'ops', deny: ['ananya', 'meera', 'vaibhav'] },
  { name: 'admin schedule write', method: 'PUT', url: () => `/admin/doctors/${ids.ananyaDoctor}/schedule`, body: () => ({ weekly: [] }), allow: 'admin', deny: ['ananya', 'meera'] },
  // section 30
  { name: 'application me', method: 'GET', url: () => '/provider-applications/me', allow: 'kavya', deny: [] },
  { name: 'ops application list', method: 'GET', url: () => '/ops/provider-applications', allow: 'meera', deny: ['vaibhav', 'ananya', 'sunita', 'kavya'] },
  { name: 'ops application read', method: 'GET', url: () => `/ops/provider-applications/${ids.application}`, allow: 'ops', deny: ['kavya', 'ananya'] },
  { name: 'ops application document', method: 'GET', url: () => `/ops/provider-applications/${ids.application}/documents/${ids.appDoc}/file`, allow: 'admin', deny: ['kavya', 'vaibhav'] },
  {
    name: 'ops application decision',
    method: 'POST',
    url: () => `/ops/provider-applications/${ids.application}/decision`,
    body: () => ({ decision: 'request_changes', note: 'Please re-upload' }),
    allow: 'ops',
    deny: ['meera', 'kavya', 'ananya'],
  },
  // section 31
  { name: 'prescription create', method: 'POST', url: () => '/clinician/prescriptions', body: () => ({ appointmentId: ids.ramesh, items: [] }), allow: 'ananya', deny: ['vaibhav', 'meera', 'sunita'] },
  { name: 'prescription list', method: 'GET', url: () => `/prescriptions?patientId=${ids.ramesh}`, allow: 'lakshmi', deny: ['stranger', 'priya', 'sunita'] },
  { name: 'prescription read', method: 'GET', url: () => `/prescriptions/${ids.rx}`, allow: 'ananya', deny: ['stranger', 'priya'] },
  { name: 'prescription pdf', method: 'GET', url: () => `/prescriptions/${ids.rx}/pdf`, allow: 'vaibhav', deny: ['stranger', 'sunita'] },
  { name: 'prescription pharmacy match', method: 'GET', url: () => `/prescriptions/${ids.rx}/pharmacy-match`, allow: 'vaibhav', deny: ['stranger'] },
  // section 32
  { name: 'invoice', method: 'GET', url: () => `/payments/${ids.payment}/invoice`, allow: 'vaibhav', deny: ['lakshmi', 'stranger', 'ananya', 'meera'] },
  { name: 'invoice pdf', method: 'GET', url: () => `/payments/${ids.payment}/invoice.pdf`, allow: 'ops', deny: ['lakshmi', 'stranger', 'meera'] },
  { name: 'provider earnings', method: 'GET', url: () => '/provider/earnings', allow: 'sunita', deny: ['vaibhav', 'ops', 'meera'] },
  { name: 'settlements', method: 'GET', url: () => '/ops/settlements', allow: 'admin', deny: ['meera', 'ananya', 'vaibhav'] },
  { name: 'settlements csv', method: 'GET', url: () => '/ops/settlements.csv', allow: 'ops', deny: ['meera', 'sunita'] },
  // section 33
  { name: 'reviews pending', method: 'GET', url: () => `/reviews/pending?patientId=${ids.ramesh}`, allow: 'vaibhav', deny: ['lakshmi', 'ananya', 'ops'] },
  { name: 'review create', method: 'POST', url: () => '/reviews', body: () => ({ targetType: 'appointment', targetId: ids.ramesh, rating: 5 }), allow: 'vaibhav', deny: [] },
  { name: 'ops reviews', method: 'GET', url: () => '/ops/reviews', allow: 'meera', deny: ['vaibhav', 'ananya', 'sunita'] },
  { name: 'moderate review', method: 'POST', url: () => `/ops/reviews/${ids.review}/moderate`, body: () => ({ status: 'published' }), allow: 'meera', deny: ['vaibhav', 'ananya'] },
  // section 34
  { name: 'inbox', method: 'GET', url: () => '/inbox', allow: 'lakshmi', deny: [] },
  { name: 'messages read', method: 'GET', url: () => `/care-episodes/${ids.episode}/messages`, allow: 'vaibhav', deny: ['lakshmi', 'priya', 'sunita', 'stranger'] },
  { name: 'message post', method: 'POST', url: () => `/care-episodes/${ids.episode}/messages`, body: () => ({ text: 'Hello team' }), allow: 'meera', deny: ['lakshmi', 'priya', 'sunita'] },
  { name: 'messages mark read', method: 'POST', url: () => `/care-episodes/${ids.episode}/messages/read`, allow: 'ananya', deny: ['lakshmi', 'sunita'] },
  // section 35
  { name: 'assign coordinator', method: 'POST', url: () => `/ops/care-episodes/${ids.episode}/assign-coordinator`, body: () => ({ userId: '00000000-0000-0000-0000-000000000000' }), allow: 'ops', deny: ['vaibhav', 'ananya', 'sunita'] },
  { name: 'caseload', method: 'GET', url: () => '/coordinator/caseload', allow: 'meera', deny: ['vaibhav', 'ananya', 'ops'] },
  { name: 'contact create', method: 'POST', url: () => '/coordinator/contacts', body: () => ({ patientId: ids.ramesh, channel: 'call', outcome: 'reached', note: 'ok' }), allow: 'meera', deny: ['vaibhav', 'ananya', 'sunita'] },
  { name: 'contact list', method: 'GET', url: () => `/coordinator/contacts?patientId=${ids.ramesh}`, allow: 'ops', deny: ['vaibhav', 'ananya'] },
  // section 36
  {
    name: 'referral create',
    method: 'POST',
    url: () => '/clinician/referrals',
    body: () => ({ careEpisodeId: ids.episode, facilityId: ids.facility, urgency: 'routine', reason: 'Assessment' }),
    allow: 'ananya',
    deny: ['vaibhav', 'priya', 'meera'],
  },
  { name: 'referral list', method: 'GET', url: () => `/referrals?patientId=${ids.ramesh}`, allow: 'lakshmi', deny: ['stranger', 'sunita'] },
  { name: 'referral update', method: 'PATCH', url: () => `/referrals/${ids.referral}`, body: () => ({ status: 'accepted' }), allow: 'ananya', deny: ['vaibhav', 'priya', 'sunita'] },
  // section 37
  { name: 'plans', method: 'GET', url: () => '/subscription-plans', allow: 'vaibhav', deny: [] },
  { name: 'my subscription', method: 'GET', url: () => '/subscriptions/me', allow: 'vaibhav', deny: [] },
  { name: 'admin plans', method: 'GET', url: () => '/admin/subscription-plans', allow: 'admin', deny: ['ops', 'vaibhav'] },
  { name: 'admin plan create', method: 'POST', url: () => '/admin/subscription-plans', body: () => ({}), allow: 'admin', deny: ['ops', 'meera'] },
  { name: 'admin plan update', method: 'PATCH', url: () => '/admin/subscription-plans/family_basic', body: () => ({ description: 'Updated' }), allow: 'admin', deny: ['ops', 'vaibhav'] },
  // section 38
  { name: 'schemes', method: 'GET', url: () => '/schemes', allow: 'vaibhav', deny: [] },
  { name: 'scheme', method: 'GET', url: () => `/schemes/${ids.scheme}`, allow: 'sunita', deny: [] },
  { name: 'admin schemes', method: 'GET', url: () => '/admin/schemes', allow: 'admin', deny: ['ops', 'meera', 'vaibhav'] },
  { name: 'admin scheme read', method: 'GET', url: () => `/admin/schemes/${ids.scheme}`, allow: 'admin', deny: ['ops'] },
  { name: 'admin scheme create', method: 'POST', url: () => '/admin/schemes', body: () => ({}), allow: 'admin', deny: ['ops', 'vaibhav'] },
  { name: 'admin scheme update', method: 'PATCH', url: () => `/admin/schemes/${ids.scheme}`, body: () => ({ helpline: '14555' }), allow: 'admin', deny: ['ops', 'meera'] },
  // section 39
  { name: 'abha verify', method: 'POST', url: () => `/patients/${ids.ramesh}/abha/verify`, allow: 'vaibhav', deny: ['lakshmi', 'stranger', 'sunita'] },
];

describe('v1.2 RBAC matrix', () => {
  for (const c of CASES) {
    it(`${c.method} ${c.name}`, async () => {
      const body = c.body?.();
      const anon = await t.req(null, c.method, c.url(), body);
      expect(anon.status, `${c.name} anonymous`).toBe(401);
      for (const who of c.deny) {
        const r = await t.req(tok[who], c.method, c.url(), body);
        expect(r.status, `${c.name} as ${who}: ${JSON.stringify(r.body)}`).toBe(403);
      }
      const ok = await t.req(tok[c.allow], c.method, c.url(), body);
      expect([401, 403], `${c.name} as ${c.allow}: ${ok.status} ${JSON.stringify(ok.body)}`).not.toContain(ok.status);
    });
  }

  it('public /media is reachable without a token (404 for unknown ids)', async () => {
    expect((await t.req(null, 'GET', '/media/00000000-0000-0000-0000-000000000000')).status).toBe(404);
  });

  it('/me/photo requires authentication', async () => {
    expect((await t.req(null, 'POST', '/me/photo', {})).status).toBe(401);
  });

  it('provider applications: any signed-in user may apply once', async () => {
    const body = { type: 'nurse', fullName: 'A', qualification: 'GNM', registrationNumber: 'R', experienceYears: 1, languages: [], preferredZoneIds: [] };
    expect((await t.req(null, 'POST', '/provider-applications', body)).status).toBe(401);
    expect((await t.req(tok.stranger, 'POST', '/provider-applications', body)).status).toBe(201);
    expect((await t.req(tok.kavya, 'POST', '/provider-applications', body)).status).toBe(409);
    expect((await t.req(tok.sunita, 'POST', '/provider-applications', body)).status).toBe(409); // already a provider
  });
});
