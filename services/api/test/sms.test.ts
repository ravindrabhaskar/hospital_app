import { afterAll, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { AppError } from '../src/lib/errors.js';
import { ConsoleSmsProvider, Msg91SmsProvider, TwilioSmsProvider, createSmsProvider } from '../src/modules/auth/sms.js';
import { SmsChannel } from '../src/modules/notifications/channels.js';
import { fakeFetch } from './fakes.js';
import { setup, type TestCtx } from './helpers.js';

describe('MSG91 adapter', () => {
  it('sends the OTP through the Flow API with the DLT-linked template and authkey header', async () => {
    const f = fakeFetch(() => ({ body: { type: 'success', message: 'ok' } }));
    const sms = new Msg91SmsProvider({ authKey: 'AUTHKEY123', otpTemplateId: 'tmpl-otp', senderId: 'CARECO' }, f.fetch);
    await sms.sendOtp('+919800000001', '482913');
    expect(f.calls).toHaveLength(1);
    const c = f.calls[0];
    expect(c.url).toBe('https://control.msg91.com/api/v5/flow');
    expect(c.method).toBe('POST');
    expect(c.headers.authkey).toBe('AUTHKEY123');
    expect(JSON.parse(c.body)).toEqual({
      template_id: 'tmpl-otp',
      short_url: '0',
      sender: 'CARECO',
      recipients: [{ mobiles: '919800000001', otp: '482913' }],
    });
  });

  it('maps provider errors (HTTP and type=error) to DEPENDENCY_UNAVAILABLE', async () => {
    const bad = new Msg91SmsProvider({ authKey: 'k', otpTemplateId: 't' }, fakeFetch(() => ({ status: 401, body: { type: 'error', message: 'Invalid authkey' } })).fetch);
    await expect(bad.sendOtp('+919800000001', '111111')).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE', details: { provider: 'msg91', status: 401 } });
    const rejected = new Msg91SmsProvider({ authKey: 'k', otpTemplateId: 't' }, fakeFetch(() => ({ body: { type: 'error', message: 'DLT' } })).fetch);
    await expect(rejected.sendOtp('+919800000001', '111111')).rejects.toBeInstanceOf(AppError);
  });

  it('notification text requires a DLT notification template', async () => {
    const f = fakeFetch(() => ({ body: { type: 'success' } }));
    await expect(new Msg91SmsProvider({ authKey: 'k', otpTemplateId: 't' }, f.fetch).sendText('+919800000001', 'hi')).rejects.toMatchObject({
      code: 'DEPENDENCY_UNAVAILABLE',
    });
    await new Msg91SmsProvider({ authKey: 'k', otpTemplateId: 't', notifyTemplateId: 'tmpl-n' }, f.fetch).sendText('+919800000001', 'You have a care update');
    expect(JSON.parse(f.calls[0].body).recipients[0]).toEqual({ mobiles: '919800000001', message: 'You have a care update' });
  });
});

describe('Twilio adapter', () => {
  it('posts a form-encoded message with basic auth', async () => {
    const f = fakeFetch(() => ({ status: 201, body: { sid: 'SM1' } }));
    const sms = new TwilioSmsProvider({ accountSid: 'AC123', authToken: 'tok', from: '+15005550006', otpTtlMin: 5 }, f.fetch);
    await sms.sendOtp('+919800000001', '654321');
    const c = f.calls[0];
    expect(c.url).toBe('https://api.twilio.com/2010-04-01/Accounts/AC123/Messages.json');
    expect(c.headers.authorization).toBe(`Basic ${Buffer.from('AC123:tok').toString('base64')}`);
    expect(c.headers['content-type']).toBe('application/x-www-form-urlencoded');
    const form = new URLSearchParams(c.body);
    expect(form.get('To')).toBe('+919800000001');
    expect(form.get('From')).toBe('+15005550006');
    expect(form.get('Body')).toContain('654321');
    expect(form.get('Body')).toContain('5 minutes');
  });

  it('prefers a messaging service sid and maps failures', async () => {
    const f = fakeFetch(() => ({ status: 400, body: { code: 21211, message: 'invalid To' } }));
    const sms = new TwilioSmsProvider({ accountSid: 'AC1', authToken: 't', messagingServiceSid: 'MG1', from: '+1' }, f.fetch);
    await expect(sms.sendText('+919800000001', 'x')).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE', details: { provider: 'twilio', status: 400 } });
    const form = new URLSearchParams(f.calls[0].body);
    expect(form.get('MessagingServiceSid')).toBe('MG1');
    expect(form.get('From')).toBeNull();
  });
});

describe('provider selection', () => {
  it('builds the configured adapter and validates its credentials', () => {
    expect(createSmsProvider(loadConfig({ NODE_ENV: 'test' }), true)).toBeInstanceOf(ConsoleSmsProvider);
    expect(createSmsProvider(loadConfig({ NODE_ENV: 'test', SMS_PROVIDER: 'msg91', MSG91_AUTH_KEY: 'k', MSG91_OTP_TEMPLATE_ID: 't' }), true).name).toBe('msg91');
    expect(
      createSmsProvider(loadConfig({ NODE_ENV: 'test', SMS_PROVIDER: 'twilio', TWILIO_ACCOUNT_SID: 'AC', TWILIO_AUTH_TOKEN: 't', TWILIO_FROM: '+1' }), true).name,
    ).toBe('twilio');
    expect(() => createSmsProvider(loadConfig({ NODE_ENV: 'test', SMS_PROVIDER: 'msg91' }), true)).toThrow(/MSG91_AUTH_KEY/);
  });

  it('SmsChannel delivers outbox text through the provider', async () => {
    const f = fakeFetch(() => ({ status: 201, body: {} }));
    await new SmsChannel(new TwilioSmsProvider({ accountSid: 'AC', authToken: 't', from: '+1' }, f.fetch)).send({
      channel: 'sms',
      recipient: '+919800000002',
      userId: null,
      text: 'You have a care update',
      critical: false,
    });
    expect(new URLSearchParams(f.calls[0].body).get('Body')).toBe('You have a care update');
  });
});

describe('OTP flow with a real adapter (mocked HTTP)', () => {
  let t: TestCtx;
  afterAll(async () => t?.close());

  it('sends the dev OTP via MSG91 outside production and fails closed when the provider is down', async () => {
    let up = true;
    const f = fakeFetch(() => (up ? { body: { type: 'success' } } : { status: 503, body: { type: 'error' } }));
    t = await setup({
      fetchImpl: f.fetch,
      sms: undefined,
      config: { SMS_PROVIDER: 'msg91', MSG91_AUTH_KEY: 'k', MSG91_OTP_TEMPLATE_ID: 'tmpl' },
    });
    expect(t.svc.sms.name).toBe('msg91');
    const r = await t.req(null, 'POST', '/auth/otp/request', { phone: '+919812345678' });
    expect(r.status).toBe(200);
    expect(r.body.devOtp).toBe('123456'); // dev-only
    expect(JSON.parse(f.calls[0].body).recipients[0]).toMatchObject({ mobiles: '919812345678', otp: '123456' });

    up = false;
    const down = await t.req(null, 'POST', '/auth/otp/request', { phone: '+919812345679' });
    expect(down.status).toBe(503);
    expect(down.body.error.code).toBe('DEPENDENCY_UNAVAILABLE');
    // The undelivered code is burnt, so it cannot be used.
    const v = await t.req(null, 'POST', '/auth/otp/verify', { phone: '+919812345679', otp: '123456' });
    expect(v.status).toBe(401);
  });
});
