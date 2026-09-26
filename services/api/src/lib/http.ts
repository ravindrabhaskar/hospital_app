/** Injectable fetch (tests pass a fake; production uses the global undici fetch). */
export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export const defaultFetch: FetchLike = (input, init) => globalThis.fetch(input, init);

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly body: unknown,
    message: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

/**
 * Call an external JSON API with a timeout. Non-2xx responses throw HttpError carrying the parsed body.
 * Never log the request body or auth headers: they carry credentials / OTPs.
 */
export async function requestJson<T = any>(
  fetchImpl: FetchLike,
  url: string,
  init: RequestInit & { timeoutMs?: number } = {},
): Promise<T> {
  const { timeoutMs = 10_000, ...rest } = init;
  const res = await fetchImpl(url, { ...rest, signal: AbortSignal.timeout(timeoutMs) });
  const text = await res.text();
  let body: unknown;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  if (!res.ok) throw new HttpError(res.status, body, `HTTP ${res.status} from ${new URL(url).host}`);
  return body as T;
}

export const basicAuth = (user: string, pass: string): string => `Basic ${Buffer.from(`${user}:${pass}`).toString('base64')}`;
