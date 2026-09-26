# 09 — Privacy and Consent

> Orientation to the **Digital Personal Data Protection Act, 2023 (DPDP Act)** and the DPDP Rules as notified. This is an engineering design document, **not legal advice**. Every legal characterization below is **[REQUIRES LEGAL REVIEW]** by India-qualified privacy/healthcare counsel before the pilot. Other regimes to assess: IT Act 2000 and SPDI Rules 2011 (transition), NMC Telemedicine Practice Guidelines 2020, ABDM Health Data Management Policy (for ABDM integration), and CERT-In directions (6-hour incident reporting).

## 1. Principles (built into the product)

1. **Consent before processing and sharing.** Purpose-specific, versioned, revocable, recorded in a ledger.
2. **Purpose limitation and data minimization.** Collect only what the flagship care journey needs. Remove fields that have no purpose.
3. **Least privilege.** RBAC + relationship checks (`03_USER_ROLES_AND_PERMISSIONS.md`); the provider sees minimum context for 24h only.
4. **Transparency.** Users can see who accessed their data (access history, P1 screen; the audit log exists in the MVP).
5. **Control.** Grant/revoke family access; revoke consents; correction, restriction, export and erasure requests.
6. **Security.** Encryption in transit (TLS 1.2+) and at rest (RDS/S3 KMS), tamper-evident audit, secrets management.
7. **No secondary use.** No model training, advertising or sale of health data. Analytics use aggregated/pseudonymized events.

## 2. DPDP roles (orientation)

| DPDP concept | CareCompanion mapping | Review |
|---|---|---|
| Data Principal | Patient (incl. dependents); for a child, the parent/lawful guardian | **[REQUIRES LEGAL REVIEW]**: children's data (verifiable parental consent) and persons with disability (lawful guardian); elderly dependents who retain capacity must consent themselves |
| Data Fiduciary | CareCompanion operating entity | Possible Significant Data Fiduciary designation (health data volume/sensitivity) → DPO, DPIA, audits **[REQUIRES LEGAL REVIEW]** |
| Data Processor | Cloud (AWS), AI vendor (Anthropic), SMS/WhatsApp, payment gateway, maps, video | DPAs with each; cross-border transfer assessment **[REQUIRES LEGAL REVIEW]** |
| Independent clinicians/partners | Doctors, home-care agencies, labs, pharmacies | Controller/processor allocation in contracts **[REQUIRES LEGAL REVIEW]** |
| Consent Manager | Not in MVP; ABDM consent flows later | — |
| Grievance redressal | In-app support + named Grievance Officer; response timelines per Rules | **[REQUIRES LEGAL REVIEW]** |

**Dependents managed by a family member:** creating a dependent profile (`POST /patients`) does not by itself establish lawful consent from an adult dependent. The pilot flow needs an attestation plus, where feasible, the dependent's own OTP confirmation. **[REQUIRES LEGAL REVIEW]**. Open decision D-Q6.

## 3. Consent purposes (from the API contract)

| Purpose code | Required | What it covers | Revocation effect |
|---|---|---|---|
| `terms` | Yes | Terms of Service acceptance | Account can no longer be used; triggers the closure flow |
| `privacy` | Yes | Privacy notice acknowledgement (notice in en/hi/te) | Same as above |
| `health_data_processing` | Yes | Processing health data to provide care coordination (profile, episodes, records, visits, plans) | Core service stops. Data is retained only as legally required (§6). Closure flow offered. |
| `ai_assistance` | Optional (required for AI) | Processing concern text by the AI pipeline, including the third-party model provider; AI record summaries | AI endpoints return `CONSENT_REQUIRED`; no new AI processing; existing AI outputs stay (labelled) unless erasure is requested |
| `share_with_clinicians` | Optional | Sharing records and snapshots with doctors the patient books or shares with | New shares blocked. Existing shares remain until they expire unless the patient revokes them individually (P1: cascade). |
| `family_sharing` | Optional | Creating grants so family members can view or act | New grants blocked. Existing grants are managed individually (revocation per grant is immediate). |
| `marketing` | Optional | Non-care communications | Marketing suppressed immediately |

Ledger rules: `(userId, purpose, version, scope, status, grantedAt, revokedAt)`. A new version of a notice requires re-consent at next login for required purposes. Consent records are never deleted (proof of consent). Consent text is versioned in `/consents/catalog` and must be approved **[REQUIRES LEGAL REVIEW]**.

Workflow-specific consent: provider identity plus consent confirmation at the doorstep (`verify-identity { consentConfirmed }`), wound image storage, mood sharing (`shareWithClinician`), location sharing on SOS/fall, and wearable connections (per provider, revocable).

## 4. Data map

| Category | Examples | Purpose | Source | Stored in | Accessed by |
|---|---|---|---|---|---|
| Identity & contact | phone, name, email, language | Auth, communication | User | RDS `users` | Self, ops (masked phone to providers) |
| Demographics | DOB, gender, blood group, height/weight | Clinical context | User/family | RDS `patients` | Self, grantees, related doctors, provider (age/gender only) |
| Health history | allergies, conditions, medications | Safety context, clinician snapshot | User, clinician, home visit | RDS | Self, grantees (`view_records`), related doctors, provider (visit context) |
| Care episodes & events | concern, status, events | Coordination | System | RDS | Self, grantees, doctors, ops |
| AI conversations | message text, intake | AI navigation | User | RDS (encrypted text table) | Self, grantees (`manage_care`), related doctor (intake/summary) |
| Vitals | BP, pulse, SpO₂, glucose… | Assessment | Provider, user, device | RDS | Self, grantees, doctors |
| Medical records | PDFs/images, AI summaries | Longitudinal context | User, provider, clinician | S3 (SSE-KMS) + RDS metadata | Self, grantees, shared/related doctors |
| Location/address | home address, lat/lng, provider GPS | Visit fulfilment, SOS | User, provider device | RDS | Assigned provider (visit), ops |
| Payments | amount, status, gateway order ID (no card data) | Commerce | Gateway | RDS | Self, `book` grantees, ops |
| Sensitive wellness | mood score/notes | Wellness (flagged) | User | RDS | Self; clinician only if shared |
| Wound images | photos | Clinician review (flagged) | User | S3 | Self, reviewing clinician |
| Provider data | credentials, registration, bank (settlement, P1), GPS | Credentialing, dispatch | Provider, ops | RDS/S3 | Ops |
| Audit & security | actor, action, IP, correlation ID | Accountability | System | RDS append-only (+ archive) | ops_admin, super_admin |
| Device tokens | push tokens | Notifications | Device | RDS | System |
| Analytics events | pseudonymous IDs, event codes | Product metrics | System | Analytics store (aggregated) | Product/ops |

Voice: audio is transcribed on-device or via STT and **not retained** by default.

## 5. Access, correction, restriction, export, erasure

| Right | MVP mechanism | Target |
|---|---|---|
| Access/summary | In-app profile, timeline, records; audit-backed access history on request | Self-serve access log (P1) |
| Correction | Patient edits patient-entered data. Clinician-verified or provider data: a correction request to support creates a new version with the original kept. | In-app request flow (P1) |
| Restriction | Record restriction hides the record from grantees/doctors (kept for audit) | — |
| Export | Support-assisted export (JSON + original files) within a legal timeline | Self-serve export (P1); FHIR export with ABDM (P2) |
| Erasure / account closure | Support-assisted: revoke all grants/sessions, delete or anonymize per the retention table, keep records required by law | Automated closure workflow (P1) |
| Grievance | In-app support + Grievance Officer email | — |
| Nomination (DPDP) | Not in MVP | **[REQUIRES LEGAL REVIEW]** |

## 6. Retention (proposed; every value **[REQUIRES LEGAL REVIEW]**)

| Data category | Proposed retention | Basis / note |
|---|---|---|
| Clinical records, consult notes, care plans, visit summaries, vitals | Active account + 3 years after last activity (minimum); adult clinical records often recommended 3+ years, minors until majority + period | Medical-record retention norms (MCI/NMC regulations, state rules) |
| Original uploaded documents | Same as clinical records | Immutable originals |
| AI conversation text (encrypted) | 1 year, then delete text and keep metadata | Minimization; kept for safety review |
| AIInteraction metadata | 3 years | Safety auditability |
| Safety events & incidents | 7 years | Clinical/legal defence |
| Audit logs | 7 years (hot 1 year, then archived to S3 Glacier with Object Lock) | Accountability |
| Consent ledger | Life of account + 7 years | Proof of consent |
| Payments/invoices | 8 years | Tax/accounting law |
| OTP requests | 24 hours | Security |
| Session/refresh tokens | Until expiry + 30 days | Security |
| Provider GPS pings | 30 days | Dispute resolution |
| Push tokens | Until invalid/logout | — |
| Mood entries | 1 year or until the user deletes | Sensitive |
| Wound images | As clinical records if clinician-reviewed; else 1 year | — |
| Application logs (no PHI) | 30–90 days | Operations |
| Backups | 35 days PITR + monthly snapshots 1 year | DR; deletion propagates on rotation |

## 7. Revocation semantics

- **Family grant revoke** (`POST /family-access/:grantId/revoke`): immediate. The next request by the grantee is denied. Pending notifications for that patient are cancelled. Audited. The patient is notified.
- **Consent revoke**: immediate effect on new processing. Processing already done stays lawful. Downstream processors are notified where relevant (for example the AI vendor has no retention by contract).
- **Record share expiry/revoke**: doctor access ends at `expiresAt`.
- **Provider**: access to `patientContext` ends 24h after visit completion, or immediately on reassignment or suspension.
- **User disabled**: all sessions revoked.

## 8. Audit requirements

For every sensitive action record who (actor, role), what (action, entity), when, where (IP, device, correlation ID), on which patient, for what purpose, permission path (self / manager / grant / relationship / break-glass), outcome (success/denied/error), and before/after hash where applicable. Sensitive actions include: login/OTP/refresh/logout; consent grant/revoke; grant create/revoke; record upload/view/**file download**/share/summarize; snapshot view; episode transition; visit assign/verify/vitals/escalate/complete; plan create; payment/refund; role/staff changes; flag flips; rule-pack approve/activate; knowledge-source status; ops safety acknowledge/resolve; break-glass access. The audit table is append-only (DB role without UPDATE/DELETE, hash chain) and is reviewed weekly (break-glass, denied spikes).

## 9. Breach response

See `docs/runbooks/INCIDENT_RESPONSE.md` and `docs/runbooks/OPERATIONS_RUNBOOK.md` §7. DPDP requires intimation to the Data Protection Board and affected Data Principals. CERT-In requires reporting of specified incidents within 6 hours. Exact timelines and content are **[REQUIRES LEGAL REVIEW]**.

See also `docs/DATA_PRIVACY.md` (operational data-privacy register).
