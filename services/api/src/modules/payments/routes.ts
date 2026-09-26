import { desc, eq, inArray } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { payments } from '../../db/schema.js';
import { assertCanActForPatient, listActablePatients } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { errors } from '../../lib/errors.js';
import { envelope, pageFromQuery } from '../../lib/pagination.js';
import { parse, zUuid } from '../../lib/validate.js';
import { requireRoles } from '../../plugins/auth.js';
import { parseWebhookEvent, verifyWebhookSignature } from './gateway.js';
import { toPayment } from './service.js';

export async function paymentRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const db = svc.db;

  app.get('/payments', async (req) => {
    const q = parse(z.object({ patientId: zUuid.optional() }), req.query);
    const page = pageFromQuery(req.query);
    let ids: string[];
    if (q.patientId) {
      await assertCanActForPatient(db, req.ctx, q.patientId, ['book', 'staff_ops'], 'payment.list');
      ids = [q.patientId];
    } else {
      ids = (await listActablePatients(db, req.ctx.user)).filter((p) => p.permissions.includes('book')).map((p) => p.patientId);
    }
    if (!ids.length) return { items: [], nextCursor: null };
    const rows = await db
      .select()
      .from(payments)
      .where(inArray(payments.patientId, ids))
      .orderBy(desc(payments.createdAt))
      .limit(page.limit + 1)
      .offset(page.offset);
    return envelope(rows.map(toPayment), page);
  });

  app.get('/payments/:id', async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [p] = await db.select().from(payments).where(eq(payments.id, id));
    if (!p) throw errors.notFound('Payment');
    await assertCanActForPatient(db, req.ctx, p.patientId, ['book', 'staff_ops'], 'payment.read');
    return toPayment(p);
  });

  app.post('/payments/:id/confirm-mock', { config: { idempotent: true } }, async (req) => {
    if (svc.config.NODE_ENV === 'production' || svc.payments.gateway.name !== 'mock') {
      throw errors.forbidden('Mock payment confirmation is disabled in this environment');
    }
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ outcome: z.enum(['success', 'failure']) }), req.body);
    const [p] = await db.select().from(payments).where(eq(payments.id, id));
    if (!p) throw errors.notFound('Payment');
    await assertCanActForPatient(db, req.ctx, p.patientId, 'book', 'payment.confirm_mock');
    if (p.status !== 'pending') return toPayment(p);
    const { payment } = await svc.payments.applyEvent(
      {
        eventId: `mock_evt_${p.gatewayOrderId}`,
        type: body.outcome === 'success' ? 'payment.captured' : 'payment.failed',
        orderId: p.gatewayOrderId,
        gatewayPaymentId: `pay_mock_${p.id.slice(0, 8)}`,
      },
      req.ctx.actor,
    );
    const [fresh] = await db.select().from(payments).where(eq(payments.id, id));
    return toPayment(fresh ?? payment!);
  });

  app.post('/payments/:id/verify', { config: { idempotent: true } }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(
      z.object({
        razorpayPaymentId: z.string().min(1).max(64),
        razorpayOrderId: z.string().min(1).max(64),
        razorpaySignature: z.string().min(1).max(256),
      }),
      req.body,
    );
    const [p] = await db.select().from(payments).where(eq(payments.id, id));
    if (!p) throw errors.notFound('Payment');
    await assertCanActForPatient(db, req.ctx, p.patientId, 'book', 'payment.verify');
    return toPayment(await svc.payments.verifyCheckout(id, body, req.ctx.actor));
  });

  app.post('/payments/:id/retry', { config: { idempotent: true } }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const [p] = await db.select().from(payments).where(eq(payments.id, id));
    if (!p) throw errors.notFound('Payment');
    await assertCanActForPatient(db, req.ctx, p.patientId, 'book', 'payment.retry');
    return toPayment(await svc.payments.retry(id, req.ctx.actor));
  });

  app.post('/payments/:id/refund', { config: { idempotent: 'optional' }, preHandler: requireRoles(svc, 'ops_admin', 'super_admin') }, async (req) => {
    const { id } = parse(z.object({ id: zUuid }), req.params);
    const body = parse(z.object({ reason: z.string().trim().min(1).max(500), amount: z.number().int().positive().optional() }), req.body);
    const updated = await svc.payments.refund(id, { amount: body.amount, reason: body.reason, actor: req.ctx.actor });
    return toPayment(updated);
  });
}

/** Public webhook endpoint with HMAC verification over the RAW body. */
export async function paymentWebhookRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  app.addContentTypeParser('application/json', { parseAs: 'buffer' }, (_req, body, done) => done(null, body));

  const header = (v: unknown): string | undefined => (typeof v === 'string' ? v : undefined);

  app.post('/webhooks/payments', { bodyLimit: 256 * 1024 }, async (req, reply) => {
    const raw = req.body as Buffer;
    const actor = { ...SYSTEM_ACTOR, name: 'payment-gateway', role: 'webhook', ip: req.ip, correlationId: req.correlationId };
    // Razorpay signs the raw body with the webhook secret configured in its dashboard (X-Razorpay-Signature).
    // X-Signature (PAYMENT_WEBHOOK_SECRET) remains accepted for the mock gateway and internal tooling.
    const rzpSig = header(req.headers['x-razorpay-signature']);
    const rzpSecret = svc.config.RAZORPAY_WEBHOOK_SECRET;
    const valid =
      Buffer.isBuffer(raw) &&
      (rzpSig !== undefined
        ? svc.payments.gateway.name === 'razorpay' && !!rzpSecret && verifyWebhookSignature(rzpSecret, raw, rzpSig)
        : verifyWebhookSignature(svc.config.PAYMENT_WEBHOOK_SECRET, raw, header(req.headers['x-signature'])));
    if (!valid) {
      await audit(svc.db, actor, { action: 'payment.webhook', entityType: 'payment', outcome: 'denied', metadata: { reason: 'bad_signature' } });
      throw errors.unauthenticated('Invalid webhook signature');
    }
    let body: unknown;
    try {
      body = JSON.parse(raw.toString('utf8'));
    } catch {
      throw errors.validation('Invalid JSON');
    }
    const ev = parseWebhookEvent(body, header(req.headers['x-razorpay-event-id']) ?? header(req.headers['x-event-id']));
    if (!ev) throw errors.validation('Unsupported webhook payload');
    const { applied, payment } = await svc.payments.applyEvent(ev, actor);
    return reply.code(200).send({ received: true, duplicate: !applied, paymentId: payment?.id ?? null });
  });
}

