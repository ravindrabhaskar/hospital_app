import { createSign } from 'node:crypto';
import { HttpError, defaultFetch, requestJson, type FetchLike } from '../../lib/http.js';
import { PermanentDeliveryError, type ChannelAdapter, type OutboundMessage } from './channels.js';

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

export interface FcmCredentials {
  projectId: string;
  clientEmail: string;
  /** PEM private key of the service account (literal "\n" sequences are accepted). */
  privateKey: string;
}

const b64url = (v: string | Buffer) => Buffer.from(v).toString('base64url');

/** Service-account JWT (RS256) for the OAuth2 JWT-bearer grant. */
export function signServiceAccountJwt(creds: Pick<FcmCredentials, 'clientEmail' | 'privateKey'>, nowSec = Math.floor(Date.now() / 1000), tokenUrl = TOKEN_URL): string {
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({ iss: creds.clientEmail, scope: SCOPE, aud: tokenUrl, iat: nowSec, exp: nowSec + 3600 }));
  const signer = createSign('RSA-SHA256');
  signer.update(`${header}.${claims}`);
  const sig = signer.sign(creds.privateKey.replace(/\\n/g, '\n'));
  return `${header}.${claims}.${b64url(sig)}`;
}

/**
 * Firebase Cloud Messaging HTTP v1 push adapter.
 * - OAuth2 access token from a service-account JWT, cached until 60 s before expiry.
 * - Payload is generic only: { title, body (lock-screen text), deepLink, notificationId } (contract section 24).
 * - UNREGISTERED / invalid tokens are reported through `onInvalidToken` (the device row is deleted) and the
 *   send fails permanently (no retries).
 */
export class FcmPushChannel implements ChannelAdapter {
  readonly channel = 'push' as const;
  private cached: { token: string; expiresAt: number } | null = null;
  private inflight: Promise<string> | null = null;

  constructor(
    private readonly creds: FcmCredentials,
    private readonly onInvalidToken: (token: string) => Promise<void>,
    private readonly fetchImpl: FetchLike = defaultFetch,
    private readonly opts: { tokenUrl?: string; apiBase?: string; timeoutMs?: number } = {},
  ) {}

  async accessToken(): Promise<string> {
    if (this.cached && this.cached.expiresAt - 60_000 > Date.now()) return this.cached.token;
    if (!this.inflight) {
      this.inflight = (async () => {
        const tokenUrl = this.opts.tokenUrl ?? TOKEN_URL;
        const assertion = signServiceAccountJwt(this.creds, Math.floor(Date.now() / 1000), tokenUrl);
        const res = await requestJson<{ access_token: string; expires_in: number }>(this.fetchImpl, tokenUrl, {
          method: 'POST',
          timeoutMs: this.opts.timeoutMs ?? 10_000,
          headers: { 'content-type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }).toString(),
        });
        this.cached = { token: res.access_token, expiresAt: Date.now() + (res.expires_in ?? 3600) * 1000 };
        return res.access_token;
      })().finally(() => {
        this.inflight = null;
      });
    }
    return this.inflight;
  }

  async send(msg: OutboundMessage): Promise<void> {
    if (!msg.recipient) throw new PermanentDeliveryError('no_device_token');
    const url = `${this.opts.apiBase ?? 'https://fcm.googleapis.com'}/v1/projects/${encodeURIComponent(this.creds.projectId)}/messages:send`;
    const data: Record<string, string> = {};
    if (msg.deepLink) data.deepLink = msg.deepLink;
    if (msg.notificationId) data.notificationId = msg.notificationId;
    const message = {
      token: msg.recipient,
      notification: { title: msg.title ?? 'CareCompanion', body: msg.text },
      data,
      android: { priority: msg.critical ? 'HIGH' : 'NORMAL' },
      apns: { headers: { 'apns-priority': msg.critical ? '10' : '5' } },
    };
    const doSend = async (token: string) =>
      requestJson(this.fetchImpl, url, {
        method: 'POST',
        timeoutMs: this.opts.timeoutMs ?? 10_000,
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ message }),
      });
    try {
      try {
        await doSend(await this.accessToken());
      } catch (err) {
        if (err instanceof HttpError && err.status === 401) {
          this.cached = null; // token revoked/expired early: refresh once
          await doSend(await this.accessToken());
        } else throw err;
      }
    } catch (err) {
      if (err instanceof HttpError && isInvalidToken(err)) {
        await this.onInvalidToken(msg.recipient);
        throw new PermanentDeliveryError('unregistered_token');
      }
      throw err;
    }
  }
}

/** FCM v1: 404 UNREGISTERED, or 400 INVALID_ARGUMENT about the registration token. */
export function isInvalidToken(err: HttpError): boolean {
  const e = (err.body as any)?.error;
  const codes: string[] = (e?.details ?? []).map((d: any) => d?.errorCode).filter(Boolean);
  if (codes.includes('UNREGISTERED')) return true;
  if (err.status === 404) return true;
  return err.status === 400 && codes.includes('INVALID_ARGUMENT') && /registration token/i.test(String(e?.message ?? ''));
}
