"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import Link from "next/link";
import { HeartPulse, KeyRound, Smartphone } from "lucide-react";
import { api, tokenStore } from "@/lib/api";
import type { AuthSession } from "@/lib/api/types";
import { useAuth } from "@/lib/auth";
import { homePathFor } from "@/lib/roles";
import { mfaPath, needsMfa } from "@/lib/mfa";
import { Button, Field, Input, errorMessage } from "@/components/ui";

const phoneSchema = z.object({
  phone: z
    .string()
    .trim()
    // Accept a bare 10-digit Indian mobile number and normalise it to +91.
    .transform((v) => (/^[6-9]\d{9}$/.test(v.replace(/[\s-]/g, "")) ? `+91${v.replace(/[\s-]/g, "")}` : v.replace(/[\s-]/g, "")))
    .pipe(z.string().regex(/^\+[1-9]\d{7,14}$/, "Enter the phone in international format, e.g. +919800000101")),
});
const otpSchema = z.object({ otp: z.string().trim().regex(/^\d{6}$/, "Enter the 6-digit code") });

type Step = { kind: "phone" } | { kind: "otp"; phone: string; devOtp?: string } | { kind: "patient" };

function LoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const { session, signIn } = useAuth();
  const [step, setStep] = useState<Step>({ kind: "phone" });
  const [formError, setFormError] = useState<string | null>(null);

  // Already signed in → go home.
  useEffect(() => {
    if (session && step.kind === "phone") {
      const home = homePathFor(session.user.roles);
      if (home && needsMfa(session.user) && !session.mfaSkipped) router.replace(mfaPath(params.get("next")));
      else if (home) router.replace(home);
    }
  }, [session, router, step.kind, params]);

  const phoneForm = useForm<z.infer<typeof phoneSchema>>({ resolver: zodResolver(phoneSchema), defaultValues: { phone: "+91" } });
  const otpForm = useForm<z.infer<typeof otpSchema>>({ resolver: zodResolver(otpSchema), defaultValues: { otp: "" } });

  const onPhone = phoneForm.handleSubmit(async ({ phone }) => {
    setFormError(null);
    try {
      const res = await api.auth.requestOtp(phone);
      otpForm.reset({ otp: "" });
      setStep({ kind: "otp", phone, devOtp: res.devOtp });
    } catch (e) {
      setFormError(errorMessage(e));
    }
  });

  const finish = (auth: AuthSession) => {
    // Tokens are stored even when MFA is pending: the MFA endpoints need them (§22).
    signIn(auth);
    const next = params.get("next");
    if (needsMfa(auth.user)) {
      router.replace(mfaPath(next));
      return;
    }
    const home = homePathFor(auth.user.roles);
    router.replace(next && next.startsWith("/") && !next.startsWith("//") ? next : (home ?? "/"));
  };

  const onOtp = otpForm.handleSubmit(async ({ otp }) => {
    if (step.kind !== "otp") return;
    setFormError(null);
    try {
      const auth = await api.auth.verifyOtp({ phone: step.phone, otp, deviceName: "CareCompanion Web Portal" });
      if (!homePathFor(auth.user.roles)) {
        // Patients (and field providers) use the mobile apps. Do not keep a portal session.
        try {
          await fetchLogout(auth.refreshToken);
        } finally {
          tokenStore.clear();
        }
        setStep({ kind: "patient" });
        return;
      }
      finish(auth);
    } catch (e) {
      setFormError(errorMessage(e));
    }
  });

  return (
    <main id="main" className="grid min-h-screen place-items-center bg-gradient-to-b from-mint-50 to-background px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 flex items-center gap-3">
          <span className="flex size-11 items-center justify-center rounded-2xl bg-primary text-white" aria-hidden>
            <HeartPulse className="size-6" />
          </span>
          <div>
            <p className="text-xl font-bold text-primary-dark">CareCompanion</p>
            <p className="text-sm text-ink-muted">Clinician · Operations · Hospital · Support · Admin portal</p>
          </div>
        </div>

        <div className="rounded-[20px] border border-line bg-white p-6 shadow-[var(--shadow-card)]">
          {params.get("expired") && step.kind === "phone" && (
            <p role="status" className="mb-4 rounded-xl bg-peach-bg px-3 py-2 text-sm text-peach-fg">
              Your session expired. Please sign in again.
            </p>
          )}
          {params.get("idle") && step.kind === "phone" && (
            <p role="status" className="mb-4 rounded-xl bg-peach-bg px-3 py-2 text-sm text-peach-fg">
              You were signed out after 15 minutes of inactivity.
            </p>
          )}

          {step.kind === "phone" && (
            <form onSubmit={onPhone} noValidate className="flex flex-col gap-4">
              <h1 className="text-lg font-semibold">Sign in with your phone</h1>
              <Field label="Mobile number" required error={phoneForm.formState.errors.phone?.message}>
                {(id, d) => (
                  <Input
                    id={id}
                    aria-describedby={d}
                    aria-invalid={!!phoneForm.formState.errors.phone}
                    type="tel"
                    autoComplete="tel"
                    inputMode="tel"
                    autoFocus
                    {...phoneForm.register("phone")}
                  />
                )}
              </Field>
              {formError && <FormError message={formError} />}
              <Button type="submit" loading={phoneForm.formState.isSubmitting} icon={<Smartphone className="size-4" aria-hidden />}>
                Send OTP
              </Button>
            </form>
          )}

          {step.kind === "otp" && (
            <form onSubmit={onOtp} noValidate className="flex flex-col gap-4">
              <h1 className="text-lg font-semibold">Enter the code</h1>
              <p className="text-sm text-ink-muted">
                We sent a 6-digit code to <span className="font-medium text-ink">{step.phone}</span>.
              </p>
              {step.devOtp && (
                <p className="rounded-xl border border-dashed border-primary-light bg-mint-50 px-3 py-2 font-mono text-sm text-primary-dark">
                  Dev OTP: {step.devOtp}
                </p>
              )}
              <Field label="One-time code" required error={otpForm.formState.errors.otp?.message}>
                {(id, d) => (
                  <Input
                    id={id}
                    aria-describedby={d}
                    aria-invalid={!!otpForm.formState.errors.otp}
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={6}
                    autoFocus
                    className="tracking-[0.4em]"
                    {...otpForm.register("otp")}
                  />
                )}
              </Field>
              {formError && <FormError message={formError} />}
              <Button type="submit" loading={otpForm.formState.isSubmitting} icon={<KeyRound className="size-4" aria-hidden />}>
                Verify and sign in
              </Button>
              <Button
                variant="ghost"
                onClick={() => {
                  setFormError(null);
                  setStep({ kind: "phone" });
                }}
              >
                Use a different number
              </Button>
            </form>
          )}

          {step.kind === "patient" && (
            <div className="flex flex-col gap-4" role="alert">
              <h1 className="text-lg font-semibold">Please use the CareCompanion mobile app</h1>
              <p className="text-sm text-ink-muted">
                This portal is for clinicians, care coordinators, hospital discharge teams, support agents and administrators. Patients, family caregivers and home-care
                providers can manage care in the CareCompanion app for Android and iOS.
              </p>
              <p className="text-sm text-ink-muted">
                Want to delete your account?{" "}
                <Link href="/account/delete" className="font-semibold text-primary-light underline">
                  Request account deletion
                </Link>
              </p>
              <Button variant="secondary" onClick={() => setStep({ kind: "phone" })}>
                Back to sign in
              </Button>
            </div>
          )}
        </div>
        <p className="mt-4 text-center text-xs text-ink-muted">Access to patient data is logged and audited.</p>
        <nav aria-label="Legal" className="mt-2 flex justify-center gap-4 text-xs text-ink-muted">
          <Link href="/privacy" className="hover:underline">
            Privacy
          </Link>
          <Link href="/terms" className="hover:underline">
            Terms
          </Link>
          <Link href="/support" className="hover:underline">
            Support
          </Link>
        </nav>
      </div>
    </main>
  );
}

async function fetchLogout(refreshToken: string) {
  try {
    await api.auth.logout(refreshToken);
  } catch {
    /* best effort */
  }
}

function FormError({ message }: { message: string }) {
  return (
    <p role="alert" className="rounded-xl bg-rose-bg px-3 py-2 text-sm text-danger-dark">
      {message}
    </p>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={null}>
      <LoginInner />
    </Suspense>
  );
}
