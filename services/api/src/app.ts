import './lib/fastify-augment.js';
import { randomUUID } from 'node:crypto';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import multipart from '@fastify/multipart';
import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyError, type FastifyInstance, type FastifyReply, type FastifyRequest } from 'fastify';
import { count, eq } from 'drizzle-orm';
import { ZodError } from 'zod';
import { corsOriginAllowed, loadConfig, productionReadinessIssues, pushConfigured, type Config } from './config.js';
import { createDb, runMigrations, type DbHandle } from './db/client.js';
import { devices, notificationOutbox, safetyEvents } from './db/schema.js';
import { safeEqual } from './lib/crypto.js';
import { AppError } from './lib/errors.js';
import { defaultFetch, type FetchLike } from './lib/http.js';
import { registerIdempotency } from './lib/idempotency.js';
import { loggerOptions } from './lib/logger.js';
import { Metrics } from './lib/metrics.js';
import { accountRoutes } from './modules/account/routes.js';
import { AiGateway } from './modules/ai/gateway.js';
import { AnthropicModel, RuleBasedModel, type ChatModel } from './modules/ai/models.js';
import { aiRoutes } from './modules/ai/routes.js';
import { adminRoutes } from './modules/admin/routes.js';
import { appointmentPaymentEffects } from './modules/appointments/service.js';
import { appointmentRoutes } from './modules/appointments/routes.js';
import { authPublicRoutes, meRoutes } from './modules/auth/routes.js';
import { MfaService } from './modules/auth/mfa.js';
import { AuthService } from './modules/auth/service.js';
import { createSmsProvider, type SmsProvider } from './modules/auth/sms.js';
import { carePlanRoutes } from './modules/careplans/routes.js';
import { clinicianRoutes } from './modules/clinician/routes.js';
import { publicConfigRoutes } from './modules/config/routes.js';
import { consentRoutes } from './modules/consent/routes.js';
import { doctorRoutes } from './modules/doctors/routes.js';
import { emergencyRoutes } from './modules/emergency/routes.js';
import { episodeRoutes } from './modules/episodes/routes.js';
import { fallRoutes } from './modules/fall/routes.js';
import { familyRoutes } from './modules/family/routes.js';
import { flagRoutes } from './modules/flags/routes.js';
import { FlagService } from './modules/flags/service.js';
import { homeVisitPaymentEffects } from './modules/homevisits/service.js';
import { homeVisitRoutes } from './modules/homevisits/routes.js';
import { insightRoutes } from './modules/insights/routes.js';
import { knowledgeAdminRoutes } from './modules/knowledge/routes.js';
import { KnowledgeService } from './modules/knowledge/service.js';
import { medicationRoutes } from './modules/medications/routes.js';
import { SmsChannel, consoleChannels, type Channel, type ChannelAdapter } from './modules/notifications/channels.js';
import { FcmPushChannel } from './modules/notifications/fcm.js';
import { notificationRoutes } from './modules/notifications/routes.js';
import { NotificationService } from './modules/notifications/service.js';
import { opsRoutes } from './modules/ops/routes.js';
import { patientRoutes } from './modules/patients/routes.js';
import { MockGateway, RazorpayGateway, type PaymentGateway } from './modules/payments/gateway.js';
import { paymentRoutes, paymentWebhookRoutes } from './modules/payments/routes.js';
import { PaymentService } from './modules/payments/service.js';
import { pharmacyPaymentEffects, pharmacyRoutes } from './modules/pharmacy/routes.js';
import { providerAppRoutes } from './modules/provider-app/routes.js';
import { providerDirectoryRoutes } from './modules/providers/routes.js';
import { recordRoutes } from './modules/records/routes.js';
import { ClamdScanner } from './modules/records/scanner.js';
import { NoopScanner, type MalwareScanner, type StorageAdapter } from './modules/records/storage.js';
import { createStorage } from './modules/records/storage-factory.js';
import { safetyAdminRoutes } from './modules/safety/routes.js';
import { SafetyService } from './modules/safety/service.js';
import { timelineRoutes } from './modules/timeline/routes.js';
import { createVideoProvider, type VideoProvider } from './modules/video/provider.js';
import { videoRoutes } from './modules/video/routes.js';
import { vitalRoutes } from './modules/vitals/routes.js';
import { wearableRoutes } from './modules/wearables/routes.js';
import { wellnessRoutes } from './modules/wellness/routes.js';
import { woundRoutes } from './modules/wound/routes.js';
import { applicationRoutes } from './modules/applications/routes.js';
import { billingRoutes } from './modules/billing/routes.js';
import { ensureInvoice } from './modules/billing/service.js';
import { coordinatorRoutes } from './modules/coordinator/routes.js';
import { mePhotoRoutes, publicMediaRoutes } from './modules/media/routes.js';
import { messagingRoutes } from './modules/messaging/routes.js';
import { prescriptionRoutes } from './modules/prescriptions/routes.js';
import { referralRoutes } from './modules/referrals/routes.js';
import { reviewRoutes } from './modules/reviews/routes.js';
import { scheduleRoutes } from './modules/schedules/routes.js';
import { schemeRoutes } from './modules/schemes/routes.js';
import { subscriptionRoutes } from './modules/subscriptions/routes.js';
import { subscriptionPaymentEffects } from './modules/subscriptions/service.js';
import { createPartners, type Partners } from './modules/partners/index.js';
import { HttpDrugKnowledgeProvider, PackDrugKnowledgeProvider } from './modules/rxcheck/engine.js';
import { WhatsAppChannel } from './modules/whatsapp/service.js';
import { abdmRoutes, abdmWebhookRoutes } from './modules/abdm/routes.js';
import { ambulanceRoutes } from './modules/ambulance/routes.js';
import { checkinRoutes } from './modules/checkins/routes.js';
import { dietRoutes } from './modules/diet/routes.js';
import { dischargeRoutes } from './modules/discharges/routes.js';
import { enterpriseRoutes } from './modules/enterprise/routes.js';
import { fieldOpsRoutes } from './modules/fieldops/routes.js';
import { geofenceRoutes, sosWebhookRoutes } from './modules/geofence/routes.js';
import { insuranceRoutes } from './modules/insurance/routes.js';
import { ivrRoutes, ivrWebhookRoutes } from './modules/ivr/routes.js';
import { labRoutes, labWebhookRoutes } from './modules/lab/routes.js';
import { labPaymentEffects } from './modules/lab/service.js';
import { physioRoutes } from './modules/physio/routes.js';
import { preventiveRoutes } from './modules/preventive/routes.js';
import { programRoutes } from './modules/programs/routes.js';
import { scribeRoutes } from './modules/scribe/routes.js';
import { secondOpinionPaymentEffects, secondOpinionRoutes } from './modules/secondopinion/routes.js';
import { supportRoutes } from './modules/support/routes.js';
import { walletRoutes } from './modules/wallet/routes.js';
import { whatsappRoutes, whatsappWebhookRoutes } from './modules/whatsapp/routes.js';
import { makeAuthenticate } from './plugins/auth.js';
import type { Services } from './services.js';
import { createLeaderElector, type LeaderElector } from './worker/leader.js';
import { Scheduler } from './worker/scheduler.js';

export interface BuildOptions {
  config?: Partial<Record<keyof Config, unknown>>;
  /** Inject a model (tests). Default: Anthropic when ANTHROPIC_API_KEY is set, else RuleBasedModel. */
  aiModel?: ChatModel;
  storage?: StorageAdapter;
  dbHandle?: DbHandle;
  channels?: Record<Channel, ChannelAdapter>;
  sms?: SmsProvider;
  paymentGateway?: PaymentGateway;
  scanner?: MalwareScanner;
  video?: VideoProvider;
  /** HTTP client for SMS / Razorpay / FCM adapters (tests inject a fake). */
  fetchImpl?: FetchLike;
  leader?: LeaderElector;
  /** Tests only: skip the production integration refusals (productionReadinessIssues). */
  skipProductionReadiness?: boolean;
  /** Start the in-process worker (default: config.WORKER_ENABLED and not test). */
  startWorker?: boolean;
  /** v1.3 partner adapters (tests inject fakes); defaults come from the config. */
  partners?: Partial<Partners>;
}

export interface BuiltApp {
  app: FastifyInstance;
  svc: Services;
  scheduler: Scheduler;
}

export const VERSION = '1.0.0';

export async function buildApp(opts: BuildOptions = {}): Promise<BuiltApp> {
  const config = loadConfig(opts.config ?? {});
  if (!opts.skipProductionReadiness) {
    const issues = productionReadinessIssues(config);
    if (issues.length) throw new Error(`Refusing to start in production:\n - ${issues.join('\n - ')}`);
  }
  const quiet = config.NODE_ENV === 'test' || config.LOG_LEVEL === 'silent';
  const fetchImpl = opts.fetchImpl ?? defaultFetch;
  const app = Fastify({
    logger: loggerOptions(config),
    trustProxy: true,
    bodyLimit: config.BODY_LIMIT_KB * 1024,
    genReqId: (req) => {
      const h = req.headers['x-correlation-id'];
      return typeof h === 'string' && /^[\w.-]{1,100}$/.test(h) ? h : randomUUID();
    },
  });

  // ---------------------------------------------------------------- services
  const ownsDb = !opts.dbHandle;
  const dbHandle = opts.dbHandle ?? (await createDb({ databaseUrl: config.DATABASE_URL, pgliteDir: config.PGLITE_DIR, poolMax: config.DATABASE_POOL_MAX }));
  await runMigrations(dbHandle);
  const db = dbHandle.db;
  const storage = opts.storage ?? createStorage(config);
  const scanner: MalwareScanner =
    opts.scanner ?? (config.CLAMAV_HOST ? new ClamdScanner(config.CLAMAV_HOST, config.CLAMAV_PORT, config.CLAMAV_TIMEOUT_MS) : new NoopScanner());
  const metrics = new Metrics({ defaultMetrics: config.NODE_ENV !== 'test' });
  const flags = new FlagService(db);
  await flags.ensureDefaults();
  const sms = opts.sms ?? createSmsProvider(config, quiet, fetchImpl);
  const channels: Record<Channel, ChannelAdapter> = opts.channels ?? consoleChannels(quiet);
  if (!opts.channels) {
    if (sms.name !== 'console') channels.sms = new SmsChannel(sms);
    if (pushConfigured(config)) {
      channels.push = new FcmPushChannel(
        { projectId: config.FCM_PROJECT_ID!, clientEmail: config.FCM_CLIENT_EMAIL!, privateKey: config.FCM_PRIVATE_KEY! },
        async (token) => {
          await db.delete(devices).where(eq(devices.pushToken, token));
        },
        fetchImpl,
      );
    }
  }
  const notify = new NotificationService(db, channels);
  notify.onDelivery = (channel, outcome) => {
    if (channel === 'push') metrics.pushSent.inc({ outcome });
    if (channel === 'sms') metrics.smsSent.inc({ provider: sms.name, outcome });
  };
  const primary: ChatModel =
    opts.aiModel ??
    (config.ANTHROPIC_API_KEY
      ? new AnthropicModel(config.AI_MODEL, { apiKey: config.ANTHROPIC_API_KEY, timeoutMs: config.AI_TIMEOUT_MS, maxRetries: config.AI_MAX_RETRIES })
      : new RuleBasedModel());
  const gateway: PaymentGateway =
    opts.paymentGateway ??
    (config.PAYMENT_GATEWAY === 'razorpay'
      ? new RazorpayGateway(config.RAZORPAY_KEY_ID, config.RAZORPAY_KEY_SECRET, { baseUrl: config.RAZORPAY_BASE_URL, timeoutMs: config.PAYMENT_TIMEOUT_MS }, fetchImpl)
      : new MockGateway());
  const payments = new PaymentService(db, gateway, notify, config);
  const auth = new AuthService(db, config, sms);
  auth.onSms = (provider, outcome) => metrics.smsSent.inc({ provider, outcome });
  const ai = new AiGateway(primary, db, flags, config);
  ai.prom = metrics;
  const video = opts.video ?? createVideoProvider(config);
  const partners = createPartners(config, fetchImpl, quiet, opts.partners);
  if (!opts.channels && partners.whatsapp.name === 'meta') channels.whatsapp = new WhatsAppChannel(partners.whatsapp, config.WHATSAPP_TEMPLATE_CARE_UPDATE);
  const svc: Services = {
    config,
    dbHandle,
    db,
    storage,
    scanner,
    sms,
    flags,
    safety: new SafetyService(db, config),
    knowledge: new KnowledgeService(db),
    ai,
    notify,
    payments,
    auth,
    mfa: new MfaService(db, config, auth),
    video,
    metrics,
    drugKnowledge:
      config.DRUG_KNOWLEDGE_PROVIDER === 'http' && config.DRUG_KNOWLEDGE_BASE_URL && config.DRUG_KNOWLEDGE_API_KEY
        ? new HttpDrugKnowledgeProvider(config.DRUG_KNOWLEDGE_BASE_URL, config.DRUG_KNOWLEDGE_API_KEY, fetchImpl)
        : new PackDrugKnowledgeProvider(config),
    partners,
  };
  metrics.collectors.push(async () => {
    const outbox = await db.select({ status: notificationOutbox.status, n: count() }).from(notificationOutbox).groupBy(notificationOutbox.status);
    metrics.outboxDepth.reset();
    for (const r of outbox) metrics.outboxDepth.set({ status: r.status }, Number(r.n));
    const se = await db
      .select({ level: safetyEvents.level, status: safetyEvents.status, n: count() })
      .from(safetyEvents)
      .groupBy(safetyEvents.level, safetyEvents.status);
    metrics.safetyEvents.reset();
    for (const r of se) metrics.safetyEvents.set({ level: r.level, status: r.status }, Number(r.n));
  });
  payments.effects.appointment = appointmentPaymentEffects(notify, video);
  payments.effects.home_visit = homeVisitPaymentEffects(notify);
  payments.effects.pharmacy_order = pharmacyPaymentEffects;
  payments.effects.subscription = subscriptionPaymentEffects(notify);
  payments.effects.lab_order = labPaymentEffects(() => svc);
  payments.effects.second_opinion = secondOpinionPaymentEffects(notify);
  // Contract section 32: every successful payment gets its sequential invoice number right away.
  payments.afterSucceeded.push(async (p) => {
    await ensureInvoice(db, config, p.id);
  });
  payments.onHookError = (err) => app.log.error({ err }, 'payment success hook failed');
  app.decorate('svc', svc);
  app.decorateRequest('correlationId', '');

  // ---------------------------------------------------------------- cross-cutting
  app.addHook('onRequest', async (req, reply) => {
    req.correlationId = req.id;
    reply.header('X-Correlation-Id', req.id);
  });
  app.addHook('onResponse', async (req, reply) => {
    // Route pattern (never the raw URL) keeps label cardinality bounded and PHI-free.
    const route = req.routeOptions.url ?? 'unmatched';
    metrics.httpDuration.observe({ method: req.method, route, status_code: String(reply.statusCode) }, reply.elapsedTime / 1000);
  });

  await app.register(helmet, {
    // JSON API: no inline content is served, but files are fetched cross-origin by the web app.
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    contentSecurityPolicy: { directives: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] } },
    hsts: config.NODE_ENV === 'production' ? { maxAge: 31536000, includeSubDomains: true } : false,
  });

  await app.register(cors, {
    origin: (origin, cb) => cb(null, corsOriginAllowed(config, origin)),
    credentials: true,
    exposedHeaders: ['X-Correlation-Id', 'X-Unread-Count', 'Idempotent-Replayed'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key', 'X-Correlation-Id', 'Accept-Language', 'X-Signature', 'X-Event-Id', 'X-Razorpay-Signature', 'X-Razorpay-Event-Id', 'X-Tenant-Code'],
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  });
  // REDIS_URL -> shared rate-limit counters across instances; otherwise per-process memory.
  const redis = config.REDIS_URL ? await createRedis(config.REDIS_URL) : null;
  await app.register(rateLimit, {
    global: true,
    ...(redis ? { redis, nameSpace: 'cc-rl:', skipOnError: true } : {}),
    max: config.RATE_LIMIT_MAX,
    timeWindow: '1 minute',
    errorResponseBuilder: (_req, ctx) => new AppError('RATE_LIMITED', `Too many requests. Retry in ${Math.ceil(ctx.ttl / 1000)}s.`),
  });
  await app.register(multipart, {
    limits: { fileSize: config.MAX_UPLOAD_MB * 1024 * 1024, files: 1, fields: 20, fieldSize: 10_000 },
  });

  app.setErrorHandler((err: FastifyError | AppError | ZodError, req, reply) => {
    const correlationId = req.correlationId || req.id;
    let status = 500;
    let body: { code: string; message: string; details: Record<string, unknown> };
    if (err instanceof AppError) {
      status = err.status;
      body = { code: err.code, message: err.message, details: err.details };
    } else if (err instanceof ZodError) {
      status = 400;
      body = { code: 'VALIDATION_ERROR', message: 'Request validation failed', details: { issues: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })) } };
    } else {
      const fe = err as FastifyError;
      const sc = fe.statusCode ?? 500;
      if (fe.code === 'FST_REQ_FILE_TOO_LARGE' || sc === 413) {
        status = 400;
        body = { code: 'VALIDATION_ERROR', message: `File too large (max ${config.MAX_UPLOAD_MB}MB)`, details: {} };
      } else if (sc === 429) {
        status = 429;
        body = { code: 'RATE_LIMITED', message: 'Too many requests', details: {} };
      } else if (sc >= 400 && sc < 500) {
        status = 400;
        body = { code: 'VALIDATION_ERROR', message: fe.message || 'Bad request', details: {} };
      } else {
        req.log.error({ err }, 'unhandled error');
        body = { code: 'INTERNAL', message: 'Something went wrong', details: {} };
      }
    }
    if (status >= 500 && err instanceof AppError) req.log.warn({ code: body.code }, 'dependency error');
    reply.code(status).send({ error: { ...body, correlationId } });
  });

  app.setNotFoundHandler((req, reply) => {
    reply.code(404).send({ error: { code: 'NOT_FOUND', message: `Route ${req.method} ${req.url.split('?')[0]} not found`, details: {}, correlationId: req.correlationId || req.id } });
  });

  // ---------------------------------------------------------------- system
  const health = async () => ({ status: 'ok', version: VERSION });
  const worker: { scheduler: Scheduler | null } = { scheduler: null };
  const ready = async (_req: unknown, reply: { code: (n: number) => unknown }) => {
    let dbOk = true;
    try {
      await dbHandle.ping();
    } catch {
      dbOk = false;
    }
    let storageOk = true;
    try {
      await storage.ping();
      await scanner.ping?.();
    } catch {
      storageOk = false;
    }
    const safety = dbOk ? await svc.safety.status() : 'unavailable';
    const ai = dbOk ? await svc.ai.health() : 'degraded';
    const ok = dbOk && storageOk && safety !== 'unavailable';
    if (!ok) reply.code(503);
    return {
      status: ok ? 'ready' : 'not_ready',
      checks: {
        db: dbOk ? 'ok' : 'error',
        ai,
        safetyRules: safety === 'ok' ? 'ok' : safety === 'fixture' ? 'fixture' : 'unavailable',
        storage: storageOk ? 'ok' : 'error',
        worker: worker.scheduler?.status() ?? 'disabled',
      },
    };
  };
  // Contract section 28: Prometheus text format; bearer METRICS_TOKEN when set; no auth in dev; closed in prod without a token.
  const metricsHandler = async (req: FastifyRequest, reply: FastifyReply) => {
    const token = config.METRICS_TOKEN;
    if (token) {
      const h = req.headers.authorization ?? '';
      if (!h.startsWith('Bearer ') || !safeEqual(h.slice(7).trim(), token)) throw new AppError('UNAUTHENTICATED', 'Invalid metrics token');
    } else if (config.NODE_ENV === 'production') {
      throw new AppError('FORBIDDEN', 'Metrics are disabled: set METRICS_TOKEN');
    }
    const body = await metrics.render();
    return reply.header('content-type', metrics.contentType).header('cache-control', 'no-store').send(body);
  };
  app.get('/health', { config: { rateLimit: false } }, health);
  app.get('/ready', { config: { rateLimit: false } }, ready);
  app.get('/metrics', { config: { rateLimit: false } }, metricsHandler);

  // ---------------------------------------------------------------- API v1
  await app.register(
    async (api) => {
      api.get('/health', health);
      api.get('/ready', ready);
      api.get('/metrics', { config: { rateLimit: false } }, metricsHandler);
      await api.register(authPublicRoutes);
      await api.register(publicConfigRoutes);
      await api.register(paymentWebhookRoutes);
      await api.register(publicMediaRoutes);
      // v1.3 partner webhooks (public; each verifies its own HMAC signature over the raw body)
      await api.register(whatsappWebhookRoutes);
      await api.register(labWebhookRoutes);
      await api.register(abdmWebhookRoutes);
      await api.register(sosWebhookRoutes);
      await api.register(ivrWebhookRoutes);

      await api.register(async (priv) => {
        priv.addHook('onRequest', makeAuthenticate(svc));
        registerIdempotency(priv, db);
        for (const mod of [
          meRoutes,
          consentRoutes,
          patientRoutes,
          familyRoutes,
          episodeRoutes,
          providerDirectoryRoutes,
          doctorRoutes,
          appointmentRoutes,
          videoRoutes,
          homeVisitRoutes,
          recordRoutes,
          timelineRoutes,
          vitalRoutes,
          aiRoutes,
          carePlanRoutes,
          medicationRoutes,
          notificationRoutes,
          paymentRoutes,
          pharmacyRoutes,
          wellnessRoutes,
          woundRoutes,
          wearableRoutes,
          fallRoutes,
          emergencyRoutes,
          insightRoutes,
          clinicianRoutes,
          providerAppRoutes,
          opsRoutes,
          adminRoutes,
          safetyAdminRoutes,
          knowledgeAdminRoutes,
          flagRoutes,
          accountRoutes,
          // v1.2 (contract sections 29-39)
          scheduleRoutes,
          mePhotoRoutes,
          applicationRoutes,
          prescriptionRoutes,
          billingRoutes,
          reviewRoutes,
          messagingRoutes,
          coordinatorRoutes,
          referralRoutes,
          subscriptionRoutes,
          schemeRoutes,
          // v1.3 (contract sections 41-62)
          checkinRoutes,
          programRoutes,
          whatsappRoutes,
          labRoutes,
          scribeRoutes,
          fieldOpsRoutes,
          secondOpinionRoutes,
          abdmRoutes,
          insuranceRoutes,
          preventiveRoutes,
          physioRoutes,
          dietRoutes,
          ambulanceRoutes,
          geofenceRoutes,
          enterpriseRoutes,
          dischargeRoutes,
          walletRoutes,
          supportRoutes,
          ivrRoutes,
        ]) {
          await priv.register(mod);
        }
      });
    },
    { prefix: config.API_PREFIX },
  );

  // ---------------------------------------------------------------- worker
  const leader = opts.leader ?? (await createLeaderElector(dbHandle, config.WORKER_LOCK_KEY));
  const scheduler = new Scheduler(svc, app.log, undefined, leader);
  worker.scheduler = scheduler;
  const startWorker = opts.startWorker ?? (config.WORKER_ENABLED && config.NODE_ENV !== 'test');
  if (startWorker) app.addHook('onReady', async () => scheduler.start(config.WORKER_INTERVAL_MS));
  app.addHook('onClose', async () => {
    await scheduler.stop();
    if (redis) await redis.quit().catch(() => undefined);
    if (ownsDb) await dbHandle.close();
  });

  return { app, svc, scheduler };
}

/** ioredis client for the shared rate-limit store. Lazy connect; errors are logged by the plugin (skipOnError). */
export async function createRedis(url: string) {
  const { Redis } = await import('ioredis');
  return new Redis(url, { lazyConnect: true, connectTimeout: 2000, maxRetriesPerRequest: 1, enableOfflineQueue: true });
}
