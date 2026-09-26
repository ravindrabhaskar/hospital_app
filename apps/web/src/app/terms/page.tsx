import type { Metadata } from "next";
import Link from "next/link";
import { Siren } from "lucide-react";
import { LegalDraftBanner, PageTitle, Prose, PublicLayout } from "@/components/public-layout";
import { publicEnv } from "@/lib/env";

export const metadata: Metadata = {
  title: "Terms of use · CareCompanion",
  description: "The terms that apply when you use the CareCompanion apps and services.",
  robots: { index: true, follow: true },
};

const UPDATED = "26 September 2026";

// Draft. [REQUIRES LEGAL REVIEW]: payments/refunds and liability sections are placeholders.
export default function TermsPage() {
  return (
    <PublicLayout>
      <LegalDraftBanner />
      <PageTitle title="Terms of use" updated={UPDATED} />

      <div role="note" className="mb-6 flex items-start gap-3 rounded-2xl border border-[#f6c9c9] bg-rose-bg p-4 text-danger-dark">
        <Siren className="mt-0.5 size-5 shrink-0" aria-hidden />
        <div className="text-sm">
          <p className="font-semibold">CareCompanion is not an emergency service.</p>
          <p>
            In a medical emergency call <strong>108</strong> (ambulance) or <strong>112</strong>, or go to the nearest hospital. Do not wait
            for a reply in the app.
          </p>
        </div>
      </div>

      <Prose>
        <p>
          These terms are an agreement between you and <strong>{publicEnv.legalEntityName}</strong> (&ldquo;CareCompanion&rdquo;,
          &ldquo;we&rdquo;) for the CareCompanion mobile apps, web portal and related services (the &ldquo;Service&rdquo;). By creating an
          account or using the Service you accept these terms and our <Link href="/privacy">privacy policy</Link>.
        </p>

        <h2>1. What the Service is</h2>
        <p>
          CareCompanion helps you organise care: book consultations and home visits, keep health records, follow care plans and
          coordinate with family and your care team.
        </p>

        <h2>2. Not an emergency service</h2>
        <p>
          The Service is not designed for emergencies and is not monitored continuously. The SOS and fall-alert features notify your
          contacts and our team on a best-effort basis and do not replace calling 108 or 112.
        </p>

        <h2>3. Not a diagnosis</h2>
        <p>
          Information from the app, including the AI care assistant, record summaries and reminders, is general guidance to help you
          navigate care. It is <strong>not a medical diagnosis or treatment</strong> and does not replace a consultation with a
          qualified doctor. Always follow the advice of your treating doctor.
        </p>

        <h2>4. Telemedicine and professional care</h2>
        <ul>
          <li>
            Consultations are provided by independent medical practitioners registered with the National Medical Commission or a State
            Medical Council, following the Telemedicine Practice Guidelines.
          </li>
          <li>The doctor decides whether a remote consultation is appropriate and may ask you to visit in person.</li>
          <li>
            Home-care services are delivered by verified nurses, technicians and other providers. Clinical decisions remain the
            responsibility of the treating professional.
          </li>
          <li>Prescriptions are issued only where the law and the guidelines allow.</li>
        </ul>

        <h2>5. Your account</h2>
        <ul>
          <li>You sign in with your mobile number and a one-time code. Keep your phone secure; you are responsible for activity on your account.</li>
          <li>Give accurate information, especially about allergies, conditions and medications.</li>
          <li>
            If you act for a family member, you confirm that you are allowed to do so and that they (or their lawful guardian) have
            agreed.
          </li>
          <li>
            You can delete your account at any time (see <Link href="/account/delete">Delete your account</Link>).
          </li>
        </ul>

        <h2>6. Acceptable use</h2>
        <p>
          Do not misuse the Service: no false information, impersonation, harassment of providers or staff, attempts to access other
          people&apos;s data, or interference with the Service&apos;s security.
        </p>

        <h2>7. Payments and refunds</h2>
        <p className="rounded-xl border border-dashed border-line bg-white p-3 text-sm text-ink-muted">
          [Placeholder, to be completed with counsel: fees and taxes, when payment is taken, the cancellation windows for consultations
          and home visits, refund eligibility and timelines, and how refunds are returned to the original payment method.]
        </p>
        <p>Payments are processed by a regulated payment gateway. We do not store your card or UPI details.</p>

        <h2>8. Limitation of liability</h2>
        <p className="rounded-xl border border-dashed border-line bg-white p-3 text-sm text-ink-muted">
          [Placeholder, to be completed with counsel: the extent of CareCompanion&apos;s liability for the platform, the position of
          independent practitioners and partners, exclusions permitted by Indian law, and the consumer rights that cannot be excluded.]
        </p>

        <h2>9. Suspension and termination</h2>
        <p>
          We may suspend access to protect patients, providers or the Service, or if these terms are broken. You may stop using the
          Service and delete your account at any time.
        </p>

        <h2>10. Changes</h2>
        <p>We will tell you in the app before material changes to these terms take effect.</p>

        <h2>11. Governing law and grievances</h2>
        <p>
          These terms are governed by the laws of India. Complaints can be raised through <Link href="/support">support</Link> or with
          our Grievance Officer (see the <Link href="/privacy#grievance">privacy policy</Link>). [Jurisdiction and dispute resolution:
          placeholder, to be completed with counsel.]
        </p>
      </Prose>
    </PublicLayout>
  );
}
