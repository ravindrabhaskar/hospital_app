# 03 — User Roles and Permissions

Authoritative for authorization. It is implemented in the `services/api` policy layer, **not** in the UI. Every denial path needs a negative test (`12_TEST_STRATEGY.md`). The API contract (`docs/api/API_CONTRACT.md`) defines the endpoints; this file defines who may call them and on whose data.

## 1. Roles

| Role (code) | Who | Application | MFA | Notes |
|---|---|---|---|---|
| `patient` | Any app user, including family caregivers | Patient app | No | Auto-assigned on first OTP verify. Gets a self `Patient`. |
| `doctor` | Registered Medical Practitioner | Web clinician portal | Yes (hook) | `Me.providerId` set. Must be verified and have an unexpired credential to appear in discovery. |
| `provider` | Home-care field worker: nurse, technician, intern, physiotherapist | Provider app | No (device-bound session recommended) | Least privilege: assigned visits only. |
| `coordinator` | Care coordinator (L2 support) | Web ops console | Yes (hook) | Episodes, visits, tasks, incidents; cannot verify providers or refund. |
| `ops_admin` | Operations admin | Web ops console | Yes (hook) | Adds provider verification, refunds, audit-log read, analytics read. |
| `super_admin` | Platform governance | Web admin | Yes (hook) | Roles, staff, rule packs, knowledge, flags, zones. |

- A user may hold **several roles** (for example a doctor who is also a patient). Authorization is evaluated per request against the role that grants the needed permission. Patient-data access still requires a relationship: roles never give blanket access to patient records, except as listed for ops.
- **"Caregiver" is not a role.** Family access is a `FamilyAccessGrant` (§3).
- Staff accounts are created only by `super_admin` (`POST /admin/staff`). Self-registration yields `patient` only.
- `mfaRequired: true` for staff. The MVP ships a stub MFA interface; real TOTP/WebAuthn is a launch gate **[REQUIRES LEGAL REVIEW]** of the privileged-access policy.
- Scope of practice per provider type (nurse vs phlebotomist vs physiotherapist) is **configuration** (`capabilities`), supplied by governance. **[REQUIRES CLINICAL GOVERNANCE]**

## 2. Patient-data access rule (the access-check helper)

Every read or write of patient-scoped data calls a single helper: `assertPatientAccess(actor, patientId, permission)`. Access is granted if **any** of the following holds:

| Path | Condition | Permissions obtained |
|---|---|---|
| Self | `patient.userId == actor.id` | all |
| Manager | Actor created the dependent (`managedByUserId`) | all four family permissions |
| Family grant | Active `FamilyAccessGrant(patientId, grantee=actor)` | only listed permissions |
| Doctor relationship | Doctor has an appointment with the patient, an episode assigned to them, or an unexpired record share | read clinical data; write notes, plans and outcomes for that patient |
| Provider assignment | Provider is assigned to an active visit (or one completed less than 24h ago) for the patient | the minimum `patientContext` for that visit only |
| Ops | `coordinator`/`ops_admin`/`super_admin` | operational data (see matrix); clinical documents only with a documented reason (break-glass, audited) |

Failure returns `403 FORBIDDEN` (or `404` when revealing existence would leak information) and writes an audit entry with `outcome: "denied"`. Revocation (grant revoked, share expired, visit closed, user disabled) takes effect on the **next request**, with no caching of permissions beyond a request.

## 3. Family access permissions

| Permission | Allows | Does not allow |
|---|---|---|
| `view_records` | Read profile, timeline, records and files, vitals, medications, care plans, episodes, appointments and visits | Create/modify anything |
| `manage_care` | Create episodes, use the AI assistant for the patient (grantee needs their own `ai_assistance` consent), complete care tasks, log doses, add vitals/meds/allergies/conditions, upload records | Booking or paying; managing grants |
| `book` | Book/cancel/reschedule appointments, request/cancel home visits, pharmacy orders, payments, SOS | Reading records beyond what is needed to book |
| `receive_alerts` | Receive notifications about the patient (critical safety, visit status, missed doses per preference) | Any data access by itself |

Rules:
- Only the patient themselves (or the managing user for a dependent) can create or revoke grants. Grantees cannot re-share.
- The creator of a dependent (`POST /patients`) receives all four permissions implicitly (it is not a revocable grant). Transfer of management is a manual ops workflow in the MVP.
- Health data that needs more sensitive handling (for example mental-wellness entries) is **not** covered by `view_records` unless `shareWithClinician`/explicit share is set. The exact list of sensitive categories is **[REQUIRES LEGAL REVIEW]** **[REQUIRES CLINICAL GOVERNANCE]**.
- Seed example: Lakshmi holds `view_records, receive_alerts` on Ramesh, so she can view the timeline but cannot book, and `POST /appointments` returns 403.

## 4. Role × resource matrix

Legend: **R** read · **C** create · **U** update/act · **—** denied · *own* = self/managed/granted patients subject to the family permission shown · *rel* = patients with a doctor relationship · *asg* = assigned visits only · (a) = audited access.

| Resource / action | patient (self/managed) | patient (grantee) | doctor | provider | coordinator | ops_admin | super_admin |
|---|---|---|---|---|---|---|---|
| Own account `/me` | RU | RU | RU | RU | RU | RU | RU |
| Consents (own) | RC, revoke | own only | own | own | own | own | own |
| Patient profile | RU | R `view_records`; U `manage_care` | R *rel* | R min context *asg* | R (a) | R (a) | R (a) |
| Allergies/conditions/emergency contacts | RCU | `manage_care` | R *rel*; C (verified) | R in `patientContext` | R | R | R |
| Family grants | RC, revoke | — | — | — | R | R | R |
| Care episodes: list/view | R | `view_records` | R *rel* | — | R | R | R |
| Care episodes: create | C 🔑 | `manage_care` | C *rel* | — | C | C | — |
| Episode transition | limited (cancel) | `manage_care` (cancel) | U *rel* (incl. RESOLVED→FOLLOW_UP) | via visit actions only | U | U | — |
| Episode notes | — | — | C *rel* | — | — | — | — |
| AI conversations | RC (needs `ai_assistance`) | `manage_care` + own consent | R intake/summary *rel* | — | — | R metadata only | R metadata only |
| Doctors/slots/facilities | R | R | R | R | R | R | R |
| Appointments: book/cancel/reschedule | C U | `book` | R *rel*; start/complete | — | R U | R U | R |
| Home visits: request/cancel | C U | `book` | R *rel* | — | R U | R U | R |
| Home visits: assign | — | — | — | — | U | U | U |
| Home visits: accept…complete, vitals, escalate | — | — | — | U *asg* | — | — | — |
| Visit code | R (own visits) | R `book`/`manage_care` | — | **never** | — | — | — |
| Records: list/view/file | R | `view_records` | R *rel*, file (a) | — | R metadata; file only break-glass (a) | same | same |
| Records: upload | C | `manage_care` | C *rel* | via visit summary | — | — | — |
| Records: share with doctor | C | — | — | — | — | — | — |
| Records: AI summarize | C (consent) | `manage_care` | R | — | — | — | — |
| Vitals | RC | R/C per permission | R *rel* | C *asg* | R | R | R |
| Care plans | R | `view_records` | C R *rel* | — | R | R | R |
| Care tasks: complete | U | `manage_care` | U | U (provider-owned tasks) | R | R | R |
| Medications / doses | RCU | R `view_records`; U `manage_care` | R *rel* (via plan C) | R in context | R | R | R |
| Pharmacy orders | C R | `book` | — | — | R | R | R |
| Payments: view | R own | `book` | — | — | R | R | R |
| Payments: refund | — | — | — | — | — | U | U |
| Payments: confirm-mock (dev only) | U | `book` | — | — | — | — | — |
| Emergency SOS | C | `book` or `manage_care` | — | via visit escalate | — | — | — |
| Wellness mood | RC | `view_records` excludes mood unless shared | R only if `shareWithClinician` | — | — | — | — |
| Wound cases | RC | `manage_care` | R, review *rel* | — | — | — | — |
| Wearables/fall events | RC | `manage_care` / `receive_alerts` | R *rel* | — | R fall events | R | R |
| Clinician queue/snapshot | — | — | R (a) *rel* | — | — | — | — |
| AI feedback/override | — | — | C | — | — | — | — |
| Safety events: view | own (in episode) | `view_records` | R *rel* + escalations inbox | own escalations | R | R | R |
| Safety events: acknowledge/resolve | — | — | U *rel* | — | U | U | U |
| Provider self `/provider/*` | — | — | — | RU | — | — | — |
| Ops overview/queues | — | — | — | — | R | R | R |
| Provider verification | — | — | — | — | — | U | U |
| Incidents | C (complaint via support) | — | C | C (via escalate) | RCU | RCU | RCU |
| Notifications/preferences/devices | RU own | own | own | own | own | own | own |
| Users/roles/staff | — | — | — | — | — | R | RCU |
| Disable user | — | — | — | — | — | — | U |
| Audit logs | — | — | — | — | — | R | R |
| Safety rule packs: create/approve/activate | — | — | — | — | — | R | C U (approve needs approver identity) |
| Knowledge sources | — | — | — | — | — | R | C U |
| AI interactions log (no raw PHI) | — | — | — | — | — | R | R |
| Feature flags / kill switch | — | — | — | — | — | R | U |
| Analytics | — | — | — | — | — | R | R |
| Service zones | — | — | — | — | — | R | C U |

Notes:
- **Rule-pack approval:** the API records `approverName` and `approverRegistration`. The software cannot verify that the approver is actually the clinical governance lead, so the human process in `07_CLINICAL_SAFETY_INTERFACE.md` §5 is mandatory **[REQUIRES CLINICAL GOVERNANCE]**. Recommended: a separate `clinical_approver` permission and two-person rule (open decision D-Q10).
- **Break-glass:** ops access to clinical documents requires a reason string and creates a high-visibility audit entry reviewed weekly. The MVP exposes metadata only in ops endpoints.
- **Provider patient context** is the minimum necessary: age, gender, allergies, conditions, active medications, address and reason. It disappears 24h after completion. Records, timeline and other episodes are never visible.

## 5. Consent gates (in addition to RBAC)

| Action | Consent required (acting user) | Enforcement in v0.1 |
|---|---|---|
| Completing onboarding (`onboardingComplete`) | `terms`, `privacy`, `health_data_processing` | Contract-defined |
| `/ai/*`, `/records/:id/summarize` | `ai_assistance` | Contract-defined → `CONSENT_REQUIRED` |
| Record share to doctor | `share_with_clinicians` (patient) | **Target policy.** Not yet enforced by the contract; tracked in `KNOWN_LIMITATIONS.md` |
| Creating family grants | `family_sharing` (patient/manager) | **Target policy.** Not yet enforced; tracked |
| Marketing messages | `marketing` | Suppressed when absent |

The target policies need a contract change in `API_CONTRACT.md` before they are enforced. **[REQUIRES LEGAL REVIEW]** covers the final purpose-to-action mapping.

## 6. Sessions

Access-token lifetime is short (`expiresIn`, recommended 15 min). Refresh tokens rotate on every use; reuse of a rotated token revokes the session family. `POST /admin/users/:id/disable` revokes all sessions. Logout revokes the presented refresh token. Staff sessions must be shorter-lived and require MFA once implemented.
