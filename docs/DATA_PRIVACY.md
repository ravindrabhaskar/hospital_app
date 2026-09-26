# Data Privacy Register

Operational companion to `docs/product/09_PRIVACY_CONSENT.md`, which holds the policy: consent purposes, rights, retention and revocation. This register records **what data we hold, where, why, who processes it, and the controls**, and serves as the input for a DPIA. All legal characterizations are **[REQUIRES LEGAL REVIEW]** under the DPDP Act 2023 and Rules.

## 1. Data inventory (field level, core tables)

| Store / table | Fields | Category | Purpose | Consent / basis | Min-necessary notes | Retention ref |
|---|---|---|---|---|---|---|
| users | phone, name, email, language, roles, lastLoginAt | Identity/contact | Account, auth, communication | `terms`, `privacy` | Email optional | Account life |
| otp_requests | phone hash, code hash, attempts, expiresAt | Security | Auth | Legitimate use (auth) | Codes hashed | 24h |
| sessions / refresh_tokens | token hash, device name, ip, expiresAt | Security | Session management | same | Hash only | Expiry + 30d |
| consents | purpose, version, scope, status, timestamps | Proof of consent | Compliance | — | — | Account + 7y |
| patients | name, dob, gender, relation, blood group, height, weight, managedBy | Health-adjacent demographics | Care context | `health_data_processing` | Height/weight optional | Clinical |
| allergies, conditions | substance/name, reaction, severity, since, source | Health | Safety context, snapshot | same | — | Clinical |
| emergency_contacts | name, phone, relation | Third-party personal data | Emergency notification | same (+ notice to contact **[REQUIRES LEGAL REVIEW]**) | Only name/phone/relation | Account life |
| family_access_grants | patient, grantee, permissions, status | Access control | Family coordination | `family_sharing` (target) | — | Account + 7y (audit) |
| care_episodes / events | title, concern, status, priority, event data | Health | Coordination | `health_data_processing` | Event `data` holds IDs and codes | Clinical |
| conversations / messages | text (encrypted), intake | Health (free text) | AI navigation | `ai_assistance` | Only the resolved patient's context | Text 1y; metadata 3y |
| ai_interactions | versions, safety level, tokens, latency, source IDs | Audit | Safety traceability | Legitimate use (safety) | No raw text in list views | 3y |
| appointments | patient, doctor, slot, mode, reason, notes, outcome | Health | Consultation | `health_data_processing` | — | Clinical |
| home_visits | address, lat/lng, window, reason, provider, visit code (hashed), observations, summary, escalation | Health + location | Home care | same | Provider sees context for 24h only | Clinical; GPS 30d |
| vitals | type, value, unit, measuredAt, source | Health | Clinical context | same | — | Clinical |
| medical_records + S3 objects | metadata, file, sha256, AI summary | Health documents | Longitudinal context | same; summary `ai_assistance` | Presigned access ≤ 5 min | Clinical |
| record_shares | record, doctor, expiresAt | Access control | Sharing | `share_with_clinicians` (target) | Time-bound | Audit |
| care_plans / tasks / medications / dose_logs | plan text, tasks, meds, adherence | Health | Continuity | `health_data_processing` | — | Clinical |
| safety_events | level, source, rules, notes | Health + safety | Escalation | Legitimate use (vital interest / safety) **[REQUIRES LEGAL REVIEW]** | — | 7y |
| notifications / devices | title, body (generic), push token | Communication | Delivery | `terms`; `marketing` for promotions | No health details in the body | 1y / until invalid |
| payments / refunds / webhook_events | amount, status, gateway IDs, payload hash | Financial | Billing | Contract | **No card/UPI credentials stored** | 8y |
| providers / credentials | registration no., qualification, evidence refs, zones, bank (P1) | Professional personal data | Credentialing | Contract with provider | — | Engagement + 7y |
| incidents | description, notes, patient link | Operational/health | Quality and safety | Legitimate use | Avoid unnecessary clinical detail | 7y |
| audit_logs | actor, action, entity, patient, ip, correlation, outcome | Security | Accountability | Legal obligation / legitimate use | No payload PHI | 7y |
| mood_entries (flag) | score, note, shareWithClinician | Sensitive health | Wellness | `health_data_processing` + explicit share | Default not shared | 1y |
| wound_cases (flag) | image, body site, note, review | Health images | Clinician review | same | — | Clinical / 1y |
| wearable connections / device vitals (flag) | provider, status, measurements | Health (device) | Trends | Per-connection permission | Source `device` | Clinical |
| fall_events / sos (flag) | location, timestamps, status | Health + location | Safety | Workflow consent on enabling | Location only at the event | 7y (safety) |
| analytics events | pseudonymous IDs, event codes, timestamps | Usage | Product metrics | Legitimate use / consent per counsel | No health payloads | 2y aggregated |

## 2. Processors and recipients register

| Recipient | Role | Data shared | Location | Safeguards | Status |
|---|---|---|---|---|---|
| AWS (ap-south-1) | Processor (hosting) | All | India | DPA, KMS, VPC | Proposed |
| Anthropic (Claude API) | Processor (AI) | Conversation text, minimal context, record text for summaries | Outside India (verify) | Zero-retention / no-training terms, minimization | **Needs legal review (Q-09)** |
| Razorpay (planned) | Processor / independent (payments) | Amount, order ID, phone/email for receipts | India | PCI-DSS on their side; no card data with us | Adapter only |
| SMS/WhatsApp provider (TBD) | Processor | Phone, generic templates | TBD | DLT templates, no health details | TBD |
| FCM / APNs | Processor | Push token, generic text | Global | Generic text only | Planned |
| Maps provider (TBD) | Processor | Address/coordinates | TBD | Minimize | TBD |
| Doctors, home-care agencies | Recipients (independent professionals / processors per contract) | Snapshot, visit context | India | Contracts, confidentiality, least privilege | Contracts pending |
| Pharmacy/lab partners (flag) | Recipients | Order items, prescription record, address | India | Partner agreements | Pending |
| ABDM (future) | Health information exchange | Consent-based records | India | ABDM policies | Not integrated |

## 3. Data flows (summary)

1. **Onboarding:** phone → OTP → consents → profile (patients table).
2. **AI:** user text → API → safety engine (local) → LLM vendor (text + minimal context) → reply → encrypted storage + AIInteraction metadata.
3. **Booking/payment:** API → gateway order → webhook → confirmation → notification (generic).
4. **Home visit:** request (address) → matching → provider app (minimum context) → vitals/observations → visit summary record → doctor snapshot.
5. **Records:** upload → scan (prod) → S3 (KMS) → metadata → optional AI summary (vendor) → share with doctor (time-bound).
6. **Family:** grant → grantee reads/acts per permission → alerts (generic push; details in-app after auth).

## 4. Data subject request (DSR) log

| Date received | Request type | Principal (pseudonymous ID) | Verified identity | Due date | Completed | Handler | Notes |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — |

## 5. DPIA summary (to complete with counsel)

| Risk | Likelihood | Severity | Mitigation | Residual |
|---|---|---|---|---|
| Unauthorized family access to a dependent's data | M | H | Explicit grants, immediate revocation, audit, dependent consent flow (Q-06) | M until Q-06 |
| Excess provider access | M | H | Assigned-visit scope, 24h expiry, minimal fields | L |
| AI vendor processing of health text | M | H | Consent, minimization, zero-retention, legal assessment | **Open** |
| Breach of record files | L | H | Private S3, KMS, presigned URLs, audit, scanning | L |
| Re-identification from analytics | L | M | Pseudonymous IDs, no health payloads, aggregation | L |
| Retention beyond need | M | M | Retention jobs (to build), backups rotation | M until built |

**Minimization reviews:** before the pilot and every quarter, review each field above against the flagship journey and remove fields that have no active purpose.
