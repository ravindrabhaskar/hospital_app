import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { safeEqual } from '../../lib/crypto.js';
import { errors } from '../../lib/errors.js';
import { parse } from '../../lib/validate.js';
import { firstDelivery, parseJsonBuffer, rawBodyParsers, verifyHmacHeader } from '../../lib/webhooks.js';
import { handleInbound, setOptIn, whatsappStatus } from './service.js';

/** Contract section 43 (authenticated part). */
export async function whatsappRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;

  app.get('/me/whatsapp', async (req) => whatsappStatus(svc.db, req.ctx.user.id));

  app.put('/me/whatsapp', async (req) => {
    const body = parse(z.object({ optedIn: z.boolean() }), req.body);
    await setOptIn(svc, req.ctx, body.optedIn, 'app');
    return whatsappStatus(svc.db, req.ctx.user.id);
  });

  // Dev simulator (non-production only): as if `text` were sent from the caller's phone.
  if (svc.config.NODE_ENV !== 'production') {
    app.post('/dev/whatsapp/simulate', async (req) => {
      const body = parse(z.object({ text: z.string().trim().min(1).max(2000) }), req.body);
      const replies = await handleInbound(svc, req.ctx.user.phone, body.text);
      return { replies };
    });
  }
}

type MetaPayload = {
  entry?: Array<{ changes?: Array<{ value?: { messages?: Array<{ id?: string; from?: string; type?: string; text?: { body?: string }; button?: { text?: string } }> } }> }>;
};

/** Public Meta Cloud API webhook: verify handshake + signed inbound messages (X-Hub-Signature-256). */
export async function whatsappWebhookRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  rawBodyParsers(app);

  app.get('/webhooks/whatsapp', async (req, reply) => {
    const q = req.query as Record<string, string | undefined>;
    const token = q['hub.verify_token'] ?? '';
    if (q['hub.mode'] === 'subscribe' && token && safeEqual(token, svc.config.WHATSAPP_VERIFY_TOKEN)) {
      return reply.header('content-type', 'text/plain').send(q['hub.challenge'] ?? '');
    }
    throw errors.forbidden('Verification failed');
  });

  app.post('/webhooks/whatsapp', { bodyLimit: 512 * 1024 }, async (req, reply) => {
    const actor = { ...SYSTEM_ACTOR, name: 'whatsapp', role: 'webhook', ip: req.ip, correlationId: req.correlationId };
    if (!Buffer.isBuffer(req.body) || !verifyHmacHeader(svc.config.WHATSAPP_APP_SECRET, req.body, req.headers['x-hub-signature-256'])) {
      await audit(svc.db, actor, { action: 'whatsapp.webhook', entityType: 'webhook', outcome: 'denied', metadata: { reason: 'bad_signature' } });
      throw errors.unauthenticated('Invalid webhook signature');
    }
    const payload = parseJsonBuffer(req.body) as MetaPayload | null;
    if (!payload) throw errors.validation('Invalid JSON');
    let handled = 0;
    for (const entry of payload.entry ?? []) {
      for (const change of entry.changes ?? []) {
        for (const m of change.value?.messages ?? []) {
          const text = m.text?.body ?? m.button?.text;
          if (!m.id || !m.from || !text) continue;
          if (!(await firstDelivery(svc.db, 'whatsapp', m.id))) continue;
          const phone = m.from.startsWith('+') ? m.from : `+${m.from}`;
          const replies = await handleInbound(svc, phone, text);
          for (const r of replies) await svc.partners.whatsapp.sendText(phone, r);
          handled++;
        }
      }
    }
    return reply.code(200).send({ received: true, handled });
  });
}
