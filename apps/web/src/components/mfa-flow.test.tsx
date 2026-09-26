import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import type { AuthSession, Me } from "@/lib/api/types";
import { ApiError } from "@/lib/api/http";
import { MfaFlow, type MfaApi } from "./mfa-flow";

const baseUser: Me = {
  id: "u1",
  phone: "+919800000101",
  name: "Dr. Ananya Rao",
  email: null,
  roles: ["doctor"],
  language: "en",
  selfPatientId: null,
  onboardingComplete: true,
  mfaRequired: true,
  mfaEnrolled: false,
  mfaVerified: false,
  providerId: "p1",
};
const verifiedSession: AuthSession = {
  accessToken: "a2",
  refreshToken: "r2",
  expiresIn: 900,
  user: { ...baseUser, mfaEnrolled: true, mfaVerified: true },
};
const codes = ["aaaa-1111", "bbbb-2222", "cccc-3333", "dddd-4444", "eeee-5555", "ffff-6666", "gggg-7777", "hhhh-8888", "iiii-9999", "jjjj-0000"];

function setup(user: Me, overrides: Partial<MfaApi> = {}) {
  const api: MfaApi = {
    enroll: vi.fn().mockResolvedValue({ secret: "JBSWY3DPEHPK3PXP", otpauthUrl: "otpauth://totp/x", qrSvg: "<svg xmlns='http://www.w3.org/2000/svg'></svg>" }),
    confirm: vi.fn().mockResolvedValue({ recoveryCodes: codes, session: verifiedSession }),
    verify: vi.fn().mockResolvedValue(verifiedSession),
    ...overrides,
  };
  const onSession = vi.fn();
  const onDone = vi.fn();
  render(<MfaFlow user={user} api={api} onSession={onSession} onDone={onDone} onSignOut={vi.fn()} />);
  return { api, onSession, onDone };
}

describe("MfaFlow", () => {
  it("enrols: QR as <img> data URI + secret → confirm → recovery codes shown once → continue", async () => {
    const { api, onSession, onDone } = setup(baseUser);
    fireEvent.click(screen.getByRole("button", { name: /set up authenticator app/i }));

    const img = await screen.findByRole("img", { name: /qr code/i });
    expect(img.getAttribute("src")).toMatch(/^data:image\/svg\+xml;base64,/);
    expect(screen.getByTestId("mfa-secret")).toHaveTextContent("JBSW Y3DP EHPK 3PXP");

    fireEvent.change(screen.getByLabelText(/6-digit code/i), { target: { value: "123456" } });
    fireEvent.click(screen.getByRole("button", { name: /confirm and turn on/i }));

    const list = await screen.findByRole("list", { name: /recovery codes/i });
    expect(list.querySelectorAll("li")).toHaveLength(10);
    expect(api.confirm).toHaveBeenCalledWith("123456");
    expect(onSession).toHaveBeenCalledWith(verifiedSession);

    const cont = screen.getByRole("button", { name: /continue to portal/i });
    expect(cont).toBeDisabled();
    fireEvent.click(screen.getByLabelText(/i have saved these recovery codes/i));
    expect(cont).toBeEnabled();
    fireEvent.click(cont);
    await waitFor(() => expect(onDone).toHaveBeenCalled());
  });

  it("rejects a malformed code without calling the API", async () => {
    const { api } = setup(baseUser);
    fireEvent.click(screen.getByRole("button", { name: /set up authenticator app/i }));
    await screen.findByRole("img", { name: /qr code/i });
    fireEvent.change(screen.getByLabelText(/6-digit code/i), { target: { value: "12ab" } });
    fireEvent.click(screen.getByRole("button", { name: /confirm and turn on/i }));
    expect(await screen.findByText(/enter the 6-digit code/i)).toBeInTheDocument();
    expect(api.confirm).not.toHaveBeenCalled();
  });

  it("switches to verification when enrol answers CONFLICT", async () => {
    setup(baseUser, { enroll: vi.fn().mockRejectedValue(new ApiError({ status: 409, code: "CONFLICT", message: "Already enrolled" })) });
    fireEvent.click(screen.getByRole("button", { name: /set up authenticator app/i }));
    expect(await screen.findByRole("heading", { name: /^two-step verification$/i })).toBeInTheDocument();
  });

  it("verifies an enrolled user with a TOTP code", async () => {
    const { api, onSession, onDone } = setup({ ...baseUser, mfaEnrolled: true });
    fireEvent.change(screen.getByLabelText(/authenticator code/i), { target: { value: "654321" } });
    fireEvent.click(screen.getByRole("button", { name: /^verify$/i }));
    await waitFor(() => expect(onDone).toHaveBeenCalled());
    expect(api.verify).toHaveBeenCalledWith({ code: "654321" });
    expect(onSession).toHaveBeenCalledWith(verifiedSession);
  });

  it("verifies with a recovery code and shows API errors", async () => {
    const verify = vi
      .fn()
      .mockRejectedValueOnce(new ApiError({ status: 429, code: "RATE_LIMITED", message: "Too many attempts" }))
      .mockResolvedValueOnce(verifiedSession);
    const { onDone } = setup({ ...baseUser, mfaEnrolled: true }, { verify });
    fireEvent.click(screen.getByRole("button", { name: /use a recovery code instead/i }));
    fireEvent.change(screen.getByLabelText(/recovery code/i), { target: { value: "aaaa-1111" } });
    fireEvent.click(screen.getByRole("button", { name: /^verify$/i }));
    expect(await screen.findByText("Too many attempts")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: /^verify$/i }));
    await waitFor(() => expect(onDone).toHaveBeenCalled());
    expect(verify).toHaveBeenLastCalledWith({ recoveryCode: "aaaa-1111" });
  });

  it("finishes immediately when no MFA step is needed", async () => {
    const { onDone } = setup({ ...baseUser, mfaEnrolled: true, mfaVerified: true });
    await waitFor(() => expect(onDone).toHaveBeenCalled());
  });
});
