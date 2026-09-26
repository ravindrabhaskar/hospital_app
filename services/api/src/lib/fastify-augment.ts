import type { Services } from '../services.js';
import type { RequestCtx } from './context.js';

declare module 'fastify' {
  interface FastifyInstance {
    svc: Services;
  }
  interface FastifyRequest {
    correlationId: string;
    ctx: RequestCtx;
    idempotencyRowId?: string;
  }
  interface FastifyContextConfig {
    /** true = Idempotency-Key required; 'optional' = honoured when sent. */
    idempotent?: boolean | 'optional';
    public?: boolean;
  }
}

export {};
