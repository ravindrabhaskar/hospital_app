"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { QueryClientContext, useQuery } from "@tanstack/react-query";
import {
  Activity,
  AlertTriangle,
  Ambulance,
  Boxes,
  Building2,
  FilePlus2,
  FlaskConical,
  Headset,
  Hospital,
  Palette,
  Stethoscope,
  Ticket,
  BadgeCheck,
  BarChart3,
  BookOpen,
  CalendarClock,
  CalendarRange,
  ClipboardList,
  Clock,
  FileCheck2,
  Gauge,
  HeartPulse,
  Home,
  IndianRupee,
  Landmark,
  LogOut,
  Map as MapIcon,
  Menu,
  MessagesSquare,
  Package,
  Receipt,
  ScrollText,
  Shield,
  Siren,
  Sparkles,
  Star,
  ToggleRight,
  UserRound,
  Users,
  Wallet,
  X,
} from "lucide-react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { ROLE_LABELS, canAccessPath, homePathFor, visibleNav, type NavIcon } from "@/lib/roles";
import { mfaPath, needsMfa } from "@/lib/mfa";
import { idlePhase, readLastActivity, secondsUntilTimeout, writeLastActivity, type IdlePhase } from "@/lib/idle";
import { Badge, Button, Dialog, LoadingState, UnauthorizedState, cx } from "./ui";

const ICONS: Record<NavIcon, typeof Home> = {
  calendar: CalendarClock,
  users: Users,
  siren: Siren,
  gauge: Gauge,
  home: Home,
  badge: BadgeCheck,
  activity: Activity,
  clock: Clock,
  alert: AlertTriangle,
  wallet: Wallet,
  scroll: ScrollText,
  shield: Shield,
  sparkles: Sparkles,
  book: BookOpen,
  toggle: ToggleRight,
  chart: BarChart3,
  map: MapIcon,
  user: UserRound,
  schedule: CalendarRange,
  rupee: IndianRupee,
  fileCheck: FileCheck2,
  receipt: Receipt,
  star: Star,
  clipboard: ClipboardList,
  messages: MessagesSquare,
  package: Package,
  landmark: Landmark,
  stethoscope: Stethoscope,
  flask: FlaskConical,
  ambulance: Ambulance,
  boxes: Boxes,
  headset: Headset,
  hospital: Hospital,
  filePlus: FilePlus2,
  heartPulse: HeartPulse,
  building: Building2,
  palette: Palette,
  ticket: Ticket,
};

/** Client-side guard + shell for every portal page (no middleware). */
export function PortalShell({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  const mfaPending = !!session && needsMfa(session.user) && !session.mfaSkipped;

  useEffect(() => {
    if (session === null) router.replace(`/login?next=${encodeURIComponent(pathname)}`);
    else if (session && !homePathFor(session.user.roles)) router.replace("/login");
    else if (mfaPending) router.replace(mfaPath(pathname));
  }, [session, router, pathname, mfaPending]);

  if (!session || mfaPending) {
    return (
      <main id="main" className="mx-auto max-w-md p-10">
        <LoadingState label="Checking your session…" />
      </main>
    );
  }

  const allowed = canAccessPath(pathname, session.user.roles);
  return (
    <ShellFrame>
      {allowed ? (
        children
      ) : (
        <div className="rounded-[20px] border border-line bg-white p-6">
          <UnauthorizedState />
          <div className="text-center">
            <Link href={homePathFor(session.user.roles) ?? "/login"} className="text-sm font-semibold text-primary-light underline">
              Go to your home page
            </Link>
          </div>
        </div>
      )}
    </ShellFrame>
  );
}

function ShellFrame({ children }: { children: ReactNode }) {
  const { user, roles, signOut } = useAuth();
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);
  const sections = visibleNav(roles);
  // The unread counter needs TanStack Query; unit tests may render the shell without a client.
  const hasQueryClient = !!useContext(QueryClientContext);

  // Close the drawer after navigating.
  useEffect(() => setMobileOpen(false), [pathname]);

  const isActive = (href: string) => {
    if (href === "/clinician" || href === "/ops") return pathname === href;
    // "/hospital" lists discharges; its sub-pages (new discharge, detail) have their own entries or none.
    if (href === "/hospital") return pathname === href || pathname.startsWith("/hospital/discharges/");
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const nav = (
    <nav aria-label="Main" className="flex flex-col gap-5 px-3 py-4">
      {sections.map((s) => (
        <div key={s.key}>
          <p className="px-3 pb-1.5 text-[11px] font-semibold uppercase tracking-wider text-ink-muted">{s.label}</p>
          <ul className="flex flex-col gap-0.5">
            {s.items.map((item) => {
              const Icon = ICONS[item.icon];
              const active = isActive(item.href);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    className={cx(
                      "flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition-colors",
                      active ? "bg-primary text-white" : "text-ink hover:bg-mint-50",
                    )}
                  >
                    <Icon className="size-[18px]" aria-hidden />
                    <span className="flex-1">{item.label}</span>
                    {item.badge === "inbox" && hasQueryClient && <InboxUnreadBadge active={active} />}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );

  return (
    <div className="flex min-h-screen">
      {/* Desktop sidebar */}
      <aside className="sticky top-0 hidden h-screen w-60 shrink-0 flex-col overflow-y-auto border-r border-line bg-white lg:flex">
        <Brand />
        {nav}
      </aside>

      {/* Tablet / mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-ink/40" aria-hidden onClick={() => setMobileOpen(false)} />
          <aside className="relative h-full w-64 overflow-y-auto bg-white shadow-xl" aria-label="Navigation drawer">
            <div className="flex items-center justify-between pr-2">
              <Brand />
              <button
                type="button"
                onClick={() => setMobileOpen(false)}
                aria-label="Close navigation"
                className="rounded-full p-2 text-ink-muted hover:bg-mint-50"
              >
                <X className="size-5" aria-hidden />
              </button>
            </div>
            {nav}
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-line bg-white/90 px-4 backdrop-blur md:px-6">
          <button
            type="button"
            className="rounded-full p-2 text-ink hover:bg-mint-50 lg:hidden"
            aria-label="Open navigation"
            aria-expanded={mobileOpen}
            onClick={() => setMobileOpen(true)}
          >
            <Menu className="size-5" aria-hidden />
          </button>
          <div className="flex-1" />
          <div className="flex min-w-0 items-center gap-3">
            <div className="hidden min-w-0 text-right sm:block">
              <p className="truncate text-sm font-semibold">{user?.name ?? user?.phone}</p>
              <p className="truncate text-xs text-ink-muted">{user?.phone}</p>
            </div>
            <ul className="flex flex-wrap gap-1" aria-label="Your roles">
              {roles
                .filter((r) => r !== "patient")
                .map((r) => (
                  <li key={r}>
                    <Badge tone="green">{ROLE_LABELS[r]}</Badge>
                  </li>
                ))}
            </ul>
            <button
              type="button"
              onClick={() => void signOut()}
              className="inline-flex h-9 items-center gap-1.5 rounded-full border border-line px-3 text-sm font-medium text-ink hover:bg-mint-50"
            >
              <LogOut className="size-4" aria-hidden />
              <span className="hidden sm:inline">Log out</span>
              <span className="sr-only sm:hidden">Log out</span>
            </button>
          </div>
        </header>
        <main id="main" tabIndex={-1} className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 md:px-6">
          {children}
        </main>
        <footer className="flex flex-wrap items-center justify-center gap-x-4 gap-y-1 border-t border-line px-4 py-3 text-xs text-ink-muted">
          <Link href="/privacy" className="hover:underline">
            Privacy
          </Link>
          <Link href="/terms" className="hover:underline">
            Terms
          </Link>
          <Link href="/support" className="hover:underline">
            Support
          </Link>
          <span>Access to patient data is logged and audited.</span>
        </footer>
      </div>
      <IdleWatcher onTimeout={() => void signOut("idle")} />
    </div>
  );
}

/** Unread care-team messages (sum of `InboxThread.unread`, §34), refreshed every 30 s. */
function InboxUnreadBadge({ active }: { active: boolean }) {
  const q = useQuery({
    queryKey: ["inbox"],
    queryFn: () => api.messages.inbox({ limit: 100 }),
    refetchInterval: 30_000,
    retry: false,
  });
  const unread = q.data?.items.reduce((n, t) => n + (t.unread ?? 0), 0) ?? 0;
  if (!unread) return null;
  return (
    <span
      className={cx(
        "min-w-5 rounded-full px-1.5 text-center text-[11px] font-bold leading-5",
        active ? "bg-white text-primary" : "bg-danger text-white",
      )}
    >
      {unread > 99 ? "99+" : unread}
      <span className="sr-only"> unread</span>
    </span>
  );
}

const ACTIVITY_EVENTS = ["pointerdown", "keydown", "wheel", "touchstart", "mousemove", "scroll"] as const;

/** Signs staff out after 15 min without activity, with a warning dialog from minute 13. */
export function IdleWatcher({ onTimeout }: { onTimeout: () => void }) {
  const lastRef = useRef<number>(0);
  const [phase, setPhase] = useState<IdlePhase>("active");
  const [secondsLeft, setSecondsLeft] = useState(0);
  const phaseRef = useRef<IdlePhase>("active");
  const timeoutRef = useRef(onTimeout);
  useEffect(() => {
    timeoutRef.current = onTimeout;
  }, [onTimeout]);

  const markActive = useCallback(() => {
    const now = Date.now();
    lastRef.current = now;
    writeLastActivity(now);
    phaseRef.current = "active";
    setPhase("active");
  }, []);

  useEffect(() => {
    lastRef.current = readLastActivity(Date.now());
    let lastWrite = 0;
    let fired = false;
    const onActivity = () => {
      // While the warning is shown only the explicit "Stay signed in" button counts.
      if (phaseRef.current !== "active") return;
      const now = Date.now();
      lastRef.current = now;
      if (now - lastWrite > 5_000) {
        lastWrite = now;
        writeLastActivity(now);
      }
    };
    const tick = () => {
      const now = Date.now();
      const p = idlePhase(lastRef.current, now);
      if (p !== phaseRef.current) {
        phaseRef.current = p;
        setPhase(p);
      }
      if (p === "warning") setSecondsLeft(secondsUntilTimeout(lastRef.current, now));
      if (p === "expired" && !fired) {
        fired = true;
        timeoutRef.current();
      }
    };
    ACTIVITY_EVENTS.forEach((e) => window.addEventListener(e, onActivity, { passive: true }));
    document.addEventListener("visibilitychange", tick);
    const id = window.setInterval(tick, 1000);
    tick();
    return () => {
      ACTIVITY_EVENTS.forEach((e) => window.removeEventListener(e, onActivity));
      document.removeEventListener("visibilitychange", tick);
      window.clearInterval(id);
    };
  }, []);

  const minutes = Math.floor(secondsLeft / 60);
  const seconds = String(secondsLeft % 60).padStart(2, "0");
  return (
    <Dialog
      open={phase === "warning"}
      onClose={markActive}
      title="Are you still there?"
      description="For patient privacy, idle staff sessions are signed out after 15 minutes."
      footer={
        <>
          <Button variant="ghost" onClick={() => timeoutRef.current()}>
            Sign out now
          </Button>
          <Button data-autofocus onClick={markActive}>
            Stay signed in
          </Button>
        </>
      }
    >
      <p className="text-sm" role="timer" aria-live="polite">
        You will be signed out in{" "}
        <strong>
          {minutes}:{seconds}
        </strong>
        .
      </p>
    </Dialog>
  );
}

function Brand() {
  return (
    <div className="flex items-center gap-2.5 px-5 py-5">
      <span className="flex size-9 items-center justify-center rounded-xl bg-primary text-white" aria-hidden>
        <HeartPulse className="size-5" />
      </span>
      <div className="leading-tight">
        <p className="font-bold text-primary-dark">CareCompanion</p>
        <p className="text-[11px] text-ink-muted">Care orchestration</p>
      </div>
    </div>
  );
}
