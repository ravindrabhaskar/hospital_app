import { createHmac } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import type { DbOrTx } from '../db/client.js';
import { webhookEvents } from '../db/schema.js';
import { hmacHex, safeEqual } from './crypto.js';

/**
 * Verify `hex(HMAC-SHA256(rawBody, secret))` sent in a header, with or without a `sha256=` prefix
 * (Meta's X-Hub-Signature-256 uses the prefix). Constant-time comparison.
 */
export function verifyHmacHeader(secret: string, raw: Buffer | string, header: unknown): boolean {
  if (typeof header !== 'string') return false;
  const sig = header.trim().replace(/^sha256=/i, '').toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(sig)) return false;
  return safeEqual(hmacHex(secret, raw), sig);
}

/** Header value a partner would send (used by tests, the simulators and mock partners). */
export const signBody = (secret: string, raw: Buffer | string): string => hmacHex(secret, raw);

/**
 * Twilio request validation: base64(HMAC-SHA1(url + sorted(key+value) of the POST params, auth token)).
 * https://www.twilio.com/docs/usage/security#validating-requests
 */
export function twilioSignature(authToken: string, url: string, params: Record<string, string>): string {
  const data = Object.keys(params)
    .sort()
    .reduce((acc, k) => acc + k + params[k], url);
  return createHmac('sha1', authToken).update(Buffer.from(data, 'utf8')).digest('base64');
}

/** Record a partner event id; false when it was already processed (idempotent webhooks). */
export async function firstDelivery(db: DbOrTx, source: string, eventId: string): Promise<boolean> {
  const rows = await db.insert(webhookEvents).values({ source, eventId: eventId.slice(0, 200) }).onConflictDoNothing().returning({ id: webhookEvents.id });
  return rows.length > 0;
}

/**
 * Keep raw bodies for signature verification in an encapsulated webhook plugin: JSON and form-encoded bodies are
 * delivered as Buffers (parse after verifying).
 */
export function rawBodyParsers(app: FastifyInstance): void {
  app.addContentTypeParser('application/json', { parseAs: 'buffer' }, (_req, body, done) => done(null, body));
  app.addContentTypeParser('application/x-www-form-urlencoded', { parseAs: 'buffer' }, (_req, body, done) => done(null, body));
}

export function parseJsonBuffer(raw: unknown): unknown {
  if (!Buffer.isBuffer(raw)) return raw ?? null;
  try {
    return JSON.parse(raw.toString('utf8'));
  } catch {
    return null;
  }
}

export function parseFormBuffer(raw: unknown): Record<string, string> {
  if (!Buffer.isBuffer(raw)) return (raw as Record<string, string>) ?? {};
  return Object.fromEntries(new URLSearchParams(raw.toString('utf8')));
}
