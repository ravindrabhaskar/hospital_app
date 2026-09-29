import { and, eq } from 'drizzle-orm';
import type { DbOrTx } from '../../db/client.js';
import { consents, conversations, medications, patients, providers, users, vitals, whatsappOptins } from '../../db/schema.js';
import { listActablePatients } from '../../lib/access.js';
import { audit } from '../../lib/audit.js';
import { primaryRole, type Lang, type RequestCtx } from '../../lib/context.js';
import { t } from '../../lib/i18n.js';
import { iso } from '../../lib/time.js';
import type { Services } from '../../services.js';
import { handleTurn, startConversation } from '../ai/assistant.js';
import { recordCheckin } from '../checkins/service.js';
import { grantConsent, hasConsent } from '../consent/routes.js';
import { toMedications } from '../medications/service.js';
import type { Channel, ChannelAdapter, OutboundMessage } from '../notifications/channels.js';
import { PermanentDeliveryError } from '../notifications/channels.js';
import type { WhatsAppAdapter } from '../partners/index.js';
import { evaluateVitals } from '../programs/service.js';
import { raiseAlert } from '../safety/alerts.js';

/** Outbox channel for WhatsApp: approved template with the generic, PHI-free lock-screen text only. */
export class WhatsAppChannel implements ChannelAdapter {
  readonly channel: Channel = 'whatsapp';
  constructor(
    private readonly wa: WhatsAppAdapter,
    private readonly template: string,
  ) {}
  async send(msg: OutboundMessage): Promise<void> {
    if (!msg.recipient) throw new PermanentDeliveryError('no_phone');
    await this.wa.sendTemplate(msg.recipient, this.template, [msg.text]);
  }
}

/** A request context for a user acting through a channel (WhatsApp, IVR). */
export async function channelCtx(db: DbOrTx, userId: string, channel: 'whatsapp' | 'ivr', lang?: Lang): Promise<RequestCtx | null> {
  const [u] = await db.select().from(users).where(eq(users.id, userId));
  if (!u || u.status !== 'active') return null;
  const [prov] = await db.select({ id: providers.id }).from(providers).where(eq(providers.userId, u.id));
  return {
    user: { id: u.id, phone: u.phone, name: u.name, roles: u.roles, language: u.language as Lang, selfPatientId: u.selfPatientId, providerId: prov?.id ?? null, sessionId: `${channel}` },
    actor: { userId: u.id, name: u.name, role: primaryRole(u.roles), ip: null, correlationId: `${channel}:${Date.now()}` },
    lang: lang ?? ((u.language as Lang) || 'en'),
  };
}

export async function whatsappStatus(db: DbOrTx, userId: string) {
  const [u] = await db.select({ phone: users.phone }).from(users).where(eq(users.id, userId));
  const [row] = await db.select().from(whatsappOptins).where(eq(whatsappOptins.userId, userId));
  const optedIn = !!row?.optedIn && (await hasConsent(db, userId, 'whatsapp_messaging'));
  return { optedIn, phone: u?.phone ?? null, optedInAt: optedIn ? iso(row!.optedInAt) : null };
}

/** Opt in/out; opting in records the `whatsapp_messaging` consent, opting out revokes it. */
export async function setOptIn(svc: Services, ctx: RequestCtx, optedIn: boolean, via: 'app' | 'whatsapp'): Promise<void> {
  await svc.db.transaction(async (tx) => {
    const now = new Date();
    if (optedIn) {
      await grantConsent(tx, ctx.user.id, 'whatsapp_messaging', '1.0');
    } else {
      await tx
        .update(consents)
        .set({ status: 'revoked', revokedAt: now })
        .where(and(eq(consents.userId, ctx.user.id), eq(consents.purpose, 'whatsapp_messaging'), eq(consents.status, 'granted')));
    }
    await tx
      .insert(whatsappOptins)
      .values({ userId: ctx.user.id, optedIn, optedInAt: optedIn ? now : null, optedOutAt: optedIn ? null : now })
      .onConflictDoUpdate({
        target: whatsappOptins.userId,
        set: optedIn ? { optedIn, optedInAt: now, updatedAt: now } : { optedIn, optedOutAt: now, updatedAt: now },
      });
    await audit(tx, ctx.actor, { action: optedIn ? 'whatsapp.opt_in' : 'whatsapp.opt_out', entityType: 'user', entityId: ctx.user.id, metadata: { via } });
  });
}

const fmtTime = (iso: string) => new Date(iso).toLocaleTimeString('en-IN', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hour12: false });

/** Today's medicine reminders for the user's patients (self and managed, then family grants). */
export async function todaysReminderLines(svc: Services, ctx: RequestCtx): Promise<string[]> {
  const patientsOf = (await listActablePatients(svc.db, ctx.user)).filter((p) => p.permissions.some((x) => x === 'view_records' || x === 'manage_care' || x === 'receive_alerts'));
  const lines: string[] = [];
  for (const p of patientsOf) {
    const [pat] = await svc.db.select({ name: patients.name }).from(patients).where(eq(patients.id, p.patientId));
    const meds = await svc.db.select().from(medications).where(and(eq(medications.patientId, p.patientId), eq(medications.active, true)));
    const mapped = await toMedications(svc.db, meds, svc.config.DOSE_MISSED_GRACE_MIN);
    const doses = mapped.flatMap((m) => m.today.map((d) => ({ at: d.scheduledAt, text: `${fmtTime(d.scheduledAt)} ${m.name} ${m.dose} (${d.status})` })));
    if (!doses.length) continue;
    doses.sort((a, b) => a.at.localeCompare(b.at));
    lines.push(`${p.isSelf ? 'You' : (pat?.name ?? 'Family member')}: ${doses.map((d) => d.text).join('; ')}`);
  }
  return lines;
}

/** Parse "BP 138/88" / "SUGAR 142" (also "GLUCOSE"). */
export function parseReading(text: string): Array<{ type: string; value: number; unit: string }> | null | 'invalid' {
  const s = text.trim().toUpperCase();
  const bp = /^BP\b/.test(s);
  const sugar = /^(SUGAR|GLUCOSE)\b/.test(s);
  if (!bp && !sugar) return null;
  if (bp) {
    const m = /^BP\s*(\d{2,3})\s*[/\\ -]\s*(\d{2,3})\s*$/.exec(s);
    if (!m) return 'invalid';
    const sys = Number(m[1]);
    const dia = Number(m[2]);
    if (sys < 50 || sys > 300 || dia < 30 || dia > 200 || dia >= sys) return 'invalid';
    return [
      { type: 'bp_systolic', value: sys, unit: 'mmHg' },
      { type: 'bp_diastolic', value: dia, unit: 'mmHg' },
    ];
  }
  const m = /^(?:SUGAR|GLUCOSE)\s*(\d{2,3})\s*(?:MG\/?DL)?\s*$/.exec(s);
  if (!m) return 'invalid';
  const v = Number(m[1]);
  if (v < 20 || v > 800) return 'invalid';
  return [{ type: 'blood_glucose', value: v, unit: 'mg/dL' }];
}

/**
 * Contract section 43: handle one inbound WhatsApp text from `phone`. Returns the plain-text replies (no diagnosis).
 * Free text goes to the AI Care Assistant pipeline (intake + deterministic safety engine; emergency -> fixed 108 template).
 */
export async function handleInbound(svc: Services, phone: string, rawText: string): Promise<string[]> {
  const text = rawText.trim().slice(0, 2000);
  const cmd = text.toUpperCase();
  // Safety first: an emergency message always gets the fixed 108 guidance, even from unknown
  // or unsubscribed numbers (they wrote to us; this reply contains no personal data).
  const isCommand = ['START', 'STOP', 'HELP', 'MENU', 'HI', 'HELLO', 'TODAY', 'REMINDERS', 'BOOK'].includes(cmd);
  const earlySafety = isCommand ? null : await svc.safety.evaluate({ text });
  const [u] = await svc.db.select({ id: users.id }).from(users).where(eq(users.phone, phone));
  const ctx = u ? await channelCtx(svc.db, u.id, 'whatsapp') : null;
  if (!u || !ctx) return [t('en', earlySafety?.level === 'emergency' ? 'ai.emergency' : 'whatsapp.unknown_user')];
  const lang = ctx.lang;
  if (earlySafety?.level === 'emergency' && !(await whatsappStatus(svc.db, u.id)).optedIn) {
    if (ctx.user.selfPatientId) {
      await raiseAlert(svc, { patientId: ctx.user.selfPatientId, level: 'emergency', source: 'message', rules: earlySafety.triggeredRules, note: 'WhatsApp message (not subscribed)' });
    }
    return [t(lang, 'ai.emergency')];
  }
  if (cmd === 'START') {
    await setOptIn(svc, ctx, true, 'whatsapp');
    return [t(lang, 'whatsapp.start')];
  }
  if (cmd === 'STOP') {
    await setOptIn(svc, ctx, false, 'whatsapp');
    return [t(lang, 'whatsapp.stop')];
  }
  if (!(await whatsappStatus(svc.db, u.id)).optedIn) return [t(lang, 'whatsapp.not_opted_in')];
  await audit(svc.db, ctx.actor, { action: 'whatsapp.inbound', entityType: 'user', entityId: u.id, metadata: { length: text.length } });

  if (cmd === 'HELP' || cmd === 'MENU' || cmd === 'HI' || cmd === 'HELLO') return [t(lang, 'whatsapp.help')];
  if (cmd === 'TODAY' || cmd === 'REMINDERS') {
    const lines = await todaysReminderLines(svc, ctx);
    return [lines.length ? `Today's reminders:\n${lines.join('\n')}` : t(lang, 'whatsapp.no_reminders')];
  }
  if (cmd === 'CHECKIN' || cmd === 'CHECK IN' || cmd === 'OK' || cmd === "I'M OK" || cmd === 'IM OK') {
    if (!ctx.user.selfPatientId) return [t(lang, 'whatsapp.no_checkin')];
    await recordCheckin(svc, { patientId: ctx.user.selfPatientId, source: 'whatsapp', actor: ctx.actor, userId: ctx.user.id });
    return [t(lang, 'whatsapp.checkin_ok')];
  }
  if (cmd === 'BOOK') {
    const base = svc.config.APP_DEEP_LINK_BASE.replace(/\/$/, '');
    return [t(lang, 'whatsapp.book', { doctors: `${base}/doctors`, visits: `${base}/home-visits/new`, lab: `${base}/lab` })];
  }
  const reading = parseReading(text);
  if (reading === 'invalid') return [t(lang, 'whatsapp.bad_reading')];
  if (reading) {
    if (!ctx.user.selfPatientId) return [t(lang, 'whatsapp.no_checkin')];
    const now = new Date();
    const rows = [];
    for (const r of reading) {
      const [row] = await svc.db
        .insert(vitals)
        .values({ patientId: ctx.user.selfPatientId, type: r.type, value: r.value, unit: r.unit, measuredAt: now, source: 'patient_entered', recordedByUserId: ctx.user.id, recordedByName: ctx.user.name })
        .returning();
      rows.push(row);
    }
    await audit(svc.db, ctx.actor, { action: 'vital.create', entityType: 'vital', entityId: rows[0].id, metadata: { via: 'whatsapp', types: reading.map((r) => r.type) } });
    const res = await evaluateVitals(svc, ctx.user.selfPatientId, rows, { engineOnlySource: 'message' });
    const label = reading.length === 2 ? `BP ${reading[0].value}/${reading[1].value} mmHg` : `Sugar ${reading[0].value} mg/dL`;
    if (res.level === 'emergency') return [t(lang, 'ai.emergency')];
    return [t(lang, res.level === 'urgent' ? 'whatsapp.vital_alert' : 'whatsapp.vital_saved', { reading: label })];
  }

  // Free text -> AI Care Assistant pipeline (the deterministic safety engine always runs first).
  const patientId = ctx.user.selfPatientId;
  if (!patientId) return [t(lang, 'whatsapp.consent_needed')];
  if (!(await hasConsent(svc.db, ctx.user.id, 'ai_assistance'))) {
    const safety = await svc.safety.evaluate({ text });
    if (safety.level === 'emergency') {
      await raiseAlert(svc, { patientId, level: 'emergency', source: 'message', rules: safety.triggeredRules, note: 'WhatsApp message (no AI consent)' });
      return [t(lang, 'ai.emergency')];
    }
    return [t(lang, 'whatsapp.consent_needed')];
  }
  const [opt] = await svc.db.select().from(whatsappOptins).where(eq(whatsappOptins.userId, ctx.user.id));
  let conv = opt?.conversationId ? (await svc.db.select().from(conversations).where(eq(conversations.id, opt.conversationId)))[0] : undefined;
  if (!conv || conv.status !== 'active' || conv.patientId !== patientId) {
    conv = await startConversation(svc, ctx, patientId);
    await svc.db.update(whatsappOptins).set({ conversationId: conv.id, updatedAt: new Date() }).where(eq(whatsappOptins.userId, ctx.user.id));
  }
  const turn = await handleTurn(svc, ctx, conv, text);
  const replies = turn.messages.filter((m) => m.role === 'assistant').map((m) => m.text);
  return replies.length ? replies : [t(lang, 'ai.fallback')];
}
