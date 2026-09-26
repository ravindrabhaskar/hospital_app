import type { ApiErrorBody, AuthSession } from "./types";
import type { TokenStore } from "./session";

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: Record<string, unknown>;
  readonly correlationId: string | null;

  constructor(opts: {
    status: number;
    code: string;
    message: string;
    details?: Record<string, unknown>;
    correlationId?: string | null;
  }) {
    super(opts.message);
    this.name = "ApiError";
    this.status = opts.status;
    this.code = opts.code;
    this.details = opts.details ?? {};
    this.correlationId = opts.correlationId ?? null;
  }

  get isUnauthenticated() {
    return this.status === 401;
  }
  get isForbidden() {
    return this.status === 403;
  }
  get isNotFound() {
    return this.status === 404;
  }
  /** §22: the session has not passed staff MFA yet. */
  get isMfaRequired() {
    return this.status === 403 && this.code === "MFA_REQUIRED";
  }
}

/** Parse any non-2xx response into an ApiError, tolerating non-JSON bodies. */
export async function parseErrorResponse(res: Response): Promise<ApiError> {
  const headerCid = res.headers.get("X-Correlation-Id");
  let body: unknown = null;
  try {
    const text = await res.text();
    body = text ? JSON.parse(text) : null;
  } catch {
    body = null;
  }
  if (isApiErrorBody(body)) {
    return new ApiError({
      status: res.status,
      code: body.error.code,
      message: body.error.message || defaultMessage(res.status),
      details: body.error.details,
      correlationId: body.error.correlationId ?? headerCid,
    });
  }
  return new ApiError({
    status: res.status,
    code: defaultCode(res.status),
    message: defaultMessage(res.status),
    correlationId: headerCid,
  });
}

function isApiErrorBody(b: unknown): b is ApiErrorBody {
  return (
    typeof b === "object" &&
    b !== null &&
    "error" in b &&
    typeof (b as ApiErrorBody).error === "object" &&
    (b as ApiErrorBody).error !== null &&
    typeof (b as ApiErrorBody).error.code === "string"
  );
}

function defaultCode(status: number): string {
  switch (status) {
    case 400:
      return "VALIDATION_ERROR";
    case 401:
      return "UNAUTHENTICATED";
    case 403:
      return "FORBIDDEN";
    case 404:
      return "NOT_FOUND";
    case 409:
      return "CONFLICT";
    case 429:
      return "RATE_LIMITED";
    case 503:
      return "DEPENDENCY_UNAVAILABLE";
    default:
      return status >= 500 ? "INTERNAL" : "UNKNOWN";
  }
}

function defaultMessage(status: number): string {
  if (status === 401) return "Your session has expired. Please sign in again.";
  if (status === 403) return "You do not have permission to do this.";
  if (status === 404) return "Not found.";
  if (status === 429) return "Too many requests. Please wait and try again.";
  if (status >= 500) return "The server had a problem. Please try again.";
  return `Request failed (${status}).`;
}

export function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") return crypto.randomUUID();
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

export type QueryValue = string | number | boolean | null | undefined;

export interface RequestOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  query?: Record<string, QueryValue>;
  body?: unknown;
  /** Send an Idempotency-Key header. `true` generates a UUID; a string is used as-is. */
  idempotencyKey?: boolean | string;
  /** Skip Authorization (auth endpoints). */
  anonymous?: boolean;
  responseType?: "json" | "blob";
  signal?: AbortSignal;
}

export interface HttpClientOptions {
  baseUrl: string;
  tokens: TokenStore;
  fetchImpl?: typeof fetch;
  /** Called once refresh fails (or no refresh token): the app should route to /login. */
  onSessionExpired?: () => void;
  /** Called when any request returns 403 `MFA_REQUIRED` (§22): the app should route to the MFA step. */
  onMfaRequired?: () => void;
}

export function buildUrl(baseUrl: string, path: string, query?: Record<string, QueryValue>): string {
  const base = baseUrl.replace(/\/+$/, "");
  const p = path.startsWith("/") ? path : `/${path}`;
  const qs = new URLSearchParams();
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v === undefined || v === null || v === "") continue;
      qs.append(k, String(v));
    }
  }
  const s = qs.toString();
  return `${base}${p}${s ? `?${s}` : ""}`;
}

export class HttpClient {
  private refreshInFlight: Promise<boolean> | null = null;
  private readonly fetchImpl: typeof fetch;

  constructor(private readonly opts: HttpClientOptions) {
    this.fetchImpl = opts.fetchImpl ?? ((...args: Parameters<typeof fetch>) => fetch(...args));
  }

  get tokens() {
    return this.opts.tokens;
  }

  get baseUrl() {
    return this.opts.baseUrl;
  }

  async request<T>(path: string, options: RequestOptions = {}): Promise<T> {
    // Idempotency key is fixed for the whole logical request, including the retry after refresh.
    const idemKey =
      options.idempotencyKey === true ? newId() : typeof options.idempotencyKey === "string" ? options.idempotencyKey : null;

    let res = await this.send(path, options, idemKey);
    if (res.status === 401 && !options.anonymous) {
      const refreshed = await this.refreshOnce();
      if (!refreshed) {
        this.expire();
        throw await parseErrorResponse(res);
      }
      res = await this.send(path, options, idemKey);
      if (res.status === 401) {
        this.expire();
        throw await parseErrorResponse(res);
      }
    }
    if (!res.ok) {
      const err = await parseErrorResponse(res);
      if (err.isMfaRequired) this.opts.onMfaRequired?.();
      throw err;
    }
    if (options.responseType === "blob") return (await res.blob()) as T;
    if (res.status === 204) return undefined as T;
    const text = await res.text();
    return (text ? JSON.parse(text) : undefined) as T;
  }

  private send(path: string, options: RequestOptions, idemKey: string | null): Promise<Response> {
    const headers: Record<string, string> = {
      Accept: options.responseType === "blob" ? "*/*" : "application/json",
      "X-Correlation-Id": newId(),
    };
    let body: BodyInit | undefined;
    if (options.body instanceof FormData) {
      body = options.body;
    } else if (options.body !== undefined) {
      headers["Content-Type"] = "application/json";
      body = JSON.stringify(options.body);
    }
    if (idemKey) headers["Idempotency-Key"] = idemKey;
    if (!options.anonymous) {
      const s = this.opts.tokens.get();
      if (s) headers.Authorization = `Bearer ${s.accessToken}`;
    }
    return this.fetchImpl(buildUrl(this.opts.baseUrl, path, options.query), {
      method: options.method ?? "GET",
      headers,
      body,
      signal: options.signal,
    });
  }

  /** Refresh the session. Concurrent 401s share a single refresh call. */
  refreshOnce(): Promise<boolean> {
    if (!this.refreshInFlight) {
      this.refreshInFlight = this.doRefresh().finally(() => {
        this.refreshInFlight = null;
      });
    }
    return this.refreshInFlight;
  }

  private async doRefresh(): Promise<boolean> {
    const s = this.opts.tokens.get();
    if (!s?.refreshToken) return false;
    try {
      const res = await this.fetchImpl(buildUrl(this.opts.baseUrl, "/auth/refresh"), {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-Correlation-Id": newId() },
        body: JSON.stringify({ refreshToken: s.refreshToken }),
      });
      if (!res.ok) return false;
      const auth = (await res.json()) as AuthSession;
      this.opts.tokens.setFromAuth(auth);
      return true;
    } catch {
      return false;
    }
  }

  private expire() {
    this.opts.tokens.clear();
    this.opts.onSessionExpired?.();
  }
}
