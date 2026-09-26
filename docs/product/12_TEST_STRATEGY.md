# 12 — Test Strategy

Rule (Build Map §17): we never accept "tests should pass". Every phase reports the exact commands run and their results. Tests run against **PGlite** (embedded Postgres), so a clean clone can run the full API suite with no external services. The AI gateway uses the **offline rule-based provider** in tests, and the safety engine uses `fixture-0.1` plus test-local packs.

## 1. Test pyramid

| Layer | Tooling | Location | Required coverage |
|---|---|---|---|
| Unit | vitest | `services/api/src/**/*.test.ts` | Episode state machine (all 121 pairs), task/visit/appointment/payment state guards, validators (zod), policy helpers (`assertPatientAccess`), safety engine matching and aggregation, policy-check filter, pricing/refund calculation, cursor encoding, idempotency hashing |
| Integration | vitest + PGlite + Fastify `inject` | `services/api/test/integration` | DB constraints (slot uniqueness, append-only events), outbox/worker, storage abstraction (local FS), AI gateway (fake + offline providers; timeout, retry, circuit breaker), webhook signature + idempotency, migrations up from empty |
| API contract | vitest + zod schemas generated from `API_CONTRACT.md` types | `services/api/test/contract` | Every endpoint's response validates against the contract shape; error envelope; list envelope; required `Idempotency-Key` |
| Authorization | vitest table-driven | `services/api/test/authz` | For each resource in the `03` matrix: positive **and negative** cases for every role, grantee permission, relationship (doctor without a relationship, provider not assigned, expired share, revoked grant, disabled user) |
| End-to-end (API level) | vitest scenario scripts using seed data | `services/api/test/e2e` | Journeys in §3 |
| Web UI | vitest + Testing Library; Playwright smoke (P1) | `apps/web` | Clinician snapshot shows AI panel distinct with sources; ops queues; admin rule-pack screen shows the fixture banner |
| Mobile | `flutter test` (unit + widget); integration_test (P1) | `apps/patient_app`, `apps/provider_app` | Loading/empty/error/offline/unauthorized states; localization keys exist for en/hi/te; offline queue dedupe; visit code never rendered in the provider app |
| AI evaluation | Evaluation runner over `docs/AI_EVALUATION.md` cases | `services/api/test/ai-evals` (+ clinician review sheet) | 14 scenario classes; safety cases must be 100% correct against the expected level/action for the pack under test |
| Security | npm audit / OSV, Semgrep (SAST), ZAP baseline (DAST, staging), gitleaks, upload fuzzing | CI + staging | No critical/high open for the launch scope |
| Performance | k6 (staging) | `infra/perf` (to add) | p95 targets in §5; slot booking under contention; AI latency with the fallback |
| Recovery | Scripted drills | Runbooks | Backup restore, dead-letter replay, migration rollback rehearsal, kill-switch drill |
| Accessibility | axe (web), Flutter semantics tests, manual TalkBack/VoiceOver, 200% text | apps | AA contrast, labels, target sizes |

## 2. Critical invariants (each must have a named test)

| # | Invariant | Test type |
|---|---|---|
| I-1 | Only allowed episode transitions succeed. RESOLVED→FOLLOW_UP is doctor-only. | Unit + API |
| I-2 | Every transition writes an event **and** an audit entry | Integration |
| I-3 | Double booking of a slot is impossible under parallel requests (N=20 concurrent) | Integration |
| I-4 | Idempotent replay returns an identical body; a different body gives 422 | Integration |
| I-5 | Duplicate/out-of-order payment webhooks never double-confirm, double-refund or duplicate bookings | Integration |
| I-6 | Invalid webhook signature → rejected, audited, no state change | Integration |
| I-7 | Unverified/expired/suspended/off-duty/out-of-zone/no-capability providers are never matched (seed "Anil" expired) | Integration |
| I-8 | Provider cannot read unassigned visits. `patientContext` is gone 24h after completion. `visitCode` is never in the provider view. | Authz |
| I-9 | Revoked family grant is denied on the very next request | Authz |
| I-10 | Grantee with only `view_records` cannot book (seed Lakshmi) | Authz |
| I-11 | LLM output cannot lower the safety level (a mock LLM returns "you're fine" for an emergency fixture input → level remains emergency, template shown) | Unit + API |
| I-12 | Emergency level replaces the reply with the fixed template in en/hi/te | API |
| I-13 | Safety engine unavailable → fail-closed behavior | Integration |
| I-14 | `kill_switch_ai` → immediate fallback; safety still evaluated | API |
| I-15 | AI endpoints without `ai_assistance` → `CONSENT_REQUIRED` | Authz |
| I-16 | Intake never contains values absent from the user text/records (adversarial hallucination tests) | AI eval |
| I-17 | Policy check blocks diagnosis-label and medication-change phrasing | Unit |
| I-18 | Original record files are immutable. The AI summary is stored separately. The file download is audited. | Integration |
| I-19 | Logs contain no PHI (a log-capture test scans for seeded names, phones and concern text) | Integration |
| I-20 | Push/lock-screen notification text contains no health details | Unit |
| I-21 | `confirm-mock` is disabled when `NODE_ENV=production`; `devOtp` is absent in production | API |
| I-22 | Production boot refuses a `fixture_unapproved` active pack | Integration |
| I-23 | Offline provider sync of the same vitals twice creates one record | Mobile + API |
| I-24 | Lists always use `{items,nextCursor}`; limit > 100 is rejected or clamped | Contract |

## 3. End-to-end journeys (seeded data, PGlite)

1. **Onboarding:** new phone → OTP 123456 → consents → name → add dependent → grant Lakshmi-like access → revoke.
2. **AI → doctor:** Vaibhav for Ramesh → Ask AI (routine fixture input) → intake complete → routing `book_doctor` → book Dr. Ananya slot → mock pay success → episode CARE_SCHEDULED → doctor starts/completes → care plan with follow-up → tasks → dose logs → follow-up booked → resolved.
3. **AI → emergency:** fixture emergency input → template → SafetyEvent open → ops acknowledge/resolve → episode EMERGENCY → TRANSFERRED/RESOLVED.
4. **Home visit:** serviceable pincode 500034 → create → auto-match Sunita (not Anil) → accept → en-route → arrived → verify code → vitals (idempotent) → observations → complete → visit_summary record → timeline.
5. **Home visit escalation:** provider escalates `emergency` → SafetyEvent → episode EMERGENCY → the family with `receive_alerts` is notified.
6. **Not serviceable:** pincode 560001 → `NOT_SERVICEABLE`.
7. **Reject/reassign:** provider rejects → `unassigned` → rematch or ops assign → SLA breach flag after `VISIT_ASSIGN_SLA_MIN`.
8. **Payment failure and refund:** failure outcome → appointment remains `pending_payment` → retry → success → cancel → refund → ops sees the refund.
9. **Records:** upload PDF → view → summarize (consent) → share with doctor for 1 day → doctor reads → expiry → denied.
10. **Ops:** overview counts match seeded state; incidents lifecycle; provider suspension removes the provider from matching.

## 4. AI evaluation

See `docs/AI_EVALUATION.md`. The eval suite runs in CI with the offline provider (deterministic) and, nightly or before release, with the configured live model. Results are recorded with model/prompt/policy/pack versions. **Clinical expected behavior for real rule packs is authored by clinical reviewers** **[REQUIRES CLINICAL GOVERNANCE]**. Pass/fail thresholds are fixed before the pilot.

## 5. Performance targets (initial SLO candidates, to be confirmed)

| Endpoint class | p95 | Notes |
|---|---|---|
| Auth, reads | < 300 ms | Mumbai region |
| Booking/visit creation | < 800 ms | incl. transaction + outbox |
| AI message (live model) | < 8 s | fallback returned by 12 s |
| AI message (fallback) | < 500 ms | — |
| Emergency template path | < 1 s | Must not depend on the LLM |
| Webhook processing | < 500 ms | — |

## 6. Test data rules

- Synthetic seed data only (`npm run seed`). **Never** real patient data in dev, test, staging or Claude sessions.
- The fixture safety pack is used only in tests. Tests that need specific rule behavior build their own in-test packs with neutral placeholders (for example keyword `"test-emergency-token"`), never medical content.
- Staging uses synthetic personas. Production data never flows to lower environments.

## 7. CI gates (`.github/workflows/ci.yml`)

| Job | Steps | Blocking |
|---|---|---|
| api | `npm ci` → `typecheck` → `lint` → `test` → `build` | Yes |
| web | `npm ci` → `typecheck` → `lint` → `test` → `build` | Yes |
| flutter (patient_app, provider_app) | `pub get` → `analyze` → `test` → `build web` | Yes |
| security (to add) | gitleaks, dependency audit, Semgrep | Yes for critical/high |
| ai-evals (to add) | offline eval run | Yes on safety cases |

Definition of Done per phase: Build Map §20 (formatted, types and lint pass, unit + integration + authz negative tests, no PHI in logs, migrations with rollback notes, docs/ADRs updated, observability added, risks listed).
