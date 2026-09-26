import type { FetchLike } from '../src/lib/http.js';

export interface RecordedCall {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
}

type Handler = (call: RecordedCall) => { status?: number; body?: unknown } | Promise<{ status?: number; body?: unknown }>;

/** Injected fetch: records every call and answers from `handler`. No network access. */
export function fakeFetch(handler: Handler): { fetch: FetchLike; calls: RecordedCall[] } {
  const calls: RecordedCall[] = [];
  const fetch: FetchLike = async (input, init = {}) => {
    const headers: Record<string, string> = {};
    new Headers(init.headers as any).forEach((v, k) => (headers[k] = v));
    const call: RecordedCall = { url: String(input), method: init.method ?? 'GET', headers, body: typeof init.body === 'string' ? init.body : '' };
    calls.push(call);
    const r = await handler(call);
    const payload = r.body === undefined ? '' : typeof r.body === 'string' ? r.body : JSON.stringify(r.body);
    return new Response(payload, { status: r.status ?? 200, headers: { 'content-type': 'application/json' } });
  };
  return { fetch, calls };
}

/** multipart/form-data body for app.inject uploads. */
export function multipart(fields: Record<string, string>, file: { field: string; name: string; data: Buffer; type: string }) {
  const boundary = '----ccfk' + Math.random().toString(16).slice(2);
  const parts: Buffer[] = Object.entries(fields).map(([k, v]) => Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`));
  parts.push(
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${file.field}"; filename="${file.name}"\r\nContent-Type: ${file.type}\r\n\r\n`),
    file.data,
    Buffer.from(`\r\n--${boundary}--\r\n`),
  );
  return { body: Buffer.concat(parts), headers: { 'content-type': `multipart/form-data; boundary=${boundary}` } };
}
