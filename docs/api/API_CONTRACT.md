# CareCompanion API Contract v1

**This file is the single source of truth shared by `services/api`, `apps/web`, `apps/patient_app` and `apps/provider_app`.**
Any change must be made here first. Clients must not invent endpoints or fields that are not listed here.

- Base URL: `http://localhost:4000/api/v1` (configurable). Android emulator: `http://10.0.2.2:4000/api/v1`.
- JSON everywhere, `camelCase` fields, timestamps ISO-8601 UTC strings (`2026-09-26T09:30:00.000Z`), dates `YYYY-MM-DD`.
- Money: integer **rupees** in API payloads (`fee: 499`). The payment gateway adapter converts to paise internally.
- IDs: UUID strings.
- Auth: `Authorization: Bearer <accessToken>` on every endpoint except `/auth/*`, `/health`, `/ready`, `/webhooks/*`.
- `X-Correlation-Id` request header is optional. The server generates one if missing and always echoes it in the response header.
- `Idempotency-Key` header (any unique string ≤128 chars) is **required** on: `POST /care-episodes`, `POST /appointments`, `POST /home-visits`, `POST /home-visits/:id/vitals`, `POST /pharmacy/orders`, `POST /emergency/sos`, `POST /payments/:id/confirm-mock`. The same key + same user returns the original response (HTTP 200/201 identical body) without re-executing.
- `Accept-Language: en | hi | te` is optional and localizes server-generated text (AI replies, notification text) where available.

## Conventions

### Error format (all non-2xx)
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Human readable", "details": {}, "correlationId": "..." } }
```
Codes: `VALIDATION_ERROR`(400) `UNAUTHENTICATED`(401) `FORBIDDEN`(403) `NOT_FOUND`(404) `CONFLICT`(409) `INVALID_STATE_TRANSITION`(409) `SLOT_UNAVAILABLE`(409) `IDEMPOTENCY_MISMATCH`(422) `RATE_LIMITED`(429) `NOT_SERVICEABLE`(422) `CONSENT_REQUIRED`(403) `INTERNAL`(500) `DEPENDENCY_UNAVAILABLE`(503).

### Lists
```json
{ "items": [ ... ], "nextCursor": "opaque-string-or-null" }
```
Query `?limit=20&cursor=...` (limit max 100). **Every list endpoint uses this envelope.**

### Roles
`patient` (app users, including family caregivers), `doctor`, `provider` (home-care field worker: nurse, technician, intern), `coordinator`, `ops_admin`, `super_admin`.
A user can hold several roles. Family/caregiver access is **not** a role. It is a `FamilyAccessGrant` from one patient to another user, with explicit permissions.

Family permissions: `view_records`, `manage_care` (create episodes, AI, care tasks), `book` (appointments, home visits, orders, payments), `receive_alerts`.

---

## 1. System
| Method | Path | Response |
|---|---|---|
| GET | `/health` | `{ "status": "ok", "version": "1.0.0" }` |
| GET | `/ready` | `{ "status": "ready", "checks": { "db": "ok", "ai": "ok" | "degraded", "safetyRules": "ok" | "fixture" } }` |

## 2. Auth
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/auth/otp/request` | `{ "phone": "+919800000001" }` | `{ "requestId", "expiresAt", "devOtp"?: "123456" }` (`devOtp` only when `NODE_ENV!=production`) |
| POST | `/auth/otp/verify` | `{ "phone", "otp", "deviceName"? }` | `AuthSession` |
| POST | `/auth/refresh` | `{ "refreshToken" }` | `AuthSession` (refresh token is rotated) |
| POST | `/auth/logout` | `{ "refreshToken" }` | `204` |
| GET | `/me` | – | `Me` |
| PATCH | `/me` | `{ "name"?, "language"?: "en"|"hi"|"te", "email"? }` | `Me` |

New phone numbers are auto-registered as `patient` on first verify. A self `Patient` profile is created and `onboardingComplete=false` until the required consents are granted and a name is set.
Staff roles (`doctor`, `coordinator`, `ops_admin`, `super_admin`) additionally get `"mfaRequired": true` in `Me`. The MFA hook is a stub interface in the MVP.
OTP: 6 digits, 5 min expiry, max 5 attempts, rate-limited to 5 requests per phone per 15 min. In dev the OTP is always `123456`.

```ts
AuthSession = { accessToken: string, refreshToken: string, expiresIn: number /*s*/, user: Me }
Me = { id, phone, name: string|null, email: string|null, roles: Role[], language: "en"|"hi"|"te",
       selfPatientId: string|null, onboardingComplete: boolean, mfaRequired: boolean,
       providerId: string|null /* set for doctor & provider roles */ }
```

## 3. Consent
Required consents for onboarding: `terms`, `privacy`, `health_data_processing`. Optional ones: `ai_assistance` (required before using AI endpoints, else `CONSENT_REQUIRED`), `share_with_clinicians`, `family_sharing`, `marketing`.
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/consents/catalog` | – | `{ items: [{ purpose, version, title, description, required: boolean }] }` |
| GET | `/consents` | – | `{ items: Consent[] }` |
| POST | `/consents` | `{ purpose, version }` | `Consent` |
| POST | `/consents/:id/revoke` | – | `Consent` |
```ts
Consent = { id, purpose, version, scope: string, status: "granted"|"revoked", grantedAt, revokedAt: string|null }
```

## 4. Patients & family
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/patients` | – | `{ items: PatientSummary[] }` the patients the caller may act for (self first) |
| POST | `/patients` | `{ name, dob, gender: "male"|"female"|"other", relation: string, bloodGroup? }` | `PatientProfile` (dependent managed by caller; caller receives all permissions) |
| GET | `/patients/:id` | – | `PatientProfile` |
| PATCH | `/patients/:id` | `{ name?, dob?, gender?, bloodGroup?, heightCm?, weightKg? }` | `PatientProfile` |
| POST | `/patients/:id/allergies` | `{ substance, reaction?, severity?: "mild"|"moderate"|"severe" }` | `Allergy` |
| DELETE | `/patients/:id/allergies/:allergyId` | – | 204 |
| POST | `/patients/:id/conditions` | `{ name, since? }` | `Condition` |
| DELETE | `/patients/:id/conditions/:conditionId` | – | 204 |
| POST | `/patients/:id/emergency-contacts` | `{ name, phone, relation }` | `EmergencyContact` |
| DELETE | `/patients/:id/emergency-contacts/:contactId` | – | 204 |
| GET | `/patients/:id/family-access` | – | `{ items: FamilyAccessGrant[] }` |
| POST | `/patients/:id/family-access` | `{ granteePhone, relation, permissions: FamilyPermission[] }` | `FamilyAccessGrant` (grantee user auto-created if the phone is new) |
| POST | `/family-access/:grantId/revoke` | – | `FamilyAccessGrant` (takes effect immediately) |

```ts
PatientSummary = { id, name, dob: string|null, age: number|null, gender, relation: "self"|string, isSelf: boolean,
                   permissions: FamilyPermission[] /* all 4 for self/managed */, avatarUrl: string|null }
PatientProfile = PatientSummary & { phone: string|null, bloodGroup: string|null, heightCm: number|null, weightKg: number|null,
                   allergies: Allergy[], conditions: Condition[], emergencyContacts: EmergencyContact[] }
Allergy = { id, substance, reaction: string|null, severity: string|null, source: Provenance, createdAt }
Condition = { id, name, since: string|null, source: Provenance, createdAt }
EmergencyContact = { id, name, phone, relation }
FamilyAccessGrant = { id, patientId, patientName, granteeUserId, granteeName: string|null, granteePhone, relation,
                      permissions: FamilyPermission[], status: "active"|"revoked", createdAt, revokedAt: string|null }
Provenance = "patient_entered" | "clinician_verified" | "home_visit" | "imported" | "ai_extracted" | "device"
```

## 5. Care Episodes (central object)
States: `NEW → INTAKE → AWAITING_CARE → CARE_SCHEDULED → UNDER_CARE → FOLLOW_UP → RESOLVED`. Exceptional states are `ESCALATED`, `EMERGENCY`, `TRANSFERRED` and `CANCELLED`.
Allowed transitions (enforced in the domain layer; anything else returns `INVALID_STATE_TRANSITION`):
- NEW → INTAKE, AWAITING_CARE, CARE_SCHEDULED, ESCALATED, EMERGENCY, CANCELLED
- INTAKE → AWAITING_CARE, CARE_SCHEDULED, ESCALATED, EMERGENCY, CANCELLED, RESOLVED
- AWAITING_CARE → CARE_SCHEDULED, ESCALATED, EMERGENCY, CANCELLED
- CARE_SCHEDULED → UNDER_CARE, AWAITING_CARE, ESCALATED, EMERGENCY, CANCELLED
- UNDER_CARE → FOLLOW_UP, RESOLVED, ESCALATED, EMERGENCY, TRANSFERRED
- FOLLOW_UP → RESOLVED, CARE_SCHEDULED, UNDER_CARE, ESCALATED, EMERGENCY
- ESCALATED → AWAITING_CARE, CARE_SCHEDULED, UNDER_CARE, EMERGENCY, TRANSFERRED, RESOLVED
- EMERGENCY → TRANSFERRED, UNDER_CARE, RESOLVED
- RESOLVED, CANCELLED, TRANSFERRED are terminal. RESOLVED → FOLLOW_UP is allowed only for `doctor`.

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/care-episodes?patientId=&status=&active=true` | – | list of `CareEpisode` |
| POST | `/care-episodes` 🔑 | `{ patientId, title, concern }` | `CareEpisode` (status NEW) |
| GET | `/care-episodes/:id` | – | `CareEpisodeDetail` |
| POST | `/care-episodes/:id/transition` | `{ to: EpisodeStatus, reason }` | `CareEpisode` |
| POST | `/care-episodes/:id/notes` (doctor) | `{ text }` | `EpisodeEvent` |

```ts
CareEpisode = { id, patientId, patientName, title, concern, status: EpisodeStatus, priority: "routine"|"urgent"|"emergency",
                ownerUserId: string|null, ownerName: string|null, nextAction: string|null, createdAt, updatedAt }
CareEpisodeDetail = CareEpisode & { events: EpisodeEvent[], appointments: Appointment[], homeVisits: HomeVisit[],
                carePlans: CarePlan[], safetyEvents: SafetyEvent[] }
EpisodeEvent = { id, type: string /* e.g. created, status_changed, ai_intake_completed, appointment_booked,
                 home_visit_requested, home_visit_completed, care_plan_created, task_completed, note_added, escalated */,
                 description, actorName: string|null, actorRole: string|null, data: object, createdAt }
```
Events are append-only. Every transition writes an event **and** an audit log entry.

## 6. Doctors, facilities & specialties
| Method | Path | Response |
|---|---|---|
| GET | `/specialties` | `{ items: [{ code, name, icon }] }` codes: `general_physician, dermatologist, pediatrician, gynecologist, cardiologist, orthopedist, psychiatrist, ent, diabetologist, neurologist` |
| GET | `/doctors?specialty=&q=&language=&mode=&availableToday=true` | list of `Doctor` (only `verified` + credential not expired) |
| GET | `/doctors/:id` | `DoctorDetail` |
| GET | `/doctors/:id/slots?date=YYYY-MM-DD` | `{ items: Slot[] }` |
| GET | `/facilities?type=hospital|clinic|lab|pharmacy&q=&lat=&lng=` | list of `Facility` sorted by distance when lat/lng given |

```ts
Doctor = { id, name, specialty, specialtyName, qualifications: string, experienceYears, rating: number, ratingCount,
           languages: string[], fees: { video, audio, chat, inClinic }, photoUrl: string|null, verified: true,
           nextAvailableAt: string|null, availableNow: boolean, facility: { id, name, area } | null,
           rankingFactors: string[] /* explainable: e.g. "Specialty match", "Available today", "Speaks Telugu" */ }
DoctorDetail = Doctor & { bio: string, registrationNumber: string, reviews: [{ id, rating, text, authorLabel, source: "verified_patient", createdAt }] }
Slot = { id, startAt, endAt, status: "available"|"booked"|"held" }
Facility = { id, name, type, address, area, city, phone, lat, lng, distanceKm: number|null, services: string[],
             emergency24x7: boolean, verified: boolean }
```

## 7. Appointments
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/appointments` 🔑 | `{ patientId, doctorId, slotId, mode: "video"|"audio"|"chat"|"in_clinic", reason, careEpisodeId? }` | `{ appointment: Appointment, payment: Payment }` |
| GET | `/appointments?patientId=&scope=upcoming|past` | – | list of `Appointment` |
| GET | `/appointments/:id` | – | `Appointment` |
| POST | `/appointments/:id/cancel` | `{ reason }` | `Appointment` (refund created if paid) |
| POST | `/appointments/:id/reschedule` | `{ slotId }` | `Appointment` |

Slot reservation is concurrency-safe (a unique constraint plus a transactional conditional update). A second booking of the same slot returns `SLOT_UNAVAILABLE`. If `careEpisodeId` is omitted, a Care Episode is created automatically with title = reason. Appointment status starts `pending_payment` and becomes `confirmed` when the payment succeeds. On confirmation the episode moves to `CARE_SCHEDULED`.
```ts
Appointment = { id, patientId, patientName, doctorId, doctorName, doctorSpecialty, doctorPhotoUrl: string|null,
                startAt, endAt, mode, status: "pending_payment"|"confirmed"|"in_progress"|"completed"|"cancelled"|"no_show",
                reason, fee, careEpisodeId, videoRoomUrl: string|null, clinicianNotes: string|null, createdAt }
```

## 8. Home visits
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/home-visit/services` | – | `{ items: [{ code, name, description, price, durationMins, icon }] }` codes: `vitals_check, sample_collection, elderly_care, post_report_consult` |
| POST | `/home-visit/serviceability` | `{ pincode, lat?, lng? }` | `{ serviceable: boolean, zoneId: string|null, zoneName: string|null, message }` |
| POST | `/home-visits` 🔑 | `{ patientId, serviceCode, address: Address, preferredStart, preferredEnd, reason, careEpisodeId? }` | `{ homeVisit: HomeVisit, payment: Payment }` |
| GET | `/home-visits?patientId=&status=&scope=active|past` | – | list of `HomeVisit` |
| GET | `/home-visits/:id` | – | `HomeVisit` (patient/family/provider/doctor/ops views are filtered by role) |
| POST | `/home-visits/:id/cancel` | `{ reason }` | `HomeVisit` |

Provider actions (role `provider`, must be the assigned provider):
| Method | Path | Body |
|---|---|---|
| POST | `/home-visits/:id/accept` | – |
| POST | `/home-visits/:id/reject` | `{ reason }` → visit goes back to `unassigned` and the auto-matcher runs again |
| POST | `/home-visits/:id/en-route` | `{ etaMinutes }` |
| POST | `/home-visits/:id/arrived` | – |
| POST | `/home-visits/:id/verify-identity` | `{ visitCode: "1234", consentConfirmed: true }` → `in_progress` if the code matches |
| POST | `/home-visits/:id/vitals` 🔑 | `{ measurements: [{ type: VitalType, value: number, unit, measuredAt }] }` |
| POST | `/home-visits/:id/observations` | `{ notes, checklist: { [key: string]: boolean|string } }` |
| POST | `/home-visits/:id/escalate` | `{ reason, severity: "urgent"|"emergency" }` → creates a SafetyEvent and moves the episode to ESCALATED/EMERGENCY |
| POST | `/home-visits/:id/complete` | `{ summary }` → a visit_summary MedicalRecord is created and the episode moves to FOLLOW_UP/UNDER_CARE |

Ops action: `POST /home-visits/:id/assign { providerId }` (coordinator/ops_admin).
All provider actions return `HomeVisit`.

Status flow: `requested → assigned → accepted → en_route → arrived → in_progress → completed`. Also `unassigned` (no provider available or rejected), `cancelled` and `escalated` (can still complete).
Auto-match on creation: verified, on-duty `provider` whose service zone covers the pincode, has the service capability configured, and has no overlapping visit. Ties are broken by fewest visits today.

```ts
Address = { line1, line2?: string, landmark?: string, city, pincode, lat?: number, lng?: number }
VitalType = "bp_systolic"|"bp_diastolic"|"pulse"|"spo2"|"temperature"|"blood_glucose"|"weight"|"respiratory_rate"
HomeVisit = { id, status, serviceCode, serviceName, price, patientId, patientName, reason, address: Address,
              preferredStart, preferredEnd, careEpisodeId,
              visitCode: string|null /* ONLY returned to the patient/family, never to the provider */,
              provider: { id, name, qualification, photoUrl: string|null, phoneMasked } | null,
              etaMinutes: number|null,
              timeline: [{ status, at, note: string|null }],
              patientContext: { age, gender, allergies: string[], conditions: string[], activeMedications: string[] } | null /* provider + doctor only */,
              vitals: VitalMeasurement[], observations: { notes, checklist } | null,
              summary: string|null, escalation: { reason, severity, at } | null, createdAt }
```

## 9. Records, timeline & vitals
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/records?patientId=&type=` | – | list of `MedicalRecord` (newest first) |
| POST | `/records` | **multipart/form-data**: `file` (pdf/jpg/png/webp/heic, ≤15MB), `patientId`, `type`, `title`, `recordDate` | `MedicalRecord` |
| GET | `/records/:id` | – | `MedicalRecord` |
| GET | `/records/:id/file` | – | the original file bytes (auth required; audited) |
| POST | `/records/:id/summarize` | – | `MedicalRecord` with `aiSummary` (requires `ai_assistance` consent) |
| POST | `/records/:id/share` | `{ doctorId, expiresInDays }` | `{ id, recordId, doctorId, expiresAt }` |
| GET | `/timeline?patientId=` | – | list of `TimelineItem` (newest first) |
| GET | `/vitals?patientId=&type=` | – | list of `VitalMeasurement` |
| POST | `/vitals` | `{ patientId, type, value, unit, measuredAt }` | `VitalMeasurement` (source `patient_entered`) |

```ts
MedicalRecord = { id, patientId, type: "lab_report"|"prescription"|"imaging"|"discharge_summary"|"visit_summary"|"other",
                  title, recordDate, source: Provenance, uploadedByName: string|null, fileName, mimeType, sizeBytes,
                  hasFile: boolean, aiSummary: { text, model, generatedAt, disclaimer } | null, createdAt }
TimelineItem = { id, kind: "record"|"appointment"|"home_visit"|"vital"|"care_plan"|"episode"|"medication",
                 title, subtitle: string|null, occurredAt, refId, source: Provenance|null }
VitalMeasurement = { id, patientId, type: VitalType, value, unit, measuredAt, source: Provenance, recordedByName: string|null }
```
Original files are immutable. AI summaries are stored separately and never overwrite the original.

## 10. AI Care Assistant
Requires the `ai_assistance` consent for the acting user.
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/ai/conversations?patientId=` | – | list of `Conversation` (messages omitted) |
| POST | `/ai/conversations` | `{ patientId }` | `Conversation` with the greeting message |
| GET | `/ai/conversations/:id` | – | `Conversation` |
| POST | `/ai/conversations/:id/messages` | `{ text, inputMode?: "text"|"voice" }` | `AssistantTurn` |

```ts
Conversation = { id, patientId, patientName, status: "active"|"routed"|"closed", careEpisodeId: string|null,
                 messages: Message[], intake: Intake, createdAt, updatedAt }
Message = { id, role: "user"|"assistant", kind: "text"|"question"|"safety_alert"|"routing"|"info",
            text, quickReplies: string[], createdAt,
            routing?: Routing, safety?: SafetyResult }
AssistantTurn = { messages: Message[] /* new messages only: the user echo + assistant replies */,
                  intake: Intake, safety: SafetyResult, routing: Routing, conversationStatus }
Intake = { chiefComplaint: IntakeField<string>, durationText: IntakeField<string>, severity: IntakeField<number /*0-10*/>,
           associatedSymptoms: IntakeField<string[]>, relevantHistory: IntakeField<string[]>,
           currentMedications: IntakeField<string[]>, allergies: IntakeField<string[]>,
           missingFields: string[], complete: boolean }
IntakeField<T> = { value: T | null, source: "user"|"record"|"model_extraction"|null, confidence: number|null }
SafetyResult = { level: "none"|"routine"|"urgent"|"emergency", triggeredRules: [{ ruleId, title, action }],
                 rulePackVersion: string, rulePackStatus: "approved"|"fixture_unapproved" }
Routing = { action: "continue_intake"|"information"|"book_doctor"|"home_visit"|"emergency",
            suggestedSpecialty: string|null, careEpisodeId: string|null, explanation }
```
Pipeline per message: patient resolution → authorized context (allergies/conditions/meds) → intake extraction → **deterministic safety engine** → reviewed knowledge (RAG) → LLM reply → policy check (no diagnosis labels) → routing → AIInteraction audit.
If the safety level is `emergency`, the assistant reply is replaced by the fixed emergency template (call 108, SOS button). The LLM cannot downgrade the level.
If the AI provider is unavailable, a safe fallback message is returned and routing offers a doctor consultation.

## 11. Care plans, tasks, medications & reminders
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/care-plans?patientId=&careEpisodeId=` | – | list of `CarePlan` |
| POST | `/care-plans` (doctor) | `CarePlanInput` | `CarePlan` (supersedes the previous active plan of the episode) |
| GET | `/care-plans/:id` | – | `CarePlan` |
| GET | `/care-tasks?patientId=&status=open|done|overdue` | – | list of `CareTask` |
| POST | `/care-tasks/:id/complete` | `{ note? }` | `CareTask` |
| GET | `/medications?patientId=&active=true` | – | list of `Medication` |
| POST | `/medications` | `{ patientId, name, dose, frequency, times: ["08:00"], startDate, endDate?, instructions? }` | `Medication` (source `patient_entered`) |
| POST | `/medications/:id/doses` | `{ scheduledAt, status: "taken"|"skipped" }` | `DoseLog` |
| GET | `/reminders/today?patientId=` | – | `{ items: Reminder[] }` |

```ts
CarePlanInput = { careEpisodeId, summary, instructions,
  tasks: [{ type: "medication"|"test"|"follow_up"|"lifestyle"|"monitoring"|"general", title, description?, dueAt?, owner: "patient"|"caregiver"|"provider" }],
  medications: [{ name, dose, frequency, times: string[], startDate, endDate?, instructions? }],
  followUp: { afterDays: number, mode: "video"|"in_clinic"|"home_visit" } | null }
CarePlan = { id, careEpisodeId, patientId, doctorId, doctorName, status: "active"|"completed"|"superseded",
             summary, instructions, tasks: CareTask[], medications: Medication[], followUpDueAt: string|null, createdAt }
CareTask = { id, carePlanId, patientId, type, title, description: string|null, dueAt: string|null, owner,
             status: "open"|"done"|"overdue"|"cancelled", completedAt: string|null, completedByName: string|null }
Medication = { id, patientId, name, dose, frequency, times: string[], startDate, endDate: string|null, instructions: string|null,
               source: Provenance, prescribedByName: string|null, active: boolean,
               today: [{ time, scheduledAt, status: "taken"|"skipped"|"pending"|"missed" }] }
DoseLog = { id, medicationId, scheduledAt, status, loggedAt }
Reminder = { id, kind: "medication"|"task"|"appointment"|"home_visit"|"follow_up", title, subtitle: string|null, at, status: "pending"|"done"|"missed", refId }
```

## 12. Notifications & devices
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/notifications` | – | list of `Notification` + header `X-Unread-Count` |
| POST | `/notifications/:id/read` | – | `Notification` |
| POST | `/notifications/read-all` | – | 204 |
| POST | `/devices` | `{ pushToken, platform: "android"|"ios"|"web" }` | 204 |
| GET | `/notification-preferences` | – | `{ push: boolean, sms: boolean, email: boolean, whatsapp: boolean, marketing: boolean }` |
| PUT | `/notification-preferences` | same | same |
```ts
Notification = { id, title, body, category: "appointment"|"home_visit"|"medication"|"care_plan"|"safety"|"record"|"payment"|"system",
                 critical: boolean, read: boolean, deepLink: string|null /* e.g. "/appointments/<id>" */, createdAt }
```
Push/lock-screen text never contains health details (for example "You have a care update").

## 13. Payments
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/payments?patientId=` | – | list of `Payment` |
| GET | `/payments/:id` | – | `Payment` |
| POST | `/payments/:id/confirm-mock` 🔑 | `{ outcome: "success"|"failure" }` | `Payment` (**dev/mock gateway only**, disabled in production) |
| POST | `/webhooks/payments` | gateway payload, header `X-Signature: hex(HMAC-SHA256(rawBody, PAYMENT_WEBHOOK_SECRET))` | 200 (idempotent on gateway event id) |
| POST | `/payments/:id/refund` (ops_admin) | `{ reason, amount? }` | `Payment` |
```ts
Payment = { id, purpose: "appointment"|"home_visit"|"pharmacy_order", refId, patientId, amount, currency: "INR",
            status: "pending"|"succeeded"|"failed"|"refunded"|"partially_refunded", gateway: "mock"|"razorpay",
            gatewayOrderId, refundedAmount, createdAt }
```

## 14. Pharmacy (partner adapter; UI screen 6)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/pharmacy/categories` | – | `{ items: [{ code, name, icon }] }` |
| GET | `/pharmacy/products?q=&category=` | – | list of `Product` |
| POST | `/pharmacy/orders` 🔑 | `{ patientId, items: [{ productId, qty }], prescriptionRecordId?, address: Address }` | `{ order: PharmacyOrder, payment: Payment }` (`VALIDATION_ERROR` if an Rx product has no prescriptionRecordId) |
| GET | `/pharmacy/orders?patientId=` | – | list of `PharmacyOrder` |
```ts
Product = { id, name, packSize, mrp, price, category, requiresPrescription: boolean, imageUrl: string|null, inStock: boolean }
PharmacyOrder = { id, patientId, items: [{ productId, name, qty, price }], total, status: "pending_payment"|"placed"|"dispatched"|"delivered"|"cancelled", partnerName, createdAt }
```

## 15. Wellness, wound, wearables, fall, emergency
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/wellness/activities` | – | `{ items: [{ code, title, description, durationMins, kind: "breathing"|"meditation"|"journaling"|"sleep" }] }` |
| POST | `/wellness/mood` | `{ patientId, score: 1-5, note?, shareWithClinician: boolean }` | `MoodEntry` + `{ supportMessage, safety: SafetyResult }` |
| GET | `/wellness/mood?patientId=` | – | list of `MoodEntry` |
| POST | `/wound-cases` | multipart: `image`, `patientId`, `bodySite`, `note?` | `WoundCase` |
| GET | `/wound-cases?patientId=` | – | list of `WoundCase` |
| GET | `/wearables/providers` | – | `{ items: [{ code: "apple_health"|"health_connect"|"fitbit"|"samsung_health", name, status: "available"|"coming_soon" }] }` |
| GET | `/wearables/connections?patientId=` | – | `{ items: [{ id, provider, status: "connected"|"revoked", connectedAt, lastSyncAt }] }` |
| POST | `/wearables/connections` | `{ patientId, provider }` | connection |
| POST | `/wearables/connections/:id/revoke` | – | connection |
| POST | `/wearables/sync` | `{ patientId, provider, measurements: [{ type: VitalType|"steps"|"sleep_minutes", value, unit, measuredAt }] }` | `{ accepted: number }` (source `device`) |
| POST | `/fall-events` | `{ patientId, source: "phone_sensor"|"wearable"|"manual", lat?, lng? }` | `FallEvent` (status `awaiting_response`, auto-escalates after `FALL_RESPONSE_TIMEOUT_SEC`) |
| POST | `/fall-events/:id/respond` | `{ safe: boolean }` | `FallEvent` |
| POST | `/emergency/sos` 🔑 | `{ patientId, lat?, lng?, note? }` | `{ sosId, careEpisodeId, helpline: "108", notifiedContacts: [{ name, phoneMasked }], nearestEmergencyFacilities: Facility[] }` |
| GET | `/insights/today?patientId=` | – | `{ items: [{ type: "heart_rate"|"steps"|"sleep"|"bp"|"spo2", label, value, unit, status: string|null, goal: number|null, source, measuredAt }] }` only data that exists (empty list when none) |

```ts
MoodEntry = { id, patientId, score, note: string|null, shareWithClinician, createdAt }
WoundCase = { id, patientId, bodySite, note, status: "retake_required"|"pending_clinician_review"|"reviewed",
              quality: { acceptable: boolean, issues: string[] /* e.g. "image_too_small", "file_too_small" */ },
              clinicianReview: { reviewerName, notes, reviewedAt } | null, imageRecordId, createdAt }
FallEvent = { id, patientId, status: "awaiting_response"|"closed_safe"|"escalated", source, createdAt, respondedAt: string|null }
```
The wound workflow performs **image-quality checks only**. It does not diagnose. Clinical analysis is disabled until a validated model is approved (`feature flag wound_ai_analysis=false`).

## 16. Clinician (role `doctor`)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/clinician/queue?date=YYYY-MM-DD` | – | `{ items: [Appointment & { patientAge, patientGender, episodeStatus, priority }] }` |
| GET | `/clinician/patients?q=` | – | list of `PatientSummary` (patients with an appointment/episode/share with this doctor only) |
| GET | `/clinician/patients/:patientId/snapshot` | – | `ClinicalSnapshot` (access audited) |
| POST | `/clinician/appointments/:id/start` | – | `Appointment` (in_progress; episode → UNDER_CARE) |
| POST | `/clinician/appointments/:id/complete` | `{ notes, outcome: "care_plan"|"resolved"|"refer"|"home_visit" }` | `Appointment` |
| GET | `/clinician/escalations` | – | list of `SafetyEvent` |
| POST | `/clinician/ai-feedback` | `{ aiInteractionId, decision: "accept"|"reject"|"modify", note }` | `{ id }` |
| GET | `/wound-cases/:id` + POST `/wound-cases/:id/review` | `{ notes }` | `WoundCase` |

```ts
ClinicalSnapshot = { patient: PatientProfile, activeEpisodes: CareEpisode[], activeMedications: Medication[],
   recentVitals: VitalMeasurement[], recentRecords: MedicalRecord[], homeVisitFindings: HomeVisit[], moodTrend: MoodEntry[] | null,
   aiSummary: { interactionId, text, advisory: true, model, generatedAt,
                claims: [{ text, sources: [{ kind: "record"|"vital"|"intake"|"home_visit"|"patient_entered", refId, label }] }] } | null,
   intake: Intake | null }
SafetyEvent = { id, patientId, patientName, careEpisodeId, level: "urgent"|"emergency", source: "ai_intake"|"home_visit"|"mood"|"fall"|"sos",
                rules: [{ ruleId, title }], status: "open"|"acknowledged"|"resolved", assignedToName: string|null, createdAt, resolvedAt: string|null, note: string|null }
```

## 17. Provider app (role `provider`)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/provider/me` | – | `{ id, name, type: "nurse"|"technician"|"intern"|"physiotherapist", qualification, verificationStatus: "pending"|"verified"|"rejected"|"suspended"|"expired", credentialExpiresAt, onDuty: boolean, zones: [{ id, name }], capabilities: string[] }` |
| POST | `/provider/duty` | `{ onDuty: boolean }` | same as `/provider/me` |
| GET | `/provider/visits?scope=today|upcoming|completed` | – | list of `HomeVisit` |
| POST | `/provider/location` | `{ lat, lng }` | 204 |

A provider can only read visits assigned to them. Once a visit is completed and 24h have passed, `patientContext` is no longer returned.

## 18. Operations (roles `coordinator`, `ops_admin`, `super_admin`)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/ops/overview` | – | `OpsOverview` |
| GET | `/ops/home-visits?status=` | – | list of `HomeVisit` + `slaBreached: boolean` on each |
| GET | `/ops/providers?status=` | – | list of `OpsProvider` |
| POST | `/ops/providers/:id/verification` (ops_admin) | `{ status: "verified"|"rejected"|"suspended", note }` | `OpsProvider` |
| GET | `/ops/safety-events?status=` | – | list of `SafetyEvent` |
| POST | `/ops/safety-events/:id/acknowledge` | – | `SafetyEvent` |
| POST | `/ops/safety-events/:id/resolve` | `{ note }` | `SafetyEvent` |
| GET | `/ops/care-episodes?status=` | – | list of `CareEpisode` |
| GET | `/ops/overdue-tasks` | – | list of `CareTask & { patientName }` |
| GET | `/ops/incidents?status=` | – | list of `Incident` |
| POST | `/ops/incidents` | `{ type: "complaint"|"incident"|"clinical_incident", title, description, severity: "low"|"medium"|"high"|"critical", patientId?, refType?, refId? }` | `Incident` |
| PATCH | `/ops/incidents/:id` | `{ status?: "open"|"investigating"|"resolved"|"closed", note? }` | `Incident` |
| GET | `/ops/payments?status=` | – | list of `Payment & { patientName }` |

```ts
OpsOverview = { counts: { activeEpisodes, openSafetyEvents, unassignedVisits, lateVisits, activeVisits, overdueTasks,
                todaysAppointments, pendingPayments, openIncidents, providersOnDuty },
                sla: { visitAssignmentMedianMins: number|null, visitOnTimeRate: number|null, safetyAckMedianMins: number|null },
                recentEvents: EpisodeEvent[] }
OpsProvider = { id, name, type, phone, qualification, verificationStatus, credentialExpiresAt, onDuty, status: "offline"|"available"|"on_visit",
                activeVisitId: string|null, zones: string[], visitsToday: number, rating: number|null }
Incident = { id, type, title, description, severity, status, patientId: string|null, patientName: string|null, reportedByName,
             notes: [{ text, authorName, at }], createdAt, updatedAt }
```
A visit is **late** if it has not reached `arrived` by `preferredEnd`. It is **SLA-breached** if it is still `requested`/`unassigned` more than `VISIT_ASSIGN_SLA_MIN` (default 30) minutes after creation.

## 19. Admin (role `super_admin`; `ops_admin` read-only where noted)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/admin/users?q=&role=` | – | list of `{ id, phone, name, roles, createdAt, lastLoginAt, status: "active"|"disabled" }` |
| PUT | `/admin/users/:id/roles` | `{ roles: Role[] }` | user |
| POST | `/admin/users/:id/disable` | – | user (revokes all sessions) |
| POST | `/admin/staff` | `{ phone, name, roles, provider?: { type, qualification, specialty?, registrationNumber, zoneIds, capabilities, credentialExpiresAt } }` | user |
| GET | `/admin/audit-logs?actorId=&entityType=&entityId=&action=` (ops_admin read) | – | list of `{ id, actorId, actorName, actorRole, action, entityType, entityId, outcome: "success"|"denied"|"error", ip, correlationId, metadata, createdAt }` |
| GET | `/admin/safety-rule-packs` | – | list of `{ id, version, status: "draft"|"fixture_unapproved"|"approved"|"retired", active: boolean, approvedBy: string|null, approvedAt, ruleCount, rules: SafetyRule[] }` |
| POST | `/admin/safety-rule-packs` | `{ version, rules: SafetyRule[] }` | pack (status draft) |
| POST | `/admin/safety-rule-packs/:id/approve` | `{ approverName, approverRegistration }` | pack |
| POST | `/admin/safety-rule-packs/:id/activate` | – | pack |
| GET | `/admin/ai-interactions?useCase=&safetyLevel=` | – | list of `{ id, useCase, userId, patientId, model, promptVersion, policyVersion, rulePackVersion, safetyLevel, latencyMs, inputTokens, outputTokens, fallbackUsed, createdAt }` (no raw PHI text) |
| GET | `/admin/knowledge-sources` | – | list of `{ id, title, owner, version, status: "draft"|"approved"|"deprecated", effectiveDate, expiresAt, chunkCount }` |
| POST | `/admin/knowledge-sources` | `{ title, owner, version, effectiveDate, expiresAt?, content }` | source (draft) |
| POST | `/admin/knowledge-sources/:id/status` | `{ status }` | source |
| GET | `/admin/feature-flags` | – | `{ items: [{ key, enabled, description, cohort: string|null }] }` |
| PUT | `/admin/feature-flags/:key` | `{ enabled, cohort? }` | flag |
| GET | `/admin/analytics` (ops_admin read) | – | `Analytics` |
| GET | `/admin/service-zones` / POST | `{ name, city, pincodes: string[] }` | zone |

```ts
SafetyRule = { id, title, description, when: { anyKeywords?: string[], allKeywords?: string[], minSeverity?: number,
               vital?: { type: VitalType, op: "lt"|"gt", value: number }, ageGte?: number }, level: "routine"|"urgent"|"emergency",
               action: "show_emergency"|"escalate_clinician"|"suggest_doctor"|"suggest_home_visit" }
Analytics = { funnel: { conversationsStarted, intakesCompleted, routedToCare, appointmentsBooked, appointmentsCompleted, homeVisitsRequested,
              homeVisitsCompleted, carePlansCreated, episodesResolved },
              continuity: { taskCompletionRate: number|null, followUpCompletionRate: number|null, medicationAdherenceRate: number|null },
              safety: { safetyEventsTotal, emergencyEvents, medianAckMins: number|null, aiFallbackRate: number|null },
              finance: { grossRevenue, refunds, paidEpisodes }, activation: { usersTotal, onboardingCompleted, familyGrants } }
```
Feature flags (seeded): `ai_assistant` (on), `wound_ai_analysis` (off), `fall_detection` (on), `wearables` (on), `pharmacy_orders` (on), `mental_wellness` (on), `govt_schemes` (off), `voice_input` (on), `kill_switch_ai` (off; when on, the AI returns the fallback immediately).

---

## 20. Seed data (dev only, `npm run seed`). All OTPs are `123456`
| Phone | Role | Name / notes |
|---|---|---|
| +919800000001 | patient | **Vaibhav** (24, male). Manages dependent father **Ramesh Kumar** (68, hypertension, type 2 diabetes, allergy penicillin). Onboarding complete, all consents granted |
| +919800000002 | patient | **Lakshmi** (daughter-in-law). Has a family grant on Ramesh with `view_records, receive_alerts` |
| +919800000101 | doctor | Dr. Ananya Rao, General Physician, ₹499 video/audio, ₹399 chat, rating 4.8 (320) |
| +919800000102 | doctor | Dr. Karthik Mehta, Internal Medicine, ₹599 |
| +919800000103 | doctor | Dr. Priya Sharma, Dermatologist, ₹499 |
| +919800000104 | doctor | Dr. Arjun Reddy, Pediatrician (speaks Telugu) |
| +919800000201 | provider | Sunita Devi, nurse (GNM), verified, zone Hyderabad-Central |
| +919800000202 | provider | Ravi Teja, phlebotomy technician, verified |
| +919800000203 | provider | Anil (intern), **credential expired** (must never be matched) |
| +919800000301 | coordinator | Meera (Care Coordinator) |
| +919800000401 | ops_admin | Operations Admin |
| +919800000501 | super_admin | Super Admin |

Service zone "Hyderabad-Central" pincodes: 500001–500040, 500081, 500082, 500084. Pincode `560001` (Bangalore) is **not serviceable**.
Seeded content: slots for all doctors for the next 7 days (09:00–13:00, 14:00–18:00, 30-min), 4 home-visit services (₹499, ₹399, ₹799, ₹599), 12 pharmacy products (incl. Paracetamol 500mg ₹30, Vitamin D3 60K ₹120, Azithromycin 500mg ₹60 Rx), 6 facilities, sample records for Ramesh (Blood Test Report, X-Ray Chest, Prescription, ECG Report), vitals, one active Care Episode with a care plan + tasks + medications (Metformin 500mg 08:00/20:00, Amlodipine 5mg 08:00), one completed home visit, the fixture safety rule pack `fixture-0.1` (status `fixture_unapproved`, active in dev).

---

# v1.1 additions: production readiness (all backwards compatible)

## 21. Public config (no auth)
`GET /config/public` →
```ts
PublicConfig = {
  flags: { ai_assistant, wound_ai_analysis, fall_detection, wearables, pharmacy_orders, mental_wellness, govt_schemes, voice_input: boolean },
  payment: { gateway: "mock"|"razorpay", razorpayKeyId: string|null },
  video: { provider: "jitsi"|"placeholder" },
  push: { enabled: boolean },
  support: { phone: string, email: string, whatsapp: string|null },
  legal: { privacyUrl: string, termsUrl: string, accountDeletionUrl: string },
  minAppVersion: { patientAndroid: string, patientIos: string, providerAndroid: string, providerIos: string }
}
```
Clients read flags from here instead of hard-coding them. If the app version is below `minAppVersion`, show a blocking "Please update" screen.

## 22. Staff MFA (TOTP)
- `Me` gains `mfaEnrolled: boolean` and `mfaVerified: boolean` (whether the current session has passed MFA).
- When `MFA_ENFORCED=true` (default **true in production**, false in dev), staff roles (doctor, coordinator, ops_admin, super_admin) get tokens from `/auth/otp/verify` that can call only `/me`, `/auth/*` and `/config/public`. Every other endpoint returns **403 `MFA_REQUIRED`** until MFA is verified.

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/auth/mfa/totp/enroll` | – | `{ secret, otpauthUrl, qrSvg }` (not allowed if already enrolled → CONFLICT) |
| POST | `/auth/mfa/totp/confirm` | `{ code }` | `{ recoveryCodes: string[10], session: AuthSession }` (session has mfaVerified=true) |
| POST | `/auth/mfa/verify` | `{ code }` or `{ recoveryCode }` | `AuthSession` (mfaVerified=true; recovery codes are single use) |
| POST | `/admin/users/:id/mfa/reset` (super_admin) | – | user (audited) |

Refresh tokens keep the session's mfaVerified state. Wrong codes are rate-limited: 5 attempts per 15 minutes, then `RATE_LIMITED`.

## 23. Account deletion & data export (app store + DPDP requirement)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/me/deletion-request` | – | `DeletionRequest` or 404 |
| POST | `/me/deletion-request` | `{ reason? }` | `DeletionRequest` (status `scheduled`, `scheduledFor` = now + `ACCOUNT_DELETION_GRACE_DAYS` (default 7)) |
| POST | `/me/deletion-request/cancel` | – | `DeletionRequest` (status `cancelled`) |
| POST | `/me/data-export` | – | `DataExport` (generated synchronously in MVP) |
| GET | `/me/data-export/:id/file` | – | `application/json` attachment with the user's profile, managed patients' records metadata, episodes, appointments, visits, care plans, medications, vitals, consents and AI conversation messages |
```ts
DeletionRequest = { id, status: "scheduled"|"cancelled"|"completed", reason: string|null, requestedAt, scheduledFor, completedAt: string|null }
DataExport = { id, status: "ready", createdAt, expiresAt, sizeBytes }
```
When the grace period ends, the worker completes deletion:
- revoke sessions, device tokens and family grants (both directions);
- anonymise the user (name/phone/email replaced);
- delete managed dependents' personal data that isn't under a legal retention hold;
- keep clinical records, payments and audit logs as the retention policy requires, **[REQUIRES LEGAL REVIEW]**, detached from identity.

Staff accounts cannot self-delete (403); an admin disables them. Deletion requests from staff roles are rejected.

## 24. Devices / push
`DELETE /devices` `{ pushToken }` → 204 (call it on logout). Pushes are sent through FCM HTTP v1 when `FCM_PROJECT_ID` and the service-account credentials are configured; otherwise the console adapter is used. The push payload carries only `{ title, body (generic), deepLink, notificationId }`.

## 25. Razorpay checkout
`Payment` gains:
```ts
checkout: { gateway: "razorpay", keyId, orderId, amountPaise, currency: "INR", name: "CareCompanion", description, prefill: { contact: string|null, name: string|null } } | null   // null for the mock gateway
```
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/payments/:id/verify` 🔑 | `{ razorpayPaymentId, razorpayOrderId, razorpaySignature }` | `Payment` (HMAC-SHA256 of `orderId|paymentId` with the key secret is verified server-side; mismatch → 400 VALIDATION_ERROR) |
| POST | `/payments/:id/retry` 🔑 | – | `Payment` with a fresh `checkout` (only when status `failed`/`pending`; mock: resets to pending) |

The webhook (`/webhooks/payments`) handles `payment.captured`, `payment.failed` and `refund.processed` with Razorpay's `X-Razorpay-Signature` header when gateway = razorpay. Clients use the mock flow (`confirm-mock`) when `PublicConfig.payment.gateway = "mock"`.

## 26. Video consultation
`GET /appointments/:id/video-session` → `{ provider: "jitsi"|"placeholder", joinUrl, roomName, token: string|null, opensAt, expiresAt }`
- Allowed for the appointment's doctor, the patient, and family with `manage_care`. Only for `mode` video/audio.
- Available from 10 min before `startAt` until 60 min after `endAt`; otherwise `409 CONFLICT` with `details.opensAt`.
- Jitsi: the room name is unguessable (HMAC of the appointment id). When `JITSI_APP_ID`/`JITSI_APP_SECRET` are set, a JWT is issued (self-hosted/JaaS). The default domain is `meet.jit.si`.
- Audio mode uses the same room with the camera off.

## 27. Uploads
Every uploaded file passes a malware scan (ClamAV `clamd` when `CLAMAV_HOST` is set; otherwise the no-op scanner, allowed only outside production). An infected file → **422 `FILE_REJECTED`**. Files are stored in S3 (SSE-KMS) when `STORAGE_DRIVER=s3`. `/records/:id/file` streams through the API, so clients are unaffected.

## 28. Operations endpoints
- `GET /metrics`: Prometheus format. Protected by the `METRICS_TOKEN` bearer token when set; no auth in dev.
- `/ready` adds `checks.storage` and `checks.worker`.


---

# v1.2 additions: functional completeness (all backwards compatible)

New `Payment.purpose` value: `"subscription"`. All new list endpoints use the standard `{ items, nextCursor }` envelope. New PDFs are generated server-side (pdfkit) and stored through the storage abstraction, as a `MedicalRecord` or an invoice file. They contain only the minimum necessary data.

## 29. Doctor self-management, schedules & photos
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/doctor/me/profile` (doctor) | – | `DoctorDetail & { acceptingBookings: boolean }` |
| PATCH | `/doctor/me/profile` | `{ bio?, languages?, qualifications?, fees?: { video, audio, chat, inClinic }, acceptingBookings? }` | same |
| GET | `/doctor/me/schedule` | – | `Schedule` |
| PUT | `/doctor/me/schedule` | `{ weekly: WeeklyBlock[] }` | `Schedule`. Regenerates **unbooked** future slots for the next `SCHEDULE_HORIZON_DAYS` (default 14). Booked and held slots are never touched. Overlapping blocks → VALIDATION_ERROR. |
| POST | `/doctor/me/leaves` | `{ date: "YYYY-MM-DD", reason? }` | `{ leave: Leave, conflicts: Appointment[] }`. Removes that day's unbooked slots. Existing appointments are **not** auto-cancelled; they are returned as conflicts to reschedule. |
| DELETE | `/doctor/me/leaves/:id` | – | 204 (the day's slots are regenerated from the weekly template) |
| GET/PUT | `/admin/doctors/:doctorId/schedule` (super_admin, ops_admin) | as above | `Schedule` |
| POST | `/me/photo` | multipart `image` (jpg/png/webp ≤ 5 MB, malware-scanned) | `{ photoUrl }`. Sets the caller's profile photo (doctor/provider photoUrl, patient self avatarUrl). |
| GET | `/media/:id` (**public, no auth**) | – | image bytes for **profile photos only** (never medical records), with `Cache-Control: public, max-age=86400` |

```ts
WeeklyBlock = { weekday: 0|1|2|3|4|5|6 /* 0 = Sunday, IST */, start: "HH:MM", end: "HH:MM", slotMins: 10|15|20|30|45|60,
                modes: ("video"|"audio"|"chat"|"in_clinic")[] }
Leave = { id, date, reason: string|null }
Schedule = { weekly: WeeklyBlock[], leaves: Leave[], horizonDays: number, timezone: "Asia/Kolkata" }
```
`photoUrl`/`avatarUrl` are absolute URLs (`${PUBLIC_API_BASE_URL}/media/<id>`). `Slot` gains `modes: string[]`. Doctors with `acceptingBookings=false` are hidden from `/doctors`.

`GET /provider/me` (§17) also returns `photoUrl: string|null`, `rating: number|null` and `ratingCount: number` (from published reviews).

## 30. Provider & doctor onboarding applications
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/provider-applications` (any authenticated user without an open or approved application) | `{ type: "nurse"|"technician"|"intern"|"physiotherapist"|"doctor", fullName, qualification, registrationNumber, registrationCouncil?, specialty? (specialty code; required for doctor), experienceYears, languages: string[], preferredZoneIds: string[] }` | `ProviderApplication` (`submitted`) |
| GET | `/provider-applications/me` | – | `ProviderApplication` or 404 |
| PATCH | `/provider-applications/me` | same fields (only when `submitted`/`changes_requested`; resubmits) | `ProviderApplication` |
| POST | `/provider-applications/me/documents` | multipart `file` (pdf/jpg/png ≤ 10 MB) + `docType: "registration_certificate"|"degree"|"id_proof"|"experience_letter"|"other"` | `ProviderApplication` |
| DELETE | `/provider-applications/me/documents/:docId` | – | `ProviderApplication` |
| GET | `/ops/provider-applications?status=` (coordinator read; ops_admin/super_admin act) | – | list of `ProviderApplication` |
| GET | `/ops/provider-applications/:id` | – | `ProviderApplication` |
| GET | `/ops/provider-applications/:id/documents/:docId/file` | – | file (audited) |
| POST | `/ops/provider-applications/:id/decision` (ops_admin, super_admin) | `{ decision: "approve"|"reject"|"request_changes", note, credentialExpiresAt? (required to approve), zoneIds?, capabilities?: string[] (home-visit service codes) }` | `ProviderApplication`. **approve** creates the verified provider row plus the role (`provider`, or `doctor` for type doctor, with default fees and an empty schedule). Audited; the applicant is notified. Approval requires ≥1 `registration_certificate` and ≥1 `id_proof` document. |

```ts
ProviderApplication = { id, userId, phone, fullName, type, qualification, registrationNumber, registrationCouncil: string|null, specialty: string|null,
  experienceYears, languages: string[], preferredZoneIds: string[], status: "submitted"|"changes_requested"|"approved"|"rejected",
  documents: [{ id, docType, fileName, mimeType, sizeBytes, uploadedAt }], decisionNote: string|null, decidedByName: string|null,
  createdAt, updatedAt, decidedAt: string|null }
```

## 31. e-Prescriptions (role `doctor`)
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/clinician/prescriptions` | `PrescriptionInput` | `Prescription` (201) |
| GET | `/prescriptions?patientId=` | – | list of `Prescription` (patient/family with `view_records`; linked doctors) |
| GET | `/prescriptions/:id` | – | `Prescription` |
| GET | `/prescriptions/:id/pdf` | – | the PDF |
| GET | `/prescriptions/:id/pharmacy-match` | – | `{ items: [{ itemIndex, drugName, product: Product|null }] }` (case-insensitive name/strength match against the catalogue) |

`POST /pharmacy/orders` also accepts `prescriptionId` in place of `prescriptionRecordId`, which satisfies the Rx requirement.
```ts
PrescriptionInput = { appointmentId, clinicalNote?: string, items: RxItem[] /* 1..20 */, advice?: string, followUpInDays?: number }
RxItem = { drugName, strength?: string, form: "tablet"|"capsule"|"syrup"|"injection"|"ointment"|"drops"|"inhaler"|"other",
           dose: string, frequency: string, timing?: string, durationDays: number, times: string[] /* "HH:MM" for reminders */, instructions?: string }
Prescription = { id, patientId, patientName, patientAge: number|null, patientGender, doctorId, doctorName, doctorQualifications, doctorRegistration,
                 appointmentId, careEpisodeId, clinicalNote: string|null, items: RxItem[], advice: string|null, followUpInDays: number|null,
                 recordId, createdAt }
```
Rules:
- The appointment must belong to the calling doctor and be `in_progress` or `completed`.
- Creating a prescription generates a PDF with the doctor's name, qualifications and registration number; the patient's name, age and gender; the date; the items and advice; a "Digitally generated" footer; and a signature line **[REQUIRES LEGAL REVIEW: e-signature rules]**.
- It stores the PDF as a `prescription` MedicalRecord (source `clinician_verified`).
- It creates one `Medication` per item (source `clinician_verified`, endDate from durationDays) so reminders start.
- It appends an episode event and notifies the patient.

## 32. Invoices, earnings & settlements
| Method | Path | Response |
|---|---|---|
| GET | `/payments/:id/invoice` | `Invoice` (status `succeeded`/`refunded`/`partially_refunded` only; else CONFLICT) |
| GET | `/payments/:id/invoice.pdf` | the PDF |
| GET | `/provider/earnings?from=&to=` (doctor or provider; defaults to the current IST month) | `Earnings` for self |
| GET | `/ops/settlements?from=&to=` (ops_admin, super_admin) | list of `Earnings` (one per doctor/provider with activity) |
| GET | `/ops/settlements.csv?from=&to=` | CSV download |
```ts
Invoice = { number /* "CC/2026-27/000123", sequential per Indian financial year */, paymentId, issuedAt, billedTo: { name, phone },
            seller: { legalName, gstin: string|null, address }, lines: [{ description, sacCode: string|null, amount, taxRate, taxAmount }],
            subtotal, tax, total, refundedAmount, currency: "INR" }
Earnings = { providerId, providerName, role: "doctor"|"provider", from, to, completedServices, grossAmount, platformFee, refunds, payable,
             lines: [{ date, description, refType: "appointment"|"home_visit", refId, amount, platformFee, payable }] }
```
Env: `SELLER_LEGAL_NAME`, `SELLER_GSTIN`, `SELLER_ADDRESS`, `HEALTHCARE_GST_RATE` (default 0) **[REQUIRES TAX REVIEW]**, `PLATFORM_FEE_PCT` (default 20). Only completed and paid services count toward earnings.

## 33. Ratings & reviews
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/reviews/pending?patientId=` | – | `{ items: [{ targetType: "appointment"|"home_visit", targetId, title, subtitle, completedAt }] }` (completed within 30 days, not yet reviewed) |
| POST | `/reviews` | `{ targetType, targetId, rating: 1..5, text? (≤1000) }` | `Review`. Only the patient or family with `manage_care`; the service must be completed; one per target (CONFLICT). |
| GET | `/ops/reviews?status=pending|published|rejected` | – | list of `Review` |
| POST | `/ops/reviews/:id/moderate` (coordinator, ops_admin, super_admin) | `{ status: "published"|"rejected", note? }` | `Review` |
```ts
Review = { id, targetType, targetId, doctorId: string|null, providerId: string|null, subjectName, rating, text: string|null,
           status: "pending"|"published"|"rejected", authorLabel: "Verified patient", moderationNote: string|null, createdAt }
```
Rating-only reviews publish immediately. Reviews with text start `pending`. Publishing recalculates the doctor/provider `rating`/`ratingCount`. `DoctorDetail.reviews` shows published reviews only.

## 34. Secure care-team messaging (one thread per Care Episode)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/inbox` | – | list of `InboxThread` (threads the caller participates in, newest first) |
| GET | `/care-episodes/:id/messages?after=<messageId>` | – | `{ items: ChatMessage[] }` (oldest→newest, max 100) |
| POST | `/care-episodes/:id/messages` | `{ text (1..2000), attachmentRecordId? }` | `ChatMessage` (201) |
| POST | `/care-episodes/:id/messages/read` | – | 204 |

Participants:
- the patient, and family with `manage_care`;
- doctors with an appointment in the episode;
- the episode's assigned coordinator;
- `ops_admin`/`super_admin` (they post as "Care team").

Providers are not participants. An attachment must be a record of the episode's patient.
Every patient/family message runs through the safety engine. On `emergency`, a system message with the fixed 108 template is appended and a SafetyEvent is created. Other participants get a generic push ("New message from your care team"). Clients poll every 10 s while a thread is open.
```ts
InboxThread = { careEpisodeId, title, patientId, patientName, lastMessage: string|null, lastSenderName: string|null, lastAt: string|null, unread: number }
ChatMessage = { id, careEpisodeId, senderUserId: string|null, senderName, senderRole: "patient"|"family"|"doctor"|"coordinator"|"care_team"|"system",
                kind: "text"|"emergency_notice"|"system" /* emergency_notice = the fixed 108 safety template */, text, attachmentRecordId: string|null, createdAt }
```

## 35. Care coordinator workspace
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/ops/care-episodes/:id/assign-coordinator` (ops_admin, super_admin; a coordinator may assign themselves) | `{ userId }` (must hold the coordinator role) | `CareEpisode` |
| GET | `/coordinator/caseload` (coordinator) | – | list of `CaseloadItem` (active episodes assigned to the caller, grouped by patient) |
| POST | `/coordinator/contacts` | `{ patientId, careEpisodeId?, channel: "call"|"whatsapp"|"sms"|"home_visit"|"in_app", outcome: "reached"|"no_answer"|"callback_requested"|"escalated", note, followUpAt? }` | `ContactLog` (also appends a `coordinator_contact` episode event) |
| GET | `/coordinator/contacts?patientId=` | – | list of `ContactLog` |

`CareEpisode` gains `coordinatorUserId: string|null, coordinatorName: string|null`.
```ts
CaseloadItem = { patient: PatientSummary, episodes: CareEpisode[], openTasks, overdueTasks, nextFollowUpAt: string|null,
                 lastContactAt: string|null, flags: ("overdue_tasks"|"missed_doses"|"open_safety_event"|"no_contact_7d")[] }
ContactLog = { id, patientId, careEpisodeId: string|null, channel, outcome, note, followUpAt: string|null, coordinatorName, createdAt }
```

## 36. Referrals (role `doctor`)
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/clinician/referrals` | `{ careEpisodeId, facilityId, specialty?, urgency: "routine"|"urgent", reason, clinicalSummary? }` | `Referral`. Generates a referral-letter PDF record, appends an episode event and notifies the patient. |
| GET | `/referrals?patientId=` | – | list of `Referral` |
| PATCH | `/referrals/:id` (the creating doctor, ops) | `{ status: "sent"|"accepted"|"completed"|"cancelled", note? }` | `Referral` |
```ts
Referral = { id, patientId, patientName, careEpisodeId, facility: Facility, specialty: string|null, urgency, reason,
             status: "created"|"sent"|"accepted"|"completed"|"cancelled", letterRecordId, createdByName, createdAt, updatedAt }
```

## 37. Family Care Plan subscriptions
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/subscription-plans` | – | list of `Plan` (active) |
| GET | `/subscriptions/me` | – | `Subscription` or 404 |
| POST | `/subscriptions` 🔑 | `{ planCode, billing: "monthly"|"yearly" }` | `{ subscription: Subscription /* pending */, payment: Payment /* purpose subscription */ }`. Becomes `active` when the payment succeeds. The period is prepaid; auto-renewal via Razorpay Subscriptions is a later adapter, and a renewal reminder goes out 7 days before period end. |
| POST | `/subscriptions/me/cancel` | – | `Subscription` (`cancelAtPeriodEnd=true`) |
| GET, POST, PATCH `/:code` | `/admin/subscription-plans` (super_admin) | `Plan` fields | `Plan` |
```ts
Plan = { code, name, description, priceMonthly, priceYearly, benefits: string[], maxMembers, coordinatorIncluded: boolean, homeVisitDiscountPct: number, active: boolean }
Subscription = { id, planCode, planName, status: "pending"|"active"|"cancelled"|"expired", billing, currentPeriodStart: string|null,
                 currentPeriodEnd: string|null, cancelAtPeriodEnd: boolean, benefits: string[], createdAt }
```
Benefits the API enforces:
- `homeVisitDiscountPct` on home visits for the subscriber's own and managed patients (`HomeVisit` gains `discountApplied: number`; the price and payment reflect it);
- `coordinatorIncluded` auto-assigns an available coordinator to the subscriber's active episodes.

Seed plans (placeholder pricing **[REQUIRES PRICING VALIDATION]**):
- `family_basic`: ₹299/mo, ₹2,999/yr, 4 members, 10% off home visits;
- `family_plus`: ₹699/mo, ₹6,999/yr, 6 members, 15% off home visits, dedicated coordinator.

## 38. Government health schemes (information only)
| Method | Path | Response |
|---|---|---|
| GET | `/schemes?state=` | list of published `Scheme` |
| GET | `/schemes/:id` | `Scheme` |
| GET, POST, PATCH `/:id` | `/admin/schemes` (super_admin) | `Scheme` (incl. drafts) |
```ts
Scheme = { id, name, authority, level: "central"|"state", state: string|null, summary, benefits: string[], eligibilityHints: string[],
           documentsTypicallyNeeded: string[], officialUrl, helpline: string|null, status: "draft"|"published", lastReviewedAt, disclaimer }
```
This is informational only. The app never tells a user they are eligible. The seed has 3 published entries (Ayushman Bharat PM-JAY, Aarogyasri Telangana, CGHS) with official URLs and generic, cautious summaries, marked **[REQUIRES CONTENT REVIEW]**. The `govt_schemes` flag now defaults to **on**.

## 39. ABHA (ABDM Health ID) linking: adapter only
`PATCH /patients/:id` accepts `abhaNumber` (14 digits; stored as `XX-XXXX-XXXX-XXXX`) and `abhaAddress` (`name@abdm` or `name@sbx`). `PatientProfile` gains `abha: { number: string|null, address: string|null, status: "unverified"|"verified" } | null`.
`POST /patients/:id/abha/verify` returns **503 `DEPENDENCY_UNAVAILABLE`** ("ABDM integration pending sandbox certification") while `ABDM_ENABLED=false` (default). The ABDM gateway adapter interface exists but is not connected.

## 40. Device features (client-only; existing endpoints)
- **Wearables**: the patient app reads steps, heart rate, sleep, SpO2, blood pressure, glucose and weight from Google Health Connect (Android) / Apple HealthKit (iOS), with explicit per-type permission. Readings go to `POST /wearables/sync`, and the connection is recorded via `POST /wearables/connections` with provider `health_connect`/`apple_health`.
- **Fall detection**: an on-device accelerometer heuristic (free-fall < 0.5 g → impact > 2.5 g within 1 s → ~2 s stillness). It runs only when the `fall_detection` flag is on and the user opts in, and it triggers the existing `POST /fall-events` confirmation flow. It is a supportive signal, not a medical device.
- **Voice replies**: text-to-speech of assistant messages in the selected language when the user used voice input or enabled "Read replies aloud".
