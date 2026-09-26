"use client";

import { Suspense, useCallback, useEffect, useMemo } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { HeartPulse } from "lucide-react";
import { api, tokenStore } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { homePathFor } from "@/lib/roles";
import { needsMfa } from "@/lib/mfa";
import { MfaFlow, type MfaApi } from "@/components/mfa-flow";
import { LoadingState } from "@/components/ui";

const mfaApi: MfaApi = {
  enroll: () => api.auth.mfaEnroll(),
  confirm: (code) => api.auth.mfaConfirm(code),
  verify: (input) => api.auth.mfaVerify(input),
};

function MfaInner() {
  const { session, signIn, signOut } = useAuth();
  const router = useRouter();
  const params = useSearchParams();

  useEffect(() => {
    if (session === null) router.replace("/login");
  }, [session, router]);

  // Fresh profile: mfaEnrolled / mfaVerified decide between enrolment and verification.
  const me = useQuery({ queryKey: ["mfa", "me"], queryFn: () => api.auth.me(), enabled: !!session, retry: false, gcTime: 0 });
  useEffect(() => {
    if (me.data) tokenStore.updateUser(me.data);
  }, [me.data]);

  // Cheap authenticated probe: 403 MFA_REQUIRED means the server enforces MFA; success means it does not (dev).
  const pending = !!session && needsMfa(me.data ?? session.user);
  const probe = useQuery({ queryKey: ["mfa", "probe"], queryFn: () => api.consents.list(), enabled: pending, retry: false, gcTime: 0 });
  const notEnforced = probe.isSuccess;

  const target = useMemo(() => {
    const next = params.get("next");
    if (next && next.startsWith("/") && !next.startsWith("//") && !next.startsWith("/mfa")) return next;
    return (session && homePathFor(session.user.roles)) ?? "/login";
  }, [params, session]);

  const onDone = useCallback(() => router.replace(target), [router, target]);
  const onSkip = useCallback(() => {
    tokenStore.setMfaSkipped(true);
    router.replace(target);
  }, [router, target]);

  // When the server does not enforce MFA (local development), continue straight to the portal.
  // Add ?setup=1 to /mfa to try the enrolment flow anyway.
  const autoSkip = notEnforced && params.get("setup") !== "1";
  useEffect(() => {
    if (autoSkip) onSkip();
  }, [autoSkip, onSkip]);

  if (!session || me.isPending || autoSkip) return <LoadingState label="Checking your account…" />;

  return (
    <MfaFlow
      key={session.user.id}
      user={me.data ?? session.user}
      api={mfaApi}
      onSession={signIn}
      onDone={onDone}
      onSignOut={() => void signOut()}
      onSkip={notEnforced ? onSkip : undefined}
    />
  );
}

export default function MfaPage() {
  return (
    <main id="main" className="grid min-h-screen place-items-center bg-gradient-to-b from-mint-50 to-background px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 flex items-center gap-3">
          <span className="flex size-11 items-center justify-center rounded-2xl bg-primary text-white" aria-hidden>
            <HeartPulse className="size-6" />
          </span>
          <div>
            <p className="text-xl font-bold text-primary-dark">CareCompanion</p>
            <p className="text-sm text-ink-muted">Staff sign-in · step 2 of 2</p>
          </div>
        </div>
        <div className="rounded-[20px] border border-line bg-white p-6 shadow-[var(--shadow-card)]">
          <Suspense fallback={<LoadingState />}>
            <MfaInner />
          </Suspense>
        </div>
      </div>
    </main>
  );
}
