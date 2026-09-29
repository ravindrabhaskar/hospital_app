# CareCompanion API (`services/api`)

Backend for CareCompanion, the AI-assisted care-orchestration platform (Hyderabad pilot).
It implements `docs/api/API_CONTRACT.md` (v1, v1.1, the v1.2 additions in sections 29-40 and the v1.3 additions in sections 41-62) as a **modular monolith**: TypeScript (strict), Fastify 5, zod,
Drizzle ORM (PostgreSQL dialect), with PostgreSQL **or** embedded PGlite.

> **Clinical safety notice:** the bundled safety rule pack `fixture-0.1` is a **NON-CLINICAL TEST FIXTURE**.
> Every rule says "FIXTURE — replace with clinician-approved rule". With `NODE_ENV=production` the server refuses to
> serve or activate an unapproved pack and fails safe (everything is routed to "consult a doctor").

## Quick start

```bash
cd services/api
npm install
npm run seed -- --reset   # creates .data/pglite + .data/files and loads the contract §20 dataset
npm run dev               # http://localhost:4000/api/v1  (dev OTP is always 123456)
```

Try: `POST /api/v1/auth/otp/request {"phone":"+919800000001"}` then `POST /api/v1/auth/otp/verify {"phone":"+919800000001","otp":"123456"}`.

No Docker or PostgreSQL is needed for development. Copy `.env.example` to `.env` to change settings.

## Scripts

| Script | What it does |
|---|---|
| `npm run dev` | `tsx watch src/server.ts` (loads `.env` if present) |
| `npm run build` / `npm start` | compile to `dist/` / run the compiled server |
| `npm run db:generate` | `drizzle-kit generate`: create a migration from `src/db/schema.ts` into `drizzle/` |
| `npm run db:migrate` | apply migrations (the server also applies them at startup) |
| `npm run seed` | idempotent dev seed; `npm run seed -- --reset` wipes the dev DB and files first |
| `npm test` | vitest (in-memory PGlite, `app.inject`) |
| `npm run lint` / `npm run typecheck` | ESLint (flat config) / `tsc --noEmit` |
| `npm run check` | typecheck + lint + test |
| `npm run verify:pg` | proves the `pg` driver path against PGlite over the wire protocol |
| `npm run create-admin -- --phone +91… --name "…"` | create/promote an admin (`node dist/scripts/create-admin.js` in production) |

## Environment variables

All are validated by zod in `src/config.ts` (see `.env.example` for defaults). Key ones:

| Variable | Default | Notes |
|---|---|---|
| `NODE_ENV` | `development` | `production` requires `DATABASE_URL`, `JWT_SECRET`, `PAYMENT_WEBHOOK_SECRET` and the integrations below; disables devOtp and confirm-mock |
| `PORT` / `API_PREFIX` | `4000` / `/api/v1` | |
| `DATABASE_URL` | empty | set → node-postgres; empty → PGlite at `PGLITE_DIR` (`.data/pglite`) |
| `JWT_SECRET` | dev value | HS256 access tokens (15 min, `ACCESS_TOKEN_TTL_SEC`) |
| `OTP_*` | 6 digits, 5 min, 5 attempts, 5 requests / 15 min | dev OTP `OTP_DEV_CODE=123456` |
| `CORS_ORIGINS` | `http://localhost:3000` | any `http://localhost:*` is also allowed outside production |
| `ANTHROPIC_API_KEY` / `AI_MODEL` | empty / `claude-opus-5` | no key → deterministic `RuleBasedModel` |
| `AI_TIMEOUT_MS`, `AI_MAX_RETRIES`, `AI_BREAKER_*` | 20000, 1, 3 failures / 60 s | gateway resilience |
| `PAYMENT_GATEWAY` / `PAYMENT_WEBHOOK_SECRET` | `mock` / dev value | webhook `X-Signature = hex(HMAC-SHA256(rawBody, secret))` |
| `STORAGE_DRIVER` / `STORAGE_DIR` / `MAX_UPLOAD_MB` | `local` / `.data/files` / 15 | `s3` = AWS S3 / MinIO (see Production configuration) |
| `WORKER_ENABLED`, `WORKER_INTERVAL_MS` | true, 15000 | in-process scheduler |
| `FALL_RESPONSE_TIMEOUT_SEC`, `VISIT_ASSIGN_SLA_MIN`, `PAYMENT_HOLD_MIN`, `DOSE_MISSED_GRACE_MIN` | 60, 30, 15, 60 | |
| `PUBLIC_API_BASE_URL` | `http://localhost:4000/api/v1` | absolute base of public URLs; profile photos are `${PUBLIC_API_BASE_URL}/media/<id>` (**set it in production**) |
| `SCHEDULE_HORIZON_DAYS` | 14 | days of slots generated ahead from each doctor's weekly schedule |
| `SELLER_LEGAL_NAME`, `SELLER_GSTIN`, `SELLER_ADDRESS` | placeholders / empty | printed on invoices **[REQUIRES TAX REVIEW]** |
| `HEALTHCARE_GST_RATE` | 0 | GST percent on invoices (amounts are tax-inclusive) **[REQUIRES TAX REVIEW]** |
| `PLATFORM_FEE_PCT` | 20 | platform fee deducted in earnings/settlements |
| `ABDM_ENABLED` | false | ABHA verification returns 503 until the ABDM adapter is connected |

## Architecture

```
src/
  app.ts            buildApp(): services container, plugins, error envelope, routes (used by tests)
  server.ts         process entry (listen, graceful shutdown)
  config.ts         zod env validation
  services.ts       dependency container type (app.svc)
  db/               schema.ts (Drizzle), client.ts (pg | PGlite), migrate.ts, seed.ts
  lib/              errors, access (RBAC + assertCanActForPatient), audit, idempotency, logger (PHI redaction),
                    pagination, validate, i18n (en/hi/te), time (IST), crypto, pdf (pdfkit layout kit), multipart
  plugins/auth.ts   bearer auth (JWT + live user/session check) and role guards
  modules/<name>/   routes.ts (+ service.ts) per bounded context:
                    auth consent patients family episodes providers doctors appointments homevisits records
                    timeline vitals ai safety knowledge careplans medications notifications payments pharmacy
                    wellness wound wearables fall emergency insights clinician provider-app ops admin analytics flags
                    v1.2: schedules media applications prescriptions billing reviews messaging coordinator
                    referrals subscriptions schemes abdm
  worker/           scheduler.ts (single-flight ticks) + jobs.ts (idempotent jobs)
drizzle/            generated SQL migrations (+ 0001 custom: append-only triggers)
test/               vitest suites
```

Cross-cutting behaviour:

- **Errors**: every non-2xx is `{ error: { code, message, details, correlationId } }` with the contract codes.
- **Correlation IDs**: `X-Correlation-Id` is accepted (or generated), used as the request id and echoed.
- **Authorization**: `lib/access.ts#assertCanActForPatient(db, ctx, patientId, perm)` is called by every patient-scoped
  route. Access paths: self, managed dependent (all four permissions), active `FamilyAccessGrant` (listed permissions
  only; revocation is immediate because it is checked per request), doctor with a care relationship (appointment,
  owned episode, care plan, or unexpired record share → `view_records` + `manage_care`), and ops roles (`staff_ops`, only
  where a route lists it). Denials are written to the audit log with `outcome: "denied"`.
- **Audit**: `audit_logs` is append-only (DB trigger rejects UPDATE/DELETE; `episode_events` likewise). Metadata never
  holds PHI.
- **Idempotency**: routes flagged `config.idempotent` require `Idempotency-Key`; `(userId, key, METHOD path)` → stored
  response; same body replays (header `Idempotent-Replayed: true`), different body → `IDEMPOTENCY_MISMATCH`, in-flight
  duplicate → `CONFLICT`; non-2xx releases the key.
- **Concurrency**: slot booking = conditional `UPDATE ... WHERE status='available'` inside a transaction plus a partial
  unique index on `appointments(slot_id) WHERE status <> 'cancelled'`.
- **Logging**: pino with redaction of phone/name/text/notes/otp/tokens/authorization/bodies; query strings are stripped.
- **Rate limiting**: global per-IP limit plus a stricter per-route limit on `/auth/otp/*`, and the DB-backed
  5-requests-per-phone-per-15-min OTP rule.

### AI pipeline (`modules/ai`)

Per message: patient resolution → authorized context → structured intake → **deterministic safety engine** →
reviewed knowledge (BM25 over approved, in-date sources) → LLM reply → policy check → routing → `ai_interactions` audit.

- Intake fields carry provenance (`user` | `record` | `model_extraction`). Model extractions are accepted only when
  grounded in the user's own words, so hallucinated values are dropped.
- Safety level is computed by rules only and can only go up within a conversation. At `emergency` the fixed template
  (call 108 / SOS) is returned and the LLM is not consulted.
- Gateway: kill switch (`kill_switch_ai`), timeout, circuit breaker, deterministic fallback, token/latency metrics.
  `AnthropicModel` uses the official `@anthropic-ai/sdk` with `AI_MODEL` (default `claude-opus-5`), low effort, and
  server-side refusal fallbacks (`fallbacks: "default"`) where the model supports them.

### Background worker (`src/worker`)

Jobs: missed-dose marking, overdue care tasks, fall auto-escalation, appointment reminders, home-visit SLA flags and
re-matching, unpaid-hold expiry, schedule horizon (once per IST day: extends every verified doctor's slots to
`SCHEDULE_HORIZON_DAYS` from their weekly template; only adds, never touches booked/held slots), subscriptions
(expire/cancel at period end, one renewal reminder 7 days before, coordinator benefit for new episodes), notification outbox dispatch (exponential backoff,
5 attempts). **Moving to BullMQ/Redis:** each entry in `JOBS` is idempotent and takes `(svc, now)`; create one
repeatable BullMQ job per entry and call the same function from the processor, then set `WORKER_ENABLED=false` in the
API process. The outbox table already acts as a durable queue for notifications.

### Notifications

Channel adapters (`push | sms | email | whatsapp`): FCM push and MSG91/Twilio SMS when configured, console otherwise; template registry with en/hi/te
for key templates; per-user preferences; critical notifications bypass preferences. Outbound channel text is always
the generic lock-screen string ("You have a care update"), never health details.

### Payments

`PaymentGateway` abstraction (`MockGateway`, `RazorpayGateway`; see Production configuration). Amounts are rupees in the API and paise at the
gateway boundary. Webhook `POST /api/v1/webhooks/payments` verifies the HMAC over the raw body and is idempotent on the
gateway event id (`payment_events.gateway_event_id` unique). Accepted payload (Razorpay-shaped):
`{"id":"evt_…","event":"payment.captured"|"payment.failed","payload":{"payment":{"entity":{"id":"pay_…","order_id":"order_…"}}}}`
(the event id may also come from the `X-Event-Id` header). Refunds create `refunds` rows and negative
`settlement_ledger` entries.

## v1.2 features (contract sections 29-40)

| Section | Module | What it does |
|---|---|---|
| 29 Schedules & photos | `schedules`, `media` | `/doctor/me/profile` (+`acceptingBookings`), weekly template + leaves, admin schedule endpoints. Regeneration runs in a transaction holding a row lock on the doctor (`SELECT ... FOR UPDATE`); every slot write is conditional on the slot status, so booked/held slots are never touched and no new slot may overlap one. Unwanted free slots are deleted, or marked `retired` (never listed or bookable) when an old cancelled appointment still references them. `Slot.modes` is enforced at booking. Doctors with `acceptingBookings=false` are hidden from `/doctors` and new bookings return 409. `POST /me/photo` (jpg/png/webp, 5 MB, malware-scanned) stores under `media/profile-photos/` with a `media` row flagged `public_profile_photo`; the public `GET /media/:id` serves only such rows (records live under `records/` and have no media row). |
| 30 Onboarding | `applications` | Applications with documents (pdf/jpg/png, 10 MB, scanned, stored under `applications/`), ops review (coordinator reads; ops_admin/super_admin decide). Approval requires a registration certificate + ID proof and creates the verified provider/doctor + role via the helper shared with `/admin/staff` (`modules/admin/staff.ts`). Doctors get default fees (499/499/399/599) and an empty schedule. |
| 31 e-Prescriptions | `prescriptions` | Only the appointment's doctor, only for `in_progress`/`completed` consultations (409 otherwise). PDF -> `prescription` MedicalRecord, one Medication per item (`endDate = start + durationDays - 1`), episode event, notification. Pharmacy match by normalised name/strength; `POST /pharmacy/orders` accepts `prescriptionId`. The clinical note is stored but not printed. |
| 32 Invoices & earnings | `billing` | Invoice issued on payment success (and lazily for older payments): the payment row is locked and the `invoice_counters` row of the Indian FY is incremented atomically (`INSERT ... ON CONFLICT DO UPDATE ... RETURNING`), numbers `CC/2026-27/000001`, gap-free. Amounts are tax-inclusive. Earnings count completed **and** paid services: per service `net = amount - refunded`, `platformFee = round(net x PLATFORM_FEE_PCT%)`, `payable = net - platformFee`. Settlements JSON + CSV (formula-injection safe). |
| 33 Reviews | `reviews` | Patient/guardian or family with `manage_care` only (clinicians and ops cannot author). Rating-only reviews publish at once; text reviews wait for moderation. Rating = (imported baseline + published reviews); the migration turns legacy `doctor_reviews` into published reviews and keeps displayed ratings unchanged. |
| 34 Messaging | `messaging` | One thread per episode; participants per contract. Patient/family messages go through the safety engine; `emergency` appends a `kind: "emergency_notice"` system message (the fixed 108 template) and opens a SafetyEvent with `source: "message"`. Push text is the generic "New message from your care team". Read markers per user. |
| 35 Coordinators | `coordinator` | Assignment (a coordinator may only assign themselves), caseload with flags, contact logs (+`coordinator_contact` episode event). |
| 36 Referrals | `referrals` | Referral letter PDF stored as an `other` MedicalRecord (clinician_verified); status flow `created -> sent/accepted/cancelled`, `sent -> accepted/completed/cancelled`, `accepted -> completed/cancelled`. |
| 37 Subscriptions | `subscriptions` | Payment purpose `subscription` (mock + Razorpay). Success activates a prepaid period (1 or 12 calendar months); cancel sets `cancelAtPeriodEnd`; the worker ends it. The home-visit discount applies to patients owned by the subscriber (`HomeVisit.discountApplied`); `coordinatorIncluded` auto-assigns the least-loaded coordinator. |
| 38 Schemes | `schemes` | Information only, behind the `govt_schemes` flag (now default on; the migration switches it on). Admin responses add `internalNote` (seed: `[REQUIRES CONTENT REVIEW]`). |
| 39 ABHA | `abdm`, `patients` | `abhaNumber`/`abhaAddress` validation + normalisation; `POST /patients/:id/abha/verify` returns 503 until the `AbdmGateway` adapter is connected. |
| 40 Device features | `wearables` | Health Connect / Apple Health connections and sync types were already supported (heart rate is sent as `pulse`). |

Generated PDFs use `lib/pdf.ts` (header band with the platform name, info boxes, tables, footer with page numbers) and
contain only the minimum necessary data. Standard PDF fonts are Latin-1 only: other scripts are replaced by `?`.

Seed additions (`npm run seed -- --reset`): weekly templates for the 4 doctors (Mon-Sat), an e-prescription for Ramesh
from Dr. Ananya (PDF + Cetirizine/Paracetamol medications), a pending review of the completed home visit, a 3-message
care-team thread, Meera assigned to Ramesh's episode + one contact log, a referral with its letter, a submitted nurse
application from **Kavya Iyer (+919800000601)** with 2 generated documents, the plans `family_basic`/`family_plus`
(no subscription) and 3 schemes (PM-JAY, Aarogyasri Telangana, CGHS).

## v1.3 features (contract sections 41-62)

Every partner integration sits behind an adapter (`modules/partners/index.ts`) with a **mock partner** (the default
outside production, driven by the worker), a real adapter enabled by env credentials, and `disabled`. In production an
unset partner defaults to `disabled` and an explicitly configured `mock` is refused at startup (`productionReadinessIssues`).
Every partner webhook verifies an HMAC signature over the raw body and is idempotent on the partner event id
(`webhook_events`). Clinical content is versioned fixture data (`fixture_unapproved`, **[REQUIRES CLINICAL GOVERNANCE]**)
that production refuses to serve until approved (same model as the safety rule packs).

| Section | Module | What it does |
|---|---|---|
| 41 Daily check-in | `checkins` | Settings + history (missed days synthesised since check-ins were enabled). Worker: at `windowEnd` (IST) the day becomes `missed` and family with `receive_alerts` are told (`checkin_missed`); after `escalateAfterMins` an `urgent` SafetyEvent (source `checkin`) is assigned to the coordinator; a later check-in the same day is `late` and auto-resolves it. |
| 42 Programs | `programs` | Versioned templates (`program_templates`; POST with an existing code or PATCH creates the next version `vN`), enrollments (doctor; coordinator only with an approved template's thresholds), summary/adherence. Every new vital (app, home visit, wearables, WhatsApp) is evaluated: a breach creates a SafetyEvent (source `program`) at `max(threshold level, safety-engine level)` and alerts the coordinator + family. Monday 09:00 IST weekly PDF report per enrollment. |
| 43 WhatsApp | `whatsapp` | Meta Cloud API adapter / console mock, `X-Hub-Signature-256` webhook + verify handshake, opt-in with the `whatsapp_messaging` consent, commands STOP/START/HELP/TODAY/CHECKIN/OK/BP x/y/SUGAR n/BOOK, free text -> AI assistant (safety engine first; without AI consent only the safety engine; emergency -> 108 template). `POST /dev/whatsapp/simulate` (non-production). Outbound notifications use the `WHATSAPP_TEMPLATE_CARE_UPDATE` template with the PHI-free lock-screen text. |
| 44 Lab | `lab` | 20 tests / 4 packages (placeholder pricing), orders with coupons/wallet, payment -> auto-matched `sample_collection` visit (no extra charge; `HomeVisit.labOrder` gives the provider tests, sample types and fasting only), completion -> `sample_collected` -> partner submission. The mock partner goes `processing` -> `report_ready` after `LAB_MOCK_REPORT_MINUTES` with a PDF watermarked "SAMPLE REPORT — NOT A REAL RESULT" stored as a `lab_report` record (source `lab_partner`). `X-Lab-Signature` webhook. |
| 46 Scribe | `scribe` | Appointment doctor only, `consentConfirmed` audited, JSON transcript or multipart audio (webm/m4a/wav <= 25 MB) through the STT adapter; audio is never stored. The draft must be grounded (every number must appear in the transcript) or the deterministic speaker-sorted draft is used. Advisory, never saved automatically. |
| 47 Rx checks | `rxcheck` | `DrugKnowledgeProvider` (versioned pack `interactions-fixture-0.1` with ~45 well-known pairs and a drug-class map, or a licensed database over HTTP). Allergy (class + cross-reactivity), duplicate therapy (active meds + within the Rx), interactions. `POST /clinician/prescriptions` rejects `major` warnings (400, `details.warnings`) unless `acknowledgedWarnings: true` + `overrideReason` (audited `prescription.override`); `Prescription.warnings` is returned. Production with an unapproved pack returns a fail-safe "checks unavailable" warning. |
| 48 Field ops | `fieldops` | Route (time window, then nearest neighbour; `MapsProvider` = haversine at `ROUTE_SPEED_KMH` or Google Distance Matrix), attendance, supplies (catalogue of 12 items), restock, low stock. |
| 49 Second opinion | `secondopinion` | Pricing table, paid requests (`second_opinion` payments), specialty queue, claim (records shared read-only for 30 days, audited), response PDF record, overdue alert to ops. |
| 50 ABDM | `abdm` | `ABDM_MODE` mock/sandbox/production/disabled. Mock: OTP `123456`, ABHA creation/linking, consent granted after `ABDM_MOCK_CONSENT_SEC` (10) and a data push importing 2 records ("Imported via ABDM (sample)", `importedVia: "abdm"`). `X-ABDM-Signature` callbacks. §39 verify still returns 503 while `ABDM_ENABLED=false`; enabled + mock verifies ABHA numbers and `@sbx` addresses. |
| 51 Insurance | `insurance` | Insurer catalogue, cashless facility filter, policies (AES-256-GCM encrypted numbers, masked `XXXX1234`), claim checklists **[REQUIRES CONTENT REVIEW]**, renewal reminders 30 and 7 days before `validTo`. |
| 52 Preventive | `preventive` | Fixture schedule `preventive-fixture-0.1` (IAP-style child schedule + adult screenings), status computed from age/sex/records, monthly reminders. |
| 53-54 Physio & diet | `physio`, `diet` | 15-exercise library, plans by the doctor or a physiotherapist/dietitian with a visit relationship, sessions (pain >= 8 notifies the author), progress; 3 diet templates, plans, per-slot logs (upsert) and adherence. New home-visit service `physiotherapy` (₹699). |
| 55 Ambulance | `ambulance` | Requests open an `emergency` SafetyEvent; the mock assigns within `AMBULANCE_MOCK_ASSIGN_SEC` (<= 20 s) and moves every 10 s (time-based, advanced by the worker and on every poll). Never replaces 108. |
| 56 Safe zone | `geofence` | Safe zone with optional IST active window, latest location only, first exit -> `urgent` SafetyEvent (source `geofence`) + family alert with a map link, return resolves; SOS devices; `X-SOS-Signature` vendor webhook -> SOS flow (source `sos_button`). |
| 57-58 Corporate & tenants | `enterprise` | Organizations (codes capped at seats, aggregate-only usage), `POST /subscriptions/redeem` (sponsored, price 0), tenants (`logoUrl` from a public media id), `GET /config/public?tenant=` branding, `X-Tenant-Code` at sign-in tags a new self profile. |
| 59 Discharges | `discharges` | `hospital_staff` bound to one facility (`users.facility_id`, set via `/admin/staff` or `/admin/users/:id/roles` with `facilityId`). Multipart create: patient + family users and grants, SMS invites, episode (-> FOLLOW_UP), hospital-issued care plan (`doctorId: null`), tasks at day offsets, medications, 30-day check-in, optional enrollment, `discharge_summary` record (`importedVia: "hospital_discharge"`), coordinator, tenant code. Worker completes at day 30. |
| 60 Offers & wallet | `wallet`, `payments` | Coupons (percent/flat, caps, min amount, purpose, usage and per-user limits), FIFO wallet ledger with 365-day expiry **[REQUIRES LEGAL REVIEW: RBI PPI rules]**, invites (reward credited by the worker after the invitee's first completed paid service). All booking endpoints accept `couponCode`/`useWallet`; `Payment` has `discount`, `walletUsed`, `amount` (charged). Fully covered payments succeed immediately; failed/voided payments give the wallet part back and release the coupon (re-applied on retry); cancellations accept `refundTo: "wallet"`. |
| 61 Support | `support` | Tickets `T-000123`, internal notes (never returned to customers), assignment, SLA (30 min urgent/high, else 4 h; breach alerts ops), metrics, ratings. `clinical_concern` opens a SafetyEvent review. Roles: `support_agent`, coordinator, ops. |
| 62 IVR | `ivr` | Menu 1 reminders, 2 check-in, 3 call-back ticket (high), 4 spoken concern (safety engine; emergency -> "call 108" + ops alert), 9 transfer to `SUPPORT_PHONE`. `POST /dev/ivr/simulate` (non-production); provider webhooks: exotel/mock (`X-IVR-Signature`, JSON) and twilio (`X-Twilio-Signature`, TwiML). |

Also: new roles `hospital_staff`, `support_agent` (MFA staff roles); provider type `dietitian`; SafetyEvent sources
`checkin`, `program`, `geofence`, `sos_button`; payment purposes `lab_order`, `second_opinion`, `ambulance`; notification
categories `program`, `checkin`, `lab`, `support`, `insurance`, `preventive`; v1.3 feature flags (all on);
`MedicalRecord.importedVia`; `CaseloadItem.flags` gains `missed_checkin` and `program_breach`; `minAppVersion.doctor*`.

Seed additions: Ramesh check-in (08:00-10:00, 10-day history with one missed day), hypertension enrollment with 14 days of
readings, 20 lab tests + 4 packages, Sunita's supplies, 15 exercises, 3 diet templates, insurers + cashless flags,
coupons `WELCOME100`/`CARE10`, tenant `deccan-sunrise`, **+919800000701** Hospital Discharge Desk with one active discharge
(Sarojini Rao, +919800000702, family +919800000703), **+919800000801** Support Desk with 2 tickets, second-opinion pricing,
an insurance policy and preventive records for Ramesh.

### v1.3 environment variables

| Variable | Default (dev) | Notes |
|---|---|---|
| `DATA_ENCRYPTION_KEY` | derived | 32 bytes; defaults to a sub-key of `MFA_ENCRYPTION_KEY` |
| `WHATSAPP_PROVIDER`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_APP_SECRET`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_API_BASE_URL`, `WHATSAPP_TEMPLATE_{CARE_UPDATE,REMINDER,ALERT,LANG}`, `APP_DEEP_LINK_BASE` | `mock` | |
| `LAB_PARTNER`, `LAB_PARTNER_NAME`, `LAB_PARTNER_BASE_URL`, `LAB_PARTNER_API_KEY`, `LAB_WEBHOOK_SECRET`, `LAB_MOCK_REPORT_MINUTES` | `mock`, 2 min | |
| `AMBULANCE_PARTNER`, `AMBULANCE_PARTNER_NAME`, `AMBULANCE_PARTNER_BASE_URL`, `AMBULANCE_PARTNER_API_KEY`, `AMBULANCE_MOCK_ASSIGN_SEC` | `mock`, 15 s | |
| `ABDM_MODE`, `ABDM_BASE_URL`, `ABDM_CLIENT_ID`, `ABDM_CLIENT_SECRET`, `ABDM_HIU_ID`, `ABDM_HIP_ID`, `ABDM_CALLBACK_URL`, `ABDM_WEBHOOK_SECRET`, `ABDM_MOCK_CONSENT_SEC` | `mock`, 10 s | production mode lists every missing item |
| `DRUG_KNOWLEDGE_PROVIDER`, `DRUG_KNOWLEDGE_BASE_URL`, `DRUG_KNOWLEDGE_API_KEY` | `fixture` | |
| `STT_PROVIDER`, `STT_BASE_URL`, `STT_API_KEY`, `STT_MODEL` | `mock` | `openai_whisper_compatible` \| `google` \| `disabled` |
| `IVR_PROVIDER`, `IVR_WEBHOOK_SECRET`, `IVR_PUBLIC_URL` | `mock` | twilio uses `TWILIO_AUTH_TOKEN` |
| `SOS_BUTTON_PROVIDER`, `SOS_WEBHOOK_SECRET` | `mock` | |
| `GOOGLE_MAPS_API_KEY`, `ROUTE_SPEED_KMH` | -, 20 | optional |
| `INVITE_REWARD_INVITER`, `INVITE_REWARD_INVITEE`, `WALLET_CREDIT_EXPIRY_DAYS`, `INVITE_REDEEM_WINDOW_DAYS` | 100, 100, 365, 7 | |
| `MIN_APP_VERSION_DOCTOR_{ANDROID,IOS}` | 1.0.0 | |

### v1.3 partner credentials the founder must obtain

| Partner | What to create | Env vars |
|---|---|---|
| **Meta WhatsApp Cloud API** | Meta Business verification, a WhatsApp Business Account + phone number, a permanent system-user access token, the app secret, webhook URL `https://<api>/api/v1/webhooks/whatsapp` with a verify token, and approved message templates (care update, reminder, family alert) | `WHATSAPP_*` |
| **Lab partner** (e.g. a NABL-accredited home-collection network) | API base URL + key, a webhook secret for `X-Lab-Signature`, the test catalogue and prices (replace the placeholder seed) | `LAB_PARTNER_*`, `LAB_WEBHOOK_SECRET` |
| **Ambulance aggregator** | API base URL + key, commercial terms (the mock is free) | `AMBULANCE_PARTNER_*` |
| **ABDM** | Sandbox registration, HIU/HIP ids, client id/secret, public callback URL; production requires ABDM certification (M1-M3) | `ABDM_*` |
| **Licensed drug database** (e.g. a CDSCO/Indian-brand-aware interaction database) | API access; until then the fixture pack is used in dev and checks fail safe in production | `DRUG_KNOWLEDGE_*` |
| **Speech-to-text** | OpenAI-compatible Whisper endpoint or Google Cloud Speech-to-Text key (Indian English/Hindi/Telugu) | `STT_*` |
| **Telephony** (Exotel or Twilio) | An Indian virtual number with an IVR flow pointing at `https://<api>/api/v1/webhooks/ivr/<provider>`; Exotel: shared HMAC secret; Twilio: auth token + public URL | `IVR_*`, `TWILIO_AUTH_TOKEN` |
| **SOS button vendor** | Device integration and a webhook secret for `X-SOS-Signature` | `SOS_*` |
| **Google Maps** (optional) | Distance Matrix API key | `GOOGLE_MAPS_API_KEY` |
| *Clinical governance* | Approve (or replace) the program templates, interaction pack, preventive schedule, exercise library and diet templates; reviewed insurance checklists | admin endpoints / DB |

## Switching to real PostgreSQL

1. Create a database (PostgreSQL 14+; uses `gen_random_uuid()` and `jsonb`).
2. Set `DATABASE_URL=postgres://user:pass@host:5432/carecompanion` in `.env`.
3. `npm run db:migrate` (or just start the server) and optionally `npm run seed`.
The schema and SQL are identical for PGlite and PostgreSQL; only the driver changes (`src/db/client.ts`).

## Adding a real clinical rule pack

1. Clinical governance authors rules in the `SafetyRule` shape (contract §19). Do not reuse fixture text.
2. `POST /api/v1/admin/safety-rule-packs {version, rules}` (super_admin) creates a `draft`.
3. `POST /admin/safety-rule-packs/:id/approve {approverName, approverRegistration}` records the approver
   (packs containing FIXTURE rules are refused).
4. `POST /admin/safety-rule-packs/:id/activate`. In production only `approved` packs can be activated or served.
5. `/ready` reports `safetyRules: "ok"` once an approved pack is active.

## Production configuration (v1.1)

Every integration is driven by environment variables and has a safe development fallback. With
`NODE_ENV=production` the server **refuses to start** (listing every problem) when a required setting is missing:
console SMS, the mock payment gateway, the no-op malware scanner, `STORAGE_DRIVER=memory`, a missing
`MFA_ENCRYPTION_KEY` or `VIDEO_ROOM_SECRET`, or partial Razorpay/FCM/Jitsi credentials (`productionReadinessIssues()` in
`src/config.ts`). `.env.production.example` lists every production variable without values.

### Credentials the founder must obtain

| Vendor | What to create | Env vars |
|---|---|---|
| **PostgreSQL** (AWS RDS / Aurora, ap-south-1) | a database + user | `DATABASE_URL` |
| **MSG91** (India) *or* **Twilio** | MSG91: account, **DLT entity + header (sender id) + OTP template** registered on a TRAI DLT portal, then a MSG91 *Flow* template linked to the DLT template id with a `##otp##` variable (optionally a second one with `##message##` for notification SMS). Twilio: account SID, auth token, sender number or Messaging Service (DLT registration still applies for Indian numbers) | `SMS_PROVIDER`, `MSG91_AUTH_KEY`, `MSG91_OTP_TEMPLATE_ID`, `MSG91_NOTIFY_TEMPLATE_ID`, `MSG91_SENDER_ID` *or* `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` / `TWILIO_MESSAGING_SERVICE_SID` |
| **Razorpay** | live Key ID + Key Secret (Settings → API keys); a webhook to `https://<api>/api/v1/webhooks/payments` with events `payment.captured`, `payment.failed`, `refund.processed` and a webhook secret | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` |
| **Firebase** (Google Cloud) | a Firebase project with Cloud Messaging; a service account with the *Firebase Cloud Messaging API Admin* role → JSON key | `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` (optional: without them pushes use the console adapter) |
| **AWS** | S3 bucket (Block Public Access, versioning), KMS key, IAM role for the API task with `s3:GetObject/PutObject/DeleteObject/ListBucket` + `kms:Encrypt/Decrypt/GenerateDataKey` | `S3_BUCKET`, `S3_REGION`, `S3_KMS_KEY_ID` (`S3_ACCESS_KEY_ID`/`S3_SECRET_ACCESS_KEY` only without an IAM role) |
| **ClamAV** (self-hosted container, e.g. `clamav/clamav`) | clamd reachable on TCP 3310 | `CLAMAV_HOST`, `CLAMAV_PORT` |
| **Jitsi** | nothing for `meet.jit.si`; for a self-hosted Jitsi with token auth an app id + secret | `JITSI_DOMAIN`, `JITSI_APP_ID`, `JITSI_APP_SECRET` |
| **Anthropic** (optional) | API key | `ANTHROPIC_API_KEY`, `AI_MODEL` |
| **Redis** (optional, >1 instance) | ElastiCache / Redis 6+ | `REDIS_URL` |
| *Self-generated secrets* | `openssl rand -base64 48` etc. | `JWT_SECRET`, `PAYMENT_WEBHOOK_SECRET`, `MFA_ENCRYPTION_KEY` (32 bytes), `VIDEO_ROOM_SECRET`, `METRICS_TOKEN` |
| *Legal/support* | final URLs and contacts | `PRIVACY_URL`, `TERMS_URL`, `ACCOUNT_DELETION_URL`, `SUPPORT_PHONE`, `SUPPORT_EMAIL`, `SUPPORT_WHATSAPP`, `MIN_APP_VERSION_*` |

### Variables by integration

| Integration | Variables (defaults) | Dev fallback |
|---|---|---|
| HTTP | `BODY_LIMIT_KB` (1024), `CORS_ORIGINS`, `RATE_LIMIT_MAX`, `REDIS_URL` | in-memory rate limits |
| SMS OTP | `SMS_PROVIDER` (`console`\|`msg91`\|`twilio`), `SMS_TIMEOUT_MS`, `MSG91_*`, `TWILIO_*` | console; dev OTP `123456` (never in production) |
| Review login | `REVIEW_PHONE`, `REVIEW_OTP` (both or neither) | off |
| Payments | `PAYMENT_GATEWAY` (`mock`), `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `RAZORPAY_BASE_URL`, `PAYMENT_TIMEOUT_MS` | mock gateway + `confirm-mock` |
| Push | `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` | console push |
| Storage | `STORAGE_DRIVER` (`local`\|`s3`\|`memory`), `STORAGE_DIR`, `S3_BUCKET`, `S3_REGION` (ap-south-1), `S3_ENDPOINT`, `S3_FORCE_PATH_STYLE`, `S3_KMS_KEY_ID`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | local disk |
| Malware scan | `CLAMAV_HOST`, `CLAMAV_PORT` (3310), `CLAMAV_TIMEOUT_MS` | no-op scanner |
| Video | `VIDEO_PROVIDER` (`jitsi`), `JITSI_DOMAIN` (meet.jit.si), `JITSI_APP_ID`, `JITSI_APP_SECRET`, `VIDEO_ROOM_SECRET`, `VIDEO_BASE_URL` (placeholder only) | Jitsi on meet.jit.si, room secret derived from `JWT_SECRET` |
| Staff MFA | `MFA_ENFORCED` (true in production), `MFA_ENCRYPTION_KEY`, `MFA_ISSUER` | not enforced; dev key derived from `JWT_SECRET` |
| DPDP | `ACCOUNT_DELETION_GRACE_DAYS` (7), `DATA_EXPORT_TTL_HOURS` (72), `DATA_EXPORT_MAX_PER_DAY` (5) | |
| Worker / DB | `WORKER_ENABLED`, `WORKER_INTERVAL_MS`, `WORKER_LOCK_KEY`, `DATABASE_POOL_MAX` (10) | PGlite: single process is always leader |
| Observability | `METRICS_TOKEN`, `LOG_LEVEL` | `/metrics` open in dev |
| Public config | `SUPPORT_*`, `PRIVACY_URL`, `TERMS_URL`, `ACCOUNT_DELETION_URL`, `MIN_APP_VERSION_{PATIENT,PROVIDER}_{ANDROID,IOS}` | placeholder values |

### How the integrations behave

- **SMS** (`modules/auth/sms.ts`): MSG91 Flow API v5 (`authkey` header, DLT-linked template) or Twilio Messages API.
  Delivery failures return `503 DEPENDENCY_UNAVAILABLE` and burn the undelivered code. Outbox SMS uses the same provider.
- **Review login** (app-store reviewers): when `REVIEW_PHONE` + `REVIEW_OTP` are set, OTP request/verify for exactly that
  phone accepts that fixed code without sending an SMS (also in production) and is audited as `auth.review_login`; the
  server logs a warning at startup. Point it at a demo patient account and remove it after review.
- **Razorpay** (`modules/payments`): real orders (`POST /v1/orders`, paise, basic auth), `Payment.checkout` for Razorpay
  Checkout, `POST /payments/:id/verify` (HMAC `order_id|payment_id`), `POST /payments/:id/retry` (fresh order; re-holds
  the slot of a failed appointment payment), refunds via `POST /v1/payments/:id/refund` (status `pending` until the
  `refund.processed` webhook; dashboard refunds are reconciled from the webhook). Webhooks accept
  `X-Razorpay-Signature` (+ `X-Razorpay-Event-Id`), idempotent on the event id. `verify`/`retry` require
  `Idempotency-Key`; `refund` honours one when sent.
- **Push** (`modules/notifications/fcm.ts`): service-account JWT (RS256, `node:crypto`) → OAuth2 token (cached), FCM v1
  send with the generic payload `{title, body, deepLink, notificationId}`; `UNREGISTERED` tokens are deleted and not
  retried. `DELETE /devices {pushToken}` on logout.
- **S3** (`modules/records/s3.ts`): write-once puts (`If-None-Match: *`), SSE-KMS, streaming reads (`/records/:id/file`
  streams through the API), MinIO via `S3_ENDPOINT`. The seed uses the configured driver too.
- **ClamAV** (`modules/records/scanner.ts`): clamd `INSTREAM` over TCP; infected → `422 FILE_REJECTED` (audited);
  clamd unreachable → `503` (fail closed). `/ready` pings clamd.
- **Video** (`modules/video`): `GET /appointments/:id/video-session`; room name = HMAC(appointment id); HS256 JWT for
  self-hosted Jitsi when `JITSI_APP_ID`/`JITSI_APP_SECRET` are set (JaaS/8x8 would need its RS256 variant).
- **Staff MFA** (`modules/auth/mfa.ts`, `totp.ts`): RFC 6238 TOTP, AES-256-GCM encrypted secrets, 10 hashed
  single-use recovery codes, session-level `mfaVerifiedAt` kept across refresh, 5 wrong codes / 15 min → `RATE_LIMITED`,
  replay protection, `POST /admin/users/:id/mfa/reset` (super_admin). With `MFA_ENFORCED=true` unverified staff sessions
  get `403 MFA_REQUIRED` everywhere except `/me`, `/auth/*`, `/config/public`.
- **Account deletion / export** (`modules/account`): grace period, then the worker revokes sessions/devices/grants,
  anonymises the user, deletes non-clinical personal data of profiles without `patients.retention_hold`, and keeps
  clinical records, payments and audit logs detached from identity **[REQUIRES LEGAL REVIEW]**. Staff get 403.
- **Scaling**: the worker runs only on the instance holding `pg_try_advisory_lock(WORKER_LOCK_KEY)` on a dedicated
  connection (fails over when that connection drops); `REDIS_URL` shares rate-limit counters. `/ready` adds
  `checks.storage` and `checks.worker` (`leader`|`standby`|`disabled`).
- **Observability**: `GET /metrics` (and `/api/v1/metrics`), Prometheus: `cc_http_request_duration_seconds{method,route,status_code}`,
  `cc_ai_request_duration_seconds`, `cc_ai_calls_total`, `cc_ai_fallbacks_total`, `cc_notification_outbox{status}`,
  `cc_safety_events{level,status}`, `cc_sms_sent_total`, `cc_push_sent_total`, `cc_worker_leader`,
  `cc_files_rejected_total` + process metrics. `@fastify/helmet` headers; pino redaction also covers secrets, TOTP codes,
  recovery codes, Razorpay signatures, private keys and join URLs.
- **Record summaries**: PDFs → text layer via `unpdf` → AI gateway; images → Claude vision when `ANTHROPIC_API_KEY` is
  set (≤5 MB, jpeg/png/webp/gif); otherwise a metadata-only summary with the disclaimer. The original file is only read.

### Creating the first admin

```bash
npm run create-admin -- --phone +919812345678 --name "Asha Rao"                 # dev (tsx), default role super_admin
node dist/scripts/create-admin.js --phone +919812345678 --roles super_admin,ops_admin   # production container
```
Idempotent (adds roles to an existing user), works with PGlite or `DATABASE_URL`, audited with actor `system:cli`.
The admin then signs in with OTP and enrols TOTP (`POST /auth/mfa/totp/enroll` → `/confirm`).

### Verifying the PostgreSQL driver

`npm run verify:pg` exposes an in-memory PGlite over the Postgres wire protocol (`@electric-sql/pglite-socket`), points
`DATABASE_URL` at it and runs migrations, the seed, API calls (login, booking race, payment, export) and the advisory
lock through `pg`. For a real server just set `DATABASE_URL` and run `npm run db:migrate`.

## Known limitations / TODO

- Consent, notification and legal copy (en/hi/te) and the account-deletion retention policy need legal/clinical review.
- Record summaries do not OCR scanned PDFs (text layer only); HEIC images get a metadata summary.
- Jitsi JWTs are HS256 (self-hosted token auth); JaaS (8x8) needs an RS256 variant.
- Wound workflow performs image-quality checks only; `wound_ai_analysis` stays off.
- Pagination is offset-based behind an opaque cursor.
- Prescription/referral/invoice PDFs: e-signature rules, SAC codes and GST treatment need legal/tax review. Family Care Plan
  auto-renewal via Razorpay Subscriptions is not implemented (prepaid periods + reminder).
- v1.3: all clinical content (program thresholds, interaction pack, preventive schedule, exercises, diet templates) is
  fixture data [REQUIRES CLINICAL GOVERNANCE]; the ABDM sandbox/production and lab/ambulance HTTP adapters follow the
  documented shapes but must be validated with each partner; wallet rules need RBI PPI legal review.
- `npm audit` reports 4 moderate advisories in dev-only tooling (drizzle-kit → @esbuild-kit → esbuild); the only fix is a
  breaking drizzle-kit downgrade. Production dependencies: 0 vulnerabilities.
