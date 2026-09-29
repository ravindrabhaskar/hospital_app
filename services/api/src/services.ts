import type { Config } from './config.js';
import type { Db, DbHandle } from './db/client.js';
import type { AiGateway } from './modules/ai/gateway.js';
import type { Metrics } from './lib/metrics.js';
import type { MfaService } from './modules/auth/mfa.js';
import type { AuthService } from './modules/auth/service.js';
import type { SmsProvider } from './modules/auth/sms.js';
import type { FlagService } from './modules/flags/service.js';
import type { KnowledgeService } from './modules/knowledge/service.js';
import type { NotificationService } from './modules/notifications/service.js';
import type { PaymentService } from './modules/payments/service.js';
import type { MalwareScanner, StorageAdapter } from './modules/records/storage.js';
import type { SafetyService } from './modules/safety/service.js';
import type { VideoProvider } from './modules/video/provider.js';
import type { Partners } from './modules/partners/index.js';
import type { DrugKnowledgeProvider } from './modules/rxcheck/engine.js';

/** Dependency container shared by modules (decorated on the Fastify instance as `app.svc`). */
export interface Services {
  config: Config;
  dbHandle: DbHandle;
  db: Db;
  storage: StorageAdapter;
  scanner: MalwareScanner;
  sms: SmsProvider;
  flags: FlagService;
  safety: SafetyService;
  knowledge: KnowledgeService;
  ai: AiGateway;
  notify: NotificationService;
  payments: PaymentService;
  auth: AuthService;
  mfa: MfaService;
  video: VideoProvider;
  metrics: Metrics;
  // v1.3 partner adapters (contract sections 41-62)
  drugKnowledge: DrugKnowledgeProvider;
  partners: Partners;
}
