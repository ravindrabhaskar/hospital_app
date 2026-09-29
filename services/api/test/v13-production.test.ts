import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfig, productionReadinessIssues } from '../src/config.js';
import { PackDrugKnowledgeProvider } from '../src/modules/rxcheck/engine.js';
import { activeSchedule } from '../src/modules/preventive/routes.js';
import { activeTemplates } from '../src/modules/programs/service.js';
import { setup, type TestCtx } from './helpers.js';

const base = {
  NODE_ENV: 'production',
  DATABASE_URL: 'postgres://x',
  JWT_SECRET: 'p'.repeat(48),
  PAYMENT_WEBHOOK_SECRET: 'w'.repeat(32),
  SMS_PROVIDER: 'msg91',
  MSG91_AUTH_KEY: 'k',
  MSG91_OTP_TEMPLATE_ID: 't',
  PAYMENT_GATEWAY: 'razorpay',
  RAZORPAY_KEY_ID: 'rzp_live_x',
  RAZORPAY_KEY_SECRET: 's',
  RAZORPAY_WEBHOOK_SECRET: 'w',
  STORAGE_DRIVER: 's3',
  S3_BUCKET: 'b',
  CLAMAV_HOST: 'clamav',
  MFA_ENCRYPTION_KEY: Buffer.alloc(32, 1).toString('base64'),
  VIDEO_ROOM_SECRET: 'v'.repeat(32),
};

describe('v1.3 production refusals for mock partners', () => {
  it('partners default to disabled in production and to mock elsewhere', () => {
    const prod = loadConfig(base);
    expect([prod.WHATSAPP_PROVIDER, prod.LAB_PARTNER, prod.AMBULANCE_PARTNER, prod.ABDM_MODE, prod.STT_PROVIDER, prod.IVR_PROVIDER, prod.SOS_BUTTON_PROVIDER]).toEqual(Array(7).fill('disabled'));
    const dev = loadConfig({ NODE_ENV: 'development' });
    expect([dev.WHATSAPP_PROVIDER, dev.LAB_PARTNER, dev.AMBULANCE_PARTNER, dev.ABDM_MODE, dev.STT_PROVIDER, dev.IVR_PROVIDER, dev.SOS_BUTTON_PROVIDER]).toEqual(Array(7).fill('mock'));
    expect(productionReadinessIssues(prod)).toEqual([]);
  });

  it('an explicitly configured mock partner is refused, and real adapters need their credentials', () => {
    const issues = productionReadinessIssues(
      loadConfig({ ...base, WHATSAPP_PROVIDER: 'mock', LAB_PARTNER: 'mock', AMBULANCE_PARTNER: 'mock', ABDM_MODE: 'mock', STT_PROVIDER: 'mock', IVR_PROVIDER: 'mock', SOS_BUTTON_PROVIDER: 'mock' }),
    ).join('\n');
    for (const k of ['WHATSAPP_PROVIDER=mock', 'LAB_PARTNER=mock', 'AMBULANCE_PARTNER=mock', 'ABDM_MODE=mock', 'STT_PROVIDER=mock', 'IVR_PROVIDER=mock', 'SOS_BUTTON_PROVIDER=mock']) expect(issues).toContain(k);
    const real = productionReadinessIssues(loadConfig({ ...base, WHATSAPP_PROVIDER: 'meta', ABDM_MODE: 'production', LAB_PARTNER: 'http', IVR_PROVIDER: 'twilio' })).join('\n');
    expect(real).toMatch(/WHATSAPP_PHONE_NUMBER_ID/);
    expect(real).toMatch(/ABDM production mode requires certification credentials; missing: ABDM_BASE_URL, ABDM_CLIENT_ID/);
    expect(real).toMatch(/LAB_PARTNER_BASE_URL/);
    expect(real).toMatch(/TWILIO_AUTH_TOKEN and IVR_PUBLIC_URL/);
  });
});

describe('unapproved clinical content is refused in production', () => {
  let t: TestCtx;
  beforeAll(async () => {
    t = await setup();
  });
  afterAll(async () => t.close());

  it('interaction pack, preventive schedule and program templates', async () => {
    const prodCfg = { ...t.svc.config, NODE_ENV: 'production' as const };
    const res = await new PackDrugKnowledgeProvider(prodCfg).check(t.svc.db, { items: [{ drugName: 'Warfarin' }, { drugName: 'Aspirin' }], allergies: [], activeMedications: [] });
    expect(res.warnings).toHaveLength(1);
    expect(res.warnings[0]).toMatchObject({ source: 'failsafe', severity: 'moderate' });
    expect(await activeSchedule(t.svc.db, prodCfg)).toBeNull();
    expect(await activeTemplates(t.svc.db, prodCfg)).toEqual([]);
    // in development the fixtures are served (clearly labelled)
    expect((await activeSchedule(t.svc.db, t.svc.config))?.status).toBe('fixture_unapproved');
    expect((await activeTemplates(t.svc.db, t.svc.config)).length).toBe(3);
  });
});
