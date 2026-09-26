import type { Metadata } from "next";
import Link from "next/link";
import { LegalDraftBanner, PageTitle, Prose, PublicLayout } from "@/components/public-layout";
import { publicEnv } from "@/lib/env";

export const metadata: Metadata = {
  title: "Privacy policy · CareCompanion",
  description: "How CareCompanion collects, uses, shares and protects personal and health data under India's DPDP Act 2023.",
  robots: { index: true, follow: true },
};

const UPDATED = "26 September 2026";

// Draft grounded in docs/product/09_PRIVACY_CONSENT.md and docs/DATA_PRIVACY.md. [REQUIRES LEGAL REVIEW]
export default function PrivacyPage() {
  const env = publicEnv;
  return (
    <PublicLayout>
      <LegalDraftBanner />
      <PageTitle title="Privacy policy" updated={UPDATED} />
      <Prose>
        <p>
          CareCompanion helps patients and their families coordinate care with doctors, home-care providers and our care team. This
          policy explains what personal data we process, why, who we share it with, how long we keep it and the rights you have. It
          is written with reference to India&apos;s <strong>Digital Personal Data Protection Act, 2023</strong> (&ldquo;DPDP Act&rdquo;) and
          the rules made under it.
        </p>
        <p>
          The Data Fiduciary is <strong>{env.legalEntityName}</strong> (&ldquo;CareCompanion&rdquo;, &ldquo;we&rdquo;). &ldquo;You&rdquo;
          means the person using the app (the Data Principal), including a family member acting for a patient.
        </p>

        <nav aria-label="On this page" className="mt-5 rounded-2xl border border-line bg-white p-4 text-sm">
          <p className="font-semibold">On this page</p>
          <ol>
            <li><a href="#principles">Our principles</a></li>
            <li><a href="#data">Data we collect</a></li>
            <li><a href="#purposes">Purposes and consent</a></li>
            <li><a href="#sharing">Who we share data with</a></li>
            <li><a href="#transfers">Where data is stored</a></li>
            <li><a href="#retention">How long we keep data</a></li>
            <li><a href="#rights">Your rights</a></li>
            <li><a href="#children">Children and dependents</a></li>
            <li><a href="#security">Security</a></li>
            <li><a href="#grievance">Grievance Officer and contact</a></li>
            <li><a href="#changes">Changes to this policy</a></li>
          </ol>
        </nav>

        <h2 id="principles">1. Our principles</h2>
        <ul>
          <li>We ask for your consent before processing and sharing health data, for specific purposes you can see and withdraw.</li>
          <li>We collect only what the care journey needs, and give people access only to what their role requires.</li>
          <li>
            We do <strong>not</strong> sell your data, use your health data for advertising, or use it to train AI models.
          </li>
          <li>Access to health records is logged, and our staff access is audited.</li>
        </ul>

        <h2 id="data">2. Data we collect</h2>
        <div className="overflow-x-auto">
          <table>
            <thead>
              <tr>
                <th>Category</th>
                <th>Examples</th>
              </tr>
            </thead>
            <tbody>
              <tr><td>Identity and contact</td><td>Phone number, name, email (optional), preferred language</td></tr>
              <tr><td>Demographics</td><td>Date of birth, gender, blood group, height and weight (optional)</td></tr>
              <tr><td>Health information</td><td>Allergies, conditions, medications, symptoms you describe, care episodes, consultation notes, care plans, vitals</td></tr>
              <tr><td>Medical documents</td><td>Reports, prescriptions and images you or your care team upload</td></tr>
              <tr><td>AI conversations</td><td>Messages you send to the AI care assistant (only if you turn it on)</td></tr>
              <tr><td>Location and address</td><td>Home address for home visits; location at the moment of an SOS or fall alert (only when you enable those features)</td></tr>
              <tr><td>Family and emergency contacts</td><td>Names and phone numbers of family members and emergency contacts you add</td></tr>
              <tr><td>Payments</td><td>Amount, status and payment-gateway reference. We never store card or UPI credentials.</td></tr>
              <tr><td>Device and security</td><td>Push-notification token, device name, IP address, sign-in and audit records</td></tr>
              <tr><td>Usage analytics</td><td>Pseudonymous event codes, without health content</td></tr>
            </tbody>
          </table>
        </div>
        <p>
          Some features (wellness mood tracking, wound photos, wearables, fall detection) collect additional data only when you
          choose to use them.
        </p>

        <h2 id="purposes">3. Purposes and consent</h2>
        <p>We process your data for the purposes below. You give or withdraw each consent in the app under Privacy settings.</p>
        <div className="overflow-x-auto">
          <table>
            <thead>
              <tr>
                <th>Purpose</th>
                <th>Required?</th>
                <th>What it covers</th>
              </tr>
            </thead>
            <tbody>
              <tr><td>Terms of use</td><td>Yes</td><td>Accepting the <Link href="/terms">terms of use</Link></td></tr>
              <tr><td>Privacy notice</td><td>Yes</td><td>Acknowledging this policy</td></tr>
              <tr><td>Health data processing</td><td>Yes</td><td>Processing your health data to coordinate your care: profile, episodes, records, visits, plans</td></tr>
              <tr><td>AI assistance</td><td>Optional</td><td>Processing the concerns you type by our AI pipeline, including a third-party AI model provider, and AI summaries of records</td></tr>
              <tr><td>Sharing with clinicians</td><td>Optional</td><td>Sharing your records and clinical snapshot with doctors you book or choose</td></tr>
              <tr><td>Family sharing</td><td>Optional</td><td>Letting family members you invite view or act on your care</td></tr>
              <tr><td>Marketing</td><td>Optional</td><td>Non-care communications</td></tr>
            </tbody>
          </table>
        </div>
        <p>
          Withdrawing a consent stops new processing for that purpose from that moment. Processing done before withdrawal remains
          lawful. Withdrawing a required consent means we can no longer provide the service, and we will offer to close your account.
          We may also process data without consent where the law allows, for example to respond to a medical emergency or to meet a
          legal obligation.
        </p>

        <h2 id="sharing">4. Who we share data with</h2>
        <p>We share only what each recipient needs, under contracts that require confidentiality and security.</p>
        <ul>
          <li><strong>Doctors</strong> you consult, and doctors you share records with (time-limited).</li>
          <li><strong>Home-care providers</strong> assigned to your visit: minimal context, available for 24 hours after the visit.</li>
          <li><strong>Family members</strong> you grant access to, with the permissions you choose. You can revoke access at any time.</li>
          <li><strong>Cloud hosting</strong> (servers located in India) that stores and runs the service.</li>
          <li><strong>SMS and messaging providers</strong> that deliver sign-in codes and generic notifications (no health details).</li>
          <li><strong>Payment gateway</strong> that processes payments. Card and UPI details go directly to the gateway.</li>
          <li><strong>Push notification services</strong> (Google Firebase, Apple) that deliver generic alerts.</li>
          <li><strong>Video consultation provider</strong> that hosts the call room.</li>
          <li>
            <strong>AI model provider</strong> (only if you enable AI assistance): receives the text of your question and minimal
            context to generate a reply. <strong>This provider may process data outside India</strong>, under terms that do not allow
            it to keep your data or use it for training.
          </li>
          <li><strong>Pharmacy and lab partners</strong> (when you place an order): the items, prescription and delivery address.</li>
          <li><strong>Authorities</strong> where the law requires it.</li>
        </ul>

        <h2 id="transfers">5. Where data is stored</h2>
        <p>
          Your data is stored on servers in India, encrypted in transit and at rest. The only planned processing outside India is by
          the AI model provider described above (and global push-notification services, which receive only generic text). Any
          transfer outside India will follow the DPDP Act and any restrictions notified by the Government of India.
        </p>

        <h2 id="retention">6. How long we keep data</h2>
        <p>We keep data only as long as needed for the purpose or as the law requires. Current proposed periods:</p>
        <div className="overflow-x-auto">
          <table>
            <thead>
              <tr>
                <th>Data</th>
                <th>Retention</th>
              </tr>
            </thead>
            <tbody>
              <tr><td>Clinical records, consultation notes, care plans, visit summaries, vitals</td><td>While your account is active, plus at least 3 years after last activity (longer for minors), as medical-record rules require</td></tr>
              <tr><td>AI conversation text</td><td>1 year, then deleted (safety metadata kept for 3 years)</td></tr>
              <tr><td>Safety events, incidents and audit logs</td><td>7 years</td></tr>
              <tr><td>Consent records</td><td>Life of the account plus 7 years</td></tr>
              <tr><td>Payments and invoices</td><td>8 years (tax and accounting law)</td></tr>
              <tr><td>Sign-in codes</td><td>24 hours</td></tr>
              <tr><td>Home-visit provider location pings</td><td>30 days</td></tr>
              <tr><td>Mood entries</td><td>1 year, or until you delete them</td></tr>
              <tr><td>Backups</td><td>Up to 1 year; deletions take effect as backups rotate</td></tr>
            </tbody>
          </table>
        </div>

        <h2 id="rights">7. Your rights</h2>
        <p>Under the DPDP Act you can:</p>
        <ul>
          <li><strong>Access</strong> a summary of your data and how it is processed. Your profile, timeline and records are visible in the app.</li>
          <li><strong>Correct and update</strong> data you entered. For data recorded by a clinician or provider, request a correction through support; the original is kept with the correction.</li>
          <li><strong>Withdraw consent</strong> for any purpose in the app&apos;s privacy settings.</li>
          <li>
            <strong>Erase</strong> your data by deleting your account. See <Link href="/account/delete">Delete your account</Link>. Some
            records must be kept by law, detached from your identity.
          </li>
          <li><strong>Export</strong> a copy of your data from the app.</li>
          <li><strong>Nominate</strong> a person to exercise your rights in case of death or incapacity (contact support).</li>
          <li><strong>Raise a grievance</strong> with our Grievance Officer, and if not resolved, with the Data Protection Board of India.</li>
        </ul>

        <h2 id="children">8. Children and dependents</h2>
        <p>
          The app is for adults. A parent or lawful guardian can add a child as a dependent and manages the child&apos;s care; by doing so
          they give verifiable consent on the child&apos;s behalf. We do not track children&apos;s behaviour or show them targeted
          advertising. An adult dependent who can decide for themselves should give their own consent; we may ask them to confirm by
          OTP.
        </p>

        <h2 id="security">9. Security</h2>
        <p>
          We use encryption in transit (TLS) and at rest, role-based access with multi-factor authentication for staff, malware
          scanning of uploads, and tamper-evident audit logs. If a personal-data breach occurs, we will inform the Data Protection
          Board and affected users as the law requires.
        </p>

        <h2 id="grievance">10. Grievance Officer and contact</h2>
        <p>
          Grievance Officer: <strong>{env.grievanceOfficerName}</strong>
          <br />
          Email: <strong>{env.grievanceOfficerEmail}</strong>
          <br />
          Other ways to reach us are on the <Link href="/support">support page</Link>. We will acknowledge a grievance promptly and
          respond within the period the DPDP Rules set.
        </p>

        <h2 id="changes">11. Changes to this policy</h2>
        <p>
          We will notify you in the app before a material change takes effect. Where a change affects a required consent, we will ask
          you to review and accept it again.
        </p>
      </Prose>
    </PublicLayout>
  );
}
