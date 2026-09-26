import type { Config } from '../../config.js';
import { maskPhone } from '../../lib/crypto.js';
import { errors } from '../../lib/errors.js';
import { HttpError, basicAuth, defaultFetch, requestJson, type FetchLike } from '../../lib/http.js';

/**
 * SMS provider adapter. `sendOtp` delivers login codes (DLT-registered template in India);
 * `sendText` delivers generic, PHI-free notification text (used by the notification outbox).
 */
export interface SmsProvider {
  readonly name: 'console' | 'msg91' | 'twilio';
  sendOtp(phone: string, code: string): Promise<void>;
  sendText(phone: string, text: string): Promise<void>;
}

export class ConsoleSmsProvider implements SmsProvider {
  readonly name = 'console' as const;
  constructor(private readonly silent = false) {}
  async sendOtp(phone: string): Promise<void> {
    // Never print the code itself outside dev tooling; dev OTP is fixed and returned as devOtp.
    if (!this.silent) console.log(`[sms:otp] OTP sent to ${maskPhone(phone)}`);
  }
  async sendText(phone: string, text: string): Promise<void> {
    if (!this.silent) console.log(`[sms:text] -> ${maskPhone(phone)}: ${text}`);
  }
}

const otpText = (code: string, ttlMin: number) =>
  `${code} is your CareCompanion verification code. It is valid for ${ttlMin} minutes. Do not share it with anyone.`;

/** Map transport/provider failures to a contract error without leaking provider details to clients. */
function providerError(provider: string, err: unknown): Error {
  const status = err instanceof HttpError ? err.status : null;
  return errors.dependency('SMS delivery is temporarily unavailable. Please try again.', { provider, ...(status ? { status } : {}) });
}

/**
 * MSG91 Flow API (v5). The flow template (MSG91_OTP_TEMPLATE_ID) is created in the MSG91 panel and
 * linked to the DLT-approved template; it must contain a variable named `otp` (e.g. "##otp## is your
 * CareCompanion verification code..."). Mobile numbers are sent without the leading '+'.
 */
export class Msg91SmsProvider implements SmsProvider {
  readonly name = 'msg91' as const;
  constructor(
    private readonly opts: {
      authKey: string;
      otpTemplateId: string;
      notifyTemplateId?: string;
      senderId?: string;
      baseUrl?: string;
      timeoutMs?: number;
    },
    private readonly fetchImpl: FetchLike = defaultFetch,
  ) {}

  private async flow(templateId: string, phone: string, vars: Record<string, string>): Promise<void> {
    const url = `${(this.opts.baseUrl ?? 'https://control.msg91.com').replace(/\/$/, '')}/api/v5/flow`;
    try {
      const res = await requestJson<{ type?: string; message?: string }>(this.fetchImpl, url, {
        method: 'POST',
        timeoutMs: this.opts.timeoutMs,
        headers: { authkey: this.opts.authKey, 'content-type': 'application/json', accept: 'application/json' },
        body: JSON.stringify({
          template_id: templateId,
          short_url: '0',
          ...(this.opts.senderId ? { sender: this.opts.senderId } : {}),
          recipients: [{ mobiles: phone.replace(/^\+/, ''), ...vars }],
        }),
      });
      if (res?.type && res.type !== 'success') throw new HttpError(200, res, 'msg91 rejected the request');
    } catch (err) {
      throw providerError('msg91', err);
    }
  }

  async sendOtp(phone: string, code: string): Promise<void> {
    await this.flow(this.opts.otpTemplateId, phone, { otp: code });
  }

  async sendText(phone: string, text: string): Promise<void> {
    // DLT rules: free text is not allowed; a notification template with a ##message## variable is required.
    if (!this.opts.notifyTemplateId) throw errors.dependency('MSG91_NOTIFY_TEMPLATE_ID is not configured');
    await this.flow(this.opts.notifyTemplateId, phone, { message: text });
  }
}

/** Twilio Programmable Messaging (Messages API, form-encoded, basic auth). */
export class TwilioSmsProvider implements SmsProvider {
  readonly name = 'twilio' as const;
  constructor(
    private readonly opts: {
      accountSid: string;
      authToken: string;
      from?: string;
      messagingServiceSid?: string;
      baseUrl?: string;
      timeoutMs?: number;
      otpTtlMin?: number;
    },
    private readonly fetchImpl: FetchLike = defaultFetch,
  ) {}

  private async send(to: string, body: string): Promise<void> {
    const base = (this.opts.baseUrl ?? 'https://api.twilio.com').replace(/\/$/, '');
    const url = `${base}/2010-04-01/Accounts/${encodeURIComponent(this.opts.accountSid)}/Messages.json`;
    const form = new URLSearchParams({ To: to, Body: body });
    if (this.opts.messagingServiceSid) form.set('MessagingServiceSid', this.opts.messagingServiceSid);
    else if (this.opts.from) form.set('From', this.opts.from);
    try {
      await requestJson(this.fetchImpl, url, {
        method: 'POST',
        timeoutMs: this.opts.timeoutMs,
        headers: { authorization: basicAuth(this.opts.accountSid, this.opts.authToken), 'content-type': 'application/x-www-form-urlencoded' },
        body: form.toString(),
      });
    } catch (err) {
      throw providerError('twilio', err);
    }
  }

  async sendOtp(phone: string, code: string): Promise<void> {
    await this.send(phone, otpText(code, this.opts.otpTtlMin ?? 5));
  }

  async sendText(phone: string, text: string): Promise<void> {
    await this.send(phone, text);
  }
}

/** Build the configured provider. `console` is refused in production by productionReadinessIssues(). */
export function createSmsProvider(config: Config, quiet: boolean, fetchImpl: FetchLike = defaultFetch): SmsProvider {
  const timeoutMs = config.SMS_TIMEOUT_MS;
  if (config.SMS_PROVIDER === 'msg91') {
    if (!config.MSG91_AUTH_KEY || !config.MSG91_OTP_TEMPLATE_ID) throw new Error('SMS_PROVIDER=msg91 requires MSG91_AUTH_KEY and MSG91_OTP_TEMPLATE_ID');
    return new Msg91SmsProvider(
      {
        authKey: config.MSG91_AUTH_KEY,
        otpTemplateId: config.MSG91_OTP_TEMPLATE_ID,
        notifyTemplateId: config.MSG91_NOTIFY_TEMPLATE_ID,
        senderId: config.MSG91_SENDER_ID,
        baseUrl: config.MSG91_BASE_URL,
        timeoutMs,
      },
      fetchImpl,
    );
  }
  if (config.SMS_PROVIDER === 'twilio') {
    if (!config.TWILIO_ACCOUNT_SID || !config.TWILIO_AUTH_TOKEN || !(config.TWILIO_FROM || config.TWILIO_MESSAGING_SERVICE_SID)) {
      throw new Error('SMS_PROVIDER=twilio requires TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_FROM or TWILIO_MESSAGING_SERVICE_SID');
    }
    return new TwilioSmsProvider(
      {
        accountSid: config.TWILIO_ACCOUNT_SID,
        authToken: config.TWILIO_AUTH_TOKEN,
        from: config.TWILIO_FROM,
        messagingServiceSid: config.TWILIO_MESSAGING_SERVICE_SID,
        baseUrl: config.TWILIO_BASE_URL,
        timeoutMs,
        otpTtlMin: Math.max(1, Math.round(config.OTP_TTL_SEC / 60)),
      },
      fetchImpl,
    );
  }
  return new ConsoleSmsProvider(quiet);
}
