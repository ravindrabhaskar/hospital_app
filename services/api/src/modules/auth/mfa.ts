import { createHash } from 'node:crypto';
import { and, count, eq, gt, isNull } from 'drizzle-orm';
import QRCode from 'qrcode';
import { parseKey32, type Config } from '../../config.js';
import type { Db } from '../../db/client.js';
import { mfaAttempts, mfaRecoveryCodes, sessions, users } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import type { Actor } from '../../lib/context.js';
import { decryptSecret, encryptSecret, sha256 } from '../../lib/crypto.js';
import { AppError, errors } from '../../lib/errors.js';
import { revokeAllSessions, type AuthService } from './service.js';
import { generateRecoveryCode, generateTotpSecret, normalizeRecoveryCode, otpauthUrl, verifyTotp } from './totp.js';

export const MFA_MAX_FAILURES = 5;
export const MFA_WINDOW_MIN = 15;
export const RECOVERY_CODE_COUNT = 10;

/**
 * Staff MFA (contract section 22): TOTP enrolment with encrypted secrets, hashed single-use recovery codes,
 * a session-level `mfaVerifiedAt` claim (kept across refresh-token rotation) and a wrong-code rate limit.
 */
export class MfaService {
  private readonly key: Buffer;

  constructor(
    private readonly db: Db,
    private readonly config: Config,
    private readonly auth: AuthService,
  ) {
    // Production requires MFA_ENCRYPTION_KEY (productionReadinessIssues); dev derives a stable key.
    this.key = (config.MFA_ENCRYPTION_KEY && parseKey32(config.MFA_ENCRYPTION_KEY)) || createHash('sha256').update(`dev-mfa-key:${config.JWT_SECRET}`).digest();
  }

  private recoveryHash(userId: string, code: string): string {
    return sha256(`${userId}:${normalizeRecoveryCode(code)}`);
  }

  private async loadUser(userId: string) {
    const [u] = await this.db.select().from(users).where(eq(users.id, userId));
    if (!u) throw errors.notFound('User');
    return u;
  }

  private async assertNotRateLimited(userId: string): Promise<void> {
    const since = new Date(Date.now() - MFA_WINDOW_MIN * 60_000);
    const [row] = await this.db
      .select({ n: count() })
      .from(mfaAttempts)
      .where(and(eq(mfaAttempts.userId, userId), eq(mfaAttempts.success, false), gt(mfaAttempts.createdAt, since)));
    if (Number(row?.n ?? 0) >= MFA_MAX_FAILURES) {
      throw new AppError('RATE_LIMITED', `Too many incorrect codes. Try again in ${MFA_WINDOW_MIN} minutes.`);
    }
  }

  private async fail(userId: string, actor: Actor, action: string): Promise<never> {
    await this.db.insert(mfaAttempts).values({ userId, success: false });
    await audit(this.db, actor, { action, entityType: 'user', entityId: userId, outcome: 'denied', metadata: { reason: 'wrong_code' } });
    const since = new Date(Date.now() - MFA_WINDOW_MIN * 60_000);
    const [row] = await this.db
      .select({ n: count() })
      .from(mfaAttempts)
      .where(and(eq(mfaAttempts.userId, userId), eq(mfaAttempts.success, false), gt(mfaAttempts.createdAt, since)));
    throw errors.validation('Incorrect code', { attemptsRemaining: Math.max(0, MFA_MAX_FAILURES - Number(row?.n ?? 0)) });
  }

  async isEnrolled(userId: string): Promise<boolean> {
    const u = await this.loadUser(userId);
    return !!u.mfaEnrolledAt;
  }

  async enroll(userId: string, actor: Actor) {
    const u = await this.loadUser(userId);
    if (u.mfaEnrolledAt) throw errors.conflict('MFA is already enrolled for this account');
    const secret = generateTotpSecret();
    await this.db.update(users).set({ mfaPendingSecretEnc: encryptSecret(this.key, secret) }).where(eq(users.id, userId));
    const url = otpauthUrl({ issuer: this.config.MFA_ISSUER, account: u.phone, secret });
    const qrSvg = await QRCode.toString(url, { type: 'svg', errorCorrectionLevel: 'M', margin: 1 });
    await audit(this.db, actor, { action: 'mfa.enroll_started', entityType: 'user', entityId: userId });
    return { secret, otpauthUrl: url, qrSvg };
  }

  async confirm(userId: string, sessionId: string, code: string, actor: Actor) {
    await this.assertNotRateLimited(userId);
    const u = await this.loadUser(userId);
    if (u.mfaEnrolledAt) throw errors.conflict('MFA is already enrolled for this account');
    if (!u.mfaPendingSecretEnc) throw errors.conflict('Start enrolment first (POST /auth/mfa/totp/enroll)');
    const secret = decryptSecret(this.key, u.mfaPendingSecretEnc);
    const step = verifyTotp(secret, code);
    if (step === null) return this.fail(userId, actor, 'mfa.enroll_confirm');
    const recoveryCodes = Array.from({ length: RECOVERY_CODE_COUNT }, generateRecoveryCode);
    const now = new Date();
    await this.db.transaction(async (tx) => {
      await tx
        .update(users)
        .set({ mfaSecretEnc: u.mfaPendingSecretEnc, mfaPendingSecretEnc: null, mfaEnrolledAt: now, mfaLastStep: step })
        .where(eq(users.id, userId));
      await tx.delete(mfaRecoveryCodes).where(eq(mfaRecoveryCodes.userId, userId));
      await tx.insert(mfaRecoveryCodes).values(recoveryCodes.map((c) => ({ userId, codeHash: this.recoveryHash(userId, c) })));
      await tx.update(sessions).set({ mfaVerifiedAt: now }).where(eq(sessions.id, sessionId));
      await tx.insert(mfaAttempts).values({ userId, success: true });
      await audit(tx, actor, { action: 'mfa.enrolled', entityType: 'user', entityId: userId });
    });
    return { recoveryCodes, session: await this.auth.issueTokensForSession(userId, sessionId) };
  }

  async verify(userId: string, sessionId: string, input: { code?: string; recoveryCode?: string }, actor: Actor) {
    await this.assertNotRateLimited(userId);
    const u = await this.loadUser(userId);
    if (!u.mfaEnrolledAt || !u.mfaSecretEnc) throw errors.conflict('MFA is not enrolled for this account', { enrolled: false });
    let method: 'totp' | 'recovery_code';
    if (input.code) {
      method = 'totp';
      const step = verifyTotp(decryptSecret(this.key, u.mfaSecretEnc), input.code, { lastStep: u.mfaLastStep });
      if (step === null) return this.fail(userId, actor, 'mfa.verify');
      // Conditional update = replay protection even under concurrent submissions of the same code.
      const ok = await this.db
        .update(users)
        .set({ mfaLastStep: step })
        .where(and(eq(users.id, userId), u.mfaLastStep === null ? isNull(users.mfaLastStep) : eq(users.mfaLastStep, u.mfaLastStep)))
        .returning({ id: users.id });
      if (!ok.length) return this.fail(userId, actor, 'mfa.verify');
    } else {
      method = 'recovery_code';
      const used = await this.db
        .update(mfaRecoveryCodes)
        .set({ usedAt: new Date() })
        .where(and(eq(mfaRecoveryCodes.userId, userId), eq(mfaRecoveryCodes.codeHash, this.recoveryHash(userId, input.recoveryCode ?? '')), isNull(mfaRecoveryCodes.usedAt)))
        .returning({ id: mfaRecoveryCodes.id });
      if (!used.length) return this.fail(userId, actor, 'mfa.verify');
    }
    await this.db.update(sessions).set({ mfaVerifiedAt: new Date() }).where(eq(sessions.id, sessionId));
    await this.db.insert(mfaAttempts).values({ userId, success: true });
    await audit(this.db, actor, { action: 'mfa.verified', entityType: 'user', entityId: userId, metadata: { method } });
    return this.auth.issueTokensForSession(userId, sessionId);
  }

  /** super_admin reset: removes the secret + recovery codes and signs the user out everywhere. */
  async reset(userId: string, actor: Actor): Promise<void> {
    await this.db.transaction(async (tx) => {
      const [u] = await tx
        .update(users)
        .set({ mfaSecretEnc: null, mfaPendingSecretEnc: null, mfaEnrolledAt: null, mfaLastStep: null })
        .where(eq(users.id, userId))
        .returning({ id: users.id });
      if (!u) throw errors.notFound('User');
      await tx.delete(mfaRecoveryCodes).where(eq(mfaRecoveryCodes.userId, userId));
      await revokeAllSessions(tx, userId);
      await audit(tx, actor, { action: 'mfa.reset', entityType: 'user', entityId: userId });
    });
  }
}
