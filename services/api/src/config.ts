import { createHash } from 'node:crypto';
import { z } from 'zod';

const bool = z
  .union([z.boolean(), z.string()])
  .transform((v) => (typeof v === 'boolean' ? v : ['1', 'true', 'yes', 'on'].includes(v.toLowerCase())));

const DEV_JWT_SECRET = 'dev-only-insecure-jwt-secret-change-me-0123456789';
const DEV_WEBHOOK_SECRET = 'dev-only-payment-webhook-secret';
export const DEV_WHATSAPP_SECRET = 'dev-only-whatsapp-app-secret';
export const DEV_LAB_SECRET = 'dev-only-lab-webhook-secret';
export const DEV_ABDM_SECRET = 'dev-only-abdm-webhook-secret';
export const DEV_IVR_SECRET = 'dev-only-ivr-webhook-secret';
export const DEV_SOS_SECRET = 'dev-only-sos-webhook-secret';

const ConfigShape = z.object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    HOST: z.string().default('0.0.0.0'),
    PORT: z.coerce.number().int().positive().default(4000),
    API_PREFIX: z.string().default('/api/v1'),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

    DATABASE_URL: z.string().optional(),
    PGLITE_DIR: z.string().default('.data/pglite'),

    JWT_SECRET: z.string().min(32).default(DEV_JWT_SECRET),
    ACCESS_TOKEN_TTL_SEC: z.coerce.number().int().positive().default(900),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
    OTP_DEV_CODE: z.string().regex(/^\d{6}$/).default('123456'),
    OTP_TTL_SEC: z.coerce.number().int().positive().default(300),
    OTP_MAX_ATTEMPTS: z.coerce.number().int().positive().default(5),
    OTP_MAX_REQUESTS: z.coerce.number().int().positive().default(5),
    OTP_WINDOW_MIN: z.coerce.number().int().positive().default(15),

    CORS_ORIGINS: z.string().default('http://localhost:3100'),
    RATE_LIMIT_MAX: z.coerce.number().int().positive().default(600),
    RATE_LIMIT_OTP_MAX: z.coerce.number().int().positive().default(20),

    ANTHROPIC_API_KEY: z.string().optional(),
    AI_MODEL: z.string().default('claude-opus-5'),
    AI_TIMEOUT_MS: z.coerce.number().int().positive().default(20000),
    AI_MAX_RETRIES: z.coerce.number().int().min(0).default(1),
    AI_BREAKER_THRESHOLD: z.coerce.number().int().positive().default(3),
    AI_BREAKER_COOLDOWN_SEC: z.coerce.number().int().positive().default(60),

    PAYMENT_GATEWAY: z.enum(['mock', 'razorpay']).default('mock'),
    PAYMENT_WEBHOOK_SECRET: z.string().min(16).default(DEV_WEBHOOK_SECRET),
    RAZORPAY_KEY_ID: z.string().optional(),
    RAZORPAY_KEY_SECRET: z.string().optional(),

    STORAGE_DRIVER: z.enum(['local', 's3', 'memory']).default('local'),
    STORAGE_DIR: z.string().default('.data/files'),
    MAX_UPLOAD_MB: z.coerce.number().positive().default(15),

    FALL_RESPONSE_TIMEOUT_SEC: z.coerce.number().int().positive().default(60),
    VISIT_ASSIGN_SLA_MIN: z.coerce.number().int().positive().default(30),
    PAYMENT_HOLD_MIN: z.coerce.number().int().positive().default(15),
    DOSE_MISSED_GRACE_MIN: z.coerce.number().int().positive().default(60),
    WORKER_ENABLED: bool.default(true),
    WORKER_INTERVAL_MS: z.coerce.number().int().positive().default(15000),

    VIDEO_BASE_URL: z.string().default('https://meet.carecompanion.local/room'),

    // ---- v1.1 production integrations (all optional in development) ----
    BODY_LIMIT_KB: z.coerce.number().int().positive().default(1024),
    REDIS_URL: z.string().optional(),
    METRICS_TOKEN: z.string().min(16).optional(),
    DATABASE_POOL_MAX: z.coerce.number().int().positive().default(10),
    WORKER_LOCK_KEY: z.coerce.number().int().default(724_911_001),

    // App-store review demo login: exactly this phone accepts this fixed OTP (no SMS). Allowed in production.
    REVIEW_PHONE: z.string().regex(/^\+\d{10,15}$/).optional(),
    REVIEW_OTP: z.string().regex(/^\d{6}$/).optional(),

    // SMS OTP delivery
    SMS_PROVIDER: z.enum(['console', 'msg91', 'twilio']).default('console'),
    SMS_TIMEOUT_MS: z.coerce.number().int().positive().default(8000),
    MSG91_AUTH_KEY: z.string().optional(),
    MSG91_OTP_TEMPLATE_ID: z.string().optional(),
    MSG91_NOTIFY_TEMPLATE_ID: z.string().optional(),
    MSG91_SENDER_ID: z.string().optional(),
    MSG91_BASE_URL: z.string().url().default('https://control.msg91.com'),
    TWILIO_ACCOUNT_SID: z.string().optional(),
    TWILIO_AUTH_TOKEN: z.string().optional(),
    TWILIO_FROM: z.string().optional(),
    TWILIO_MESSAGING_SERVICE_SID: z.string().optional(),
    TWILIO_BASE_URL: z.string().url().default('https://api.twilio.com'),

    // Razorpay
    RAZORPAY_WEBHOOK_SECRET: z.string().optional(),
    RAZORPAY_BASE_URL: z.string().url().default('https://api.razorpay.com'),
    PAYMENT_TIMEOUT_MS: z.coerce.number().int().positive().default(10000),

    // Push (FCM HTTP v1)
    FCM_PROJECT_ID: z.string().optional(),
    FCM_CLIENT_EMAIL: z.string().optional(),
    FCM_PRIVATE_KEY: z.string().optional(),

    // Object storage (S3 / MinIO)
    S3_BUCKET: z.string().optional(),
    S3_REGION: z.string().default('ap-south-1'),
    S3_ENDPOINT: z.string().url().optional(),
    S3_FORCE_PATH_STYLE: bool.default(false),
    S3_KMS_KEY_ID: z.string().optional(),
    S3_ACCESS_KEY_ID: z.string().optional(),
    S3_SECRET_ACCESS_KEY: z.string().optional(),

    // Malware scanning (ClamAV clamd)
    CLAMAV_HOST: z.string().optional(),
    CLAMAV_PORT: z.coerce.number().int().positive().default(3310),
    CLAMAV_TIMEOUT_MS: z.coerce.number().int().positive().default(15000),

    // Video (Jitsi)
    VIDEO_PROVIDER: z.enum(['jitsi', 'placeholder']).default('jitsi'),
    JITSI_DOMAIN: z.string().default('meet.jit.si'),
    JITSI_APP_ID: z.string().optional(),
    JITSI_APP_SECRET: z.string().optional(),
    VIDEO_ROOM_SECRET: z.string().min(16).optional(),

    // Staff MFA
    MFA_ENFORCED: bool.optional(),
    MFA_ENCRYPTION_KEY: z.string().optional(),
    MFA_ISSUER: z.string().default('CareCompanion'),

    // Account deletion / export
    ACCOUNT_DELETION_GRACE_DAYS: z.coerce.number().int().min(0).default(7),
    DATA_EXPORT_TTL_HOURS: z.coerce.number().int().positive().default(72),
    DATA_EXPORT_MAX_PER_DAY: z.coerce.number().int().positive().default(5),

    // Public config (GET /config/public)
    SUPPORT_PHONE: z.string().default('+914000000000'),
    SUPPORT_EMAIL: z.string().default('support@carecompanion.example'),
    SUPPORT_WHATSAPP: z.string().optional(),
    PRIVACY_URL: z.string().default('https://carecompanion.example/privacy'),
    TERMS_URL: z.string().default('https://carecompanion.example/terms'),
    ACCOUNT_DELETION_URL: z.string().default('https://carecompanion.example/account/delete'),
    MIN_APP_VERSION_PATIENT_ANDROID: z.string().default('1.0.0'),
    MIN_APP_VERSION_PATIENT_IOS: z.string().default('1.0.0'),
    MIN_APP_VERSION_PROVIDER_ANDROID: z.string().default('1.0.0'),
    MIN_APP_VERSION_PROVIDER_IOS: z.string().default('1.0.0'),
    MIN_APP_VERSION_DOCTOR_ANDROID: z.string().default('1.0.0'),
    MIN_APP_VERSION_DOCTOR_IOS: z.string().default('1.0.0'),

    // ---- v1.2 functional completeness ----
    /** Absolute base used to build public URLs such as profile photos (`${PUBLIC_API_BASE_URL}/media/<id>`). */
    PUBLIC_API_BASE_URL: z.string().default('http://localhost:4000/api/v1'),
    /** Days of bookable slots generated ahead from each doctor's weekly schedule (contract section 29). */
    SCHEDULE_HORIZON_DAYS: z.coerce.number().int().min(1).max(90).default(14),
    // Invoices (contract section 32) [REQUIRES TAX REVIEW]
    SELLER_LEGAL_NAME: z.string().default('CareCompanion Health Services Pvt. Ltd. (placeholder)'),
    SELLER_GSTIN: z.string().optional(),
    SELLER_ADDRESS: z.string().default('Hyderabad, Telangana, India (placeholder address)'),
    /** GST rate in percent applied to invoices (healthcare services are generally exempt; default 0). */
    HEALTHCARE_GST_RATE: z.coerce.number().min(0).max(28).default(0),
    /** Platform fee in percent deducted from provider earnings. */
    PLATFORM_FEE_PCT: z.coerce.number().min(0).max(100).default(20),
    /** ABDM (ABHA) integration. The adapter is not connected yet: verify returns 503 while false. */
    ABDM_ENABLED: bool.default(false),

    // ---- v1.3 growth & care programs (contract sections 41-62) ----
    /** Key for field-level encryption of sensitive identifiers (insurance policy numbers). 32 bytes hex/base64. */
    DATA_ENCRYPTION_KEY: z.string().optional(),
    // WhatsApp assistant (section 43): mock (console) | meta (Cloud API) | disabled
    WHATSAPP_PROVIDER: z.enum(['mock', 'meta', 'disabled']).optional(),
    WHATSAPP_PHONE_NUMBER_ID: z.string().optional(),
    WHATSAPP_ACCESS_TOKEN: z.string().optional(),
    WHATSAPP_APP_SECRET: z.string().min(8).default(DEV_WHATSAPP_SECRET),
    WHATSAPP_VERIFY_TOKEN: z.string().min(8).default('dev-only-whatsapp-verify-token'),
    WHATSAPP_API_BASE_URL: z.string().url().default('https://graph.facebook.com/v21.0'),
    WHATSAPP_TEMPLATE_CARE_UPDATE: z.string().default('care_update'),
    WHATSAPP_TEMPLATE_REMINDER: z.string().default('daily_reminder'),
    WHATSAPP_TEMPLATE_ALERT: z.string().default('family_alert'),
    WHATSAPP_TEMPLATE_LANG: z.string().default('en'),
    APP_DEEP_LINK_BASE: z.string().default('https://carecompanion.example/app'),
    // Lab partner (section 44): mock | http | disabled
    LAB_PARTNER: z.enum(['mock', 'http', 'disabled']).optional(),
    LAB_PARTNER_NAME: z.string().default('Sample Diagnostics (mock partner)'),
    LAB_PARTNER_BASE_URL: z.string().url().optional(),
    LAB_PARTNER_API_KEY: z.string().optional(),
    LAB_WEBHOOK_SECRET: z.string().min(8).default(DEV_LAB_SECRET),
    LAB_MOCK_REPORT_MINUTES: z.coerce.number().min(0).max(1440).default(2),
    // Ambulance partner (section 55): mock | http | disabled
    AMBULANCE_PARTNER: z.enum(['mock', 'http', 'disabled']).optional(),
    AMBULANCE_PARTNER_NAME: z.string().default('Sample Ambulance Network (mock partner)'),
    AMBULANCE_PARTNER_BASE_URL: z.string().url().optional(),
    AMBULANCE_PARTNER_API_KEY: z.string().optional(),
    AMBULANCE_MOCK_ASSIGN_SEC: z.coerce.number().int().min(0).max(20).default(15),
    // ABDM gateway (section 50): mock | sandbox | production | disabled
    ABDM_MODE: z.enum(['mock', 'sandbox', 'production', 'disabled']).optional(),
    ABDM_BASE_URL: z.string().url().optional(),
    ABDM_CLIENT_ID: z.string().optional(),
    ABDM_CLIENT_SECRET: z.string().optional(),
    ABDM_HIU_ID: z.string().optional(),
    ABDM_HIP_ID: z.string().optional(),
    ABDM_CALLBACK_URL: z.string().url().optional(),
    ABDM_WEBHOOK_SECRET: z.string().min(8).default(DEV_ABDM_SECRET),
    ABDM_MOCK_CONSENT_SEC: z.coerce.number().int().min(0).max(3600).default(10),
    // Drug knowledge (section 47): fixture pack | licensed database over HTTP
    DRUG_KNOWLEDGE_PROVIDER: z.enum(['fixture', 'http']).default('fixture'),
    DRUG_KNOWLEDGE_BASE_URL: z.string().url().optional(),
    DRUG_KNOWLEDGE_API_KEY: z.string().optional(),
    // Speech-to-text for the scribe and IVR (sections 46, 62)
    STT_PROVIDER: z.enum(['mock', 'openai_whisper_compatible', 'google', 'disabled']).optional(),
    STT_BASE_URL: z.string().url().optional(),
    STT_API_KEY: z.string().optional(),
    STT_MODEL: z.string().default('whisper-1'),
    // Telephony IVR (section 62): mock | exotel | twilio | disabled
    IVR_PROVIDER: z.enum(['mock', 'exotel', 'twilio', 'disabled']).optional(),
    IVR_WEBHOOK_SECRET: z.string().min(8).default(DEV_IVR_SECRET),
    IVR_PUBLIC_URL: z.string().url().optional(),
    // SOS button vendor (section 56): mock | vendor | disabled
    SOS_BUTTON_PROVIDER: z.enum(['mock', 'vendor', 'disabled']).optional(),
    SOS_WEBHOOK_SECRET: z.string().min(8).default(DEV_SOS_SECRET),
    // Maps (section 48): haversine estimate unless a Google Maps key is set
    GOOGLE_MAPS_API_KEY: z.string().optional(),
    ROUTE_SPEED_KMH: z.coerce.number().positive().max(120).default(20),
    // Offers, wallet & invites (section 60)
    INVITE_REWARD_INVITER: z.coerce.number().int().min(0).max(10_000).default(100),
    INVITE_REWARD_INVITEE: z.coerce.number().int().min(0).max(10_000).default(100),
    WALLET_CREDIT_EXPIRY_DAYS: z.coerce.number().int().min(1).max(3650).default(365),
    INVITE_REDEEM_WINDOW_DAYS: z.coerce.number().int().min(1).max(365).default(7),
  });

export const ConfigSchema = ConfigShape.superRefine((c, ctx) => {
    if (c.NODE_ENV === 'production') {
      if (c.JWT_SECRET === DEV_JWT_SECRET) ctx.addIssue({ code: 'custom', path: ['JWT_SECRET'], message: 'must be set in production' });
      if (c.PAYMENT_WEBHOOK_SECRET === DEV_WEBHOOK_SECRET)
        ctx.addIssue({ code: 'custom', path: ['PAYMENT_WEBHOOK_SECRET'], message: 'must be set in production' });
      if (!c.DATABASE_URL) ctx.addIssue({ code: 'custom', path: ['DATABASE_URL'], message: 'PostgreSQL is required in production' });
    }
    if (!!c.REVIEW_PHONE !== !!c.REVIEW_OTP) {
      ctx.addIssue({ code: 'custom', path: ['REVIEW_OTP'], message: 'REVIEW_PHONE and REVIEW_OTP must be set together' });
    }
    if (c.DATA_ENCRYPTION_KEY && !parseKey32(c.DATA_ENCRYPTION_KEY)) {
      ctx.addIssue({ code: 'custom', path: ['DATA_ENCRYPTION_KEY'], message: 'must be 32 bytes as 64 hex chars or base64' });
    }
    if (c.MFA_ENCRYPTION_KEY && !parseKey32(c.MFA_ENCRYPTION_KEY)) {
      ctx.addIssue({ code: 'custom', path: ['MFA_ENCRYPTION_KEY'], message: 'must be 32 bytes as 64 hex chars or base64' });
    }
  })
  // MFA_ENFORCED defaults to true in production and false elsewhere (contract §22).
  // v1.3 partners: the mock partner is the default outside production; production defaults to `disabled`
  // (an explicitly configured mock is refused by productionReadinessIssues).
  .transform((c) => {
    const prod = c.NODE_ENV === 'production';
    const partner = <T extends string>(v: T | undefined): T | 'mock' | 'disabled' => v ?? (prod ? 'disabled' : 'mock');
    return {
      ...c,
      MFA_ENFORCED: c.MFA_ENFORCED ?? prod,
      WHATSAPP_PROVIDER: partner(c.WHATSAPP_PROVIDER),
      LAB_PARTNER: partner(c.LAB_PARTNER),
      AMBULANCE_PARTNER: partner(c.AMBULANCE_PARTNER),
      ABDM_MODE: partner(c.ABDM_MODE),
      STT_PROVIDER: partner(c.STT_PROVIDER),
      IVR_PROVIDER: partner(c.IVR_PROVIDER),
      SOS_BUTTON_PROVIDER: partner(c.SOS_BUTTON_PROVIDER),
    };
  });

export type Config = z.infer<typeof ConfigSchema>;

export function loadConfig(overrides: Partial<Record<keyof Config, unknown>> = {}): Config {
  const raw: Record<string, unknown> = {};
  for (const key of Object.keys(ConfigShape.shape)) {
    if (process.env[key] !== undefined && process.env[key] !== '') raw[key] = process.env[key];
  }
  Object.assign(raw, overrides);
  const parsed = ConfigSchema.safeParse(raw);
  if (!parsed.success) {
    const msg = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid configuration: ${msg}`);
  }
  return parsed.data;
}

/** Decode a 32-byte key given as 64 hex chars or base64 (44 chars). */
export function parseKey32(v: string): Buffer | null {
  const s = v.trim();
  if (/^[0-9a-f]{64}$/i.test(s)) return Buffer.from(s, 'hex');
  try {
    const b = Buffer.from(s, 'base64');
    return b.length === 32 ? b : null;
  } catch {
    return null;
  }
}

export const pushConfigured = (c: Config): boolean => !!(c.FCM_PROJECT_ID && c.FCM_CLIENT_EMAIL && c.FCM_PRIVATE_KEY);

/**
 * Field-level encryption key (insurance policy numbers): DATA_ENCRYPTION_KEY when set, otherwise a sub-key derived
 * from MFA_ENCRYPTION_KEY (required in production), otherwise (dev only) from JWT_SECRET.
 */
export function dataEncryptionKey(c: Config): Buffer {
  const direct = c.DATA_ENCRYPTION_KEY ? parseKey32(c.DATA_ENCRYPTION_KEY) : null;
  if (direct) return direct;
  const base = (c.MFA_ENCRYPTION_KEY && parseKey32(c.MFA_ENCRYPTION_KEY)) || Buffer.from(`dev-data-key:${c.JWT_SECRET}`);
  return createHash('sha256').update(Buffer.concat([Buffer.from('carecompanion-data-key-v1:'), base])).digest();
}

/**
 * Production startup refusals for integrations (contract v1.1). Returned as a list so the caller can
 * print all problems at once. `buildApp` throws when this is non-empty and NODE_ENV=production.
 */
export function productionReadinessIssues(c: Config): string[] {
  if (c.NODE_ENV !== 'production') return [];
  const issues: string[] = [];
  const need = (cond: unknown, msg: string) => {
    if (!cond) issues.push(msg);
  };
  // SMS
  need(c.SMS_PROVIDER !== 'console', 'SMS_PROVIDER=console is not allowed in production (use msg91 or twilio)');
  if (c.SMS_PROVIDER === 'msg91') need(c.MSG91_AUTH_KEY && c.MSG91_OTP_TEMPLATE_ID, 'MSG91_AUTH_KEY and MSG91_OTP_TEMPLATE_ID are required');
  if (c.SMS_PROVIDER === 'twilio') {
    need(c.TWILIO_ACCOUNT_SID && c.TWILIO_AUTH_TOKEN, 'TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN are required');
    need(c.TWILIO_FROM || c.TWILIO_MESSAGING_SERVICE_SID, 'TWILIO_FROM or TWILIO_MESSAGING_SERVICE_SID is required');
  }
  // Payments
  need(c.PAYMENT_GATEWAY === 'razorpay', 'PAYMENT_GATEWAY=mock is not allowed in production');
  if (c.PAYMENT_GATEWAY === 'razorpay') {
    need(c.RAZORPAY_KEY_ID && c.RAZORPAY_KEY_SECRET, 'RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are required');
    need(c.RAZORPAY_WEBHOOK_SECRET, 'RAZORPAY_WEBHOOK_SECRET is required');
  }
  // Storage + scanning
  need(c.STORAGE_DRIVER !== 'memory', 'STORAGE_DRIVER=memory is not allowed in production');
  if (c.STORAGE_DRIVER === 's3') need(c.S3_BUCKET, 'S3_BUCKET is required when STORAGE_DRIVER=s3');
  need(c.CLAMAV_HOST, 'CLAMAV_HOST is required in production (the no-op malware scanner is refused)');
  // MFA
  need(c.MFA_ENCRYPTION_KEY, 'MFA_ENCRYPTION_KEY is required in production');
  // Video
  if (c.JITSI_APP_ID || c.JITSI_APP_SECRET) need(c.JITSI_APP_ID && c.JITSI_APP_SECRET, 'JITSI_APP_ID and JITSI_APP_SECRET must be set together');
  need(c.VIDEO_ROOM_SECRET, 'VIDEO_ROOM_SECRET is required in production (unguessable room names)');
  // FCM (optional, but all-or-nothing)
  if (c.FCM_PROJECT_ID || c.FCM_CLIENT_EMAIL || c.FCM_PRIVATE_KEY) {
    need(pushConfigured(c), 'FCM_PROJECT_ID, FCM_CLIENT_EMAIL and FCM_PRIVATE_KEY must be set together');
  }
  // ---- v1.3 partner integrations: mock partners are refused in production (use the real adapter or `disabled`).
  need(c.WHATSAPP_PROVIDER !== 'mock', 'WHATSAPP_PROVIDER=mock is not allowed in production (use meta or disabled)');
  if (c.WHATSAPP_PROVIDER === 'meta') {
    need(c.WHATSAPP_PHONE_NUMBER_ID && c.WHATSAPP_ACCESS_TOKEN, 'WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_ACCESS_TOKEN are required for WHATSAPP_PROVIDER=meta');
    need(c.WHATSAPP_APP_SECRET !== DEV_WHATSAPP_SECRET, 'WHATSAPP_APP_SECRET must be set (webhook X-Hub-Signature-256 verification)');
    need(c.WHATSAPP_VERIFY_TOKEN !== 'dev-only-whatsapp-verify-token', 'WHATSAPP_VERIFY_TOKEN must be set');
  }
  need(c.LAB_PARTNER !== 'mock', 'LAB_PARTNER=mock is not allowed in production (use http or disabled)');
  if (c.LAB_PARTNER === 'http') {
    need(c.LAB_PARTNER_BASE_URL && c.LAB_PARTNER_API_KEY, 'LAB_PARTNER_BASE_URL and LAB_PARTNER_API_KEY are required for LAB_PARTNER=http');
    need(c.LAB_WEBHOOK_SECRET !== DEV_LAB_SECRET, 'LAB_WEBHOOK_SECRET must be set');
  }
  need(c.AMBULANCE_PARTNER !== 'mock', 'AMBULANCE_PARTNER=mock is not allowed in production (use http or disabled)');
  if (c.AMBULANCE_PARTNER === 'http') need(c.AMBULANCE_PARTNER_BASE_URL && c.AMBULANCE_PARTNER_API_KEY, 'AMBULANCE_PARTNER_BASE_URL and AMBULANCE_PARTNER_API_KEY are required');
  need(c.ABDM_MODE !== 'mock' && c.ABDM_MODE !== 'sandbox', `ABDM_MODE=${c.ABDM_MODE} is not allowed in production (use production after certification, or disabled)`);
  if (c.ABDM_MODE === 'production') {
    const missing: string[] = (
      [
        ['ABDM_BASE_URL', c.ABDM_BASE_URL],
        ['ABDM_CLIENT_ID', c.ABDM_CLIENT_ID],
        ['ABDM_CLIENT_SECRET', c.ABDM_CLIENT_SECRET],
        ['ABDM_HIU_ID', c.ABDM_HIU_ID],
        ['ABDM_HIP_ID', c.ABDM_HIP_ID],
        ['ABDM_CALLBACK_URL', c.ABDM_CALLBACK_URL],
      ] as const
    )
      .filter(([, v]) => !v)
      .map(([k]) => k);
    if (c.ABDM_WEBHOOK_SECRET === DEV_ABDM_SECRET) missing.push('ABDM_WEBHOOK_SECRET');
    need(!missing.length, `ABDM production mode requires certification credentials; missing: ${missing.join(', ')}`);
  }
  if (c.DRUG_KNOWLEDGE_PROVIDER === 'http') need(c.DRUG_KNOWLEDGE_BASE_URL && c.DRUG_KNOWLEDGE_API_KEY, 'DRUG_KNOWLEDGE_BASE_URL and DRUG_KNOWLEDGE_API_KEY are required');
  need(c.STT_PROVIDER !== 'mock', 'STT_PROVIDER=mock is not allowed in production (use openai_whisper_compatible, google or disabled)');
  if (c.STT_PROVIDER === 'openai_whisper_compatible' || c.STT_PROVIDER === 'google') need(c.STT_API_KEY, 'STT_API_KEY is required for the speech-to-text provider');
  need(c.IVR_PROVIDER !== 'mock', 'IVR_PROVIDER=mock is not allowed in production (use exotel, twilio or disabled)');
  if (c.IVR_PROVIDER === 'exotel') need(c.IVR_WEBHOOK_SECRET !== DEV_IVR_SECRET, 'IVR_WEBHOOK_SECRET must be set for exotel');
  if (c.IVR_PROVIDER === 'twilio') need(c.TWILIO_AUTH_TOKEN && c.IVR_PUBLIC_URL, 'TWILIO_AUTH_TOKEN and IVR_PUBLIC_URL are required for IVR_PROVIDER=twilio (X-Twilio-Signature)');
  need(c.SOS_BUTTON_PROVIDER !== 'mock', 'SOS_BUTTON_PROVIDER=mock is not allowed in production (use vendor or disabled)');
  if (c.SOS_BUTTON_PROVIDER === 'vendor') need(c.SOS_WEBHOOK_SECRET !== DEV_SOS_SECRET, 'SOS_WEBHOOK_SECRET must be set');
  return issues;
}

export function corsOriginAllowed(config: Config, origin: string | undefined): boolean {
  if (!origin) return true;
  const list = config.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean);
  if (list.includes(origin)) return true;
  if (config.NODE_ENV !== 'production' && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return true;
  return false;
}
