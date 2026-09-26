import { createHmac, randomBytes } from 'node:crypto';
import { base32Decode, base32Encode } from '../../lib/crypto.js';

/** RFC 6238 TOTP (HMAC-SHA1, 6 digits, 30 s step) implemented with node:crypto. */
export const TOTP_STEP_SEC = 30;
export const TOTP_DIGITS = 6;

export function generateTotpSecret(bytes = 20): string {
  return base32Encode(randomBytes(bytes));
}

/** RFC 4226 HOTP. */
export function hotp(secretBase32: string, counter: number, digits = TOTP_DIGITS): string {
  const key = base32Decode(secretBase32);
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(counter));
  const mac = createHmac('sha1', key).update(buf).digest();
  const offset = mac[mac.length - 1] & 0x0f;
  const bin = ((mac[offset] & 0x7f) << 24) | (mac[offset + 1] << 16) | (mac[offset + 2] << 8) | mac[offset + 3];
  return String(bin % 10 ** digits).padStart(digits, '0');
}

export const totpStep = (timeMs: number = Date.now()): number => Math.floor(timeMs / 1000 / TOTP_STEP_SEC);

export function totp(secretBase32: string, timeMs: number = Date.now()): string {
  return hotp(secretBase32, totpStep(timeMs));
}

/**
 * Verify a code within +/- `window` steps. Returns the matched step (for replay protection) or null.
 * Steps <= `lastStep` are rejected so a code can be used only once.
 */
export function verifyTotp(secretBase32: string, code: string, opts: { timeMs?: number; window?: number; lastStep?: number | null } = {}): number | null {
  if (!/^\d{6}$/.test(code)) return null;
  const now = totpStep(opts.timeMs ?? Date.now());
  const window = opts.window ?? 1;
  for (let d = -window; d <= window; d++) {
    const step = now + d;
    if (opts.lastStep != null && step <= opts.lastStep) continue;
    if (hotp(secretBase32, step) === code) return step;
  }
  return null;
}

export function otpauthUrl(p: { issuer: string; account: string; secret: string }): string {
  const label = encodeURIComponent(`${p.issuer}:${p.account}`);
  const q = new URLSearchParams({ secret: p.secret, issuer: p.issuer, algorithm: 'SHA1', digits: String(TOTP_DIGITS), period: String(TOTP_STEP_SEC) });
  return `otpauth://totp/${label}?${q.toString()}`;
}

/** Recovery code like "K7Q2M-9XW4D" (50 bits of entropy). */
export function generateRecoveryCode(): string {
  const raw = base32Encode(randomBytes(7)).slice(0, 10);
  return `${raw.slice(0, 5)}-${raw.slice(5)}`;
}

export const normalizeRecoveryCode = (code: string): string => code.toUpperCase().replace(/[^A-Z2-7]/g, '');
