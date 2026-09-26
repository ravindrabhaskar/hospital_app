import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { medicalRecords } from '../src/db/schema.js';
import { sha256 } from '../src/lib/crypto.js';
import type { ChatModel, ModelRequest, ModelResponse } from '../src/modules/ai/models.js';
import { toAnthropicMessages } from '../src/modules/ai/models.js';
import { extractPdfText } from '../src/modules/records/summarize.js';
import { samplePdf } from '../src/db/seed.js';
import { SEED_PHONES, rameshId, setup, type TestCtx } from './helpers.js';

/** Fake vision-capable LLM that records what it was sent. */
class RecordingModel implements ChatModel {
  readonly name = 'fake-claude';
  readonly kind = 'llm' as const;
  readonly supportsVision = true;
  requests: ModelRequest[] = [];
  async generate(req: ModelRequest): Promise<ModelResponse> {
    this.requests.push(req);
    return { text: 'This report lists routine blood test values from your lab.', model: this.name, inputTokens: 10, outputTokens: 10 };
  }
}

async function recordByTitle(t: TestCtx, token: string, patientId: string, title: string) {
  const r = await t.req(token, 'GET', `/records?patientId=${patientId}`);
  return r.body.items.find((x: any) => x.title === title);
}

describe('record summarisation', () => {
  const model = new RecordingModel();
  let t: TestCtx;
  let token: string;
  let ramesh: string;
  beforeAll(async () => {
    t = await setup({ aiModel: model });
    token = (await t.login(SEED_PHONES.vaibhav)).accessToken;
    ramesh = await rameshId(t, token);
  });
  afterAll(async () => t.close());

  it('extracts PDF text (unpdf) and sends it to the model; the original is unchanged', async () => {
    expect(await extractPdfText(samplePdf('Hello PDF'))).toContain('Hello PDF');
    expect(await extractPdfText(Buffer.from('%PDF-broken'))).toBe('');
    const rec = await recordByTitle(t, token, ramesh, 'Blood Test Report');
    const [before] = await t.svc.db.select().from(medicalRecords).where(eq(medicalRecords.id, rec.id));
    const bytesBefore = await t.svc.storage.get(before.storageKey!);
    const r = await t.req(token, 'POST', `/records/${rec.id}/summarize`);
    expect(r.status).toBe(200);
    expect(r.body.aiSummary).toMatchObject({ model: 'fake-claude', text: expect.stringContaining('blood test') });
    expect(r.body.aiSummary.disclaimer).toBeTruthy();
    const req = model.requests.at(-1)!;
    expect(req.messages[0].content).toContain('SAMPLE DOCUMENT - synthetic test data - Blood Test Report');
    expect(req.images).toBeUndefined();
    const [after] = await t.svc.db.select().from(medicalRecords).where(eq(medicalRecords.id, rec.id));
    expect(after.sha256).toBe(before.sha256);
    expect(sha256(await t.svc.storage.get(after.storageKey!))).toBe(sha256(bytesBefore));
  });

  it('images go through the vision path as base64 image blocks', async () => {
    const rec = await recordByTitle(t, token, ramesh, 'X-Ray Chest');
    const r = await t.req(token, 'POST', `/records/${rec.id}/summarize`);
    expect(r.status).toBe(200);
    const req = model.requests.at(-1)!;
    expect(req.images).toHaveLength(1);
    expect(req.images![0].mediaType).toBe('image/png');
    const msgs = toAnthropicMessages(req);
    expect((msgs[0].content as any[])[0]).toMatchObject({ type: 'image', source: { type: 'base64', media_type: 'image/png' } });
    expect((msgs[0].content as any[])[1]).toMatchObject({ type: 'text' });
  });
});

describe('record summarisation without an LLM', () => {
  let t: TestCtx;
  beforeAll(async () => {
    t = await setup(); // RuleBasedModel (no ANTHROPIC_API_KEY)
  });
  afterAll(async () => t.close());

  it('returns the metadata-only summary with the disclaimer', async () => {
    const token = (await t.login(SEED_PHONES.vaibhav)).accessToken;
    const ramesh = await rameshId(t, token);
    const rec = await recordByTitle(t, token, ramesh, 'X-Ray Chest');
    const r = await t.req(token, 'POST', `/records/${rec.id}/summarize`);
    expect(r.status).toBe(200);
    expect(r.body.aiSummary.model).toBe('rule-based-v1');
    expect(r.body.aiSummary.text).toContain('X-Ray Chest');
    expect(r.body.aiSummary.text).toContain('review the original document');
    expect(r.body.aiSummary.disclaimer).toBeTruthy();
  });
});
