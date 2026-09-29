import { randomUUID } from 'node:crypto';
import type { Config } from '../../config.js';
import { maskPhone } from '../../lib/crypto.js';
import { AppError, errors } from '../../lib/errors.js';
import { HttpError, requestJson, type FetchLike } from '../../lib/http.js';
import { haversineKm } from '../providers/routes.js';

/**
 * v1.3 partner adapters. Each integration has a mock partner (default outside production, driven by the worker to
 * simulate realistic lifecycles), a real adapter enabled by env credentials, and `disabled`.
 * productionReadinessIssues() refuses mocks in production.
 */

const dependencyError = (partner: string, err: unknown): AppError => {
  const status = err instanceof HttpError ? err.status : null;
  return errors.dependency(`${partner} is temporarily unavailable`, { partner, status });
};

// ---------------------------------------------------------------- WhatsApp (Meta Cloud API)
export interface WhatsAppAdapter {
  readonly name: 'mock' | 'meta' | 'disabled';
  /** Free-form reply inside the 24-hour customer-service window. */
  sendText(to: string, text: string): Promise<void>;
  /** Business-initiated message using an approved template (WHATSAPP_TEMPLATE_*). */
  sendTemplate(to: string, template: string, params: string[]): Promise<void>;
}

export class MockWhatsApp implements WhatsAppAdapter {
  readonly name = 'mock' as const;
  /** Messages "sent" (tests and the dev simulator inspect this). */
  readonly outbox: Array<{ to: string; text?: string; template?: string; params?: string[]; at: string }> = [];
  constructor(private readonly quiet: boolean) {}
  async sendText(to: string, text: string): Promise<void> {
    this.outbox.push({ to, text, at: new Date().toISOString() });
    if (this.outbox.length > 500) this.outbox.shift();
    // eslint-disable-next-line no-console -- dev mock partner output
    if (!this.quiet) console.log(`[whatsapp:mock] -> ${maskPhone(to)}: ${text.slice(0, 120)}`);
  }
  async sendTemplate(to: string, template: string, params: string[]): Promise<void> {
    this.outbox.push({ to, template, params, at: new Date().toISOString() });
    if (this.outbox.length > 500) this.outbox.shift();
    // eslint-disable-next-line no-console -- dev mock partner output
    if (!this.quiet) console.log(`[whatsapp:mock] -> ${maskPhone(to)}: template ${template}`);
  }
}

/** https://developers.facebook.com/docs/whatsapp/cloud-api/reference/messages */
export class MetaWhatsApp implements WhatsAppAdapter {
  readonly name = 'meta' as const;
  constructor(
    private readonly c: Config,
    private readonly fetchImpl: FetchLike,
  ) {}
  private async post(body: Record<string, unknown>): Promise<void> {
    try {
      await requestJson(this.fetchImpl, `${this.c.WHATSAPP_API_BASE_URL.replace(/\/$/, '')}/${this.c.WHATSAPP_PHONE_NUMBER_ID}/messages`, {
        method: 'POST',
        timeoutMs: 10_000,
        headers: { authorization: `Bearer ${this.c.WHATSAPP_ACCESS_TOKEN}`, 'content-type': 'application/json' },
        body: JSON.stringify({ messaging_product: 'whatsapp', ...body }),
      });
    } catch (err) {
      throw dependencyError('WhatsApp', err);
    }
  }
  sendText(to: string, text: string): Promise<void> {
    return this.post({ to: to.replace(/^\+/, ''), type: 'text', text: { body: text.slice(0, 4096), preview_url: false } });
  }
  sendTemplate(to: string, template: string, params: string[]): Promise<void> {
    return this.post({
      to: to.replace(/^\+/, ''),
      type: 'template',
      template: {
        name: template,
        language: { code: this.c.WHATSAPP_TEMPLATE_LANG },
        components: params.length ? [{ type: 'body', parameters: params.map((p) => ({ type: 'text', text: p })) }] : [],
      },
    });
  }
}

export class DisabledWhatsApp implements WhatsAppAdapter {
  readonly name = 'disabled' as const;
  async sendText(): Promise<void> {}
  async sendTemplate(): Promise<void> {}
}

// ---------------------------------------------------------------- Lab partner
export interface LabPartner {
  readonly name: 'mock' | 'http' | 'disabled';
  readonly displayName: string;
  submitOrder(o: { orderId: string; testCodes: string[]; collectedAt: string }): Promise<{ partnerOrderId: string }>;
  cancelOrder(partnerOrderId: string): Promise<void>;
}

export class MockLabPartner implements LabPartner {
  readonly name = 'mock' as const;
  constructor(readonly displayName: string) {}
  async submitOrder(): Promise<{ partnerOrderId: string }> {
    return { partnerOrderId: `LABMOCK-${randomUUID().slice(0, 8).toUpperCase()}` };
  }
  async cancelOrder(): Promise<void> {}
}

/** Generic REST lab partner: POST /orders {reference, tests[], collectedAt} -> {id}; POST /orders/:id/cancel. Results arrive by webhook. */
export class HttpLabPartner implements LabPartner {
  readonly name = 'http' as const;
  constructor(
    readonly displayName: string,
    private readonly baseUrl: string,
    private readonly apiKey: string,
    private readonly fetchImpl: FetchLike,
  ) {}
  async submitOrder(o: { orderId: string; testCodes: string[]; collectedAt: string }): Promise<{ partnerOrderId: string }> {
    try {
      const res = await requestJson<{ id?: string }>(this.fetchImpl, `${this.baseUrl.replace(/\/$/, '')}/orders`, {
        method: 'POST',
        headers: { authorization: `Bearer ${this.apiKey}`, 'content-type': 'application/json' },
        body: JSON.stringify({ reference: o.orderId, tests: o.testCodes, collectedAt: o.collectedAt }),
      });
      if (!res?.id) throw new Error('no id');
      return { partnerOrderId: res.id };
    } catch (err) {
      throw dependencyError('Lab partner', err);
    }
  }
  async cancelOrder(partnerOrderId: string): Promise<void> {
    try {
      await requestJson(this.fetchImpl, `${this.baseUrl.replace(/\/$/, '')}/orders/${encodeURIComponent(partnerOrderId)}/cancel`, {
        method: 'POST',
        headers: { authorization: `Bearer ${this.apiKey}` },
      });
    } catch (err) {
      throw dependencyError('Lab partner', err);
    }
  }
}

export class DisabledLabPartner implements LabPartner {
  readonly name = 'disabled' as const;
  readonly displayName = 'Lab partner (disabled)';
  async submitOrder(): Promise<never> {
    throw errors.dependency('Lab tests at home are not available yet');
  }
  async cancelOrder(): Promise<void> {}
}

// ---------------------------------------------------------------- Ambulance partner
export interface AmbulanceStatus {
  status: 'searching' | 'assigned' | 'en_route' | 'arrived' | 'transporting' | 'completed' | 'cancelled' | 'no_vehicle';
  vehicle: { number: string; driverName: string; phone: string } | null;
  etaMinutes: number | null;
  location: { lat: number; lng: number } | null;
}

export interface AmbulancePartner {
  readonly name: 'mock' | 'http' | 'disabled';
  readonly displayName: string;
  /** Price in rupees for this request type (0 = free; the mock is free). */
  price(type: 'bls' | 'als'): number;
  request(r: { requestId: string; type: 'bls' | 'als'; pickup: { lat: number; lng: number; address: string } }): Promise<{ partnerRequestId: string }>;
  /** Real partners are polled by the worker; the mock is simulated in the ambulance service. */
  status?(partnerRequestId: string): Promise<AmbulanceStatus>;
  cancel(partnerRequestId: string): Promise<void>;
}

export class MockAmbulancePartner implements AmbulancePartner {
  readonly name = 'mock' as const;
  constructor(readonly displayName: string) {}
  price(): number {
    return 0;
  }
  async request(): Promise<{ partnerRequestId: string }> {
    return { partnerRequestId: `AMBMOCK-${randomUUID().slice(0, 8).toUpperCase()}` };
  }
  async cancel(): Promise<void> {}
}

/** Generic REST ambulance aggregator: POST /requests, GET /requests/:id, POST /requests/:id/cancel. */
export class HttpAmbulancePartner implements AmbulancePartner {
  readonly name = 'http' as const;
  constructor(
    readonly displayName: string,
    private readonly baseUrl: string,
    private readonly apiKey: string,
    private readonly fetchImpl: FetchLike,
  ) {}
  price(): number {
    return 0; // Billed by the partner directly until a pricing agreement exists.
  }
  private url(p: string) {
    return `${this.baseUrl.replace(/\/$/, '')}${p}`;
  }
  async request(r: { requestId: string; type: 'bls' | 'als'; pickup: { lat: number; lng: number; address: string } }): Promise<{ partnerRequestId: string }> {
    try {
      const res = await requestJson<{ id?: string }>(this.fetchImpl, this.url('/requests'), {
        method: 'POST',
        headers: { authorization: `Bearer ${this.apiKey}`, 'content-type': 'application/json' },
        body: JSON.stringify({ reference: r.requestId, type: r.type, pickup: r.pickup }),
      });
      if (!res?.id) throw new Error('no id');
      return { partnerRequestId: res.id };
    } catch (err) {
      throw dependencyError('Ambulance partner', err);
    }
  }
  async status(id: string): Promise<AmbulanceStatus> {
    try {
      return await requestJson<AmbulanceStatus>(this.fetchImpl, this.url(`/requests/${encodeURIComponent(id)}`), { headers: { authorization: `Bearer ${this.apiKey}` } });
    } catch (err) {
      throw dependencyError('Ambulance partner', err);
    }
  }
  async cancel(id: string): Promise<void> {
    try {
      await requestJson(this.fetchImpl, this.url(`/requests/${encodeURIComponent(id)}/cancel`), { method: 'POST', headers: { authorization: `Bearer ${this.apiKey}` } });
    } catch (err) {
      throw dependencyError('Ambulance partner', err);
    }
  }
}

export class DisabledAmbulancePartner implements AmbulancePartner {
  readonly name = 'disabled' as const;
  readonly displayName = 'Ambulance partner (disabled)';
  price(): number {
    return 0;
  }
  async request(): Promise<never> {
    throw errors.dependency('Ambulance booking is not available. Please call 108.');
  }
  async cancel(): Promise<void> {}
}

// ---------------------------------------------------------------- ABDM gateway (section 50)
export interface AbdmGatewayV3 {
  readonly mode: 'mock' | 'sandbox' | 'production' | 'disabled';
  startAbhaCreation(mobile: string): Promise<{ gatewayTxnId: string }>;
  startLinkExisting(abhaNumber: string): Promise<{ gatewayTxnId: string }>;
  verifyOtp(gatewayTxnId: string, otp: string, kind: 'create' | 'link', abhaNumber: string | null): Promise<{ abhaNumber: string; abhaAddress: string }>;
  requestConsent(r: { consentRequestId: string; abhaAddress: string; hiTypes: string[]; from: string; to: string; purpose: string }): Promise<{ gatewayRequestId: string }>;
}

export const ABDM_MOCK_OTP = '123456';

export class MockAbdmGateway implements AbdmGatewayV3 {
  readonly mode = 'mock' as const;
  async startAbhaCreation(): Promise<{ gatewayTxnId: string }> {
    return { gatewayTxnId: `abdm-mock-${randomUUID()}` };
  }
  async startLinkExisting(): Promise<{ gatewayTxnId: string }> {
    return { gatewayTxnId: `abdm-mock-${randomUUID()}` };
  }
  async verifyOtp(_txn: string, otp: string, kind: 'create' | 'link', abhaNumber: string | null): Promise<{ abhaNumber: string; abhaAddress: string }> {
    if (otp !== ABDM_MOCK_OTP) throw errors.validation('Incorrect OTP', { field: 'otp' });
    const digits = abhaNumber?.replace(/\D/g, '') || `91${Array.from({ length: 12 }, () => Math.floor(Math.random() * 10)).join('')}`;
    const n = `${digits.slice(0, 2)}-${digits.slice(2, 6)}-${digits.slice(6, 10)}-${digits.slice(10, 14)}`;
    return { abhaNumber: n, abhaAddress: `${kind === 'create' ? 'cc' : 'linked'}${digits.slice(-6)}@sbx` };
  }
  async requestConsent(): Promise<{ gatewayRequestId: string }> {
    return { gatewayRequestId: `abdm-consent-mock-${randomUUID()}` };
  }
}

/**
 * ABDM sandbox / production gateway (M1 ABHA, M3 HIU consent). Requires ABDM certification: client id/secret,
 * HIU/HIP registration and a public callback URL. Calls use the gateway session token.
 * [REQUIRES ABDM CERTIFICATION: endpoint paths and payloads must be validated in the ABDM sandbox]
 */
export class HttpAbdmGateway implements AbdmGatewayV3 {
  private token: { value: string; exp: number } | null = null;
  constructor(
    readonly mode: 'sandbox' | 'production',
    private readonly c: Config,
    private readonly fetchImpl: FetchLike,
  ) {}
  private missing(): string[] {
    return (
      [
        ['ABDM_BASE_URL', this.c.ABDM_BASE_URL],
        ['ABDM_CLIENT_ID', this.c.ABDM_CLIENT_ID],
        ['ABDM_CLIENT_SECRET', this.c.ABDM_CLIENT_SECRET],
        ['ABDM_HIU_ID', this.c.ABDM_HIU_ID],
        ['ABDM_CALLBACK_URL', this.c.ABDM_CALLBACK_URL],
      ] as const
    )
      .filter(([, v]) => !v)
      .map(([k]) => k);
  }
  private async call<T>(path: string, body: unknown): Promise<T> {
    const missing = this.missing();
    if (missing.length) throw errors.dependency('ABDM integration pending sandbox certification', { missing });
    try {
      if (!this.token || this.token.exp < Date.now()) {
        const s = await requestJson<{ accessToken: string; expiresIn?: number }>(this.fetchImpl, `${this.c.ABDM_BASE_URL}/gateway/v0.5/sessions`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ clientId: this.c.ABDM_CLIENT_ID, clientSecret: this.c.ABDM_CLIENT_SECRET }),
        });
        this.token = { value: s.accessToken, exp: Date.now() + (s.expiresIn ?? 600) * 1000 - 30_000 };
      }
      return await requestJson<T>(this.fetchImpl, `${this.c.ABDM_BASE_URL}${path}`, {
        method: 'POST',
        headers: { authorization: `Bearer ${this.token.value}`, 'content-type': 'application/json', 'X-CM-ID': this.mode === 'sandbox' ? 'sbx' : 'abdm' },
        body: JSON.stringify(body),
      });
    } catch (err) {
      if (err instanceof AppError) throw err;
      throw dependencyError('ABDM gateway', err);
    }
  }
  async startAbhaCreation(mobile: string): Promise<{ gatewayTxnId: string }> {
    const r = await this.call<{ txnId: string }>('/v1/registration/mobile/generateOtp', { mobile: mobile.replace(/^\+91/, '') });
    return { gatewayTxnId: r.txnId };
  }
  async startLinkExisting(abhaNumber: string): Promise<{ gatewayTxnId: string }> {
    const r = await this.call<{ txnId: string }>('/v1/auth/init', { healthid: abhaNumber, authMethod: 'MOBILE_OTP' });
    return { gatewayTxnId: r.txnId };
  }
  async verifyOtp(txnId: string, otp: string, kind: 'create' | 'link'): Promise<{ abhaNumber: string; abhaAddress: string }> {
    const r = await this.call<{ healthIdNumber: string; healthId: string }>(kind === 'create' ? '/v1/registration/mobile/verifyOtp' : '/v1/auth/confirmWithMobileOTP', { txnId, otp });
    return { abhaNumber: r.healthIdNumber, abhaAddress: r.healthId };
  }
  async requestConsent(r: { consentRequestId: string; abhaAddress: string; hiTypes: string[]; from: string; to: string; purpose: string }): Promise<{ gatewayRequestId: string }> {
    await this.call('/gateway/v0.5/consent-requests/init', {
      requestId: r.consentRequestId,
      timestamp: new Date().toISOString(),
      consent: {
        purpose: { code: r.purpose },
        patient: { id: r.abhaAddress },
        hiu: { id: this.c.ABDM_HIU_ID },
        hiTypes: r.hiTypes,
        permission: { accessMode: 'VIEW', dateRange: { from: r.from, to: r.to }, frequency: { unit: 'HOUR', value: 1, repeats: 0 } },
      },
    });
    return { gatewayRequestId: r.consentRequestId };
  }
}

export class DisabledAbdmGateway implements AbdmGatewayV3 {
  readonly mode = 'disabled' as const;
  private fail(): never {
    throw errors.dependency('ABDM integration pending sandbox certification');
  }
  async startAbhaCreation(): Promise<never> {
    return this.fail();
  }
  async startLinkExisting(): Promise<never> {
    return this.fail();
  }
  async verifyOtp(): Promise<never> {
    return this.fail();
  }
  async requestConsent(): Promise<never> {
    return this.fail();
  }
}

// ---------------------------------------------------------------- Speech-to-text (sections 46, 62)
export interface SpeechToText {
  readonly name: string;
  transcribe(audio: Buffer, mimeType: string, lang?: string): Promise<string>;
}

export const MOCK_TRANSCRIPT =
  'Doctor: Good morning, how are you feeling today? Patient: My blood pressure readings at home have been around 150 over 90 this week and I get mild headaches in the morning. Doctor: Are you taking the amlodipine every day? Patient: Yes, every morning. Doctor: Please continue it, keep recording your BP daily and we will review in two weeks.';

export class MockSpeechToText implements SpeechToText {
  readonly name = 'mock';
  async transcribe(): Promise<string> {
    return MOCK_TRANSCRIPT;
  }
}

/** OpenAI Whisper-compatible `/audio/transcriptions` (multipart). */
export class WhisperCompatibleStt implements SpeechToText {
  readonly name = 'openai_whisper_compatible';
  constructor(
    private readonly baseUrl: string,
    private readonly apiKey: string,
    private readonly model: string,
    private readonly fetchImpl: FetchLike,
  ) {}
  async transcribe(audio: Buffer, mimeType: string, lang?: string): Promise<string> {
    const form = new FormData();
    form.append('file', new Blob([new Uint8Array(audio)], { type: mimeType }), `audio.${mimeType.split('/')[1] ?? 'webm'}`);
    form.append('model', this.model);
    if (lang) form.append('language', lang);
    try {
      const res = await this.fetchImpl(`${this.baseUrl.replace(/\/$/, '')}/audio/transcriptions`, {
        method: 'POST',
        headers: { authorization: `Bearer ${this.apiKey}` },
        body: form,
        signal: AbortSignal.timeout(60_000),
      });
      if (!res.ok) throw new HttpError(res.status, null, `HTTP ${res.status}`);
      const body = (await res.json()) as { text?: string };
      return body.text ?? '';
    } catch (err) {
      throw dependencyError('Speech-to-text', err);
    }
  }
}

/** Google Cloud Speech-to-Text v1 `speech:recognize` with an API key. */
export class GoogleStt implements SpeechToText {
  readonly name = 'google';
  constructor(
    private readonly apiKey: string,
    private readonly fetchImpl: FetchLike,
  ) {}
  async transcribe(audio: Buffer, mimeType: string, lang = 'en'): Promise<string> {
    const encoding = mimeType.includes('webm') ? 'WEBM_OPUS' : mimeType.includes('wav') ? 'LINEAR16' : 'ENCODING_UNSPECIFIED';
    try {
      const res = await requestJson<{ results?: Array<{ alternatives?: Array<{ transcript?: string }> }> }>(
        this.fetchImpl,
        `https://speech.googleapis.com/v1/speech:recognize?key=${encodeURIComponent(this.apiKey)}`,
        {
          method: 'POST',
          timeoutMs: 60_000,
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ config: { encoding, languageCode: `${lang}-IN`, enableAutomaticPunctuation: true }, audio: { content: audio.toString('base64') } }),
        },
      );
      return (res.results ?? []).map((r) => r.alternatives?.[0]?.transcript ?? '').join(' ').trim();
    } catch (err) {
      throw dependencyError('Speech-to-text', err);
    }
  }
}

export class DisabledStt implements SpeechToText {
  readonly name = 'disabled';
  async transcribe(): Promise<never> {
    throw errors.dependency('Speech-to-text is not configured');
  }
}

// ---------------------------------------------------------------- Maps (section 48)
export interface MapsProvider {
  readonly name: 'haversine' | 'google';
  /** Distance (km) and travel time (minutes) from one origin to each destination. */
  distances(origin: { lat: number; lng: number }, dests: Array<{ lat: number; lng: number }>): Promise<Array<{ km: number; minutes: number }>>;
}

export class HaversineMaps implements MapsProvider {
  readonly name = 'haversine' as const;
  constructor(private readonly speedKmh: number) {}
  async distances(origin: { lat: number; lng: number }, dests: Array<{ lat: number; lng: number }>) {
    return dests.map((d) => {
      const km = haversineKm(origin.lat, origin.lng, d.lat, d.lng);
      return { km: Math.round(km * 10) / 10, minutes: Math.round((km / this.speedKmh) * 60) };
    });
  }
}

/** Google Distance Matrix API; falls back to the haversine estimate on errors. */
export class GoogleMaps implements MapsProvider {
  readonly name = 'google' as const;
  constructor(
    private readonly apiKey: string,
    private readonly fallback: HaversineMaps,
    private readonly fetchImpl: FetchLike,
  ) {}
  async distances(origin: { lat: number; lng: number }, dests: Array<{ lat: number; lng: number }>) {
    if (!dests.length) return [];
    try {
      const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${origin.lat},${origin.lng}&destinations=${dests.map((d) => `${d.lat},${d.lng}`).join('|')}&mode=driving&key=${encodeURIComponent(this.apiKey)}`;
      const res = await requestJson<{ rows?: Array<{ elements?: Array<{ status: string; distance?: { value: number }; duration?: { value: number } }> }> }>(this.fetchImpl, url, { timeoutMs: 5000 });
      const els = res.rows?.[0]?.elements ?? [];
      const fb = await this.fallback.distances(origin, dests);
      return dests.map((_, i) => {
        const e = els[i];
        return e?.status === 'OK' && e.distance && e.duration ? { km: Math.round(e.distance.value / 100) / 10, minutes: Math.round(e.duration.value / 60) } : fb[i];
      });
    } catch {
      return this.fallback.distances(origin, dests);
    }
  }
}

// ---------------------------------------------------------------- container
export interface Partners {
  whatsapp: WhatsAppAdapter;
  lab: LabPartner;
  ambulance: AmbulancePartner;
  abdm: AbdmGatewayV3;
  stt: SpeechToText;
  maps: MapsProvider;
}

export function createPartners(c: Config, fetchImpl: FetchLike, quiet: boolean, overrides: Partial<Partners> = {}): Partners {
  const haversine = new HaversineMaps(c.ROUTE_SPEED_KMH);
  return {
    whatsapp: overrides.whatsapp ?? (c.WHATSAPP_PROVIDER === 'meta' ? new MetaWhatsApp(c, fetchImpl) : c.WHATSAPP_PROVIDER === 'mock' ? new MockWhatsApp(quiet) : new DisabledWhatsApp()),
    lab:
      overrides.lab ??
      (c.LAB_PARTNER === 'http' && c.LAB_PARTNER_BASE_URL && c.LAB_PARTNER_API_KEY
        ? new HttpLabPartner(c.LAB_PARTNER_NAME, c.LAB_PARTNER_BASE_URL, c.LAB_PARTNER_API_KEY, fetchImpl)
        : c.LAB_PARTNER === 'mock'
          ? new MockLabPartner(c.LAB_PARTNER_NAME)
          : new DisabledLabPartner()),
    ambulance:
      overrides.ambulance ??
      (c.AMBULANCE_PARTNER === 'http' && c.AMBULANCE_PARTNER_BASE_URL && c.AMBULANCE_PARTNER_API_KEY
        ? new HttpAmbulancePartner(c.AMBULANCE_PARTNER_NAME, c.AMBULANCE_PARTNER_BASE_URL, c.AMBULANCE_PARTNER_API_KEY, fetchImpl)
        : c.AMBULANCE_PARTNER === 'mock'
          ? new MockAmbulancePartner(c.AMBULANCE_PARTNER_NAME)
          : new DisabledAmbulancePartner()),
    abdm:
      overrides.abdm ??
      (c.ABDM_MODE === 'mock' ? new MockAbdmGateway() : c.ABDM_MODE === 'sandbox' || c.ABDM_MODE === 'production' ? new HttpAbdmGateway(c.ABDM_MODE, c, fetchImpl) : new DisabledAbdmGateway()),
    stt:
      overrides.stt ??
      (c.STT_PROVIDER === 'openai_whisper_compatible' && c.STT_API_KEY
        ? new WhisperCompatibleStt(c.STT_BASE_URL ?? 'https://api.openai.com/v1', c.STT_API_KEY, c.STT_MODEL, fetchImpl)
        : c.STT_PROVIDER === 'google' && c.STT_API_KEY
          ? new GoogleStt(c.STT_API_KEY, fetchImpl)
          : c.STT_PROVIDER === 'mock'
            ? new MockSpeechToText()
            : new DisabledStt()),
    maps: overrides.maps ?? (c.GOOGLE_MAPS_API_KEY ? new GoogleMaps(c.GOOGLE_MAPS_API_KEY, haversine, fetchImpl) : haversine),
  };
}
