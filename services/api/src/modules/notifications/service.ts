import { and, eq, inArray, lte } from 'drizzle-orm';
import type { Db, DbOrTx } from '../../db/client.js';
import {
  devices,
  familyAccessGrants,
  notificationOutbox,
  notificationPreferences,
  notifications,
  patients,
  users,
} from '../../db/schema.js';
import type { Lang } from '../../lib/context.js';
import { t } from '../../lib/i18n.js';
import { PermanentDeliveryError, type Channel, type ChannelAdapter } from './channels.js';

export type NotificationCategory =
  | 'appointment'
  | 'home_visit'
  | 'medication'
  | 'care_plan'
  | 'safety'
  | 'record'
  | 'payment'
  | 'system'
  // v1.3 (contract preamble of sections 41-62)
  | 'program'
  | 'checkin'
  | 'lab'
  | 'support'
  | 'insurance'
  | 'preventive';

export interface NotifyInput {
  template: string; // key prefix in i18n, e.g. 'appointment_confirmed'
  params?: Record<string, string | number>;
  category: NotificationCategory;
  critical?: boolean;
  deepLink?: string | null;
  dedupeKey?: string | null;
  /** i18n key of the generic lock-screen / push text (default `notify.lockscreen`). Must never contain PHI. */
  lockScreenKey?: string;
}

export const DEFAULT_PREFS = { push: true, sms: true, email: false, whatsapp: false, marketing: false };

export class NotificationService {
  /** Delivery metrics hook (set by buildApp). */
  onDelivery: ((channel: Channel, outcome: 'sent' | 'retry' | 'failed') => void) | null = null;

  constructor(
    private readonly db: Db,
    private readonly channels: Record<Channel, ChannelAdapter>,
  ) {}

  /** Users who should receive alerts about a patient: self, managing guardian, grantees with receive_alerts. */
  async alertRecipients(db: DbOrTx, patientId: string): Promise<string[]> {
    const [p] = await db.select({ userId: patients.userId, ownerUserId: patients.ownerUserId }).from(patients).where(eq(patients.id, patientId));
    if (!p) return [];
    const ids = new Set<string>();
    if (p.userId) ids.add(p.userId);
    if (p.ownerUserId) ids.add(p.ownerUserId);
    const grants = await db
      .select({ userId: familyAccessGrants.granteeUserId, permissions: familyAccessGrants.permissions })
      .from(familyAccessGrants)
      .where(and(eq(familyAccessGrants.patientId, patientId), eq(familyAccessGrants.status, 'active')));
    for (const g of grants) if (g.permissions.includes('receive_alerts')) ids.add(g.userId);
    return [...ids];
  }

  async notifyPatient(patientId: string, n: NotifyInput): Promise<void> {
    await this.notifyUsers(await this.alertRecipients(this.db, patientId), n);
  }

  async notifyUsers(userIds: string[], n: NotifyInput): Promise<void> {
    if (!userIds.length) return;
    const recipients = await this.db
      .select({ id: users.id, language: users.language, status: users.status })
      .from(users)
      .where(inArray(users.id, [...new Set(userIds)]));
    for (const u of recipients) {
      if (u.status !== 'active') continue;
      const lang = (u.language as Lang) ?? 'en';
      const [row] = await this.db
        .insert(notifications)
        .values({
          userId: u.id,
          title: t(lang, `notify.${n.template}.title`, n.params),
          body: t(lang, `notify.${n.template}.body`, n.params),
          category: n.category,
          critical: n.critical ?? false,
          deepLink: n.deepLink ?? null,
          templateKey: n.template,
          dedupeKey: n.dedupeKey ?? null,
        })
        .onConflictDoNothing()
        .returning();
      if (!row) continue; // deduplicated
      await this.enqueue(u.id, row.id, lang, n);
    }
  }

  private async enqueue(userId: string, notificationId: string, lang: Lang, n: NotifyInput): Promise<void> {
    const [prefs] = await this.db.select().from(notificationPreferences).where(eq(notificationPreferences.userId, userId));
    const p = prefs ?? { ...DEFAULT_PREFS, userId };
    const critical = n.critical ?? false;
    const lockScreenText = t(lang, critical ? 'notify.lockscreen.critical' : (n.lockScreenKey ?? 'notify.lockscreen'));
    const channels: Channel[] = [];
    if (critical || p.push) channels.push('push');
    if (critical || (p.sms && (n.category === 'appointment' || n.category === 'payment'))) channels.push('sms');
    if (!critical && p.email) channels.push('email');
    if (!critical && p.whatsapp) channels.push('whatsapp');
    for (const channel of channels) {
      let recipients: Array<string | null> = [null];
      if (channel === 'push') {
        const toks = await this.db.select({ token: devices.pushToken }).from(devices).where(eq(devices.userId, userId));
        if (!toks.length) continue; // no registered device
        recipients = toks.map((d) => d.token);
      } else if (channel === 'sms' || channel === 'whatsapp') {
        const [u] = await this.db.select({ phone: users.phone }).from(users).where(eq(users.id, userId));
        recipients = [u?.phone ?? null];
      }
      for (const recipient of recipients) {
        await this.db.insert(notificationOutbox).values({ notificationId, userId, channel, recipient, lockScreenText, critical });
      }
    }
  }

  /** Direct SMS to a non-user (e.g. emergency contact). Text must be PHI-free. */
  async smsDirect(phone: string, text: string, critical = true): Promise<void> {
    await this.db.insert(notificationOutbox).values({ channel: 'sms', recipient: phone, lockScreenText: text, critical });
  }

  /** Dispatch due outbox rows with exponential backoff; returns number sent. */
  async dispatchOutbox(now = new Date(), batch = 50): Promise<number> {
    const due = await this.db
      .select()
      .from(notificationOutbox)
      .where(and(eq(notificationOutbox.status, 'pending'), lte(notificationOutbox.nextAttemptAt, now)))
      .limit(batch);
    let sent = 0;
    const ids = [...new Set(due.map((r) => r.notificationId).filter((x): x is string => !!x))];
    const links = ids.length
      ? new Map((await this.db.select({ id: notifications.id, deepLink: notifications.deepLink }).from(notifications).where(inArray(notifications.id, ids))).map((n) => [n.id, n.deepLink]))
      : new Map<string, string | null>();
    for (const row of due) {
      const channel = row.channel as Channel;
      try {
        await this.channels[channel].send({
          channel,
          recipient: row.recipient,
          userId: row.userId,
          text: row.lockScreenText,
          critical: row.critical,
          title: 'CareCompanion',
          deepLink: row.notificationId ? (links.get(row.notificationId) ?? null) : null,
          notificationId: row.notificationId,
        });
        await this.db.update(notificationOutbox).set({ status: 'sent', sentAt: now, attempts: row.attempts + 1 }).where(eq(notificationOutbox.id, row.id));
        this.onDelivery?.(channel, 'sent');
        sent++;
      } catch (err) {
        const attempts = row.attempts + 1;
        if (err instanceof PermanentDeliveryError) {
          await this.db.update(notificationOutbox).set({ attempts, status: 'failed', lastError: err.message.slice(0, 200) }).where(eq(notificationOutbox.id, row.id));
          this.onDelivery?.(channel, 'failed');
          continue;
        }
        this.onDelivery?.(channel, attempts >= 5 ? 'failed' : 'retry');
        await this.db
          .update(notificationOutbox)
          .set({
            attempts,
            status: attempts >= 5 ? 'failed' : 'pending',
            lastError: err instanceof Error ? err.message.slice(0, 200) : 'send_failed',
            nextAttemptAt: new Date(now.getTime() + Math.min(3600, 2 ** attempts * 15) * 1000),
          })
          .where(eq(notificationOutbox.id, row.id));
      }
    }
    return sent;
  }
}

export function toNotification(n: typeof notifications.$inferSelect) {
  return {
    id: n.id,
    title: n.title,
    body: n.body,
    category: n.category,
    critical: n.critical,
    read: n.read,
    deepLink: n.deepLink,
    createdAt: n.createdAt.toISOString(),
  };
}
