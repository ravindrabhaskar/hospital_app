import { and, desc, eq, gt, inArray, isNull } from 'drizzle-orm';
import { SignJWT, jwtVerify } from 'jose';
import type { Config } from '../../config.js';
import type { Db, DbOrTx } from '../../db/client.js';
import {
  consents,
  notificationPreferences,
  otpRequests,
  patients,
  providers,
  refreshTokens,
  sessions,
  users,
  type Role,
} from '../../db/schema.js';
import { STAFF_ROLES, type Lang } from '../../lib/context.js';
import { randomDigits, randomToken, safeEqual, sha256 } from '../../lib/crypto.js';
import { AppError, errors } from '../../lib/errors.js';
import { REQUIRED_CONSENTS } from '../consent/catalog.js';
import type { SmsProvider } from './sms.js';

const ISSUER = 'carecompanion-api';
const AUDIENCE = 'carecompanion';

export type UserRow = typeof users.$inferSelect;

/** Staff roles that must pass MFA when MFA_ENFORCED (contract section 22). */
export const isMfaStaff = (roles: Role[]): boolean => roles.some((r) => STAFF_ROLES.includes(r));

export async function buildMe(db: DbOrTx, userId: string, sessionId: string | null = null) {
  const [u] = await db.select().from(users).where(eq(users.id, userId));
  if (!u) throw errors.notFound('User');
  const [sess] = sessionId ? await db.select({ mfaVerifiedAt: sessions.mfaVerifiedAt }).from(sessions).where(eq(sessions.id, sessionId)) : [];
  const [prov] = await db.select({ id: providers.id }).from(providers).where(eq(providers.userId, u.id));
  const granted = await db
    .select({ purpose: consents.purpose })
    .from(consents)
    .where(and(eq(consents.userId, u.id), eq(consents.status, 'granted'), inArray(consents.purpose, REQUIRED_CONSENTS)));
  const grantedSet = new Set(granted.map((g) => g.purpose));
  return {
    id: u.id,
    phone: u.phone,
    name: u.name,
    email: u.email,
    roles: u.roles,
    language: u.language as Lang,
    selfPatientId: u.selfPatientId,
    onboardingComplete: !!u.name && REQUIRED_CONSENTS.every((c) => grantedSet.has(c)),
    mfaRequired: isMfaStaff(u.roles),
    mfaEnrolled: !!u.mfaEnrolledAt,
    mfaVerified: !!sess?.mfaVerifiedAt,
    providerId: u.roles.includes('doctor') || u.roles.includes('provider') ? (prov?.id ?? null) : null,
  };
}

/** Find or auto-register a user by phone (role patient + self Patient profile). */
export async function ensureUser(db: DbOrTx, phone: string, opts: { name?: string | null; roles?: Role[] } = {}): Promise<UserRow> {
  const [existing] = await db.select().from(users).where(eq(users.phone, phone));
  if (existing) return existing;
  const roles = opts.roles ?? ['patient'];
  const [u] = await db
    .insert(users)
    .values({ phone, name: opts.name ?? null, roles })
    .onConflictDoNothing()
    .returning();
  if (!u) {
    const [again] = await db.select().from(users).where(eq(users.phone, phone));
    return again;
  }
  await db.insert(notificationPreferences).values({ userId: u.id }).onConflictDoNothing();
  if (roles.includes('patient')) {
    const [p] = await db
      .insert(patients)
      .values({ name: u.name, phone, userId: u.id, ownerUserId: u.id, ownerRelation: 'self' })
      .returning();
    const [updated] = await db.update(users).set({ selfPatientId: p.id }).where(eq(users.id, u.id)).returning();
    return updated;
  }
  return u;
}

export class AuthService {
  private readonly key: Uint8Array;
  /** Metrics hook (set by buildApp). */
  onSms: ((provider: string, outcome: 'ok' | 'error') => void) | null = null;
  constructor(
    private readonly db: Db,
    private readonly config: Config,
    private readonly sms: SmsProvider,
  ) {
    this.key = new TextEncoder().encode(config.JWT_SECRET);
  }

  /** True only for the configured REVIEW_PHONE (exact match) when REVIEW_OTP is also set. */
  isReviewPhone(phone: string): boolean {
    return !!this.config.REVIEW_PHONE && !!this.config.REVIEW_OTP && phone === this.config.REVIEW_PHONE;
  }

  private otpHash(phone: string, code: string): string {
    return sha256(`${phone}:${code}:${this.config.JWT_SECRET}`);
  }

  async requestOtp(phone: string) {
    const windowStart = new Date(Date.now() - this.config.OTP_WINDOW_MIN * 60_000);
    const recent = await this.db
      .select({ id: otpRequests.id })
      .from(otpRequests)
      .where(and(eq(otpRequests.phone, phone), gt(otpRequests.createdAt, windowStart)));
    if (recent.length >= this.config.OTP_MAX_REQUESTS) {
      throw new AppError('RATE_LIMITED', 'Too many OTP requests. Please try again later.');
    }
    const dev = this.config.NODE_ENV !== 'production';
    const expiresAt = new Date(Date.now() + this.config.OTP_TTL_SEC * 1000);
    if (this.isReviewPhone(phone)) {
      // App-store review account: fixed code, no SMS. Never applies to any other phone.
      const [row] = await this.db.insert(otpRequests).values({ phone, codeHash: this.otpHash(phone, this.config.REVIEW_OTP!), expiresAt }).returning();
      return { requestId: row.id, expiresAt: expiresAt.toISOString() };
    }
    // The fixed dev OTP exists only outside production; production always generates a random code.
    const code = dev ? this.config.OTP_DEV_CODE : randomDigits(6);
    const [row] = await this.db.insert(otpRequests).values({ phone, codeHash: this.otpHash(phone, code), expiresAt }).returning();
    try {
      await this.sms.sendOtp(phone, code);
      this.onSms?.(this.sms.name, 'ok');
    } catch (err) {
      this.onSms?.(this.sms.name, 'error');
      // Do not leave a usable code behind when delivery failed.
      await this.db.update(otpRequests).set({ consumedAt: new Date() }).where(eq(otpRequests.id, row.id));
      throw err;
    }
    return { requestId: row.id, expiresAt: expiresAt.toISOString(), ...(dev ? { devOtp: code } : {}) };
  }

  /** Returns the user id on success. */
  async verifyOtp(phone: string, otp: string): Promise<UserRow> {
    const [req] = await this.db
      .select()
      .from(otpRequests)
      .where(and(eq(otpRequests.phone, phone), isNull(otpRequests.consumedAt), gt(otpRequests.expiresAt, new Date())))
      .orderBy(desc(otpRequests.createdAt))
      .limit(1);
    if (!req) throw errors.unauthenticated('OTP expired or not requested');
    if (req.attempts >= this.config.OTP_MAX_ATTEMPTS) {
      throw new AppError('RATE_LIMITED', 'Too many incorrect attempts. Please request a new OTP.');
    }
    if (!safeEqual(req.codeHash, this.otpHash(phone, otp))) {
      const attempts = req.attempts + 1;
      await this.db.update(otpRequests).set({ attempts }).where(eq(otpRequests.id, req.id));
      throw new AppError('UNAUTHENTICATED', 'Incorrect OTP', { attemptsRemaining: Math.max(0, this.config.OTP_MAX_ATTEMPTS - attempts) });
    }
    await this.db.update(otpRequests).set({ consumedAt: new Date() }).where(eq(otpRequests.id, req.id));
    const user = await this.db.transaction((tx) => ensureUser(tx, phone));
    if (user.status !== 'active') throw errors.forbidden('Account is disabled');
    await this.db.update(users).set({ lastLoginAt: new Date() }).where(eq(users.id, user.id));
    return user;
  }

  async issueSession(userId: string, deviceName: string | null) {
    const [session] = await this.db.insert(sessions).values({ userId, deviceName }).returning();
    return this.issueTokensForSession(userId, session.id);
  }

  /** New access + refresh token pair for an existing session (keeps the session's mfaVerified state). */
  async issueTokensForSession(userId: string, sessionId: string) {
    const refreshToken = randomToken(48);
    await this.db.insert(refreshTokens).values({
      sessionId,
      tokenHash: sha256(refreshToken),
      expiresAt: new Date(Date.now() + this.config.REFRESH_TOKEN_TTL_DAYS * 86400_000),
    });
    const [sess] = await this.db.select({ mfaVerifiedAt: sessions.mfaVerifiedAt }).from(sessions).where(eq(sessions.id, sessionId));
    // `mfa` is informational; the authoritative MFA state is re-read from the session row on every request.
    const accessToken = await new SignJWT({ sid: sessionId, mfa: !!sess?.mfaVerifiedAt })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer(ISSUER)
      .setAudience(AUDIENCE)
      .setIssuedAt()
      .setExpirationTime(Math.floor(Date.now() / 1000) + this.config.ACCESS_TOKEN_TTL_SEC)
      .sign(this.key);
    return {
      accessToken,
      refreshToken,
      expiresIn: this.config.ACCESS_TOKEN_TTL_SEC,
      user: await buildMe(this.db, userId, sessionId),
    };
  }

  /** Rotating refresh tokens with reuse detection (reuse revokes the whole session). */
  async refresh(token: string) {
    const [row] = await this.db.select().from(refreshTokens).where(eq(refreshTokens.tokenHash, sha256(token)));
    if (!row) throw errors.unauthenticated('Invalid refresh token');
    const [session] = await this.db.select().from(sessions).where(eq(sessions.id, row.sessionId));
    if (!session || session.revokedAt || row.revokedAt) throw errors.unauthenticated('Session revoked');
    if (row.usedAt) {
      await this.revokeSession(session.id);
      throw errors.unauthenticated('Refresh token reuse detected; session revoked');
    }
    if (row.expiresAt < new Date()) throw errors.unauthenticated('Refresh token expired');
    const [user] = await this.db.select().from(users).where(eq(users.id, session.userId));
    if (!user || user.status !== 'active') throw errors.unauthenticated('Account is disabled');
    const marked = await this.db
      .update(refreshTokens)
      .set({ usedAt: new Date() })
      .where(and(eq(refreshTokens.id, row.id), isNull(refreshTokens.usedAt)))
      .returning({ id: refreshTokens.id });
    if (!marked.length) {
      await this.revokeSession(session.id);
      throw errors.unauthenticated('Refresh token reuse detected; session revoked');
    }
    return this.issueTokensForSession(user.id, session.id);
  }

  async logout(token: string): Promise<void> {
    const [row] = await this.db.select().from(refreshTokens).where(eq(refreshTokens.tokenHash, sha256(token)));
    if (row) await this.revokeSession(row.sessionId);
  }

  async revokeSession(sessionId: string): Promise<void> {
    const now = new Date();
    await this.db.update(sessions).set({ revokedAt: now }).where(eq(sessions.id, sessionId));
    await this.db.update(refreshTokens).set({ revokedAt: now }).where(and(eq(refreshTokens.sessionId, sessionId), isNull(refreshTokens.revokedAt)));
  }

  async verifyAccessToken(token: string): Promise<{ userId: string; sessionId: string }> {
    try {
      const { payload } = await jwtVerify(token, this.key, { issuer: ISSUER, audience: AUDIENCE, algorithms: ['HS256'] });
      if (typeof payload.sub !== 'string' || typeof payload.sid !== 'string') throw new Error('bad claims');
      return { userId: payload.sub, sessionId: payload.sid };
    } catch {
      throw errors.unauthenticated('Invalid or expired access token');
    }
  }
}

export async function revokeAllSessions(db: DbOrTx, userId: string): Promise<void> {
  const now = new Date();
  const s = await db.select({ id: sessions.id }).from(sessions).where(and(eq(sessions.userId, userId), isNull(sessions.revokedAt)));
  if (!s.length) return;
  const ids = s.map((x) => x.id);
  await db.update(sessions).set({ revokedAt: now }).where(inArray(sessions.id, ids));
  await db.update(refreshTokens).set({ revokedAt: now }).where(inArray(refreshTokens.sessionId, ids));
}
