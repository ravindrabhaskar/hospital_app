"use client";

import { useEffect, useReducer, useState, type FormEvent } from "react";
import { Copy, Download, KeyRound, LifeBuoy, ShieldCheck, Smartphone } from "lucide-react";
import { ApiError } from "@/lib/api/http";
import type { AuthSession, Me, MfaConfirmResponse, MfaEnrollResponse, MfaVerifyInput } from "@/lib/api/types";
import { TOTP_CODE_RE, formatSecret, initialMfaState, mfaReducer, qrImageSrc, recoveryCodesText } from "@/lib/mfa";
import { Button, Field, Input, errorMessage } from "./ui";

export interface MfaApi {
  enroll: () => Promise<MfaEnrollResponse>;
  confirm: (code: string) => Promise<MfaConfirmResponse>;
  verify: (input: MfaVerifyInput) => Promise<AuthSession>;
}

export interface MfaFlowProps {
  user: Me;
  api: MfaApi;
  /** Store rotated tokens (the confirm/verify responses carry a new, MFA-verified session). */
  onSession: (auth: AuthSession) => void;
  /** MFA passed: continue into the portal. */
  onDone: () => void;
  onSignOut: () => void;
  /** Set when the API does not enforce MFA (dev): offers "Skip for now". */
  onSkip?: () => void;
}

export function MfaFlow({ user, api, onSession, onDone, onSignOut, onSkip }: MfaFlowProps) {
  const [state, dispatch] = useReducer(mfaReducer, user, initialMfaState);
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    if (state.kind === "done") onDone();
  }, [state.kind, onDone]);

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

  const startEnroll = () =>
    run(async () => {
      try {
        const enrollment = await api.enroll();
        setCode("");
        dispatch({ type: "ENROLL_STARTED", enrollment });
      } catch (e) {
        if (e instanceof ApiError && e.status === 409) {
          dispatch({ type: "ALREADY_ENROLLED" });
          return;
        }
        throw e;
      }
    });

  const confirm = (e: FormEvent) => {
    e.preventDefault();
    const c = code.trim();
    if (!TOTP_CODE_RE.test(c)) return setError("Enter the 6-digit code from your authenticator app.");
    void run(async () => {
      const res = await api.confirm(c);
      onSession(res.session);
      setCode("");
      dispatch({ type: "CONFIRMED", recoveryCodes: res.recoveryCodes });
    });
  };

  const verify = (e: FormEvent) => {
    e.preventDefault();
    if (state.kind !== "verify") return;
    const c = code.trim();
    if (state.method === "totp" && !TOTP_CODE_RE.test(c)) return setError("Enter the 6-digit code from your authenticator app.");
    if (state.method === "recovery" && c.length < 6) return setError("Enter one of your recovery codes.");
    void run(async () => {
      const auth = await api.verify(state.method === "totp" ? { code: c } : { recoveryCode: c });
      onSession(auth);
      dispatch({ type: "VERIFIED" });
    });
  };

  const copy = async (text: string, what: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setNotice(`${what} copied to the clipboard.`);
    } catch {
      setNotice("Copy failed. Select the text and copy it manually.");
    }
  };

  const download = (codes: string[]) => {
    const blob = new Blob([recoveryCodesText(codes, user.phone)], { type: "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "carecompanion-recovery-codes.txt";
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 10_000);
  };

  const codeField = (label: string, recovery = false) => (
    <Field label={label} required error={error ?? undefined}>
      {(id, d) => (
        <Input
          id={id}
          aria-describedby={d}
          aria-invalid={!!error}
          inputMode={recovery ? "text" : "numeric"}
          autoComplete="one-time-code"
          maxLength={recovery ? 32 : 6}
          autoFocus
          className={recovery ? "font-mono" : "tracking-[0.4em]"}
          value={code}
          onChange={(e) => setCode(e.target.value)}
        />
      )}
    </Field>
  );

  return (
    <div className="flex flex-col gap-4">
      {state.kind === "intro" && (
        <>
          <Header title="Set up two-step verification" />
          <p className="text-sm text-ink-muted">
            Staff accounts protect patient data with an authenticator app (Google Authenticator, Microsoft Authenticator, 1Password,
            Authy…). You will scan a QR code once, then enter a 6-digit code when you sign in.
          </p>
          {error && <FormError message={error} />}
          <Button onClick={() => void startEnroll()} loading={busy} icon={<Smartphone className="size-4" aria-hidden />}>
            Set up authenticator app
          </Button>
        </>
      )}

      {state.kind === "enroll" && (
        <form onSubmit={confirm} noValidate className="flex flex-col gap-4">
          <Header title="Scan the QR code" />
          <ol className="list-decimal space-y-1 pl-5 text-sm text-ink-muted">
            <li>Open your authenticator app and add an account.</li>
            <li>Scan this code, or enter the key manually.</li>
            <li>Type the 6-digit code the app shows.</li>
          </ol>
          <div className="flex justify-center rounded-xl border border-line bg-white p-3">
            {/* eslint-disable-next-line @next/next/no-img-element -- data URI; next/image adds nothing here */}
            <img src={qrImageSrc(state.enrollment.qrSvg)} alt="QR code to add CareCompanion to your authenticator app" width={192} height={192} className="size-48" />
          </div>
          <div>
            <p className="text-[13px] font-medium">Manual entry key</p>
            <div className="mt-1 flex items-center gap-2">
              <code className="flex-1 break-all rounded-xl bg-mint-50 px-3 py-2 font-mono text-sm" data-testid="mfa-secret">
                {formatSecret(state.enrollment.secret)}
              </code>
              <Button
                size="sm"
                variant="secondary"
                onClick={() => void copy(state.enrollment.secret, "Key")}
                icon={<Copy className="size-4" aria-hidden />}
                aria-label="Copy the manual entry key"
              >
                Copy
              </Button>
            </div>
          </div>
          {codeField("6-digit code")}
          <Button type="submit" loading={busy} icon={<ShieldCheck className="size-4" aria-hidden />}>
            Confirm and turn on
          </Button>
          <Button variant="ghost" onClick={() => dispatch({ type: "RESTART" })}>
            Start over
          </Button>
        </form>
      )}

      {state.kind === "recovery" && (
        <>
          <Header title="Save your recovery codes" />
          <p className="rounded-xl bg-peach-bg px-3 py-2 text-sm text-peach-fg" role="alert">
            These codes are shown <strong>only once</strong>. Each one lets you sign in if you lose your phone, and works a single time.
          </p>
          <ul aria-label="Recovery codes" className="grid grid-cols-2 gap-2 rounded-xl border border-line bg-mint-50 p-3 font-mono text-sm">
            {state.codes.map((c) => (
              <li key={c} className="text-center">
                {c}
              </li>
            ))}
          </ul>
          <div className="flex flex-wrap gap-2">
            <Button size="sm" variant="secondary" onClick={() => void copy(state.codes.join("\n"), "Recovery codes")} icon={<Copy className="size-4" aria-hidden />}>
              Copy all
            </Button>
            <Button size="sm" variant="secondary" onClick={() => download(state.codes)} icon={<Download className="size-4" aria-hidden />}>
              Download .txt
            </Button>
          </div>
          <label className="flex items-start gap-2 text-sm">
            <input
              type="checkbox"
              className="mt-0.5 size-4 accent-[#631D3F]"
              checked={state.acknowledged}
              onChange={(e) => dispatch({ type: "ACKNOWLEDGE", value: e.target.checked })}
            />
            I have saved these recovery codes somewhere safe.
          </label>
          <Button disabled={!state.acknowledged} onClick={() => dispatch({ type: "CONTINUE" })}>
            Continue to portal
          </Button>
        </>
      )}

      {state.kind === "verify" && (
        <form onSubmit={verify} noValidate className="flex flex-col gap-4">
          <Header title="Two-step verification" />
          <p className="text-sm text-ink-muted">
            {state.method === "totp"
              ? "Enter the 6-digit code from your authenticator app."
              : "Enter one of your saved recovery codes. Each code works only once."}
          </p>
          {state.method === "totp" ? codeField("Authenticator code") : codeField("Recovery code", true)}
          <Button type="submit" loading={busy} icon={<KeyRound className="size-4" aria-hidden />}>
            Verify
          </Button>
          <Button
            variant="ghost"
            icon={<LifeBuoy className="size-4" aria-hidden />}
            onClick={() => {
              setCode("");
              setError(null);
              dispatch({ type: "USE_METHOD", method: state.method === "totp" ? "recovery" : "totp" });
            }}
          >
            {state.method === "totp" ? "Use a recovery code instead" : "Use the authenticator app instead"}
          </Button>
          <p className="text-xs text-ink-muted">Lost your phone and your recovery codes? Ask a super admin to reset your MFA.</p>
        </form>
      )}

      {notice && (
        <p role="status" className="text-xs text-ink-muted">
          {notice}
        </p>
      )}

      {(state.kind === "intro" || state.kind === "verify") && onSkip && (
        <div className="rounded-xl border border-dashed border-line p-3 text-xs text-ink-muted">
          This API server does not enforce MFA (development).{" "}
          <button type="button" className="font-semibold text-primary-light underline" onClick={onSkip}>
            Skip for now
          </button>
        </div>
      )}

      {state.kind !== "recovery" && (
        <button type="button" onClick={onSignOut} className="self-center text-sm text-ink-muted underline">
          Sign out
        </button>
      )}
    </div>
  );
}

function Header({ title }: { title: string }) {
  return (
    <div className="flex items-center gap-2">
      <ShieldCheck className="size-5 text-primary" aria-hidden />
      <h1 className="text-lg font-semibold">{title}</h1>
    </div>
  );
}

function FormError({ message }: { message: string }) {
  return (
    <p role="alert" className="rounded-xl bg-rose-bg px-3 py-2 text-sm text-danger-dark">
      {message}
    </p>
  );
}
