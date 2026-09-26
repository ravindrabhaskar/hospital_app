import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import type { AuthSession, DeletionRequest, Me, Role } from "@/lib/api/types";
import { ApiError } from "@/lib/api/http";
import { AccountDeletionFlow, normalizePhone, type DeletionApi } from "./account-deletion";

function auth(roles: Role[]): AuthSession {
  const user: Me = {
    id: "u9",
    phone: "+919800000001",
    name: "Ramesh",
    email: null,
    roles,
    language: "en",
    selfPatientId: "pt1",
    onboardingComplete: true,
    mfaRequired: false,
    providerId: null,
  };
  return { accessToken: "a", refreshToken: "r", expiresIn: 900, user };
}

const scheduled: DeletionRequest = {
  id: "d1",
  status: "scheduled",
  reason: null,
  requestedAt: "2026-09-26T04:00:00.000Z",
  scheduledFor: "2026-10-03T04:00:00.000Z",
  completedAt: null,
};

function makeApi(overrides: Partial<DeletionApi> = {}): DeletionApi {
  return {
    requestOtp: vi.fn().mockResolvedValue({ requestId: "q", expiresAt: "2026-09-26T04:05:00.000Z", devOtp: "123456" }),
    verifyOtp: vi.fn().mockResolvedValue(auth(["patient"])),
    getRequest: vi.fn().mockResolvedValue(null),
    schedule: vi.fn().mockResolvedValue(scheduled),
    cancel: vi.fn().mockResolvedValue({ ...scheduled, status: "cancelled" }),
    logout: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

async function signIn(api: DeletionApi) {
  render(<AccountDeletionFlow api={api} />);
  fireEvent.change(screen.getByLabelText(/mobile number/i), { target: { value: "98000 00001" } });
  fireEvent.click(screen.getByRole("button", { name: /send otp/i }));
  expect(await screen.findByText(/dev otp: 123456/i)).toBeInTheDocument();
  fireEvent.change(screen.getByLabelText(/one-time code/i), { target: { value: "123456" } });
  fireEvent.click(screen.getByRole("button", { name: /^verify$/i }));
}

describe("Account deletion page", () => {
  it("normalises bare Indian mobile numbers", () => {
    expect(normalizePhone("98000 00001")).toBe("+919800000001");
    expect(normalizePhone("+919800000001")).toBe("+919800000001");
  });

  it("a patient-only account with no request can schedule deletion, then is signed out", async () => {
    const api = makeApi();
    await signIn(api);
    expect(api.requestOtp).toHaveBeenCalledWith("+919800000001");
    expect(await screen.findByText(/no deletion is scheduled/i)).toBeInTheDocument();
    const btn = screen.getByRole("button", { name: /schedule account deletion/i });
    expect(btn).toBeDisabled();
    fireEvent.change(screen.getByLabelText(/reason/i), { target: { value: "Not using it" } });
    fireEvent.click(screen.getByLabelText(/i understand/i));
    fireEvent.click(btn);
    expect(await screen.findByRole("heading", { name: /deletion scheduled/i })).toBeInTheDocument();
    expect(api.schedule).toHaveBeenCalledWith("Not using it");
    expect(api.logout).toHaveBeenCalled();
    expect(screen.getByText(/signed out of this page/i)).toBeInTheDocument();
  });

  it("shows an existing scheduled request and lets the user cancel it", async () => {
    const api = makeApi({ getRequest: vi.fn().mockResolvedValue(scheduled) });
    await signIn(api);
    expect(await screen.findByText(/deletion scheduled/i)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: /cancel deletion request/i }));
    expect(await screen.findByRole("heading", { name: /deletion cancelled/i })).toBeInTheDocument();
    expect(api.cancel).toHaveBeenCalled();
    expect(api.logout).toHaveBeenCalled();
  });

  it("offers a new request after a cancelled one", async () => {
    const api = makeApi({ getRequest: vi.fn().mockResolvedValue({ ...scheduled, status: "cancelled" }) });
    await signIn(api);
    expect(await screen.findByText(/was cancelled/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /schedule account deletion/i })).toBeInTheDocument();
  });

  it("staff accounts are told to contact their admin and are signed out", async () => {
    const api = makeApi({ verifyOtp: vi.fn().mockResolvedValue(auth(["doctor", "patient"])) });
    await signIn(api);
    expect(await screen.findByRole("heading", { name: /staff accounts cannot be deleted here/i })).toBeInTheDocument();
    expect(api.logout).toHaveBeenCalled();
    expect(api.getRequest).not.toHaveBeenCalled();
  });

  it("shows API errors (e.g. a wrong OTP) without leaving the step", async () => {
    const api = makeApi({ verifyOtp: vi.fn().mockRejectedValue(new ApiError({ status: 400, code: "VALIDATION_ERROR", message: "Invalid OTP" })) });
    await signIn(api);
    expect(await screen.findByText("Invalid OTP")).toBeInTheDocument();
    await waitFor(() => expect(screen.getByLabelText(/one-time code/i)).toBeInTheDocument());
  });
});
