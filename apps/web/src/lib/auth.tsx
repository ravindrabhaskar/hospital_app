"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useSyncExternalStore, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { api, onMfaRequired, onSessionExpired, tokenStore, type StoredSession } from "@/lib/api";
import type { AuthSession, Me, Role } from "@/lib/api/types";
import { clearLastActivity } from "@/lib/idle";
import { markMfaRequired, mfaPath } from "@/lib/mfa";

export type SignOutReason = "user" | "idle";

interface AuthContextValue {
  /** `undefined` until hydrated on the client. */
  session: StoredSession | null | undefined;
  user: Me | null;
  roles: Role[];
  signIn: (auth: AuthSession) => void;
  signOut: (reason?: SignOutReason) => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const subscribe = (cb: () => void) => tokenStore.subscribe(cb);
const getSnapshot = () => tokenStore.get();
const getServerSnapshot = () => undefined;

export function AuthProvider({ children }: { children: ReactNode }) {
  const session = useSyncExternalStore<StoredSession | null | undefined>(subscribe, getSnapshot, getServerSnapshot);
  const router = useRouter();
  const qc = useQueryClient();

  useEffect(() => {
    // Refresh failed (or no refresh token): the client already cleared the tokens.
    onSessionExpired(() => {
      qc.clear();
      clearLastActivity();
      router.replace("/login?expired=1");
    });
    // Any 403 MFA_REQUIRED (§22): mark the session unverified and route to the MFA step.
    onMfaRequired(() => {
      const s = tokenStore.get();
      if (!s) return;
      tokenStore.set({ ...s, mfaSkipped: false, user: markMfaRequired(s.user) });
      const here = window.location.pathname;
      if (!here.startsWith("/mfa")) router.replace(mfaPath(here + window.location.search));
    });
    return () => {
      onSessionExpired(null);
      onMfaRequired(null);
    };
  }, [qc, router]);

  // Refresh the cached user profile once per load (roles or MFA state may have changed).
  const hasSession = !!session;
  useEffect(() => {
    if (!hasSession) return;
    let cancelled = false;
    api.auth
      .me()
      .then((me) => {
        if (!cancelled) tokenStore.updateUser(me);
      })
      .catch(() => {
        /* 401s are handled by the client; other errors keep the cached profile */
      });
    return () => {
      cancelled = true;
    };
  }, [hasSession]);

  const signIn = useCallback((auth: AuthSession) => tokenStore.setFromAuth(auth), []);

  const signOut = useCallback(
    async (reason: SignOutReason = "user") => {
      const s = tokenStore.get();
      tokenStore.clear();
      qc.clear();
      clearLastActivity();
      router.replace(reason === "idle" ? "/login?idle=1" : "/login");
      if (s?.refreshToken) {
        try {
          await api.auth.logout(s.refreshToken);
        } catch {
          /* ignore: cleared locally regardless */
        }
      }
    },
    [qc, router],
  );

  const value = useMemo<AuthContextValue>(
    () => ({ session, user: session?.user ?? null, roles: session?.user.roles ?? [], signIn, signOut }),
    [session, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
