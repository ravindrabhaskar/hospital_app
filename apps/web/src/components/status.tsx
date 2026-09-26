"use client";

import {
  AlertOctagon,
  AlertTriangle,
  BadgeCheck,
  Bot,
  CircleDot,
  Download,
  Home,
  PenLine,
  Smartphone,
  Stethoscope,
} from "lucide-react";
import type {
  AppointmentStatus,
  EpisodeStatus,
  HomeVisitStatus,
  PaymentStatus,
  Priority,
  Provenance,
  SafetyEvent,
  VerificationStatus,
} from "@/lib/api/types";
import { humanize } from "@/lib/format";
import { Badge, type Tone } from "./ui";

const EPISODE_TONE: Record<EpisodeStatus, Tone> = {
  NEW: "sky",
  INTAKE: "sky",
  AWAITING_CARE: "amber",
  CARE_SCHEDULED: "green",
  UNDER_CARE: "green",
  FOLLOW_UP: "lavender",
  RESOLVED: "neutral",
  ESCALATED: "red",
  EMERGENCY: "dark",
  TRANSFERRED: "neutral",
  CANCELLED: "neutral",
};

export function EpisodeStatusBadge({ status }: { status: EpisodeStatus }) {
  return <Badge tone={EPISODE_TONE[status] ?? "neutral"}>{humanize(status)}</Badge>;
}

export function PriorityBadge({ priority }: { priority: Priority }) {
  if (priority === "emergency")
    return (
      <Badge tone="dark" icon={<AlertOctagon className="size-3" aria-hidden />}>
        Emergency
      </Badge>
    );
  if (priority === "urgent")
    return (
      <Badge tone="red" icon={<AlertTriangle className="size-3" aria-hidden />}>
        Urgent
      </Badge>
    );
  return <Badge tone="neutral">Routine</Badge>;
}

export function SafetyLevelBadge({ level }: { level: SafetyEvent["level"] }) {
  return <PriorityBadge priority={level} />;
}

const PROVENANCE: Record<Provenance, { label: string; tone: Tone; icon: React.ReactNode }> = {
  clinician_verified: { label: "Clinician verified", tone: "green", icon: <BadgeCheck className="size-3" aria-hidden /> },
  patient_entered: { label: "Patient entered", tone: "neutral", icon: <PenLine className="size-3" aria-hidden /> },
  home_visit: { label: "Home visit", tone: "sky", icon: <Home className="size-3" aria-hidden /> },
  imported: { label: "Imported", tone: "neutral", icon: <Download className="size-3" aria-hidden /> },
  ai_extracted: { label: "AI extracted", tone: "lavender", icon: <Bot className="size-3" aria-hidden /> },
  device: { label: "Device", tone: "sky", icon: <Smartphone className="size-3" aria-hidden /> },
};

export function ProvenanceBadge({ source }: { source: Provenance | null | undefined }) {
  if (!source) return null;
  const p = PROVENANCE[source] ?? { label: humanize(source), tone: "neutral" as Tone, icon: null };
  return (
    <Badge tone={p.tone} icon={p.icon} title={`Source: ${p.label}`}>
      {p.label}
    </Badge>
  );
}

const VISIT_TONE: Record<HomeVisitStatus, Tone> = {
  requested: "amber",
  unassigned: "red",
  assigned: "sky",
  accepted: "sky",
  en_route: "lavender",
  arrived: "green",
  in_progress: "green",
  completed: "neutral",
  cancelled: "neutral",
  escalated: "red",
};

export function VisitStatusBadge({ status }: { status: HomeVisitStatus }) {
  return <Badge tone={VISIT_TONE[status] ?? "neutral"}>{humanize(status)}</Badge>;
}

const APPT_TONE: Record<AppointmentStatus, Tone> = {
  pending_payment: "amber",
  confirmed: "sky",
  in_progress: "green",
  completed: "neutral",
  cancelled: "neutral",
  no_show: "red",
};

export function AppointmentStatusBadge({ status }: { status: AppointmentStatus }) {
  return (
    <Badge tone={APPT_TONE[status] ?? "neutral"} icon={status === "in_progress" ? <Stethoscope className="size-3" aria-hidden /> : undefined}>
      {humanize(status)}
    </Badge>
  );
}

const PAY_TONE: Record<PaymentStatus, Tone> = {
  pending: "amber",
  succeeded: "green",
  failed: "red",
  refunded: "neutral",
  partially_refunded: "lavender",
};

export function PaymentStatusBadge({ status }: { status: PaymentStatus }) {
  return <Badge tone={PAY_TONE[status] ?? "neutral"}>{humanize(status)}</Badge>;
}

const VERIFY_TONE: Record<VerificationStatus, Tone> = {
  pending: "amber",
  verified: "green",
  rejected: "red",
  suspended: "red",
  expired: "red",
};

export function VerificationBadge({ status }: { status: VerificationStatus }) {
  return (
    <Badge tone={VERIFY_TONE[status] ?? "neutral"} icon={status === "verified" ? <BadgeCheck className="size-3" aria-hidden /> : undefined}>
      {humanize(status)}
    </Badge>
  );
}

export function GenericStatusBadge({ status, tone }: { status: string; tone?: Tone }) {
  return (
    <Badge tone={tone ?? "neutral"} icon={<CircleDot className="size-3" aria-hidden />}>
      {humanize(status)}
    </Badge>
  );
}
