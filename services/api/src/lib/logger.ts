import type { FastifyServerOptions } from 'fastify';
import type { Config } from '../config.js';

/**
 * PHI / secret redaction. Fastify does not log bodies by default; these paths also
 * protect any object we log explicitly (e.g. `req.log.info({ body })`).
 */
export const REDACT_PATHS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["x-signature"]',
  'req.headers["x-razorpay-signature"]',
  'req.headers["idempotency-key"]',
  'headers.authorization',
  '*.phone',
  '*.name',
  '*.text',
  '*.notes',
  '*.note',
  '*.otp',
  '*.code',
  '*.visitCode',
  '*.accessToken',
  '*.refreshToken',
  '*.token',
  '*.pushToken',
  '*.authorization',
  '*.summary',
  // v1.1 secrets / credentials / one-time codes
  '*.secret',
  '*.otpauthUrl',
  '*.qrSvg',
  '*.recoveryCode',
  '*.recoveryCodes',
  '*.razorpaySignature',
  '*.razorpay_signature',
  '*.signature',
  '*.privateKey',
  '*.private_key',
  '*.apiKey',
  '*.authKey',
  '*.authkey',
  '*.password',
  '*.assertion',
  '*.access_token',
  '*.jwt',
  '*.joinUrl',
  '*.keySecret',
  '*.concern',
  '*.reason',
  'body',
  '*.body',
];

export function loggerOptions(config: Config): FastifyServerOptions['logger'] {
  if (config.LOG_LEVEL === 'silent') return false;
  return {
    level: config.LOG_LEVEL,
    redact: { paths: REDACT_PATHS, censor: '[REDACTED]' },
    serializers: {
      req(req: { method: string; url: string; id: string }) {
        // Strip query strings: they may contain search terms such as phone numbers.
        return { method: req.method, url: req.url.split('?')[0], reqId: req.id };
      },
    },
    ...(config.NODE_ENV === 'development'
      ? { transport: { target: 'pino-pretty', options: { translateTime: 'SYS:HH:MM:ss', ignore: 'pid,hostname' } } }
      : {}),
  };
}
