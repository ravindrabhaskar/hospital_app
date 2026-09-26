"use client";

import { useMemo, useState, type FormEvent } from "react";
import { CalendarX2, KeyRound, LogOut, Smartphone, Trash2, Undo2 } from "lucide-react";
import { API_BASE_URL } from "@/lib/api";
import { ApiError, HttpClient } from "@/lib/api/http";
import { TokenStore } from "@/lib/api/session";
import { createEndpoints } from "@/lib/api/endpoints";
import type { AuthSession, DeletionRequest, OtpRequestResponse } from "@/lib/api/types";
import { formatDateTime } from "@/lib/format";
import { STAFF_ROLES, hasAnyRole } from "@/lib/roles";
import { Badge, Button, Field, Input, Textarea, errorMessage } from "./ui";

/** Everything the deletion page needs from the API (§2, §23). Injected in tests. */
export interface DeletionApi {
  requestOtp: (phone: string) => Promise<OtpRequestResponse>;
  verifyOtp: (phone: string, otp: string) => Promise<AuthSession>;
  /** `null` when there is no request (404). */
  getRequest: () => Promise<DeletionRequest | null>;
  schedule: (reason?: string) => Promise<DeletionRequest>;
  cancel: () => Promise<DeletionRequest>;
  logout: () => Promise<void>;
}

/**
 * A private, memory-only API client: this page must work for patient-only accounts and must never
 * touch (or be blocked by) the staff portal session in sessionStorage.
 */
export function createDeletionApi(baseUrl: string = API_BASE_URL): DeletionApi {
  const tokens = new TokenStore(null);
  const http = new HttpClient({ baseUrl, tokens });
  const api = createEndpoints(http);
  return {
    requestOtp: (phone) => api.auth.requestOtp(phone),
    verifyOtp: async (phone, otp) => {
      const auth = await api.auth.verifyOtp({ phone, otp, deviceName: "CareCompanion account deletion page" });
      tokens.setFromAuth(auth);
      return auth;
    },
    getRequest: async () => {
      try {
        return await api.account.deletionRequest();
      } catch (e) {
        if (e instanceof ApiError && e.status === 404) return null;
        throw e;
      }
    },
    schedule: (reason) => api.account.requestDeletion(reason),
    cancel: () => api.account.cancelDeletion(),
    logout: async () => {
      const s = tokens.get();
      tokens.clear();
      if (s?.refreshToken) {
        try {
          await api.auth.logout(s.refreshToken);
        } catch {
          /* best effort */
        }
      }
    },
  };
}

export function normalizePhone(v: string): string {
  const compact = v.trim().replace(/[\s-]/g, "");
  return /^[6-9]\d{9}$/.test(compact) ? `+91${compact}` : compact;
}
const PHONE_RE = /^\+[1-9]\d{7,14}$/;

export type DeletionStep =
  | { kind: "phone" }
  | { kind: "otp"; phone: string; devOtp?: string }
  | { kind: "staff" }
  | { kind: "status"; phone: string; request: DeletionRequest | null }
  | { kind: "finished"; request: DeletionRequest };

export function AccountDeletionFlow({ api: injected }: { api?: DeletionApi }) {
  const api = useMemo(() => injected ?? createDeletionApi(), [injected]);
  const [step, setStep] = useState<DeletionStep>({ kind: "phone" });
  const [phone, setPhone] = useState("+91");
  const [otp, setOtp] = useState("");
  const [reason, setReason] = useState("");
  const [confirmed, setConfirmed] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const run = async (fn: () => Promise<void>) => {
    setError(null);
    setBusy(true);
    try {
      await fn();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  const onPhone = (e: FormEvent) => {
    e.preventDefault();
    const p = normalizePhone(phone);
    if (!PHONE_RE.test(p)) return setError("Enter your mobile number, e.g. 98xxxxxxxx or +9198xxxxxxxx.");
    void run(async () => {
      const res = await api.requestOtp(p);
      setOtp("");
      setStep({ kind: "otp", phone: p, devOtp: res.devOtp });
    });
  };

  const onOtp = (e: FormEvent) => {
    e.preventDefault();
    if (step.kind !== "otp") return;
    if (!/^\d{6}$/.test(otp.trim())) return setError("Enter the 6-digit code.");
    void run(async () => {
      const auth = await api.verifyOtp(step.phone, otp.trim());
      if (hasAnyRole(auth.user.roles, STAFF_ROLES)) {
        await api.logout();
        setStep({ kind: "staff" });
        return;
      }
      const request = await api.getRequest();
      setStep({ kind: "status", phone: step.phone, request });
    });
  };

  const schedule = () =>
    run(async () => {
      const request = await api.schedule(reason.trim() || undefined);
      await api.logout();
      setStep({ kind: "finished", request });
    });

  const cancel = () =>
    run(async () => {
      const request = await api.cancel();
      await api.logout();
      setStep({ kind: "finished", request });
    });

  const signOut = () =>
    run(async () => {
      await api.logout();
      setPhone("+91");
      setStep({ kind: "phone" });
    });

  const err = error && (
    <p role="alert" className="rounded-xl bg-rose-bg px-3 py-2 text-sm text-danger-dark">
      {error}
    </p>
  );

  return (
    <div className="rounded-[20px] border border-line bg-white p-5 shadow-[var(--shadow-card)] sm:p-6" aria-live="polite">
      {step.kind === "phone" && (
        <form onSubmit={onPhone} noValidate className="flex flex-col gap-4">
          <h2 className="text-lg font-semibold">Sign in to continue</h2>
          <p className="text-sm text-ink-muted">Use the mobile number registered with your CareCompanion account.</p>
          <Field label="Mobile number" required>
            {(id, d) => (
              <Input id={id} aria-describedby={d} type="tel" autoComplete="tel" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
            )}
          </Field>
          {err}
          <Button type="submit" loading={busy} icon={<Smartphone className="size-4" aria-hidden />}>
            Send OTP
          </Button>
        </form>
      )}

      {step.kind === "otp" && (
        <form onSubmit={onOtp} noValidate className="flex flex-col gap-4">
          <h2 className="text-lg font-semibold">Enter the code</h2>
          <p className="text-sm text-ink-muted">
            We sent a 6-digit code to <span className="font-medium text-ink">{step.phone}</span>.
          </p>
          {step.devOtp && (
            <p className="rounded-xl border border-dashed border-primary-light bg-mint-50 px-3 py-2 font-mono text-sm text-primary-dark">
              Dev OTP: {step.devOtp}
            </p>
          )}
          <Field label="One-time code" required>
            {(id, d) => (
              <Input
                id={id}
                aria-describedby={d}
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                className="tracking-[0.4em]"
                value={otp}
                onChange={(e) => setOtp(e.target.value)}
              />
            )}
          </Field>
          {err}
          <Button type="submit" loading={busy} icon={<KeyRound className="size-4" aria-hidden />}>
            Verify
          </Button>
          <Button variant="ghost" onClick={() => setStep({ kind: "phone" })}>
            Use a different number
          </Button>
        </form>
      )}

      {step.kind === "staff" && (
        <div role="alert" className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold">Staff accounts cannot be deleted here</h2>
          <p className="text-sm text-ink-muted">
            This number belongs to a CareCompanion staff account (doctor, coordinator or administrator). Please contact your
            administrator to close or disable it. You have been signed out.
          </p>
          <Button variant="secondary" onClick={() => setStep({ kind: "phone" })}>
            Back
          </Button>
        </div>
      )}

      {step.kind === "status" && (
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-lg font-semibold">Your account</h2>
            <span className="text-sm text-ink-muted">{step.phone}</span>
          </div>

          {step.request?.status === "scheduled" ? (
            <>
              <div className="rounded-xl bg-peach-bg p-3 text-sm text-peach-fg">
                <p className="flex items-center gap-2 font-semibold">
                  <CalendarX2 className="size-4" aria-hidden /> Deletion scheduled
                </p>
                <p>
                  Your account will be deleted on <strong>{formatDateTime(step.request.scheduledFor)} IST</strong>. Until then you can
                  cancel and keep using CareCompanion.
                </p>
                <p className="mt-1 text-xs">Requested {formatDateTime(step.request.requestedAt)}</p>
              </div>
              {err}
              <Button variant="secondary" loading={busy} onClick={() => void cancel()} icon={<Undo2 className="size-4" aria-hidden />}>
                Cancel deletion request
              </Button>
            </>
          ) : step.request?.status === "completed" ? (
            <p className="rounded-xl bg-mint-50 p-3 text-sm">
              This account was deleted on {formatDateTime(step.request.completedAt)} IST.
            </p>
          ) : (
            <>
              {step.request?.status === "cancelled" && (
                <p className="text-sm text-ink-muted">
                  <Badge tone="neutral">Cancelled</Badge> A previous request from {formatDateTime(step.request.requestedAt)} was cancelled.
                </p>
              )}
              <p className="text-sm">
                No deletion is scheduled. If you continue, your account is scheduled for deletion after the grace period, and you are
                signed out of this page.
              </p>
              <Field label="Reason (optional)" hint="Helps us improve. Please do not include health details.">
                {(id, d) => <Textarea id={id} aria-describedby={d} rows={2} maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />}
              </Field>
              <label className="flex items-start gap-2 text-sm">
                <input type="checkbox" className="mt-0.5 size-4 accent-[#0B5D45]" checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} />
                I understand that my account and personal data will be deleted after the grace period, except records the law requires
                CareCompanion to keep.
              </label>
              {err}
              <Button variant="danger" disabled={!confirmed} loading={busy} onClick={() => void schedule()} icon={<Trash2 className="size-4" aria-hidden />}>
                Schedule account deletion
              </Button>
            </>
          )}
          <Button variant="ghost" onClick={() => void signOut()} icon={<LogOut className="size-4" aria-hidden />}>
            Sign out
          </Button>
        </div>
      )}

      {step.kind === "finished" && (
        <div role="status" className="flex flex-col gap-3">
          {step.request.status === "scheduled" ? (
            <>
              <h2 className="text-lg font-semibold">Deletion scheduled</h2>
              <p className="text-sm">
                Your account will be deleted on <strong>{formatDateTime(step.request.scheduledFor)} IST</strong>. Changed your mind? Sign
                in again here before then and cancel the request.
              </p>
            </>
          ) : (
            <>
              <h2 className="text-lg font-semibold">Deletion cancelled</h2>
              <p className="text-sm">Your account will not be deleted. You can keep using CareCompanion as before.</p>
            </>
          )}
          <p className="text-xs text-ink-muted">You have been signed out of this page.</p>
          <Button
            variant="secondary"
            onClick={() => {
              setConfirmed(false);
              setReason("");
              setStep({ kind: "phone" });
            }}
          >
            Done
          </Button>
        </div>
      )}
    </div>
  );
}
