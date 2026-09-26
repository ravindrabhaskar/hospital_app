import { Counter, Gauge, Histogram, Registry, collectDefaultMetrics } from 'prom-client';

/**
 * Prometheus metrics. One Registry per app instance (tests build many apps in one process).
 * Labels never carry PHI or user ids: routes are the route *pattern* (`/patients/:id`), not the URL.
 */
export class Metrics {
  readonly registry = new Registry();
  readonly httpDuration: Histogram<'method' | 'route' | 'status_code'>;
  readonly aiLatency: Histogram<'use_case' | 'model_kind' | 'outcome'>;
  readonly aiFallbacks: Counter<'use_case' | 'reason'>;
  readonly aiCalls: Counter<'use_case'>;
  readonly outboxDepth: Gauge<'status'>;
  readonly safetyEvents: Gauge<'level' | 'status'>;
  readonly smsSent: Counter<'provider' | 'outcome'>;
  readonly pushSent: Counter<'outcome'>;
  readonly workerLeader: Gauge;
  readonly filesRejected: Counter;

  constructor(opts: { defaultMetrics?: boolean } = {}) {
    if (opts.defaultMetrics !== false) collectDefaultMetrics({ register: this.registry, prefix: 'cc_' });
    const registers = [this.registry];
    this.httpDuration = new Histogram({
      name: 'cc_http_request_duration_seconds',
      help: 'HTTP request duration by route pattern and status code',
      labelNames: ['method', 'route', 'status_code'],
      buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
      registers,
    });
    this.aiLatency = new Histogram({
      name: 'cc_ai_request_duration_seconds',
      help: 'AI gateway call latency',
      labelNames: ['use_case', 'model_kind', 'outcome'],
      buckets: [0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 40],
      registers,
    });
    this.aiCalls = new Counter({ name: 'cc_ai_calls_total', help: 'AI gateway calls', labelNames: ['use_case'], registers });
    this.aiFallbacks = new Counter({
      name: 'cc_ai_fallbacks_total',
      help: 'AI calls answered by the deterministic fallback',
      labelNames: ['use_case', 'reason'],
      registers,
    });
    this.outboxDepth = new Gauge({ name: 'cc_notification_outbox', help: 'Notification outbox rows by status', labelNames: ['status'], registers });
    this.safetyEvents = new Gauge({ name: 'cc_safety_events', help: 'Safety events by level and status', labelNames: ['level', 'status'], registers });
    this.smsSent = new Counter({ name: 'cc_sms_sent_total', help: 'SMS sends', labelNames: ['provider', 'outcome'], registers });
    this.pushSent = new Counter({ name: 'cc_push_sent_total', help: 'Push sends', labelNames: ['outcome'], registers });
    this.workerLeader = new Gauge({ name: 'cc_worker_leader', help: '1 when this instance holds the worker leader lock', registers });
    this.filesRejected = new Counter({ name: 'cc_files_rejected_total', help: 'Uploads rejected by the malware scanner', registers });
  }

  /** Called on scrape to refresh DB-derived gauges. */
  collectors: Array<() => Promise<void>> = [];

  async render(): Promise<string> {
    for (const c of this.collectors) {
      try {
        await c();
      } catch {
        // a failing collector must never break scraping
      }
    }
    return this.registry.metrics();
  }

  get contentType(): string {
    return this.registry.contentType;
  }
}
