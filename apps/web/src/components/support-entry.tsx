"use client";

import type { ReactNode } from "react";
import { useAuth } from "@/lib/auth";
import { canUseSupportDesk } from "@/lib/roles";
import { PortalShell } from "./app-shell";
import { SupportDesk } from "./support-desk";

/**
 * `/support` serves two audiences: the public help page (contacts + FAQ, statically rendered) and, for signed-in
 * support agents, coordinators and admins, the §61 support desk inside the portal shell.
 */
export function SupportEntry({ publicContent }: { publicContent: ReactNode }) {
  const { session } = useAuth();
  if (session && canUseSupportDesk(session.user.roles)) {
    return (
      <PortalShell>
        <SupportDesk />
      </PortalShell>
    );
  }
  return <>{publicContent}</>;
}
