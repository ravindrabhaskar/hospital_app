"use client";

import type { ReactNode } from "react";
import { PortalShell } from "@/components/app-shell";

export default function PortalLayout({ children }: { children: ReactNode }) {
  return <PortalShell>{children}</PortalShell>;
}
