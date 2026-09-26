"use client";

import { Mail, MessageCircle, Phone } from "lucide-react";
import { publicEnv } from "@/lib/env";
import { usePublicConfig } from "@/lib/public-config";
import { LoadingState } from "./ui";

/** Support contacts from GET /config/public (§21), falling back to NEXT_PUBLIC_SUPPORT_* while it is unavailable. */
export function SupportContacts() {
  const config = usePublicConfig();
  if (config.isPending) return <LoadingState label="Loading contact details…" rows={2} />;
  const s = config.data?.support;
  const phone = s?.phone || publicEnv.supportPhone;
  const email = s?.email || publicEnv.supportEmail;
  const whatsapp = s?.whatsapp ?? null;
  if (!phone && !email && !whatsapp) {
    return <p className="text-sm text-ink-muted">Contact details are temporarily unavailable. Please try again later.</p>;
  }
  const waDigits = whatsapp?.replace(/[^\d]/g, "");
  return (
    <ul className="grid gap-3 sm:grid-cols-3">
      {phone && (
        <Contact icon={<Phone className="size-5" aria-hidden />} label="Call us" value={phone} href={`tel:${phone.replace(/\s+/g, "")}`} />
      )}
      {email && <Contact icon={<Mail className="size-5" aria-hidden />} label="Email" value={email} href={`mailto:${email}`} />}
      {whatsapp && waDigits && (
        <Contact icon={<MessageCircle className="size-5" aria-hidden />} label="WhatsApp" value={whatsapp} href={`https://wa.me/${waDigits}`} />
      )}
    </ul>
  );
}

function Contact({ icon, label, value, href }: { icon: React.ReactNode; label: string; value: string; href: string }) {
  return (
    <li className="rounded-2xl border border-line bg-white p-4">
      <div className="flex items-center gap-2 text-primary">
        {icon}
        <span className="text-sm font-semibold text-ink">{label}</span>
      </div>
      <a href={href} className="mt-1 block break-all text-[15px] font-medium text-primary-light underline" rel="noopener noreferrer">
        {value}
      </a>
    </li>
  );
}
