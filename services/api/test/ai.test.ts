import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { and, eq } from 'drizzle-orm';
import { aiInteractions, consents, users } from '../src/db/schema.js';
import type { ChatModel, ModelRequest } from '../src/modules/ai/models.js';
import { evaluateRules, FIXTURE_RULES } from '../src/modules/safety/engine.js';
import { extractFromMessage, emptyIntake, findSeverity, mergeGroundedExtraction } from '../src/modules/ai/intake.js';
import { SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

/** Fake LLM: always claims nothing is wrong; for extraction it hallucinates values. */
class LyingModel implements ChatModel {
  readonly name = 'fake-llm';
  readonly kind = 'llm' as const;
  calls: ModelRequest[] = [];
  async generate(req: ModelRequest) {
    this.calls.push(req);
    if (req.system.startsWith('Extract')) {
      return {
        text: JSON.stringify({
          chiefComplaint: 'migraine with aura',
          durationText: '3 weeks',
          severity: 9,
          associatedSymptoms: ['blurred vision'],
          currentMedications: ['ibuprofen 400mg'],
          allergies: ['peanuts'],
          relevantHistory: ['asthma'],
        }),
        model: this.name,
        inputTokens: 10,
        outputTokens: 10,
      };
    }
    return { text: 'This is nothing serious, safety level none. Just rest.', model: this.name, inputTokens: 12, outputTokens: 9 };
  }
}

class DownModel implements ChatModel {
  readonly name = 'down-llm';
  readonly kind = 'llm' as const;
  async generate(): Promise<never> {
    throw new Error('provider_unavailable');
  }
}

describe('safety engine (unit)', () => {
  const pack = { version: 'fixture-0.1', status: 'fixture_unapproved' as const };
  it('keyword, vital, severity and age rules', () => {
    expect(evaluateRules(FIXTURE_RULES, { text: 'I have CHEST PAIN since morning' }, pack).level).toBe('emergency');
    expect(evaluateRules(FIXTURE_RULES, { text: 'I can’t breathe properly' }, pack).level).toBe('emergency');
    expect(evaluateRules(FIXTURE_RULES, { vitals: [{ type: 'spo2', value: 88 }] }, pack).level).toBe('emergency');
    expect(evaluateRules(FIXTURE_RULES, { vitals: [{ type: 'spo2', value: 95 }] }, pack).level).toBe('none');
    expect(evaluateRules(FIXTURE_RULES, { text: 'headache', severity: 8 }, pack).level).toBe('urgent');
    const elderly = evaluateRules(FIXTURE_RULES, { text: 'fever since 2 days', ageYears: 68 }, pack);
    expect(elderly.triggeredRules.map((r) => r.action)).toContain('suggest_home_visit');
    expect(evaluateRules(FIXTURE_RULES, { text: 'fever since 2 days', ageYears: 30 }, pack).level).toBe('none');
    expect(evaluateRules(FIXTURE_RULES, { text: 'chestpainless' }, pack).level).toBe('none');
    for (const r of FIXTURE_RULES) expect(r.description).toContain('FIXTURE — replace with clinician-approved rule');
  });

  it('intake extraction never invents values', () => {
    const i1 = extractFromMessage(emptyIntake(), 'I have a headache since yesterday', 'chiefComplaint');
    expect(i1.chiefComplaint).toMatchObject({ value: 'headache', source: 'user' });
    expect(i1.durationText.value).toBe('since yesterday');
    expect(i1.severity.value).toBeNull();
    expect(i1.allergies.value).toBeNull();
    expect(i1.missingFields).toEqual(['severity', 'associatedSymptoms']);
    const merged = mergeGroundedExtraction(i1, { severity: 9, allergies: ['peanuts'], currentMedications: ['ibuprofen'], associatedSymptoms: ['nausea'] }, 'I have a headache since yesterday');
    expect(merged.severity.value).toBeNull();
    expect(merged.allergies.value).toBeNull();
    expect(merged.currentMedications.value).toBeNull();
    expect(merged.associatedSymptoms.value).toBeNull();
    const grounded = mergeGroundedExtraction(i1, { associatedSymptoms: ['yesterday'] }, 'I have a headache since yesterday');
    expect(grounded.associatedSymptoms).toMatchObject({ value: ['yesterday'], source: 'model_extraction' });
  });
});

describe('intake severity and progress (unit, B25)', () => {
  it('typed severity answers are understood, case-insensitively', () => {
    expect(findSeverity('Moderate', true)).toBe(5);
    expect(findSeverity('moderate (5/10)', true)).toBe(5);
    expect(findSeverity('MODERATE', true)).toBe(5);
    expect(findSeverity('severe', true)).toBe(8);
    expect(findSeverity('it is quite severe', true)).toBe(8);
    expect(findSeverity('mild', true)).toBe(3);
    expect(findSeverity('Mild (3/10)', true)).toBe(3);
    expect(findSeverity('7', true)).toBe(7);
    expect(findSeverity('about 6 out of 10', true)).toBe(6);
    expect(findSeverity('seven', true)).toBe(7);
    expect(findSeverity('unbearable', true)).toBe(9);
    // Not asked: free words are not turned into a severity.
    expect(findSeverity('severe', false)).toBeNull();
    expect(findSeverity('banana', true)).toBeNull();
  });

  it('a severity word typed while duration was asked fills severity, not duration', () => {
    const i1 = extractFromMessage(emptyIntake(), 'I have a sore throat', 'chiefComplaint');
    const i2 = extractFromMessage(i1, 'Moderate', 'durationText');
    expect(i2.durationText.value).toBeNull();
    expect(i2.severity.value).toBe(5);
  });

  it('progress is monotonic over the fixed question list', () => {
    let i = emptyIntake();
    expect(i.progress).toEqual({ step: 1, total: 4, answered: 0 });
    const steps = [i.progress.step];
    for (const [text, asked] of [
      ['I have a headache', 'chiefComplaint'],
      ['2 days', 'durationText'],
      ['severe', 'severity'],
      ['no', 'associatedSymptoms'],
    ] as const) {
      i = extractFromMessage(i, text, asked);
      expect(i.progress.total).toBe(4);
      steps.push(i.progress.step);
    }
    expect(steps).toEqual([1, 2, 3, 4, 4]);
    expect(i.progress.answered).toBe(4);
    expect(i.complete).toBe(true);
  });
});

describe('AI assistant (API)', () => {
  let t: TestCtx;
  let fake: LyingModel;
  let vaibhav: string;
  let ramesh: string;
  beforeAll(async () => {
    fake = new LyingModel();
    t = await setup({ aiModel: fake });
    vaibhav = (await t.login(SEED_PHONES.vaibhav)).accessToken;
    ramesh = await rameshId(t, vaibhav);
  });
  afterAll(async () => t.close());

  const start = async () => {
    const c = await t.req(vaibhav, 'POST', '/ai/conversations', { patientId: ramesh });
    expect(c.status).toBe(201);
    return c.body;
  };
  const say = (id: string, text: string) => t.req(vaibhav, 'POST', `/ai/conversations/${id}/messages`, { text });

  it('greets and prefills history from the authorized record', async () => {
    const c = await start();
    expect(c.messages).toHaveLength(1);
    expect(c.messages[0]).toMatchObject({ role: 'assistant', kind: 'question' });
    expect(c.intake.allergies).toMatchObject({ value: ['Penicillin'], source: 'record' });
    expect(c.intake.relevantHistory.value).toEqual(['Hypertension', 'Type 2 diabetes']);
  });

  it('emergency keyword -> emergency even though the model says "nothing serious"', async () => {
    const c = await start();
    const r = await say(c.id, 'My father has severe chest pain and is sweating');
    expect(r.status).toBe(200);
    expect(r.body.safety.level).toBe('emergency');
    expect(r.body.routing.action).toBe('emergency');
    const alert = r.body.messages.find((m: any) => m.kind === 'safety_alert');
    expect(alert.text).toContain('108');
    expect(JSON.stringify(r.body.messages)).not.toMatch(/nothing serious/i);
    expect(r.body.conversationStatus).toBe('routed');
    expect(r.body.routing.careEpisodeId).toBeTruthy();
    const ep = await t.req(vaibhav, 'GET', `/care-episodes/${r.body.routing.careEpisodeId}`);
    expect(ep.body.status).toBe('EMERGENCY');
    expect(ep.body.safetyEvents[0]).toMatchObject({ level: 'emergency', source: 'ai_intake' });
    // stays emergency on the next turn
    const r2 = await say(c.id, 'ok it is better now, nothing serious');
    expect(r2.body.safety.level).toBe('emergency');
  });

  it('LLM text that violates policy is replaced; intake contains only what the user said', async () => {
    const c = await start();
    const r1 = await say(c.id, 'I have a headache since yesterday');
    expect(r1.body.intake.chiefComplaint.value).toBe('headache');
    expect(r1.body.intake.durationText.value).toBe('since yesterday');
    expect(r1.body.intake.severity.value).toBeNull(); // model hallucinated 9
    expect(r1.body.intake.currentMedications.value).not.toContain('ibuprofen 400mg');
    expect(r1.body.intake.allergies.value).toEqual(['Penicillin']);
    expect(r1.body.routing.action).toBe('continue_intake');
    const q = r1.body.messages.find((m: any) => m.kind === 'question');
    expect(q.quickReplies.length).toBeGreaterThan(0);
    const r2 = await say(c.id, 'Moderate (5/10)');
    expect(r2.body.intake.severity).toMatchObject({ value: 5, source: 'user' });
    const r3 = await say(c.id, 'No other symptoms');
    expect(r3.body.intake.complete).toBe(true);
    expect(r3.body.intake.associatedSymptoms.value).toEqual([]);
    expect(r3.body.routing.action).toBe('book_doctor');
    expect(r3.body.routing.suggestedSpecialty).toBe('general_physician');
    const info = r3.body.messages.find((m: any) => m.kind === 'info');
    expect(info.text).not.toMatch(/nothing serious/i); // policy check replaced the model output
    const rows = await t.svc.db.select().from(aiInteractions).where(eq(aiInteractions.conversationId, c.id));
    expect(rows.length).toBeGreaterThan(0);
    for (const row of rows) {
      expect(row.promptVersion).toBeTruthy();
      expect(row.rulePackVersion).toBeTruthy();
      expect(Object.values(row).join(' ')).not.toMatch(/headache/i); // no raw PHI text in the audit table
    }
  });

  it('suggested specialty is one that bookable doctors have (no ENT doctor -> general physician) (B11)', async () => {
    const ent = await t.req(vaibhav, 'GET', '/doctors?specialty=ent');
    expect(ent.body.items).toHaveLength(0);
    const c = await start();
    await say(c.id, 'I have a sore throat since 2 days');
    await say(c.id, 'mild');
    const r = await say(c.id, 'no');
    expect(r.body.intake.complete).toBe(true);
    const sp = r.body.routing.suggestedSpecialty;
    expect(sp).toBe('general_physician');
    const docs = await t.req(vaibhav, 'GET', `/doctors?specialty=${sp}`);
    expect(docs.body.items.length).toBeGreaterThan(0);
    // A specialty that exists is still suggested.
    const c2 = await start();
    await say(c2.id, 'I have a skin rash since 3 days');
    await say(c2.id, 'Moderate');
    const r2 = await say(c2.id, 'no');
    expect(r2.body.routing.suggestedSpecialty).toBe('dermatologist');
  });

  it('typed severity is understood; after routing, follow-ups are acknowledged without repeating the routing reply (B25)', async () => {
    const c = await start();
    const r1 = await say(c.id, 'I have a stomach ache');
    expect(r1.body.intake.progress).toMatchObject({ step: 2, total: 4 });
    const r2 = await say(c.id, 'since yesterday');
    expect(r2.body.intake.progress).toMatchObject({ step: 3, total: 4 });
    const r3 = await say(c.id, 'Moderate');
    expect(r3.body.intake.severity).toMatchObject({ value: 5, source: 'user' });
    expect(r3.body.messages.find((m: any) => m.kind === 'question').text).not.toMatch(/scale of 0 to 10/);
    expect(r3.body.intake.progress).toMatchObject({ step: 4, total: 4 });
    const r4 = await say(c.id, 'no');
    expect(r4.body.intake.complete).toBe(true);
    expect(r4.body.messages.filter((m: any) => m.kind === 'routing')).toHaveLength(1);
    const r5 = await say(c.id, 'thank you');
    expect(r5.status).toBe(200);
    expect(r5.body.messages.filter((m: any) => m.kind === 'routing')).toHaveLength(0);
    expect(r5.body.routing.action).toBe('book_doctor'); // still returned for the client
    const r6 = await say(c.id, 'ok');
    const assistantTexts = [...r5.body.messages, ...r6.body.messages].filter((m: any) => m.role === 'assistant').map((m: any) => m.text);
    expect(assistantTexts.length).toBeGreaterThan(0);
    for (const txt of assistantTexts) expect(txt).not.toBe(r4.body.messages.find((m: any) => m.kind === 'routing').text);
    const conv = await t.req(vaibhav, 'GET', `/ai/conversations/${c.id}`);
    expect(conv.body.intake.progress).toMatchObject({ step: 4, total: 4, answered: 4 });
  });

  it('missing ai_assistance consent -> CONSENT_REQUIRED', async () => {
    const [u] = await t.svc.db.select().from(users).where(eq(users.phone, SEED_PHONES.vaibhav));
    const [c] = await t.svc.db.select().from(consents).where(and(eq(consents.userId, u.id), eq(consents.purpose, 'ai_assistance')));
    expect((await t.req(vaibhav, 'POST', `/consents/${c.id}/revoke`)).body.status).toBe('revoked');
    const r = await t.req(vaibhav, 'POST', '/ai/conversations', { patientId: ramesh });
    expect(r.status).toBe(403);
    expect(r.body.error.code).toBe('CONSENT_REQUIRED');
    expect((await t.req(vaibhav, 'POST', '/consents', { purpose: 'ai_assistance', version: '1.0' })).status).toBe(201);
  });

  it('family member without manage_care cannot use AI for the patient', async () => {
    const lakshmi = (await t.login(SEED_PHONES.lakshmi)).accessToken;
    const r = await t.req(lakshmi, 'POST', '/ai/conversations', { patientId: ramesh });
    expect(r.status).toBe(403);
    expect(r.body.error.code).toBe('FORBIDDEN');
  });
});

describe('AI fallback', () => {
  it('model unavailable -> safe fallback and doctor routing', async () => {
    const t = await setup({ aiModel: new DownModel() });
    try {
      const tok = (await t.login(SEED_PHONES.vaibhav)).accessToken;
      const pid = await rameshId(t, tok);
      const c = await t.req(tok, 'POST', '/ai/conversations', { patientId: pid });
      await t.req(tok, 'POST', `/ai/conversations/${c.body.id}/messages`, { text: 'I have a cough for 3 days' });
      await t.req(tok, 'POST', `/ai/conversations/${c.body.id}/messages`, { text: '4/10' });
      const r = await t.req(tok, 'POST', `/ai/conversations/${c.body.id}/messages`, { text: 'no' });
      expect(r.status).toBe(200);
      expect(r.body.routing.action).toBe('book_doctor');
      expect(r.body.messages.some((m: any) => /temporarily limited/.test(m.text))).toBe(true);
      const rows = await t.svc.db.select().from(aiInteractions).where(eq(aiInteractions.conversationId, c.body.id));
      expect(rows.some((x) => x.fallbackUsed)).toBe(true);
      // kill switch -> immediate fallback
      const admin = (await t.login(SEED_PHONES.admin)).accessToken;
      expect((await t.req(admin, 'PUT', '/admin/feature-flags/kill_switch_ai', { enabled: true })).body.enabled).toBe(true);
      const ready = await t.req(null, 'GET', '/api/v1/ready');
      expect(ready.body.checks.ai).toBe('degraded');
    } finally {
      await t.close();
    }
  });
});
