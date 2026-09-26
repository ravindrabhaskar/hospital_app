# 02 — MVP Scope

Priority key: **P0** = required for the controlled Hyderabad pilot. **P1** = next release, or built now but only behind a flag, assistive-only and not part of pilot acceptance. **P2** = future.
Scope rule (Build Map §8 and Blueprint §51): deferred capabilities are added only after the core care workflow has shown clinical safety, user demand, provider reliability and viable economics.

## 1. P0: launch scope

| # | Capability | What "done" means for the pilot | Primary API area | Surfaces |
|---|---|---|---|---|
| 1 | OTP authentication and sessions | Phone OTP, refresh rotation, logout/revocation, staff MFA hook (stub) | `/auth/*`, `/me` | all |
| 2 | Consent and privacy controls | Consent catalogue, grant/revoke, AI consent gate, audit | `/consents` | patient app |
| 3 | Patient profile | Demographics, allergies, conditions, emergency contacts, each with provenance | `/patients/:id` | patient app |
| 4 | Family profiles and permissions | Managed dependents plus revocable `FamilyAccessGrant` with 4 permissions | `/patients`, `/family-access` | patient app |
| 5 | Care Episode | State machine, append-only events, ownership, idempotent creation | `/care-episodes` | all |
| 6 | AI Care Assistant (text; voice input where available) | Conversation → intake → safety → RAG → reply → routing, fully audited | `/ai/*` | patient app |
| 7 | Structured intake | Typed fields with source and confidence, missing-field prompts, no diagnosis labels | `/ai/*` | patient app, clinician |
| 8 | Deterministic safety engine | Versioned rule packs, approval workflow, trace, fail-safe | `/admin/safety-rule-packs` | admin |
| 9 | Reviewed knowledge (RAG) | Source registry with owner/version/status/dates; keyword retrieval with citations | `/admin/knowledge-sources` | admin |
| 10 | Doctor discovery and booking | Verified-only doctors, explainable ranking, concurrency-safe slots, reschedule/cancel | `/doctors`, `/appointments` | patient app |
| 11 | Home assessment | Serviceability, auto-match, lifecycle, visit code, vitals, observations, escalation, completion | `/home-visit*` | patient + provider apps, ops |
| 12 | Provider registry and credentials | Verification states, expiry exclusion, zones, capabilities from config | `/provider/*`, `/ops/providers` | ops, provider app |
| 13 | Health Timeline and records | Secure upload, immutable originals, provenance, sharing, audited file access | `/records`, `/timeline`, `/vitals` | patient app, clinician |
| 14 | Report summary (assistive) | AI summary stored separately, with disclaimer; consent-gated | `/records/:id/summarize` | patient app |
| 15 | Care Plan and Care Tasks | Doctor-authored plan, tasks with owner/due/status, overdue detection | `/care-plans`, `/care-tasks` | clinician, patient app |
| 16 | Medication reminders | Schedule, dose logging (taken/skipped/missed), today's reminders | `/medications`, `/reminders` | patient app |
| 17 | Follow-up workflow | Follow-up due date from the plan, FOLLOW_UP state, re-booking | care-plan + episodes | all |
| 18 | Emergency pathway | Fixed emergency template (108), SOS with contact notification and nearest 24×7 facilities; no dispatch promise | `/emergency/sos` | patient app |
| 19 | Clinician portal | Queue, snapshot with sources, notes, outcome, care plan, escalations, AI feedback/override | `/clinician/*` | web |
| 20 | Provider app | Duty toggle, assignments, accept/reject, en-route/arrived, verify, vitals, observations, escalate, complete, offline queue | `/provider/*`, `/home-visits/:id/*` | provider app |
| 21 | Operations control tower | Overview counts, SLA, unassigned/late visits, safety inbox, overdue tasks, incidents, payments | `/ops/*` | web |
| 22 | Payments and refunds | Mock gateway + Razorpay-shaped adapter, HMAC webhooks, idempotency, refunds | `/payments`, `/webhooks/payments` | all |
| 23 | Notifications | In-app list, preferences, device tokens, critical vs non-critical, no health details on the lock screen | `/notifications*`, `/devices` | all |
| 24 | Analytics and audit | Funnel/continuity/safety/finance metrics, immutable audit log viewer | `/admin/analytics`, `/admin/audit-logs` | web |
| 25 | Admin | Users/roles, staff creation, feature flags, service zones, AI interaction log | `/admin/*` | web |
| 26 | Localization en/hi/te | All strings as keys; server text localized via `Accept-Language` | all | all |

## 2. P1: next release, or flagged and assistive-only now

| Capability | Status in this build | Guardrail |
|---|---|---|
| Teleconsultation video | `videoRoomUrl` field only; video adapter stubbed | Partner selection pending |
| Advanced voice (STT/TTS in hi/te) | `voice_input` flag; device STT input only | hi/te AI flows need evaluation before public enablement |
| Clinician AI summary with claim-level sources | Implemented as advisory (`aiSummary.claims[].sources`) | Visually distinct panel; never overwrites clinician data |
| Pharmacy orders (partner adapter) | `pharmacy_orders` flag on (dev) | Rx products require an uploaded prescription record; no own logistics |
| Diagnostics marketplace | Not built | Partner adapter interface only |
| Hospital/facility discovery | Basic `/facilities` list | Emergency flow shows 24×7 facilities by distance, never by review ranking |
| Wound photo + clinician review | Image-quality checks + clinician review queue | `wound_ai_analysis=false`. **No diagnosis.** **[REQUIRES LEGAL REVIEW]** **[REQUIRES CLINICAL GOVERNANCE]** |
| Mental wellness (mood check-in, activities) | `mental_wellness` flag | Non-diagnostic; the mood entry runs through the safety engine; the self-harm pathway must come from governance **[REQUIRES CLINICAL GOVERNANCE]** |
| Fall events | `fall_detection` flag; manual/sensor event → confirmation → timeout escalation | Not "automatic fall detection" as a claim. **[REQUIRES LEGAL REVIEW]** |
| Offline capture in provider app | Encrypted local queue with idempotent sync | Only for vitals/observations |
| WhatsApp/SMS channels | Adapter interface; in-app + push only | Provider selection pending |
| Family Care Plan subscription | Not built | Pricing needs validation |

## 3. P2: future

Wearable integrations (Apple Health, Health Connect, Fitbit, Samsung Health) · remote patient monitoring · chronic-care programmes · hospital integrations/post-discharge B2B programme · ABDM production (ABHA linking, HIP/HIU, HPR/HFR verification, UHI) · government-scheme intelligence · insurance/TPA and employer integrations · provider SaaS · predictive/advanced clinical AI (only with validation and regulatory clearance) · AR/VR.

## 4. Reference UI features beyond P0: how they are handled

The reference designs (`docs/design/all_screens_reference.jpeg`, 12 screens) show several features the scope documents defer. The founder's UI is honoured without expanding the clinical claims:

| Feature in reference UI | Handling | Feature flag (seed default) | What the UI must say or do |
|---|---|---|---|
| Wound analysis | Capture/upload → **image-quality check only** (`retake_required` / `pending_clinician_review`) → clinician review | `wound_ai_analysis` **off** | "A clinician will review your photo." No severity, infection or treatment output. |
| Wearables / health insights | Connection records + manual `/wearables/sync` (source `device`); real OAuth integrations are P2 | `wearables` on (dev) | Insight cards render **only when real data exists** (HOME-05). No diagnosis from a single reading. |
| Fall detection | Manual/phone-sensor event → "Are you safe?" → auto-escalate after `FALL_RESPONSE_TIMEOUT_SEC` → notify emergency contacts | `fall_detection` on (dev) | No promise of automatic detection accuracy or ambulance dispatch. |
| Mental wellness | Mood score + guided activities + optional share with clinician; safety evaluation of mood notes | `mental_wellness` on (dev) | "Wellness support, not therapy or diagnosis." Crisis pathway text comes from governance. |
| Government schemes | Not implemented | `govt_schemes` **off** | Hidden. Never infer entitlement. |
| Pharmacy / order medicines | Partner catalogue + orders, Rx gate | `pharmacy_orders` on (dev) | Partner name shown; no medication recommendations. |

**Pilot rule:** for the production pilot cohort, every P1 flag defaults to **off** unless the founder, clinical governance and legal sign off per feature (Regulatory Feature Register, `14_DECISIONS.md` D-Q7). Dev/staging keep them on for UI testing.

## 5. Explicitly out of scope (MVP)

- Autonomous diagnosis, differential diagnosis lists or "possible causes" output to patients.
- AI prescribing, dose changes or medication recommendations.
- Declaring a patient "safe" or symptoms "harmless".
- Unsupervised emergency dispatch or ambulance promises.
- AI wound diagnosis, infection detection or severity grading.
- AI mental-health diagnosis or therapy.
- Predictive disease scoring.
- Own pharmacy logistics or own laboratory network.
- Insurance claims engine.
- Production ABDM connectivity (only adapter boundaries exist; no claim of integration).
- Government-data access through any unapproved interface.
- AR/VR, gamification, social community.
- Nationwide provider network; any geography beyond the Hyderabad pilot zones.
- Model training on production health data.
- Doctor ranking based on paid placement (ranking must be explainable: `rankingFactors`).

## 6. MVP acceptance criteria (condensed from PRD §19, FRD §20, Build Map §25)

1. A new patient completes OTP onboarding and the required consents, and adds a dependent.
2. A family member with a grant acts only within the granted permissions, and revocation takes effect on the next request.
3. A concern becomes a Care Episode through structured AI intake, with provenance on every intake field.
4. A triggered deterministic rule cannot be downgraded by the LLM. Emergency shows the fixed template.
5. A patient books a doctor slot (double booking impossible) or requests and tracks a home visit.
6. Only verified, unexpired, on-duty, zone- and capability-matched providers are matched; the provider completes the visit with the visit code and consent.
7. A clinician sees a source-linked snapshot, completes the consult and authors a Care Plan.
8. Care Plan tasks, reminders and the follow-up continue after the consultation.
9. Original records are immutable and provenance is visible.
10. Ops can see and act on unassigned/late visits, safety events, overdue tasks, incidents and payments without database access.
11. Repeated payment callbacks cannot double-charge or duplicate bookings.
12. Every sensitive action appears in the audit log; AI interactions are versioned.
