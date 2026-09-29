import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { checkins, safetyEvents, supportTickets, users, vitals } from '../src/db/schema.js';
import { istDate } from '../src/lib/time.js';
import { signBody } from '../src/lib/webhooks.js';
import { toTwiml } from '../src/modules/ivr/routes.js';
import type { MockWhatsApp } from '../src/modules/partners/index.js';
import { handleInbound, parseReading } from '../src/modules/whatsapp/service.js';
import { P, SEED_PHONES, setup, type TestCtx } from './helpers.js';

let t: TestCtx;
let vaibhav: string;
let lakshmi: string;
let vSelf: string;

beforeAll(async () => {
  t = await setup();
  const v = await t.login(SEED_PHONES.vaibhav);
  vaibhav = v.accessToken;
  vSelf = v.user.selfPatientId;
  lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
});
afterAll(async () => t.close());

const sim = async (token: string, text: string) => {
  const r = await t.req(token, 'POST', '/dev/whatsapp/simulate', { text });
  expect(r.status).toBe(200);
  return r.body.replies as string[];
};

const post = (url: string, body: unknown, headers: Record<string, string>) =>
  t.app.inject({ method: 'POST', url: `${P}${url}`, payload: typeof body === 'string' ? body : JSON.stringify(body), headers: { 'content-type': 'application/json', ...headers } });

describe('WhatsApp command parsing', () => {
  it('parses BP and SUGAR readings strictly', () => {
    expect(parseReading('BP 138/88')).toEqual([
      { type: 'bp_systolic', value: 138, unit: 'mmHg' },
      { type: 'bp_diastolic', value: 88, unit: 'mmHg' },
    ]);
    expect(parseReading('sugar 142')).toEqual([{ type: 'blood_glucose', value: 142, unit: 'mg/dL' }]);
    expect(parseReading('BP 88/138')).toBe('invalid');
    expect(parseReading('BP high')).toBe('invalid');
    expect(parseReading('hello')).toBeNull();
  });
});

describe('WhatsApp assistant (section 43) via the dev simulator', () => {
  it('only opted-in users are served; START opts in (consent recorded); STOP opts out', async () => {
    expect((await t.req(vaibhav, 'GET', '/me/whatsapp')).body).toMatchObject({ optedIn: false, phone: SEED_PHONES.vaibhav, optedInAt: null });
    expect((await sim(vaibhav, 'TODAY'))[0]).toMatch(/not subscribed/i);
    expect((await sim(vaibhav, 'START'))[0]).toMatch(/Welcome/);
    const st = await t.req(vaibhav, 'GET', '/me/whatsapp');
    expect(st.body.optedIn).toBe(true);
    expect(st.body.optedInAt).toBeTruthy();
    const consents = await t.req(vaibhav, 'GET', '/consents');
    expect(consents.body.items.some((c: any) => c.purpose === 'whatsapp_messaging' && c.status === 'granted')).toBe(true);
  });

  it('TODAY lists reminders for the family; CHECKIN records the check-in; BOOK sends deep links', async () => {
    const today = await sim(vaibhav, 'today');
    expect(today[0]).toMatch(/Ramesh Kumar: .*Metformin/);
    expect((await sim(vaibhav, 'CHECKIN'))[0]).toMatch(/check-in/i);
    const rows = await t.svc.db.select().from(checkins).where(and(eq(checkins.patientId, vSelf), eq(checkins.date, istDate())));
    expect(rows[0]?.source).toBe('whatsapp');
    expect((await sim(vaibhav, 'OK'))[0]).toMatch(/check-in/i);
    expect((await sim(vaibhav, 'BOOK'))[0]).toMatch(/doctors/);
  });

  it('BP / SUGAR record patient-entered vitals; a dangerous reading is escalated by the safety engine', async () => {
    expect((await sim(vaibhav, 'BP 138/88'))[0]).toBe('Saved: BP 138/88 mmHg. Thank you.');
    expect((await sim(vaibhav, 'SUGAR 142'))[0]).toMatch(/Saved: Sugar 142/);
    const v = await t.svc.db.select().from(vitals).where(eq(vitals.patientId, vSelf));
    expect(v.filter((x) => x.source === 'patient_entered').map((x) => x.type).sort()).toEqual(['blood_glucose', 'bp_diastolic', 'bp_systolic']);
    expect((await sim(vaibhav, 'BP 150'))[0]).toMatch(/could not read/);
    const alert = await sim(vaibhav, 'BP 195/100');
    expect(alert[0]).toMatch(/needs attention/);
    const ev = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, vSelf), eq(safetyEvents.source, 'message')));
    expect(ev.some((e) => e.level === 'urgent')).toBe(true);
  });

  it('free text goes to the AI assistant; an emergency gets the fixed 108 template', async () => {
    const r = await sim(vaibhav, 'I have chest pain and sweating');
    expect(r.join(' ')).toMatch(/108/);
    const ev = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, vSelf), eq(safetyEvents.source, 'ai_intake'), eq(safetyEvents.level, 'emergency')));
    expect(ev.length).toBeGreaterThan(0);
    // STOP opts out; afterwards nothing is served
    expect((await sim(vaibhav, 'STOP'))[0]).toMatch(/unsubscribed/);
    expect((await t.req(vaibhav, 'GET', '/me/whatsapp')).body.optedIn).toBe(false);
    expect((await sim(vaibhav, 'TODAY'))[0]).toMatch(/not subscribed/i);
  });

  it('an emergency from an unsubscribed user still gets the 108 template and alerts ops', async () => {
    expect((await t.req(vaibhav, 'GET', '/me/whatsapp')).body.optedIn).toBe(false);
    const before = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, vSelf), eq(safetyEvents.source, 'message'), eq(safetyEvents.level, 'emergency')));
    const r = await sim(vaibhav, 'severe chest pain and cannot breathe');
    expect(r[0]).toMatch(/108/);
    const after = await t.svc.db.select().from(safetyEvents).where(and(eq(safetyEvents.patientId, vSelf), eq(safetyEvents.source, 'message'), eq(safetyEvents.level, 'emergency')));
    expect(after.length).toBe(before.length + 1);
    // Non-emergency text from an unsubscribed user is still not served.
    expect((await sim(vaibhav, 'what is a normal pulse'))[0]).toMatch(/not subscribed/i);
  });

  it('an emergency from an unknown number gets the 108 template; other text gets the unknown-user reply', async () => {
    expect((await handleInbound(t.svc, '+919999999999', 'he is unconscious'))[0]).toMatch(/108/);
    expect((await handleInbound(t.svc, '+919999999999', 'hello there'))[0]).toMatch(/not registered/);
  });

  it('without AI consent, free text is still screened by the safety engine', async () => {
    const put = await t.req(lakshmi, 'PUT', '/me/whatsapp', { optedIn: true });
    expect(put.body.optedIn).toBe(true);
    expect((await sim(lakshmi, 'what is a normal pulse'))[0]).toMatch(/AI assistance/);
    const em = await sim(lakshmi, "I can't breathe");
    expect(em[0]).toMatch(/108/);
  });
});

describe('WhatsApp webhook (Meta Cloud API)', () => {
  it('verify handshake', async () => {
    const ok = await t.app.inject({ method: 'GET', url: `${P}/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=${t.svc.config.WHATSAPP_VERIFY_TOKEN}&hub.challenge=abc123` });
    expect(ok.statusCode).toBe(200);
    expect(ok.body).toBe('abc123');
    const bad = await t.app.inject({ method: 'GET', url: `${P}/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=wrong-token-x&hub.challenge=abc` });
    expect(bad.statusCode).toBe(403);
  });

  it('rejects bad signatures; handles signed messages once (idempotent on message id) and replies through the adapter', async () => {
    const payload = JSON.stringify({ entry: [{ changes: [{ value: { messages: [{ id: 'wamid.TEST1', from: '919800000001', type: 'text', text: { body: 'START' } }] } }] }] });
    expect((await post('/webhooks/whatsapp', payload, {})).statusCode).toBe(401);
    expect((await post('/webhooks/whatsapp', payload, { 'x-hub-signature-256': 'sha256=' + 'a'.repeat(64) })).statusCode).toBe(401);
    const sig = 'sha256=' + signBody(t.svc.config.WHATSAPP_APP_SECRET, payload);
    const ok = await post('/webhooks/whatsapp', payload, { 'x-hub-signature-256': sig });
    expect(ok.statusCode).toBe(200);
    expect(JSON.parse(ok.body)).toMatchObject({ received: true, handled: 1 });
    const again = await post('/webhooks/whatsapp', payload, { 'x-hub-signature-256': sig });
    expect(JSON.parse(again.body).handled).toBe(0);
    const wa = t.svc.partners.whatsapp as MockWhatsApp;
    expect(wa.outbox.some((m) => m.to === SEED_PHONES.vaibhav && /Welcome/.test(m.text ?? ''))).toBe(true);
  });

  it('other partner webhooks reject missing or wrong HMAC signatures', async () => {
    for (const [url, header] of [
      ['/webhooks/lab/mock', 'x-lab-signature'],
      ['/webhooks/abdm', 'x-abdm-signature'],
      ['/webhooks/sos-button', 'x-sos-signature'],
      ['/webhooks/ivr/mock', 'x-ivr-signature'],
    ] as const) {
      const body = JSON.stringify({ eventId: 'e1' });
      expect((await post(url, body, {})).statusCode, url).toBe(401);
      expect((await post(url, body, { [header]: signBody('not-the-secret', body) })).statusCode, url).toBe(401);
    }
  });
});

describe('IVR (section 62)', () => {
  const ivr = async (body: Record<string, unknown>) => {
    const r = await t.req(null, 'POST', '/dev/ivr/simulate', body);
    return r;
  };

  it('requires authentication for the simulator', async () => {
    expect((await ivr({ fromPhone: SEED_PHONES.vaibhav })).status).toBe(401);
  });

  it('menu 1 (reminders), invalid option, 2 (check-in)', async () => {
    const start = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav });
    expect(start.status).toBe(200);
    expect(start.body).toMatchObject({ gather: 'digits', ended: false });
    expect(start.body.say).toMatch(/Press 1/);
    const sid = start.body.sessionId;
    const one = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav, sessionId: sid, digits: '1' });
    expect(one.body.say).toMatch(/Metformin/);
    expect(one.body.gather).toBe('digits');
    const bad = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav, sessionId: sid, digits: '7' });
    expect(bad.body.say).toMatch(/not a valid option/);
    const two = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav, sessionId: sid, digits: '2' });
    expect(two.body).toMatchObject({ gather: 'none', ended: true });
    expect(two.body.say).toMatch(/check-in/);
    // another caller cannot continue this session
    expect((await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.lakshmi, sessionId: sid, digits: '1' })).status).toBe(403);
  });

  it('menu 3 creates a high-priority call-back ticket; 9 transfers to the care team', async () => {
    const s = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.lakshmi });
    const r = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.lakshmi, sessionId: s.body.sessionId, digits: '3' });
    expect(r.body.ended).toBe(true);
    const lid = (await t.svc.db.select({ id: users.id }).from(users).where(eq(users.phone, SEED_PHONES.lakshmi)))[0].id;
    const tickets = await t.svc.db.select().from(supportTickets).where(eq(supportTickets.userId, lid));
    expect(tickets.some((x) => x.category === 'other' && x.priority === 'high' && x.source === 'ivr')).toBe(true);
    const s2 = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.lakshmi });
    const nine = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.lakshmi, sessionId: s2.body.sessionId, digits: '9' });
    expect(nine.body.say).toMatch(/Connecting/);
  });

  it('menu 4: spoken concern -> safety engine; an emergency says "call 108" and alerts ops', async () => {
    const s = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav });
    const four = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav, sessionId: s.body.sessionId, digits: '4' });
    expect(four.body.gather).toBe('speech');
    const before = (await t.svc.db.select().from(safetyEvents).where(eq(safetyEvents.patientId, vSelf))).length;
    const sp = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav, sessionId: s.body.sessionId, speechText: 'I have severe chest pain' });
    expect(sp.body.say).toMatch(/108/);
    expect(sp.body.ended).toBe(true);
    expect((await t.svc.db.select().from(safetyEvents).where(eq(safetyEvents.patientId, vSelf))).length).toBe(before + 1);
    // a non-emergency concern is noted
    const s2 = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav });
    await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav, sessionId: s2.body.sessionId, digits: '4' });
    const calm = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: SEED_PHONES.vaibhav, sessionId: s2.body.sessionId, speechText: 'I have a mild cough since two days' });
    expect(calm.body.say).toMatch(/noted/);
  });

  it('unknown callers hear the support number', async () => {
    const r = await t.req(vaibhav, 'POST', '/dev/ivr/simulate', { fromPhone: '+919811122233' });
    expect(r.body.ended).toBe(true);
    expect(r.body.say).toContain(t.svc.config.SUPPORT_PHONE);
  });

  it('provider webhook: signed callbacks drive the same menu; TwiML rendering for Twilio', async () => {
    const body = JSON.stringify({ CallSid: 'CA-test-1', From: '+919800000002' });
    const r = await post('/webhooks/ivr/mock', body, { 'x-ivr-signature': signBody(t.svc.config.IVR_WEBHOOK_SECRET, body) });
    expect(r.statusCode).toBe(200);
    expect(JSON.parse(r.body)).toMatchObject({ gather: 'digits', ended: false });
    const body2 = JSON.stringify({ CallSid: 'CA-test-1', From: '+919800000002', Digits: '2' });
    const r2 = await post('/webhooks/ivr/mock', body2, { 'x-ivr-signature': signBody(t.svc.config.IVR_WEBHOOK_SECRET, body2) });
    expect(JSON.parse(r2.body).ended).toBe(true);
    // a provider that is not configured is not exposed
    expect((await post('/webhooks/ivr/twilio', body, {})).statusCode).toBe(404);
    const xml = toTwiml({ sessionId: 's', say: 'Press 1 & 2', gather: 'digits', ended: false, lang: 'hi' }, 'https://api.example/ivr');
    expect(xml).toContain('<Gather input="dtmf"');
    expect(xml).toContain('Press 1 &amp; 2');
    expect(xml).toContain('hi-IN');
    expect(toTwiml({ sessionId: 's', say: 'Bye', gather: 'none', ended: true, lang: 'en', transferTo: '+914000000000' }, 'x')).toContain('<Dial>+914000000000</Dial>');
  });
});
