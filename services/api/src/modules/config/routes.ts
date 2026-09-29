import type { FastifyInstance } from 'fastify';
import { pushConfigured } from '../../config.js';
import { brandingFor } from '../enterprise/routes.js';

/** Client-visible flags (contract section 21). kill_switch_ai stays server-side. */
export const PUBLIC_FLAGS = [
  'ai_assistant',
  'wound_ai_analysis',
  'fall_detection',
  'wearables',
  'pharmacy_orders',
  'mental_wellness',
  'govt_schemes',
  'voice_input',
  // v1.3
  'lab_tests',
  'care_programs',
  'second_opinion',
  'insurance',
  'preventive_care',
  'exercise_plans',
  'diet_plans',
  'ambulance',
  'safe_zone',
  'wallet_invites',
  'support_desk',
  'whatsapp',
  'daily_checkin',
  'abdm',
] as const;

/** GET /config/public (no auth). */
export async function publicConfigRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const c = svc.config;

  app.get('/config/public', async (req, reply) => {
    const tenant = (req.query as Record<string, unknown> | undefined)?.tenant;
    const flags = Object.fromEntries(await Promise.all(PUBLIC_FLAGS.map(async (k) => [k, await svc.flags.isEnabled(k)] as const)));
    reply.header('cache-control', 'public, max-age=60');
    return {
      flags,
      payment: {
        gateway: svc.payments.gateway.name,
        razorpayKeyId: svc.payments.gateway.name === 'razorpay' ? (svc.payments.gateway.keyId ?? null) : null,
      },
      video: { provider: svc.video.name },
      push: { enabled: pushConfigured(c) },
      support: { phone: c.SUPPORT_PHONE, email: c.SUPPORT_EMAIL, whatsapp: c.SUPPORT_WHATSAPP ?? null },
      legal: { privacyUrl: c.PRIVACY_URL, termsUrl: c.TERMS_URL, accountDeletionUrl: c.ACCOUNT_DELETION_URL },
      branding: await brandingFor(svc.db, c, typeof tenant === 'string' ? tenant.slice(0, 40) : undefined),
      minAppVersion: {
        patientAndroid: c.MIN_APP_VERSION_PATIENT_ANDROID,
        patientIos: c.MIN_APP_VERSION_PATIENT_IOS,
        providerAndroid: c.MIN_APP_VERSION_PROVIDER_ANDROID,
        providerIos: c.MIN_APP_VERSION_PROVIDER_IOS,
        doctorAndroid: c.MIN_APP_VERSION_DOCTOR_ANDROID,
        doctorIos: c.MIN_APP_VERSION_DOCTOR_IOS,
      },
    };
  });
}
