import Link from "next/link";
import type { ReactNode } from "react";
import { FileWarning, HeartPulse } from "lucide-react";
import { publicEnv } from "@/lib/env";

/** Server-rendered chrome for public pages (no login). */
export function PublicLayout({ children, wide = false }: { children: ReactNode; wide?: boolean }) {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="border-b border-line bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <Link href="/" className="flex items-center gap-2.5">
            <span className="flex size-9 items-center justify-center rounded-xl bg-primary text-white" aria-hidden>
              <HeartPulse className="size-5" />
            </span>
            <span className="font-bold text-primary-dark">CareCompanion</span>
          </Link>
          <nav aria-label="Site" className="flex items-center gap-4 text-sm">
            <Link href="/support" className="font-medium text-ink hover:underline">
              Support
            </Link>
            <Link
              href="/login"
              className="inline-flex h-9 items-center rounded-full border border-primary px-3.5 text-[13px] font-semibold text-primary hover:bg-mint-50"
            >
              Staff login
            </Link>
          </nav>
        </div>
      </header>
      <main id="main" className={`mx-auto w-full flex-1 px-4 py-8 ${wide ? "max-w-5xl" : "max-w-3xl"}`}>
        {children}
      </main>
      <PublicFooter />
    </div>
  );
}

export function PublicFooter() {
  return (
    <footer className="border-t border-line bg-white">
      <div className="mx-auto flex max-w-5xl flex-col gap-3 px-4 py-6 text-sm text-ink-muted sm:flex-row sm:items-center sm:justify-between">
        <p>
          © {new Date().getFullYear()} CareCompanion. Not an emergency service: in an emergency call <strong className="text-ink">108</strong>.
        </p>
        <nav aria-label="Legal and help" className="flex flex-wrap gap-x-4 gap-y-1">
          <Link href="/privacy" className="hover:underline">
            Privacy policy
          </Link>
          <Link href="/terms" className="hover:underline">
            Terms of use
          </Link>
          <Link href="/account/delete" className="hover:underline">
            Delete account
          </Link>
          <Link href="/support" className="hover:underline">
            Support
          </Link>
        </nav>
      </div>
    </footer>
  );
}

/** Controlled by NEXT_PUBLIC_LEGAL_DRAFT (default true). */
export function LegalDraftBanner() {
  if (!publicEnv.legalDraft) return null;
  return (
    <div role="note" className="mb-6 flex items-start gap-3 rounded-2xl border border-[#f8d9b5] bg-peach-bg p-4 text-peach-fg">
      <FileWarning className="mt-0.5 size-5 shrink-0" aria-hidden />
      <div className="text-sm">
        <p className="font-semibold">Draft, pending legal review</p>
        <p>This document is a working draft. It has not yet been approved by legal counsel and may change before launch.</p>
      </div>
    </div>
  );
}

/** Readable long-form text without a typography plugin. */
export function Prose({ children }: { children: ReactNode }) {
  return (
    <div className="text-[15px] leading-7 text-ink [&_a]:font-medium [&_a]:text-primary-light [&_a]:underline [&_h2]:mt-8 [&_h2]:scroll-mt-20 [&_h2]:text-lg [&_h2]:font-semibold [&_h3]:mt-5 [&_h3]:font-semibold [&_li]:mt-1 [&_ol]:mt-3 [&_ol]:list-decimal [&_ol]:pl-6 [&_p]:mt-3 [&_table]:mt-3 [&_table]:w-full [&_table]:text-sm [&_td]:border-t [&_td]:border-line [&_td]:py-2 [&_td]:pr-3 [&_td]:align-top [&_th]:py-2 [&_th]:pr-3 [&_th]:text-left [&_th]:font-semibold [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:pl-6">
      {children}
    </div>
  );
}

export function PageTitle({ title, updated }: { title: string; updated?: string }) {
  return (
    <div className="mb-4">
      <h1 className="text-[28px] font-bold leading-9 text-ink">{title}</h1>
      {updated && <p className="mt-1 text-sm text-ink-muted">Last updated: {updated}</p>}
    </div>
  );
}
