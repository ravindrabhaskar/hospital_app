import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';

export const sha256 = (input: string | Buffer): string => createHash('sha256').update(input).digest('hex');
export const randomToken = (bytes = 32): string => randomBytes(bytes).toString('base64url');
export const randomDigits = (n: number): string => Array.from({ length: n }, () => randomInt(0, 10)).join('');
export const hmacHex = (secret: string, body: string | Buffer): string => createHmac('sha256', secret).update(body).digest('hex');

export function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

/** "+919800000201" -> "+9198XXXXX201" */
export function maskPhone(phone: string | null | undefined): string {
  if (!phone) return '';
  if (phone.length < 8) return '*'.repeat(phone.length);
  return phone.slice(0, 5) + 'X'.repeat(phone.length - 8) + phone.slice(-3);
}

// ---------------------------------------------------------------- AES-256-GCM (secrets at rest)
/** Encrypt a short secret: "v1.<iv>.<tag>.<ciphertext>" (base64url parts). */
export function encryptSecret(key: Buffer, plaintext: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  return ['v1', iv.toString('base64url'), cipher.getAuthTag().toString('base64url'), ct.toString('base64url')].join('.');
}

export function decryptSecret(key: Buffer, payload: string): string {
  const [v, iv, tag, ct] = payload.split('.');
  if (v !== 'v1' || !iv || !tag || ct === undefined) throw new Error('invalid encrypted payload');
  const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(iv, 'base64url'));
  decipher.setAuthTag(Buffer.from(tag, 'base64url'));
  return Buffer.concat([decipher.update(Buffer.from(ct, 'base64url')), decipher.final()]).toString('utf8');
}

// ---------------------------------------------------------------- base32 (RFC 4648, no padding)
const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function base32Encode(buf: Buffer): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of buf) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += B32[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += B32[(value << (5 - bits)) & 31];
  return out;
}

export function base32Decode(input: string): Buffer {
  const clean = input.toUpperCase().replace(/=+$/, '').replace(/\s/g, '');
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const ch of clean) {
    const idx = B32.indexOf(ch);
    if (idx < 0) throw new Error('invalid base32');
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}
