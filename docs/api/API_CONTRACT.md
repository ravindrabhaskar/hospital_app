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
| GET | `/provider/me` | – | `{ id, name, type: "nurse"|"technician"|"intern"|"physiotherapist"|"dietitian", qualification, verificationStatus: "pending"|"verified"|"rejected"|"suspended"|"expired", credentialExpiresAt, onDuty: boolean, zones: [{ id, name }], capabilities: string[] }` |
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
  minAppVersion: { patientAndroid: string, patientIos: string, providerAndroid: string, providerIos: string, doctorAndroid: string, doctorIos: string }
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
                 lastContactAt: string|null, flags: ("overdue_tasks"|"missed_doses"|"open_safety_event"|"no_contact_7d"|"missed_checkin"|"program_breach")[] }
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


---

# v1.3 additions: growth & care-program features (all backwards compatible)

Conventions as before: `{ items, nextCursor }` lists, 🔑 = `Idempotency-Key` required, and every sensitive action is audited.

**Partner integrations** (WhatsApp, lab, ambulance, ABDM, drug database, telephony, SOS button, speech-to-text) each sit behind an adapter interface with:
- a **mock partner** that is the default outside production and simulates realistic flows through the worker;
- a real adapter enabled by env credentials;
- a refusal to start in production while the mock is configured, except where noted.

**Clinical content** (program thresholds, interaction packs, preventive schedules, exercise and diet templates) is versioned data with `status: "fixture_unapproved"|"approved"`. Fixtures are clearly labelled **[REQUIRES CLINICAL GOVERNANCE]**, and production refuses to use unapproved packs (the same model as the safety rule packs, §19).

New roles:
- `hospital_staff`: linked to one facility; can use the §59 discharge endpoints and read their facility's discharged patients;
- `support_agent`: can use the §61 support desk.

Coordinators and ops admins can also act on support tickets.

New provider types: `dietitian` (plus the existing `physiotherapist`).

New `SafetyEvent.source` values: `"checkin"`, `"program"`, `"geofence"`, `"sos_button"`. New `Payment.purpose` values: `"lab_order"`, `"second_opinion"`, `"ambulance"`. New `Notification.category` values: `"program"`, `"checkin"`, `"lab"`, `"support"`, `"insurance"`, `"preventive"`.

## 41. Daily "I'm OK" check-in
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/patients/:id/checkin-settings` | – | `CheckinSettings` |
| PUT | `/patients/:id/checkin-settings` (`manage_care`) | `CheckinSettings` minus `patientId` | `CheckinSettings` |
| POST | `/patients/:id/checkins` (patient or `manage_care`) | `{ mood?: 1..5, note? }` | `CheckIn` (the day's status becomes `ok`, or `late` if after the window) |
| GET | `/patients/:id/checkins?days=30` | – | list of `CheckIn` (one per day, including missed days) |
```ts
CheckinSettings = { patientId, enabled, windowStart: "HH:MM", windowEnd: "HH:MM", escalateAfterMins: number, notifyFamily: boolean, notifyCoordinator: boolean }
CheckIn = { id, patientId, date, status: "ok"|"late"|"missed"|"pending", checkedInAt: string|null, mood: number|null, note: string|null }
```
Worker behaviour:
- At `windowEnd` (IST) with no check-in, the day becomes `missed` and family with `receive_alerts` get a push/WhatsApp ("{name} hasn't checked in today").
- After `escalateAfterMins` more, an `urgent` SafetyEvent (source `checkin`) is created and assigned to the coordinator.
- A later check-in the same day resolves it automatically.
- Seed: enabled for Ramesh, 08:00–10:00.

## 42. Chronic care programs (remote monitoring)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/care-programs/templates` | – | list of `ProgramTemplate` (codes `hypertension`, `diabetes`, `heart_failure`) |
| POST | `/care-programs/enrollments` (doctor; coordinator only with thresholds from an approved template) | `{ patientId, templateCode, thresholds?: Threshold[], startDate, endDate?, careEpisodeId? }` | `Enrollment` |
| GET | `/care-programs/enrollments?patientId=` | – | list of `Enrollment` |
| PATCH | `/care-programs/enrollments/:id` (doctor) | `{ status?: "active"|"paused"|"completed", thresholds? }` | `Enrollment` |
| GET | `/care-programs/enrollments/:id/summary?from=&to=` | – | `ProgramSummary` |
| GET/POST | `/admin/care-programs/templates` (POST with an existing code creates its next version) + `POST /admin/care-programs/templates/:code/approve` (super_admin) | – | templates |
```ts
ProgramTemplate = { code, name, description, metrics: [{ type: VitalType, frequency: "daily"|"twice_daily"|"weekly", unit }], defaultThresholds: Threshold[], status: "fixture_unapproved"|"approved", version }
Threshold = { type: VitalType, op: "lt"|"gt", value: number, level: "routine"|"urgent"|"emergency", message: string }
Enrollment = { id, patientId, patientName, templateCode, templateName, status, thresholds: Threshold[], thresholdsApprovedByName: string|null, startDate, endDate: string|null, careEpisodeId: string|null, adherencePct7d: number|null, lastReadingAt: string|null, openBreaches: number, createdAt }
ProgramSummary = { enrollmentId, from, to, expectedReadings, receivedReadings, adherencePct, breaches: [{ at, type, value, threshold: Threshold, safetyEventId }], trend: [{ date, type, avg, min, max }] }
```
Readings are ordinary vitals (patient-entered, device or home visit). Each new vital is evaluated against active enrollments. A breach creates a SafetyEvent (source `program`, the threshold's level) and notifies the coordinator and family (`receive_alerts`). The deterministic safety engine still runs as well; the program can never lower a safety level.
**Weekly report**: every Monday 09:00 IST the worker generates a "Weekly health report" PDF record per active enrollment and notifies the family.
Seed: Ramesh enrolled in `hypertension` (fixture thresholds: systolic > 160 urgent, > 180 emergency, < 90 urgent), with 14 days of readings.

## 43. WhatsApp assistant
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/me/whatsapp` | – | `{ optedIn: boolean, phone, optedInAt: string|null }` |
| PUT | `/me/whatsapp` | `{ optedIn }` | same (records a `whatsapp_messaging` consent) |
| GET | `/webhooks/whatsapp` | Meta verify handshake (`hub.mode`, `hub.verify_token`, `hub.challenge`) | challenge |
| POST | `/webhooks/whatsapp` | Meta Cloud API payload; `X-Hub-Signature-256` HMAC with `WHATSAPP_APP_SECRET` | 200 |
| POST | `/dev/whatsapp/simulate` (**non-production only**, any authenticated user) | `{ text }` (as if sent from the caller's phone) | `{ replies: string[] }` |

Inbound message handling:
- It resolves the user by phone, and only opted-in users are served.
- `STOP` opts the user out; `START` opts them in.
- `TODAY` / `REMINDERS` returns today's reminders for the user's patients.
- `CHECKIN` / `OK` records the §41 check-in.
- `BP 138/88` / `SUGAR 142` records a patient-entered vital, evaluated by §42 and the safety engine.
- `BOOK` sends deep links to the apps.
- Any other text goes to the AI Care Assistant pipeline (intake + **safety engine**; emergency → the fixed 108 template).
- Replies are plain text with no diagnosis. Outbound reminders use approved template names (`WHATSAPP_TEMPLATE_*`). The adapter is a console mock in dev, or Meta Cloud API (`WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACCESS_TOKEN`).

## 44. Lab tests at home
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/lab/tests?q=&category=` | – | list of `LabTest` |
| GET | `/lab/packages` | – | list of `LabPackage` |
| POST | `/lab/orders` 🔑 | `{ patientId, testIds: string[], packageIds?: string[], address: Address, preferredStart, preferredEnd, prescriptionId?, careEpisodeId?, couponCode? }` | `{ order: LabOrder, payment: Payment }` |
| GET | `/lab/orders?patientId=` / `GET /lab/orders/:id` | – | `LabOrder` |
| POST | `/lab/orders/:id/cancel` | `{ reason }` | `LabOrder` (refund if paid) |
| POST | `/webhooks/lab/:partner` | partner payload, HMAC `X-Lab-Signature` | 200 |
| GET | `/ops/lab-orders?status=` | – | list of `LabOrder` |
```ts
LabTest = { id, code, name, description, category, sampleType: "blood"|"urine"|"swab"|"other", fastingRequired: boolean, fastingHours: number|null, turnaroundHours, price, mrp, partnerName }
LabPackage = { id, code, name, testIds: string[], price, mrp, description }
LabOrder = { id, patientId, patientName, tests: [{ id, name }], total, discount, status: "pending_payment"|"scheduled"|"sample_collected"|"processing"|"report_ready"|"cancelled",
             collectionVisitId: string|null, preferredStart, preferredEnd, reportRecordId: string|null, partnerName, partnerOrderId: string|null,
             timeline: [{ status, at }], careEpisodeId: string|null, createdAt }
```
`HomeVisit` gains `labOrder: { id, tests: [{ id, name, sampleType }], fastingRequired: boolean, fastingHours: number|null } | null`. It is set for sample-collection visits, is visible to the assigned provider, and never includes prices. After payment a `sample_collection` home visit is created and auto-matched (§8). Completing that visit moves the order to `sample_collected`, then the partner adapter submits it. The mock partner moves it to `processing` and, after `LAB_MOCK_REPORT_MINUTES` (default 2), to `report_ready`. It generates a PDF watermarked **"SAMPLE REPORT — NOT A REAL RESULT"** with plausible values. The report becomes a `lab_report` MedicalRecord (source `lab_partner`) linked to the episode, and the patient and linked doctor are notified. Seed: 20 tests, 4 packages, with pricing marked placeholder.

## 45. Doctor mobile app
`GET /care-episodes?patientId=` is also allowed for a doctor linked to that patient (the same rule as the §16 snapshot). Client-only otherwise. It uses §16, §29, §31, §33–§36, §46, §47 and push (`/devices`). No new endpoints.

## 46. AI consultation notes ("scribe")
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/clinician/appointments/:id/scribe` (doctor of the appointment) | JSON `{ transcript, consentConfirmed: true }` **or** multipart `audio` (webm/m4a/wav ≤ 25 MB) + `consentConfirmed=true` | `ScribeDraft` |
```ts
ScribeDraft = { id, appointmentId, transcript, draft: { subjective, objective, assessment, plan }, model, advisory: true, generatedAt, audioRetained: false }
```
Rules:
- `consentConfirmed` must be true, meaning the patient agreed to recording (the event is audited).
- Audio goes through the speech-to-text adapter (`STT_PROVIDER=mock|openai_whisper_compatible|google`; the mock returns a canned transcript in dev). Audio is **discarded** after transcription.
- The draft comes from the AI gateway and passes the policy check (no invented findings: the prompt forbids facts that aren't in the transcript).
- The doctor edits and then saves via the existing complete-consultation notes. AI text never auto-saves into the record.

## 47. Drug interaction & allergy checks
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/clinician/prescriptions/check` | `{ patientId, items: [{ drugName, strength? }] }` | `{ warnings: RxWarning[], knowledgePack: { version, status } }` |
```ts
RxWarning = { severity: "info"|"moderate"|"major", type: "allergy"|"duplicate_therapy"|"interaction"|"dose_form", drugs: string[], message, source: string }
```
The engine checks:
- **allergy**: patient allergies against drug names and drug classes, using a class map;
- **duplicate therapy**: against the patient's active medications of the same drug or class;
- **interactions**: from a versioned interaction pack (fixture pack `interactions-fixture-0.1`, ~40 well-known pairs, marked **[REQUIRES CLINICAL GOVERNANCE — replace with a licensed drug database adapter]**; the adapter interface `DrugKnowledgeProvider` exists).

`POST /clinician/prescriptions` (§31) now also runs the check and returns `warnings`. When any `major` warning exists, the prescription is rejected (400, `details.warnings`) unless the body includes `acknowledgedWarnings: true` and `overrideReason`. Overrides are audited.

## 48. Nurse route planning, attendance & supplies (role `provider`)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/provider/route?date=` | – | `{ date, stops: [{ order, visitId, serviceName, window: { start, end }, address, lat, lng, distanceFromPrevKm, etaAt }], totalKm, startLocation: { lat, lng }|null }` |
| POST | `/provider/attendance` | `{ action: "check_in"|"check_out", lat?, lng? }` | `{ id, action, at, lat, lng }` |
| GET | `/provider/attendance?month=YYYY-MM` | – | `{ items: [{ date, checkInAt, checkOutAt, hours, visits }] }` |
| GET | `/provider/supplies` | – | `{ items: [{ code, name, unit, onHand, reorderLevel }] }` |
| POST | `/provider/supplies/usage` | `{ visitId, items: [{ code, qty }] }` | updated supplies |
| POST | `/ops/providers/:id/supplies/restock` (ops) | `{ items: [{ code, qty }] }` | supplies |
| GET | `/ops/supplies/low-stock` | – | list `{ providerId, providerName, code, name, onHand, reorderLevel }` |

Routes are ordered by time window first, then nearest-neighbour by haversine distance (default speed 20 km/h). A `MapsProvider` adapter (Google Distance Matrix, when `GOOGLE_MAPS_API_KEY` is set) refines distances and ETAs. The start point is the provider's last location, or the zone centre. Seed: supplies for Sunita, and lat/lng on seeded addresses.

## 49. Specialist second opinion
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/second-opinions/pricing` | – | `{ items: [{ specialty, price, turnaroundHours }] }` |
| POST | `/second-opinions` 🔑 | `{ patientId, specialty, question, recordIds: string[] }` | `{ request: SecondOpinion, payment: Payment }` |
| GET | `/second-opinions?patientId=` / `/second-opinions/:id` | – | `SecondOpinion` |
| GET | `/clinician/second-opinions?scope=open|mine` (doctor) | – | list (open ones in the doctor's specialty) |
| POST | `/clinician/second-opinions/:id/claim` | – | `SecondOpinion` |
| POST | `/clinician/second-opinions/:id/respond` | `{ opinion, recommendations: string[], suggestTeleconsult: boolean }` | `SecondOpinion` (opinion PDF record created; patient notified) |
```ts
SecondOpinion = { id, patientId, patientName, specialty, question, records: [{ id, title }], status: "pending_payment"|"open"|"claimed"|"answered"|"cancelled",
                  price, doctorName: string|null, opinion: string|null, recommendations: string[], opinionRecordId: string|null, dueAt: string|null, createdAt, answeredAt: string|null }
```
The records are shared read-only with the claiming doctor (audited). An unanswered request past `dueAt` alerts ops.

## 50. ABDM (ABHA creation, record linking, consent): sandbox-ready adapter
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/abdm/abha/create/start` | `{ patientId, method: "mobile", mobile }` | `{ txnId }` |
| POST | `/abdm/abha/create/verify` | `{ txnId, otp }` | `PatientProfile.abha` (status `verified`) |
| POST | `/abdm/abha/link-existing/start` / `verify` | `{ patientId, abhaNumber }` / `{ txnId, otp }` | same |
| POST | `/abdm/consent-requests` | `{ patientId, hiTypes: ("Prescription"|"DiagnosticReport"|"DischargeSummary"|"OPConsultation")[], from, to, purpose: "CAREMGT" }` | `AbdmConsentRequest` |
| GET | `/abdm/consent-requests?patientId=` | – | list |
| POST | `/webhooks/abdm` | gateway callbacks (signature verified) | 200 |
```ts
AbdmConsentRequest = { id, patientId, hiTypes, from, to, status: "requested"|"granted"|"denied"|"expired"|"data_received", recordsImported: number, createdAt }
```
`ABDM_MODE=mock|sandbox|production` (default `mock`). The mock gateway simulates the OTP (dev OTP `123456`), ABHA creation, consent grant after 10 s, and a data push that imports 2 sample records (source `imported`, titled "Imported via ABDM (sample)"). The §39 verify endpoint also works in mock mode. Production mode requires certification (the startup refusal names the missing items).

## 51. Insurance helper
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/insurance/insurers` | – | list `{ code, name, type: "private"|"public"|"government" }` |
| GET/POST | `/patients/:id/insurance-policies` | `{ insurerCode, policyNumber, planName?, type: "individual"|"family_floater"|"corporate"|"government", sumInsured?, validFrom, validTo, tpaName?, cardRecordId?, membersCovered?: string[] }` | `InsurancePolicy` |
| PATCH/DELETE | `/patients/:id/insurance-policies/:policyId` | – | – |
| GET | `/insurance/claim-checklist?type=cashless|reimbursement` | – | `{ steps: string[], documents: string[], disclaimer }` |

`GET /facilities` gains `?cashlessInsurer=<code>`, and `Facility` gains `cashlessInsurers: string[]`.
```ts
InsurancePolicy = { id, patientId, insurerCode, insurerName, policyNumberMasked, planName, type, sumInsured: number|null, validFrom, validTo, tpaName, cardRecordId, status: "active"|"expiring_soon"|"expired", createdAt }
```
The worker sends renewal reminders 30 and 7 days before `validTo`. Policy numbers are stored encrypted and returned masked. Checklist content is marked **[REQUIRES CONTENT REVIEW]**.

## 52. Vaccination & preventive screening
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/patients/:id/preventive-schedule` | – | `{ items: PreventiveItem[], scheduleVersion, scheduleStatus }` |
| POST | `/patients/:id/preventive-records` | `{ code, doneAt, notes?, recordId? }` | `PreventiveItem` |
```ts
PreventiveItem = { code, name, category: "vaccine"|"screening", description, dueDate: string|null, status: "upcoming"|"due"|"overdue"|"done"|"not_applicable", lastDoneAt: string|null, repeatEveryMonths: number|null }
```
Items are computed from age and sex using versioned fixture schedules: a child immunisation schedule and adult screenings (BP, glucose, lipids, cervical/breast/colorectal screening, influenza/pneumococcal for 65+). They are marked **[REQUIRES CLINICAL GOVERNANCE]**. The worker sends monthly due/overdue reminders to the patient and family.

## 53. Physiotherapy & exercise programs
New home-visit service `physiotherapy` (₹699, capability required).
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/exercise-library?bodyArea=` | – | list `{ id, title, bodyArea, level, durationSecs, videoUrl: string|null, imageUrl: string|null, instructions: string[], precautions: string[] }` |
| POST | `/exercise-plans` (doctor, or provider of type physiotherapist) | `{ patientId, careEpisodeId?, items: [{ exerciseId, sets, reps, holdSecs?, perDay, notes? }], startDate, weeks }` | `ExercisePlan` |
| GET | `/exercise-plans?patientId=` | – | list `ExercisePlan` |
| POST | `/exercise-plans/:id/sessions` | `{ completedExerciseIds: string[], painScore: 0..10, note? }` | `ExerciseSession` |
| GET | `/exercise-plans/:id/progress` | – | `{ sessionsPlanned, sessionsDone, adherencePct, painTrend: [{ date, painScore }] }` |
```ts
ExercisePlan = { id, patientId, authorName, authorRole, items: [...], startDate, endDate, status: "active"|"completed", createdAt }
ExerciseSession = { id, planId, at, completedExerciseIds, painScore, note }
```
A pain score ≥ 8 in a session notifies the plan author. Seed library: 15 exercises (videos null → illustrated instructions).

## 54. Diet plans
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/diet-templates` | – | list `{ code, name, conditions: string[], status }` (fixtures: diabetic, low-salt cardiac, renal) |
| POST | `/diet-plans` (doctor, or provider of type dietitian) | `{ patientId, templateCode?, conditions: string[], calorieTarget?: number, meals: [{ slot: "early_morning"|"breakfast"|"mid_morning"|"lunch"|"evening"|"dinner"|"bedtime", items: string[], notes? }], avoid: string[], notes?, validUntil }` | `DietPlan` |
| GET | `/diet-plans?patientId=` | – | list `DietPlan` |
| POST | `/diet-plans/:id/logs` | `{ date, slot, followed: boolean, note? }` | `{ id }` |
| GET | `/diet-plans/:id/adherence?days=14` | – | `{ days: [{ date, slotsLogged, slotsFollowed }], adherencePct }` |
```ts
DietPlan = { id, patientId, authorName, authorRole, conditions, calorieTarget, meals, avoid, notes, validUntil, status: "active"|"expired", createdAt }
```
Meal suggestions in templates are Indian vegetarian/non-vegetarian options.

## 55. Ambulance booking
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/ambulance/requests` 🔑 | `{ patientId, pickup: { lat, lng, address }, destinationFacilityId?, type: "bls"|"als", reason, sosId? }` | `AmbulanceRequest` (plus `payment` when the partner is paid; the mock is free) |
| GET | `/ambulance/requests/:id` | – | `AmbulanceRequest` (clients poll every 5 s) |
| POST | `/ambulance/requests/:id/cancel` | `{ reason }` | `AmbulanceRequest` |
| GET | `/ops/ambulance-requests?status=` | – | list |
```ts
AmbulanceRequest = { id, patientId, patientName, type, status: "searching"|"assigned"|"en_route"|"arrived"|"transporting"|"completed"|"cancelled"|"no_vehicle",
  vehicle: { number, driverName, phoneMasked } | null, etaMinutes: number|null, location: { lat, lng, updatedAt } | null,
  pickup, destination: Facility | null, partnerName, timeline: [{ status, at }], createdAt }
```
This never replaces 108: every screen keeps "Call 108" as the primary action. A request also creates an `emergency` SafetyEvent for ops. The mock partner assigns a vehicle within 20 s, then moves it towards the pickup every 10 s.

## 56. Dementia safety: safe zone & SOS button
| Method | Path | Body | Response |
|---|---|---|---|
| GET/PUT | `/patients/:id/safe-zone` (`manage_care`) | `{ enabled, centerLat, centerLng, radiusMeters (100..5000), label?, activeFrom?: "HH:MM", activeTo?: "HH:MM" }` | `SafeZone` |
| POST | `/patients/:id/location` (the patient's own device in "companion mode", or a paired tracker) | `{ lat, lng, accuracyM, source: "phone"|"tracker" }` | `{ inside: boolean }` |
| GET | `/patients/:id/location/latest` (family with `receive_alerts`, coordinator) | – | `{ lat, lng, at, inside, source } | 404` |
| POST | `/patients/:id/sos-devices` | `{ deviceId, model }` | `{ id, deviceId, model, pairedAt }` |
| DELETE | `/patients/:id/sos-devices/:deviceRowId` | – | 204 |
| POST | `/webhooks/sos-button` | vendor payload, HMAC `X-SOS-Signature` | 200 → same flow as `/emergency/sos` |

The first location outside the zone (while active) creates an `urgent` SafetyEvent (source `geofence`), and family get a push/WhatsApp with a map link. Returning inside resolves it. Only the latest location is kept; history is not stored.

## 57. Company (corporate) health plans
| Method | Path | Body | Response |
|---|---|---|---|
| GET/POST, PATCH `/:id` | `/admin/organizations` (super_admin) | `{ name, contactName, contactEmail, planCode, seats, validFrom, validTo, billingNote? }` | `Organization` |
| POST | `/admin/organizations/:id/codes` | `{ count: 1..500 }` | `{ codes: string[] }` (single-use, 10 chars) |
| GET | `/admin/organizations/:id/usage` | – | `{ seats, redeemed, activeMembers, servicesUsed: { appointments, homeVisits, labOrders } }` (aggregates only, no PHI) |
| POST | `/subscriptions/redeem` | `{ code }` | `Subscription` (active, sponsored; `sponsorName` set; price 0) |

`Subscription` gains `sponsorName: string|null`.

## 58. Hospital white-label branding
| Method | Path | Body | Response |
|---|---|---|---|
| GET/POST, PATCH `/:id` | `/admin/tenants` (super_admin; responses include `id` and `logoUrl`) | `{ code, displayName, primaryColor: "#RRGGBB", logoMediaId?, facilityIds: string[], supportPhone?, supportEmail? }` | `Tenant` |

`GET /config/public?tenant=<code>` adds `branding: { tenantCode, displayName, logoUrl, primaryColor, supportPhone, supportEmail } | null`. The apps accept `--dart-define=TENANT_CODE=...` and apply the name, primary colour and logo, and show "Powered by CareCompanion". Patients and episodes gain `tenantCode: string|null` (set when created via a tenant's discharge flow or app build).

## 59. Hospital post-discharge programs (role `hospital_staff`)
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/discharges` (multipart) | `patient` JSON `{ name, phone, dob, gender }`, `familyPhone?`, `dischargeDate`, `diagnosisSummary`, `treatingDoctorName`, `followUp` JSON `{ tasks: [...], medications: [...], followUpDays: number[] }`, `programTemplateCode?`, `file` (discharge summary PDF) | `Discharge` |
| GET | `/discharges?status=` | – | list `Discharge` (own facility only) |
| GET | `/discharges/:id` | – | `Discharge` with progress |
```ts
Discharge = { id, facility: Facility, patientId, patientName, dischargeDate, diagnosisSummary, treatingDoctorName, status: "active"|"completed"|"readmitted"|"withdrawn",
              careEpisodeId, carePlanId, enrollmentId: string|null, day: number /* days since discharge */, tasksDone, tasksTotal, missedCheckins, openAlerts, invitedPhones: string[], createdAt }
```
Creating a discharge:
- finds or creates the patient user by phone; SMS/WhatsApp invites go to the patient and family;
- creates a care episode (`UNDER_CARE` → `FOLLOW_UP`) plus a care plan built from the hospital's follow-up (marked "Hospital-issued"), and follow-up tasks at the given day offsets;
- enables the §41 daily check-in for 30 days and the §42 enrollment if a template is given;
- stores the PDF as a `discharge_summary` record (source `imported`);
- assigns a coordinator and sets `tenantCode` from the facility's tenant.

The worker completes the program at day 30. Seed: facility "Deccan Sunrise Multispeciality" with hospital_staff user **+919800000701** (Hospital Discharge Desk), and 1 active discharge.

## 60. Offers, wallet & invites
| Method | Path | Body | Response |
|---|---|---|---|
| GET/POST, PATCH `/:id` | `/admin/coupons` (super_admin) | `{ code, description, type: "percent"|"flat", value, maxDiscount?, minAmount?, appliesTo: Payment.purpose[], validFrom, validTo, usageLimit?, perUserLimit, active }` | `Coupon` |
| POST | `/coupons/validate` | `{ code, purpose, amount }` | `{ valid, discount, finalAmount, message }` |
| GET | `/wallet` | – | `{ balance, transactions: [{ id, type: "credit"|"debit", amount, reason, refType, refId, at }] }` |
| GET | `/me/invite` | – | `{ code, shareText, invitedCount, rewardsEarned }` |
| POST | `/me/invite/redeem` | `{ code }` (once, within 7 days of signup) | `{ ok: true }` |

The booking endpoints (`/appointments`, `/home-visits`, `/lab/orders`, `/pharmacy/orders`, `/subscriptions`, `/second-opinions`) accept `couponCode?` and `useWallet?: boolean`. The resulting `Payment` gains `discount`, `walletUsed` and `amount` (the remainder charged). A fully covered payment succeeds immediately.

Invite rewards (`INVITE_REWARD_INVITER`, default ₹100; `INVITE_REWARD_INVITEE`, default ₹100) are credited when the invitee's first paid service completes. Wallet credit is non-withdrawable and expires after 365 days **[REQUIRES LEGAL REVIEW: RBI PPI rules]**. Refunds can go back to the original method (default) or the wallet (user choice). EMI is offered by Razorpay checkout itself; there is no app logic for it. Seed coupons: `WELCOME100` (flat ₹100 on the first home visit), `CARE10` (10% off lab orders, max ₹200).

## 61. Support desk
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/support/tickets` | `{ subject, category: "booking"|"payment"|"refund"|"app_issue"|"clinical_concern"|"other", message, refType?, refId?, attachmentRecordId? }` | `Ticket` |
| GET | `/support/tickets` (mine) / `GET /support/tickets/:id` | – | `Ticket` (with messages) |
| POST | `/support/tickets/:id/messages` | `{ text }` | `TicketMessage` |
| POST | `/support/tickets/:id/rating` (after resolved) | `{ score: 1..5, comment? }` | `Ticket` |
| GET | `/ops/support/tickets?status=&assignedTo=me` (support_agent, coordinator, ops_admin, super_admin) | – | list `Ticket` |
| POST | `/ops/support/tickets/:id/assign` | `{ userId }` | `Ticket` |
| POST | `/ops/support/tickets/:id/reply` | `{ text, internal?: boolean }` | `TicketMessage` |
| PATCH | `/ops/support/tickets/:id` | `{ status?, priority? }` | `Ticket` |
| GET | `/ops/support/metrics` | – | `{ open, avgFirstResponseMins, avgResolutionHours, csatAvg, byCategory: {} }` |
```ts
Ticket = { id, number /* "T-000123" */, userId, userName, subject, category, status: "open"|"pending_customer"|"resolved"|"closed", priority: "low"|"normal"|"high"|"urgent",
           assignedToName: string|null, refType, refId, messages: TicketMessage[], rating: { score, comment } | null, slaDueAt, createdAt, updatedAt }
TicketMessage = { id, ticketId, authorName, authorRole: "customer"|"agent"|"system", text, internal: boolean, at }
```
`clinical_concern` tickets automatically create a SafetyEvent review. They are never handled by support alone.
The first-response SLA is 30 min for `urgent`/`high`, else 4 h, and a breach alerts ops. Internal notes are never shown to customers. Seed: support_agent **+919800000801** (Support Desk), plus 2 tickets.

## 62. Telephony line for elders without smartphones (IVR)
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/webhooks/ivr/:provider` | provider callback (Exotel/Twilio-style, signature verified) | provider XML/JSON response |
| POST | `/dev/ivr/simulate` (**non-production only**) | `{ fromPhone, digits?: string, speechText?: string, sessionId? }` | `{ sessionId, say: string, gather: "digits"|"speech"|"none", ended: boolean }` |

The menu is in the caller's language (en/hi/te, from the user profile, else asked first):
- **1**: hear today's medicine reminders;
- **2**: "I'm OK" check-in (§41);
- **3**: request a call back from the care coordinator (creates a support ticket, category `other`, priority `high`);
- **4**: speak a health concern (speech → text → AI intake + safety engine; emergency → "Please call 108 now" and an ops alert);
- **9**: connect to the care team (transfer to `SUPPORT_PHONE`).

Unknown callers hear the support number. The adapter is `IVR_PROVIDER=mock|exotel|twilio`.

### v1.3 follow-ups (additive)
- `GET /patients/:id/sos-devices` → `{ items: [{ id, deviceId, model, pairedAt }] }` (requires `manage_care`).
- `GET /diet-plans/:id/logs?date=YYYY-MM-DD` → `{ items: [{ id, date, slot, followed, note }] }`.
- `PublicConfig.flags` gains these flags, all on by default: `lab_tests`, `care_programs`, `second_opinion`, `insurance`, `preventive_care`, `exercise_plans`, `diet_plans`, `ambulance`, `safe_zone`, `wallet_invites`, `support_desk`, `whatsapp`, `daily_checkin`, `abdm`.
- `MedicalRecord` gains `importedVia: "abdm"|"hospital_discharge"|null`.
