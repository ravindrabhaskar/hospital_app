import type { Metadata } from "next";
import Link from "next/link";
import { PageTitle, Prose, PublicLayout } from "@/components/public-layout";
import { SupportContacts } from "@/components/support-contacts";

export const metadata: Metadata = {
  title: "Support · CareCompanion",
  description: "Contact CareCompanion support and find answers to common questions.",
  robots: { index: true, follow: true },
};

const FAQ: { q: string; a: React.ReactNode }[] = [
  {
    q: "Is CareCompanion an emergency service?",
    a: (
      <>
        No. In a medical emergency call <strong>108</strong> or <strong>112</strong>, or go to the nearest hospital.
      </>
    ),
  },
  {
    q: "I did not receive my sign-in code.",
    a: "Check that the number is correct and that you have signal. You can request a new code after a short wait; for security, only a few codes can be requested in 15 minutes.",
  },
  {
    q: "How do I add a family member or manage someone's care?",
    a: "In the app, open Family and invite them. You choose what they can do (view records, manage care, book, receive alerts) and can revoke access at any time.",
  },
  {
    q: "How do I cancel a booking or get a refund?",
    a: "Open the booking in the app to cancel it. Refunds go back to the original payment method. If something went wrong, contact us with the booking details.",
  },
  {
    q: "Is the AI assistant a doctor?",
    a: "No. It helps you describe concerns and find the right next step. It does not diagnose. A registered doctor makes clinical decisions.",
  },
  {
    q: "How do I download or delete my data?",
    a: (
      <>
        You can export your data from the app&apos;s privacy settings. To delete your account, use{" "}
        <Link href="/account/delete">Delete your account</Link>.
      </>
    ),
  },
  {
    q: "I am a doctor or staff member and cannot sign in.",
    a: "Staff sign in at the portal with their phone and an authenticator app. If you lost your authenticator and recovery codes, ask your administrator to reset MFA.",
  },
];

export default function SupportPage() {
  return (
    <PublicLayout>
      <PageTitle title="Support" />
      <p className="text-[15px] text-ink-muted">We are here to help with bookings, home visits, payments, your account and privacy requests.</p>
      <section aria-labelledby="contact" className="mt-6">
        <h2 id="contact" className="mb-3 text-lg font-semibold">
          Contact us
        </h2>
        <SupportContacts />
      </section>
      <section aria-labelledby="faq" className="mt-8">
        <h2 id="faq" className="mb-3 text-lg font-semibold">
          Frequently asked questions
        </h2>
        <div className="flex flex-col gap-2">
          {FAQ.map((f) => (
            <details key={f.q} className="group rounded-2xl border border-line bg-white p-4 open:shadow-[var(--shadow-card)]">
              <summary className="cursor-pointer list-none font-semibold marker:hidden">
                <span className="mr-2 inline-block text-primary transition-transform group-open:rotate-90" aria-hidden>
                  ›
                </span>
                {f.q}
              </summary>
              <Prose>
                <p>{f.a}</p>
              </Prose>
            </details>
          ))}
        </div>
      </section>
      <p className="mt-8 text-sm text-ink-muted">
        Privacy questions or complaints can also go to our Grievance Officer: see the <Link href="/privacy#grievance" className="underline">privacy policy</Link>.
      </p>
    </PublicLayout>
  );
}
