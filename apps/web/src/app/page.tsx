import type { Metadata } from "next";
import Link from "next/link";
import { CalendarCheck2, FileHeart, HeartHandshake, Home, ShieldCheck, Stethoscope } from "lucide-react";
import { PublicLayout } from "@/components/public-layout";
import { SignedInRedirect } from "@/components/signed-in-redirect";

export const metadata: Metadata = {
  title: "CareCompanion · Care coordination for families",
  description: "Doctor consultations, home visits and health records for you and your family, coordinated in one place.",
  robots: { index: true, follow: true },
};

const FEATURES = [
  { icon: Stethoscope, title: "Consult registered doctors", text: "Video, audio and in-clinic consultations with doctors who see your full history." },
  { icon: Home, title: "Care at home", text: "Verified nurses and technicians for home visits, sample collection and follow-ups." },
  { icon: FileHeart, title: "All records in one place", text: "Reports, prescriptions and vitals organised on one timeline for each family member." },
  { icon: CalendarCheck2, title: "Care plans that stick", text: "Medication reminders and tasks from your doctor, shared with family if you choose." },
  { icon: HeartHandshake, title: "Family coordination", text: "Manage care for parents and children with permissions you control." },
  { icon: ShieldCheck, title: "Privacy first", text: "Consent-based sharing, encryption and audit trails. We never sell your data." },
];

/** Public landing page. Signed-in staff are sent to their portal home. */
export default function Index() {
  return (
    <PublicLayout wide>
      <SignedInRedirect />
      <section className="rounded-[28px] bg-gradient-to-br from-mint-50 via-white to-sky-bg px-6 py-12 sm:px-10">
        <h1 className="max-w-2xl text-[32px] font-bold leading-10 text-primary-dark sm:text-[40px] sm:leading-[48px]">
          Care for your family, coordinated.
        </h1>
        <p className="mt-4 max-w-xl text-[16px] leading-7 text-ink-muted">
          CareCompanion brings doctor consultations, home visits, health records and care plans together, so you and the people who
          look after you are always on the same page.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link href="/support" className="inline-flex h-11 items-center rounded-[28px] bg-primary px-5 text-sm font-semibold text-white hover:bg-primary-dark">
            Get help
          </Link>
          <Link href="/login" className="inline-flex h-11 items-center rounded-[28px] border border-primary bg-white px-5 text-sm font-semibold text-primary hover:bg-mint-50">
            Staff login
          </Link>
        </div>
        <p className="mt-4 text-sm text-ink-muted">Patients and families use the CareCompanion app for Android and iOS.</p>
      </section>

      <section aria-labelledby="features" className="mt-10">
        <h2 id="features" className="sr-only">
          Features
        </h2>
        <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map(({ icon: Icon, title, text }) => (
            <li key={title} className="rounded-[20px] border border-line bg-white p-5 shadow-[var(--shadow-card)]">
              <span className="flex size-10 items-center justify-center rounded-xl bg-mint-100 text-primary" aria-hidden>
                <Icon className="size-5" />
              </span>
              <h3 className="mt-3 font-semibold">{title}</h3>
              <p className="mt-1 text-sm text-ink-muted">{text}</p>
            </li>
          ))}
        </ul>
      </section>

      <p className="mt-10 rounded-2xl border border-[#f6c9c9] bg-rose-bg p-4 text-sm text-danger-dark">
        CareCompanion is not an emergency service. In a medical emergency call <strong>108</strong> or <strong>112</strong>.
      </p>
    </PublicLayout>
  );
}
