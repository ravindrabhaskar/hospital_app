"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { homePathFor } from "@/lib/roles";

/** On public pages that double as an entry point: a signed-in staff user goes to their portal home. */
export function SignedInRedirect() {
  const { session } = useAuth();
  const router = useRouter();
  useEffect(() => {
    const home = session ? homePathFor(session.user.roles) : null;
    if (home) router.replace(home);
  }, [session, router]);
  return null;
}
