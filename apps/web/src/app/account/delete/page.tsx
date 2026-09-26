import type { Metadata } from "next";
import Link from "next/link";
import { AccountDeletionFlow } from "@/components/account-deletion";
import { LegalDraftBanner, PageTitle, Prose, PublicLayout } from "@/components/public-layout";

export const metadata: Metadata = {
  title: "Delete your account · CareCompanion",
  description: "Request deletion of your CareCompanion account and personal data, or cancel a pending request.",
  robots: { index: true, follow: true },
};

/** Account deletion page required by Google Play (and DPDP erasure). Works for patient-only accounts. */
export default function AccountDeletePage() {
  return (
    <PublicLayout wide>
      <LegalDraftBanner />
      <PageTitle title="Delete your CareCompanion account" />
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_400px]">
        <Prose>
          <p>
            You can ask us to delete your CareCompanion account and personal data at any time, from the privacy settings in the CareCompanion app
            or on this page. Sign in with your mobile number to schedule or cancel a deletion.
          </p>

          <h2>How it works</h2>
          <ol>
            <li>Sign in with your registered mobile number and the one-time code we send you.</li>
            <li>
              Schedule the deletion. It takes effect after a <strong>grace period of 7 days</strong>; the exact date is shown when you
              schedule it.
            </li>
            <li>Until that date you can cancel here or in the app, and nothing is lost.</li>
            <li>When the grace period ends, the deletion runs automatically and cannot be undone.</li>
          </ol>

          <h2>What is deleted</h2>
          <ul>
            <li>Your sign-in sessions and devices; you are signed out everywhere and push notifications stop.</li>
            <li>Your name, phone number and email: your account is anonymised and cannot be recovered.</li>
            <li>Family access you gave to others, and access others gave to you.</li>
            <li>Personal data of family members you manage as dependents, unless the law requires it to be kept.</li>
          </ul>

          <h2>What is kept, and why</h2>
          <p>Some records must be kept by law. They are detached from your identity and used only for these obligations:</p>
          <ul>
            <li>Clinical records (consultation notes, care plans, visit summaries, vitals), as medical-record rules require.</li>
            <li>Payment and invoice records, for 8 years under tax and accounting law.</li>
            <li>Audit and safety logs, for 7 years, for security and patient safety.</li>
            <li>Proof of the consents you gave.</li>
          </ul>
          <p>
            Backups roll over within their rotation period. See the <Link href="/privacy#retention">privacy policy</Link> for the full
            retention table.
          </p>

          <h2>Want a copy first?</h2>
          <p>You can export a copy of your data from the privacy settings in the app before deleting your account.</p>

          <h2>Staff accounts</h2>
          <p>Doctors, coordinators and administrators cannot delete their account here. Please contact your administrator.</p>

          <p>
            Need help? <Link href="/support">Contact support</Link>.
          </p>
        </Prose>
        <div className="lg:sticky lg:top-6 lg:self-start">
          <AccountDeletionFlow />
        </div>
      </div>
    </PublicLayout>
  );
}
