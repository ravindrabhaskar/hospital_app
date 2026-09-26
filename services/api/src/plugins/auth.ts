import { eq } from 'drizzle-orm';
import type { FastifyRequest } from 'fastify';
import { providers, sessions, users } from '../db/schema.js';
import { audit } from '../lib/audit.js';
import { parseLang, primaryRole, type Lang, type RequestCtx } from '../lib/context.js';
import { errors } from '../lib/errors.js';
import { isMfaStaff } from '../modules/auth/service.js';
import type { Services } from '../services.js';

/**
 * Routes a staff session may call before passing MFA (contract section 22): /me, /auth/* and /config/public
 * (the last two are public or MFA endpoints). Paths are relative to API_PREFIX.
 */
export function mfaExempt(path: string): boolean {
  return path === '/me' || path.startsWith('/auth/') || path === '/config/public';
}

/** Verifies the bearer token, checks the user is active and the session not revoked, sets req.ctx. */
export function makeAuthenticate(svc: Services) {
  return async function authenticate(req: FastifyRequest): Promise<void> {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) throw errors.unauthenticated();
    const { userId, sessionId } = await svc.auth.verifyAccessToken(header.slice(7).trim());
    const [u] = await svc.db.select().from(users).where(eq(users.id, userId));
    if (!u || u.status !== 'active') throw errors.unauthenticated('Account is disabled');
    const [s] = await svc.db.select({ revokedAt: sessions.revokedAt, mfaVerifiedAt: sessions.mfaVerifiedAt }).from(sessions).where(eq(sessions.id, sessionId));
    if (!s || s.revokedAt) throw errors.unauthenticated('Session revoked');
    if (svc.config.MFA_ENFORCED && !s.mfaVerifiedAt && isMfaStaff(u.roles)) {
      const route = (req.routeOptions.url ?? req.url.split('?')[0]).slice(svc.config.API_PREFIX.length) || '/';
      if (!mfaExempt(route)) throw errors.mfaRequired();
    }
    const [prov] = await svc.db.select({ id: providers.id }).from(providers).where(eq(providers.userId, u.id));
    const lang: Lang = parseLang(req.headers['accept-language'], (u.language as Lang) ?? 'en');
    const ctx: RequestCtx = {
      user: {
        id: u.id,
        phone: u.phone,
        name: u.name,
        roles: u.roles,
        language: u.language as Lang,
        selfPatientId: u.selfPatientId,
        providerId: prov?.id ?? null,
        sessionId,
      },
      actor: {
        userId: u.id,
        name: u.name,
        role: primaryRole(u.roles),
        ip: req.ip,
        correlationId: req.correlationId,
      },
      lang,
    };
    req.ctx = ctx;
  };
}

/** Route-level role guard (preHandler). Denials are audited. */
export function requireRoles(svc: Services, ...roles: string[]) {
  return async function roleGuard(req: FastifyRequest): Promise<void> {
    const ctx = req.ctx;
    if (!ctx) throw errors.unauthenticated();
    if (roles.some((r) => ctx.user.roles.includes(r as never))) return;
    await audit(svc.db, ctx.actor, {
      action: `${req.method} ${req.routeOptions.url ?? req.url.split('?')[0]}`,
      entityType: 'route',
      outcome: 'denied',
      metadata: { requiredRoles: roles },
    });
    throw errors.forbidden();
  };
}
