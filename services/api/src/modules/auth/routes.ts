import { and, eq, isNull } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { patients, tenants, users } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR } from '../../lib/context.js';
import { parse, zPhone } from '../../lib/validate.js';
import { buildMe } from './service.js';

/** Public auth routes (/auth/*). */
export async function authPublicRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  const otpRateLimit = { rateLimit: { max: svc.config.RATE_LIMIT_OTP_MAX, timeWindow: '1 minute' } };

  app.post('/auth/otp/request', { config: otpRateLimit }, async (req) => {
    const body = parse(z.object({ phone: zPhone }), req.body);
    return svc.auth.requestOtp(body.phone);
  });

  app.post('/auth/otp/verify', { config: otpRateLimit }, async (req) => {
    const body = parse(z.object({ phone: zPhone, otp: z.string().regex(/^\d{6}$/), deviceName: z.string().max(100).optional() }), req.body);
    try {
      const user = await svc.auth.verifyOtp(body.phone, body.otp);
      await audit(svc.db, { ...SYSTEM_ACTOR, userId: user.id, name: user.name, role: 'patient', ip: req.ip, correlationId: req.correlationId }, {
        action: svc.auth.isReviewPhone(body.phone) ? 'auth.review_login' : 'auth.login',
        entityType: 'user',
        entityId: user.id,
      });
      // Contract section 58: a white-label app build sends X-Tenant-Code; a self profile without a tenant adopts it.
      const tenantHeader = req.headers['x-tenant-code'];
      if (typeof tenantHeader === 'string' && /^[a-z0-9_-]{2,40}$/.test(tenantHeader) && user.selfPatientId) {
        const [tn] = await svc.db.select({ code: tenants.code }).from(tenants).where(eq(tenants.code, tenantHeader));
        if (tn) await svc.db.update(patients).set({ tenantCode: tn.code }).where(and(eq(patients.id, user.selfPatientId), isNull(patients.tenantCode)));
      }
      return await svc.auth.issueSession(user.id, body.deviceName ?? null);
    } catch (err) {
      await audit(svc.db, { ...SYSTEM_ACTOR, ip: req.ip, correlationId: req.correlationId }, {
        action: 'auth.login',
        entityType: 'user',
        outcome: 'denied',
        metadata: { reason: err instanceof Error ? err.message : 'error' },
      });
      throw err;
    }
  });

  app.post('/auth/refresh', async (req) => {
    const body = parse(z.object({ refreshToken: z.string().min(10).max(200) }), req.body);
    return svc.auth.refresh(body.refreshToken);
  });

  app.post('/auth/logout', async (req, reply) => {
    const body = parse(z.object({ refreshToken: z.string().min(10).max(200) }), req.body);
    await svc.auth.logout(body.refreshToken);
    return reply.code(204).send();
  });
}

/** Authenticated /me routes. */
export async function meRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;

  app.get('/me', async (req) => buildMe(svc.db, req.ctx.user.id, req.ctx.user.sessionId));

  app.patch('/me', async (req) => {
    const body = parse(
      z.object({
        name: z.string().trim().min(1).max(100).optional(),
        language: z.enum(['en', 'hi', 'te']).optional(),
        email: z.string().email().max(200).nullable().optional(),
      }),
      req.body,
    );
    const user = req.ctx.user;
    await svc.db.transaction(async (tx) => {
      if (Object.keys(body).length) await tx.update(users).set(body).where(eq(users.id, user.id));
      if (body.name && user.selfPatientId) {
        await tx.update(patients).set({ name: body.name, updatedAt: new Date() }).where(eq(patients.id, user.selfPatientId));
      }
      await audit(tx, req.ctx.actor, { action: 'user.update_profile', entityType: 'user', entityId: user.id, metadata: { fields: Object.keys(body) } });
    });
    return buildMe(svc.db, user.id, user.sessionId);
  });

  // ---------------------------------------------------------------- staff MFA (contract section 22)
  const mfaLimit = { rateLimit: { max: 30, timeWindow: '1 minute' } };

  app.post('/auth/mfa/totp/enroll', { config: mfaLimit }, async (req) => svc.mfa.enroll(req.ctx.user.id, req.ctx.actor));

  app.post('/auth/mfa/totp/confirm', { config: mfaLimit }, async (req) => {
    const body = parse(z.object({ code: z.string().trim().regex(/^\d{6}$/, 'Expected a 6-digit code') }), req.body);
    return svc.mfa.confirm(req.ctx.user.id, req.ctx.user.sessionId, body.code, req.ctx.actor);
  });

  app.post('/auth/mfa/verify', { config: mfaLimit }, async (req) => {
    const body = parse(
      z.union([
        z.object({ code: z.string().trim().regex(/^\d{6}$/, 'Expected a 6-digit code') }),
        z.object({ recoveryCode: z.string().trim().min(8).max(20) }),
      ]),
      req.body,
    );
    return svc.mfa.verify(req.ctx.user.id, req.ctx.user.sessionId, body, req.ctx.actor);
  });
}
