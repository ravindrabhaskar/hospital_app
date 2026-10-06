import { describe, expect, it, vi } from "vitest";
import { ApiError, HttpClient, buildUrl, parseErrorResponse } from "./http";
import { TokenStore } from "./session";
import { createEndpoints } from "./endpoints";
import type { AuthSession, Me } from "./types";

const BASE = "http://api.test/api/v1";

const me: Me = {
  id: "u1",
  phone: "+919800000101",
  name: "Dr. Ananya Rao",
  email: null,
  roles: ["doctor"],
  language: "en",
  selfPatientId: null,
  onboardingComplete: true,
  mfaRequired: true,
  providerId: "p1",
};

function memoryStorage() {
  const m = new Map<string, string>();
  return {
    getItem: (k: string) => m.get(k) ?? null,
    setItem: (k: string, v: string) => void m.set(k, v),
    removeItem: (k: string) => void m.delete(k),
    raw: m,
  };
}

function json(status: number, body: unknown, headers: Record<string, string> = {}) {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

function setup(initial: { access?: string; refresh?: string } = { access: "old-access", refresh: "old-refresh" }) {
  const storage = memoryStorage();
  const tokens = new TokenStore(storage);
  if (initial.access) {
    tokens.set({ accessToken: initial.access, refreshToken: initial.refresh ?? "", expiresAt: Date.now() + 60_000, user: me });
  }
  const fetchMock = vi.fn<typeof fetch>();
  const onSessionExpired = vi.fn();
  const http = new HttpClient({ baseUrl: BASE, tokens, fetchImpl: fetchMock, onSessionExpired });
  return { http, tokens, fetchMock, onSessionExpired, storage, api: createEndpoints(http) };
}

const refreshed: AuthSession = { accessToken: "new-access", refreshToken: "new-refresh", expiresIn: 900, user: me };

function headersOf(call: Parameters<typeof fetch>) {
  return (call[1]?.headers ?? {}) as Record<string, string>;
}

describe("buildUrl", () => {
  it("joins base and path and drops empty query values", () => {
    expect(buildUrl(`${BASE}/`, "/ops/home-visits", { status: "unassigned", cursor: undefined, q: "", limit: 20 })).toBe(
      `${BASE}/ops/home-visits?status=unassigned&limit=20`,
    );
  });
});

describe("parseErrorResponse", () => {
  it("parses the contract error envelope", async () => {
    const err = await parseErrorResponse(
      json(409, { error: { code: "INVALID_STATE_TRANSITION", message: "Cannot go from NEW to RESOLVED", details: { from: "NEW" }, correlationId: "cid-1" } }),
    );
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(409);
    expect(err.code).toBe("INVALID_STATE_TRANSITION");
    expect(err.message).toBe("Cannot go from NEW to RESOLVED");
    expect(err.details).toEqual({ from: "NEW" });
    expect(err.correlationId).toBe("cid-1");
  });

  it("falls back to a status-derived code for non-JSON bodies and uses the echoed correlation header", async () => {
    const err = await parseErrorResponse(new Response("<html>Bad gateway</html>", { status: 503, headers: { "X-Correlation-Id": "hdr-cid" } }));
    expect(err.code).toBe("DEPENDENCY_UNAVAILABLE");
    expect(err.correlationId).toBe("hdr-cid");
    expect(err.message).toMatch(/server/i);
  });

  it("maps 403 to FORBIDDEN when the body has no envelope", async () => {
    const err = await parseErrorResponse(json(403, { message: "nope" }));
    expect(err.code).toBe("FORBIDDEN");
    expect(err.isForbidden).toBe(true);
  });
});

describe("HttpClient", () => {
  it("sends bearer token, correlation id and JSON body", async () => {
    const { api, fetchMock } = setup();
    fetchMock.mockResolvedValueOnce(json(200, { id: "x" }));
    await api.clinician.aiFeedback({ aiInteractionId: "ai-1", decision: "accept", note: "" });
    const call = fetchMock.mock.calls[0]!;
    expect(call[0]).toBe(`${BASE}/clinician/ai-feedback`);
    expect(call[1]?.method).toBe("POST");
    const h = headersOf(call);
    expect(h.Authorization).toBe("Bearer old-access");
    expect(h["X-Correlation-Id"]).toBeTruthy();
    expect(h["Content-Type"]).toBe("application/json");
    expect(JSON.parse(String(call[1]?.body))).toEqual({ aiInteractionId: "ai-1", decision: "accept", note: "" });
  });

  it("does not send Authorization on anonymous auth endpoints", async () => {
    const { api, fetchMock } = setup();
    fetchMock.mockResolvedValueOnce(json(200, { requestId: "r", expiresAt: "2026-09-26T09:30:00.000Z", devOtp: "123456" }));
    const res = await api.auth.requestOtp("+919800000101");
    expect(res.devOtp).toBe("123456");
    expect(headersOf(fetchMock.mock.calls[0]!).Authorization).toBeUndefined();
  });

  it("returns undefined for 204 responses", async () => {
    const { http, fetchMock } = setup();
    fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }));
    await expect(http.request("/notifications/read-all", { method: "POST" })).resolves.toBeUndefined();
  });

  it("on 401 refreshes once, stores the rotated tokens and retries with the new token and same idempotency key", async () => {
    const { http, fetchMock, tokens, storage } = setup();
    fetchMock
      .mockResolvedValueOnce(json(401, { error: { code: "UNAUTHENTICATED", message: "expired" } }))
      .mockResolvedValueOnce(json(200, refreshed))
      .mockResolvedValueOnce(json(201, { ok: true }));

    const res = await http.request<{ ok: boolean }>("/care-episodes", { method: "POST", body: { a: 1 }, idempotencyKey: true });
    expect(res).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(3);

    const [first, refresh, retry] = fetchMock.mock.calls;
    expect(refresh![0]).toBe(`${BASE}/auth/refresh`);
    expect(JSON.parse(String(refresh![1]?.body))).toEqual({ refreshToken: "old-refresh" });
    expect(headersOf(retry!).Authorization).toBe("Bearer new-access");
    expect(headersOf(first!)["Idempotency-Key"]).toBeTruthy();
    expect(headersOf(retry!)["Idempotency-Key"]).toBe(headersOf(first!)["Idempotency-Key"]);

    expect(tokens.get()?.refreshToken).toBe("new-refresh");
    expect(JSON.parse(storage.raw.get("cc.session.v1")!).accessToken).toBe("new-access");
  });

  it("logs out when refresh fails", async () => {
    const { http, fetchMock, tokens, onSessionExpired } = setup();
    fetchMock
      .mockResolvedValueOnce(json(401, { error: { code: "UNAUTHENTICATED", message: "expired" } }))
      .mockResolvedValueOnce(json(401, { error: { code: "UNAUTHENTICATED", message: "refresh revoked" } }));

    await expect(http.request("/me")).rejects.toMatchObject({ status: 401, code: "UNAUTHENTICATED" });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(tokens.get()).toBeNull();
    expect(onSessionExpired).toHaveBeenCalledTimes(1);
  });

  it("logs out (without looping) when the retried request is still 401", async () => {
    const { http, fetchMock, tokens, onSessionExpired } = setup();
    fetchMock
      .mockResolvedValueOnce(json(401, {}))
      .mockResolvedValueOnce(json(200, refreshed))
      .mockResolvedValueOnce(json(401, {}));
    await expect(http.request("/me")).rejects.toBeInstanceOf(ApiError);
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(tokens.get()).toBeNull();
    expect(onSessionExpired).toHaveBeenCalledTimes(1);
  });

  it("logs out immediately when there is no refresh token", async () => {
    const { http, fetchMock, onSessionExpired } = setup({ access: "a", refresh: "" });
    fetchMock.mockResolvedValueOnce(json(401, {}));
    await expect(http.request("/me")).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(onSessionExpired).toHaveBeenCalledTimes(1);
  });

  it("shares a single refresh between concurrent 401s", async () => {
    const { http, fetchMock } = setup();
    let refreshCalls = 0;
    fetchMock.mockImplementation(async (input, init) => {
      const url = String(input);
      const auth = (init?.headers as Record<string, string>).Authorization;
      if (url.endsWith("/auth/refresh")) {
        refreshCalls++;
        await new Promise((r) => setTimeout(r, 5));
        return json(200, refreshed);
      }
      return auth === "Bearer new-access" ? json(200, { url }) : json(401, {});
    });
    const [a, b] = await Promise.all([http.request<{ url: string }>("/ops/overview"), http.request<{ url: string }>("/ops/incidents")]);
    expect(a.url).toContain("/ops/overview");
    expect(b.url).toContain("/ops/incidents");
    expect(refreshCalls).toBe(1);
  });

  it("does not attempt refresh for 403 and surfaces the API error", async () => {
    const { http, fetchMock, onSessionExpired } = setup();
    fetchMock.mockResolvedValueOnce(json(403, { error: { code: "FORBIDDEN", message: "ops_admin only" } }));
    await expect(http.request("/payments/p1/refund", { method: "POST", body: { reason: "x" } })).rejects.toMatchObject({
      status: 403,
      code: "FORBIDDEN",
      message: "ops_admin only",
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(onSessionExpired).not.toHaveBeenCalled();
  });

  it("fetches record files as blobs with auth", async () => {
    const { api, fetchMock } = setup();
    fetchMock.mockResolvedValueOnce(new Response(new Blob(["%PDF"], { type: "application/pdf" }), { status: 200 }));
    const blob = await api.records.file("rec-1");
    expect(blob).toBeInstanceOf(Blob);
    expect(fetchMock.mock.calls[0]![0]).toBe(`${BASE}/records/rec-1/file`);
    expect(headersOf(fetchMock.mock.calls[0]!).Authorization).toBe("Bearer old-access");
  });
});

describe("TokenStore", () => {
  it("hydrates from storage and clears it on logout", () => {
    const storage = memoryStorage();
    new TokenStore(storage).setFromAuth(refreshed);
    const second = new TokenStore(storage);
    expect(second.get()?.accessToken).toBe("new-access");
    second.clear();
    expect(storage.raw.size).toBe(0);
  });
});

describe("approve program template (QA B5)", () => {
  it("POSTs the approver name, registration and version as the body", async () => {
    const { api, fetchMock } = setup();
    fetchMock.mockResolvedValueOnce(json(200, { code: "hf", version: "1.1", status: "approved" }));
    await api.adminPrograms.approve("hf", { approverName: "Dr Asha Rao", approverRegistration: "KMC-1234", version: "1.1" });
    const call = fetchMock.mock.calls[0]!;
    expect(call[0]).toBe(`${BASE}/admin/care-programs/templates/hf/approve`);
    expect(call[1]?.method).toBe("POST");
    expect(JSON.parse(String(call[1]?.body))).toEqual({ approverName: "Dr Asha Rao", approverRegistration: "KMC-1234", version: "1.1" });
  });
});

describe("ApiError.userMessage (QA B24)", () => {
  it("expands a generic validation failure with the API's field issues", () => {
    const e = new ApiError({
      status: 400,
      code: "VALIDATION_ERROR",
      message: "Request validation failed",
      details: { issues: [{ path: "description", message: "String must contain at least 1 character(s)" }, { path: "defaultThresholds.0.value", message: "Required" }] },
    });
    expect(e.fieldIssues).toHaveLength(2);
    expect(e.userMessage).toBe("Please check: Description: String must contain at least 1 character(s); Default thresholds 1 value: Required");
  });

  it("keeps the plain message when there are no issues", () => {
    expect(new ApiError({ status: 409, code: "CONFLICT", message: "Already exists" }).userMessage).toBe("Already exists");
    expect(new ApiError({ status: 400, code: "VALIDATION_ERROR", message: "validTo must be after validFrom" }).userMessage).toBe("validTo must be after validFrom");
  });
});
