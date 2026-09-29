import { and, eq } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { ivrSessions, users } from '../../db/schema.js';
import { audit } from '../../lib/audit.js';
import { SYSTEM_ACTOR, type Lang } from '../../lib/context.js';
import { safeEqual } from '../../lib/crypto.js';
import { errors } from '../../lib/errors.js';
import { t } from '../../lib/i18n.js';
import { parse, zPhone, zUuid } from '../../lib/validate.js';
import { parseFormBuffer, parseJsonBuffer, rawBodyParsers, twilioSignature, verifyHmacHeader } from '../../lib/webhooks.js';
import type { Services } from '../../services.js';
import { handleTurn, startConversation } from '../ai/assistant.js';
import { recordCheckin } from '../checkins/service.js';
import { hasConsent } from '../consent/routes.js';
import { raiseAlert, usersWithRoles } from '../safety/alerts.js';
import { createTicket } from '../support/routes.js';
import { channelCtx, todaysReminderLines } from '../whatsapp/service.js';

/** Contract section 62: telephony line (IVR) for elders without smartphones. */
export interface IvrOutput {
  sessionId: string;
  say: string;
  gather: 'digits' | 'speech' | 'none';
  ended: boolean;
  /** Set when the call should be transferred (menu 9). */
  transferTo?: string | null;
  lang: Lang;
}

const LANGS: Record<string, Lang> = { '1': 'en', '2': 'hi', '3': 'te' };

export async function ivrStep(svc: Services, p: { provider: string; sessionId?: string | null; callId?: string | null; fromPhone: string; digits?: string | null; speechText?: string | null }): Promise<IvrOutput> {
  const db = svc.db;
  let [session] = p.sessionId
    ? await db.select().from(ivrSessions).where(eq(ivrSessions.id, p.sessionId))
    : p.callId
      ? await db.select().from(ivrSessions).where(and(eq(ivrSessions.provider, p.provider), eq(ivrSessions.callId, p.callId)))
      : [];
  if (session && session.fromPhone !== p.fromPhone) throw errors.forbidden('Session belongs to another caller');
  const out = (say: string, gather: IvrOutput['gather'], _state: string, lang: Lang, transferTo: string | null = null): IvrOutput => ({ sessionId: session!.id, say, gather, ended: gather === 'none', transferTo, lang });
  const save = async (state: string, lang: Lang | null) => {
    await db.update(ivrSessions).set({ state, lang, updatedAt: new Date(), ...(state === 'ended' ? { endedAt: new Date() } : {}) }).where(eq(ivrSessions.id, session!.id));
  };

  const [user] = await db.select().from(users).where(eq(users.phone, p.fromPhone));
  if (!session) {
    [session] = await db
      .insert(ivrSessions)
      .values({ provider: p.provider, callId: p.callId ?? null, fromPhone: p.fromPhone, userId: user?.id ?? null, lang: user && ['en', 'hi', 'te'].includes(user.language) ? user.language : null })
      .returning();
    await audit(db, { ...SYSTEM_ACTOR, name: `ivr:${p.provider}` }, { action: 'ivr.call', entityType: 'ivr_session', entityId: session.id, metadata: { known: !!user } });
    if (!user || user.status !== 'active') {
      await save('ended', 'en');
      return out(t('en', 'ivr.unknown_caller', { phone: svc.config.SUPPORT_PHONE }), 'none', 'ended', 'en');
    }
    if (!session.lang) {
      await save('lang', null);
      return out(t('en', 'ivr.choose_language'), 'digits', 'lang', 'en');
    }
    await save('menu', session.lang as Lang);
    return out(t(session.lang as Lang, 'ivr.menu'), 'digits', 'menu', session.lang as Lang);
  }
  if (session.state === 'ended') return out('', 'none', 'ended', (session.lang as Lang) ?? 'en');
  if (!user) return out(t('en', 'ivr.unknown_caller', { phone: svc.config.SUPPORT_PHONE }), 'none', 'ended', 'en');
  const ctx = await channelCtx(db, user.id, 'ivr', (session.lang as Lang) ?? undefined);
  if (!ctx) return out(t('en', 'ivr.unknown_caller', { phone: svc.config.SUPPORT_PHONE }), 'none', 'ended', 'en');
  let lang: Lang = (session.lang as Lang) ?? 'en';

  if (session.state === 'lang') {
    const chosen = LANGS[(p.digits ?? '').trim()];
    if (!chosen) return out(t('en', 'ivr.choose_language'), 'digits', 'lang', 'en');
    lang = chosen;
    await save('menu', lang);
    return out(t(lang, 'ivr.menu'), 'digits', 'menu', lang);
  }

  if (session.state === 'concern') {
    const text = (p.speechText ?? '').trim();
    if (!text) return out(t(lang, 'ivr.speak_concern'), 'speech', 'concern', lang);
    await save('ended', lang);
    const safety = await svc.safety.evaluate({ text });
    const patientId = ctx.user.selfPatientId;
    if (safety.level === 'emergency') {
      if (patientId) {
        await raiseAlert(svc, { patientId, level: 'emergency', source: 'message', rules: safety.triggeredRules, note: 'Emergency concern reported on the phone line (IVR)' });
      }
      await svc.notify.notifyUsers(await usersWithRoles(db, ['coordinator', 'ops_admin']), {
        template: 'safety_alert',
        params: { patient: 'a caller on the phone line' },
        category: 'safety',
        critical: true,
        deepLink: '/ops/safety-events',
        dedupeKey: `ivr_emergency:${session.id}`,
      });
      return out(t(lang, 'ivr.emergency'), 'none', 'ended', lang);
    }
    if (patientId && (await hasConsent(db, ctx.user.id, 'ai_assistance'))) {
      const conv = await startConversation(svc, ctx, patientId);
      await handleTurn(svc, ctx, conv, text);
    } else {
      await createTicket(svc, { userId: ctx.user.id, userName: ctx.user.name, patientId, subject: 'Health concern (phone line)', category: 'clinical_concern', message: text, source: 'ivr', actor: ctx.actor });
    }
    return out(t(lang, 'ivr.concern_noted'), 'none', 'ended', lang);
  }

  // menu
  const d = (p.digits ?? '').trim();
  switch (d) {
    case '1': {
      const lines = await todaysReminderLines(svc, ctx);
      const say = lines.length ? t(lang, 'ivr.reminders', { list: lines.join('. ') }) : t(lang, 'ivr.no_reminders');
      return out(`${say} ${t(lang, 'ivr.menu')}`, 'digits', 'menu', lang);
    }
    case '2': {
      if (!ctx.user.selfPatientId) {
        await save('ended', lang);
        return out(t(lang, 'ivr.no_checkin'), 'none', 'ended', lang);
      }
      await recordCheckin(svc, { patientId: ctx.user.selfPatientId, source: 'ivr', actor: ctx.actor, userId: ctx.user.id });
      await save('ended', lang);
      return out(t(lang, 'ivr.checkin_ok'), 'none', 'ended', lang);
    }
    case '3': {
      await createTicket(svc, {
        userId: ctx.user.id,
        userName: ctx.user.name,
        patientId: ctx.user.selfPatientId,
        subject: 'Call back requested (phone line)',
        category: 'other',
        priority: 'high',
        message: 'The caller pressed 3 on the CareCompanion phone line to request a call back from the care coordinator.',
        source: 'ivr',
        actor: ctx.actor,
      });
      await save('ended', lang);
      return out(t(lang, 'ivr.callback'), 'none', 'ended', lang);
    }
    case '4':
      await save('concern', lang);
      return out(t(lang, 'ivr.speak_concern'), 'speech', 'concern', lang);
    case '9':
      await save('ended', lang);
      return out(t(lang, 'ivr.transfer'), 'none', 'ended', lang, svc.config.SUPPORT_PHONE);
    default:
      return out(`${t(lang, 'ivr.invalid')} ${t(lang, 'ivr.menu')}`, 'digits', 'menu', lang);
  }
}

const xmlEscape = (s: string) => s.replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' })[c]!);
const VOICE_LANG: Record<Lang, string> = { en: 'en-IN', hi: 'hi-IN', te: 'te-IN' };

/** TwiML for Twilio (<Gather> for input, <Dial> for transfer, <Hangup/> at the end). */
export function toTwiml(o: IvrOutput, actionUrl: string): string {
  const say = `<Say language="${VOICE_LANG[o.lang]}">${xmlEscape(o.say)}</Say>`;
  if (o.gather === 'digits') return `<?xml version="1.0" encoding="UTF-8"?><Response><Gather input="dtmf" numDigits="1" timeout="8" action="${xmlEscape(actionUrl)}">${say}</Gather>${say}</Response>`;
  if (o.gather === 'speech') return `<?xml version="1.0" encoding="UTF-8"?><Response><Gather input="speech" language="${VOICE_LANG[o.lang]}" speechTimeout="auto" action="${xmlEscape(actionUrl)}">${say}</Gather></Response>`;
  if (o.transferTo) return `<?xml version="1.0" encoding="UTF-8"?><Response>${say}<Dial>${xmlEscape(o.transferTo)}</Dial></Response>`;
  return `<?xml version="1.0" encoding="UTF-8"?><Response>${say}<Hangup/></Response>`;
}

export async function ivrRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  if (svc.config.NODE_ENV === 'production') return;
  // Dev simulator (non-production only).
  app.post('/dev/ivr/simulate', async (req) => {
    const body = parse(z.object({ fromPhone: zPhone, digits: z.string().max(10).optional(), speechText: z.string().max(2000).optional(), sessionId: zUuid.optional() }), req.body);
    const o = await ivrStep(svc, { provider: 'simulator', sessionId: body.sessionId ?? null, fromPhone: body.fromPhone, digits: body.digits ?? null, speechText: body.speechText ?? null });
    return { sessionId: o.sessionId, say: o.say, gather: o.gather, ended: o.ended };
  });
}

/**
 * Provider callbacks. exotel / mock: JSON or form body signed with X-IVR-Signature = hex(HMAC-SHA256(rawBody,
 * IVR_WEBHOOK_SECRET)); response JSON {sessionId, say, gather, ended, transferTo}. twilio: X-Twilio-Signature over
 * IVR_PUBLIC_URL + path + sorted params (TWILIO_AUTH_TOKEN); response TwiML.
 */
export async function ivrWebhookRoutes(app: FastifyInstance): Promise<void> {
  const svc = app.svc;
  rawBodyParsers(app);
  app.post('/webhooks/ivr/:provider', { bodyLimit: 64 * 1024 }, async (req, reply) => {
    const { provider } = parse(z.object({ provider: z.enum(['exotel', 'twilio', 'mock']) }), req.params);
    const cfg = svc.config.IVR_PROVIDER;
    if (cfg === 'disabled' || (provider !== cfg && !(provider === 'mock' && svc.config.NODE_ENV !== 'production'))) throw errors.notFound('IVR provider');
    const actor = { ...SYSTEM_ACTOR, name: `ivr:${provider}`, role: 'webhook', ip: req.ip, correlationId: req.correlationId };
    const raw = req.body;
    let params: Record<string, string>;
    let valid: boolean;
    if (provider === 'twilio') {
      params = parseFormBuffer(raw);
      const url = `${(svc.config.IVR_PUBLIC_URL ?? '').replace(/\/$/, '')}${req.url}`;
      const sig = req.headers['x-twilio-signature'];
      valid = !!svc.config.TWILIO_AUTH_TOKEN && typeof sig === 'string' && safeEqual(twilioSignature(svc.config.TWILIO_AUTH_TOKEN, url, params), sig);
    } else {
      valid = Buffer.isBuffer(raw) && verifyHmacHeader(svc.config.IVR_WEBHOOK_SECRET, raw, req.headers['x-ivr-signature']);
      const ct = String(req.headers['content-type'] ?? '');
      params = ct.includes('json') ? ((parseJsonBuffer(raw) as Record<string, string>) ?? {}) : parseFormBuffer(raw);
    }
    if (!valid) {
      await audit(svc.db, actor, { action: 'ivr.webhook', entityType: 'webhook', outcome: 'denied', metadata: { reason: 'bad_signature', provider } });
      throw errors.unauthenticated('Invalid webhook signature');
    }
    const from = String(params.From ?? params.from ?? params.CallFrom ?? '').replace(/^0/, '+91');
    const fromPhone = from.startsWith('+') ? from : `+${from}`;
    if (!/^\+\d{10,15}$/.test(fromPhone)) throw errors.validation('Missing caller number');
    const o = await ivrStep(svc, {
      provider,
      callId: String(params.CallSid ?? params.callSid ?? params.CallId ?? '') || null,
      fromPhone,
      digits: (params.Digits ?? params.digits ?? null) as string | null,
      speechText: (params.SpeechResult ?? params.speechText ?? null) as string | null,
    });
    if (provider === 'twilio') {
      return reply.header('content-type', 'text/xml').send(toTwiml(o, `${(svc.config.IVR_PUBLIC_URL ?? '').replace(/\/$/, '')}${req.url}`));
    }
    return reply.send({ sessionId: o.sessionId, say: o.say, gather: o.gather, ended: o.ended, transferTo: o.transferTo ?? null });
  });
}
