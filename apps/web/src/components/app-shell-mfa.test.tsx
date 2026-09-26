import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { act, render, screen } from "@testing-library/react";
import type { Me } from "@/lib/api/types";
import { HttpClient } from "@/lib/api/http";
import { TokenStore } from "@/lib/api/session";
import { IDLE_TIMEOUT_MS, IDLE_WARNING_MS } from "@/lib/idle";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, push: vi.fn() }),
  usePathname: () => "/ops/tasks",
}));

let user: Me;
let mfaSkipped = false;
const signOut = vi.fn();
vi.mock("@/lib/auth", () => ({
  useAuth: () => ({
    session: { accessToken: "a", refreshToken: "r", expiresAt: Date.now() + 1000, user, mfaSkipped },
    user,
    roles: user.roles,
    signIn: vi.fn(),
    signOut,
  }),
}));

import { IdleWatcher, PortalShell } from "./app-shell";

const coordinator: Me = {
  id: "u1",
  phone: "+919800000301",
  name: "Meera",
  email: null,
  roles: ["coordinator"],
  language: "en",
  selfPatientId: null,
  onboardingComplete: true,
  mfaRequired: true,
  mfaEnrolled: true,
  mfaVerified: false,
  providerId: null,
};

describe("MFA_REQUIRED redirect", () => {
  beforeEach(() => {
    replace.mockReset();
    mfaSkipped = false;
  });

  it("sends an unverified staff session to the MFA step and hides portal content", () => {
    user = coordinator;
    render(<PortalShell><p>secret page</p></PortalShell>);
    expect(replace).toHaveBeenCalledWith("/mfa?next=%2Fops%2Ftasks");
    expect(screen.queryByText("secret page")).not.toBeInTheDocument();
  });

  it("lets a verified session through", () => {
    user = { ...coordinator, mfaVerified: true };
    render(<PortalShell><p>secret page</p></PortalShell>);
    expect(replace).not.toHaveBeenCalled();
    expect(screen.getByText("secret page")).toBeInTheDocument();
  });

  it("respects an explicit skip when the server does not enforce MFA", () => {
    user = coordinator;
    mfaSkipped = true;
    render(<PortalShell><p>secret page</p></PortalShell>);
    expect(screen.getByText("secret page")).toBeInTheDocument();
  });

  it("the HTTP client reports 403 MFA_REQUIRED (and only that 403)", async () => {
    const onMfaRequired = vi.fn();
    const responses = [
      new Response(JSON.stringify({ error: { code: "MFA_REQUIRED", message: "MFA required", correlationId: "c1" } }), { status: 403 }),
      new Response(JSON.stringify({ error: { code: "FORBIDDEN", message: "No", correlationId: "c2" } }), { status: 403 }),
    ];
    const http = new HttpClient({
      baseUrl: "http://api.test/api/v1",
      tokens: new TokenStore(null),
      fetchImpl: vi.fn(async () => responses.shift()!),
      onMfaRequired,
    });
    await expect(http.request("/ops/overview")).rejects.toMatchObject({ code: "MFA_REQUIRED", isMfaRequired: true });
    expect(onMfaRequired).toHaveBeenCalledTimes(1);
    await expect(http.request("/admin/users")).rejects.toMatchObject({ code: "FORBIDDEN" });
    expect(onMfaRequired).toHaveBeenCalledTimes(1);
  });
});

describe("IdleWatcher", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    sessionStorage.clear();
  });
  afterEach(() => vi.useRealTimers());

  it("warns at 13 minutes and signs out at 15", () => {
    const onTimeout = vi.fn();
    render(<IdleWatcher onTimeout={onTimeout} />);
    act(() => vi.advanceTimersByTime(IDLE_WARNING_MS + 1000));
    expect(screen.getByRole("dialog", { name: /still there/i })).toBeInTheDocument();
    expect(onTimeout).not.toHaveBeenCalled();
    act(() => vi.advanceTimersByTime(IDLE_TIMEOUT_MS - IDLE_WARNING_MS));
    expect(onTimeout).toHaveBeenCalledTimes(1);
  });

  it("'Stay signed in' resets the timer", () => {
    const onTimeout = vi.fn();
    render(<IdleWatcher onTimeout={onTimeout} />);
    act(() => vi.advanceTimersByTime(IDLE_WARNING_MS + 1000));
    act(() => screen.getByRole("button", { name: /stay signed in/i }).click());
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    act(() => vi.advanceTimersByTime(IDLE_TIMEOUT_MS - 60_000));
    expect(onTimeout).not.toHaveBeenCalled();
  });
});
