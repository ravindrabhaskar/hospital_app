# Build Plan

Maps the founder's Build Map (Phases 0–27, the controlling document) to this repository. Status key:
- **Implemented (MVP)**: foundational implementation in v0.1.0, built against `docs/api/API_CONTRACT.md`. It still needs hardening, clinical approval and staging evidence before the pilot.
- **Adapter/stub**: an interface or boundary exists; the real external integration does not.
- **Pending (human/ops)**: needs people, vendors, approvals or production infrastructure. Code alone cannot close it.

"Implemented" never means "clinically approved" or "launch-ready". See `docs/LAUNCH_CHECKLIST.md` and `docs/KNOWN_LIMITATIONS.md`.

## 1. Phase table

| Phase | Scope (Build Map) | Where in repo | Status |
|---|---|---|---|
| 0 | Repository audit, architecture baseline, ADR-001/002, P0/P1/P2 backlog | `docs/product/*`, `docs/adr/*`, `docs/BUILD_PLAN.md` | Implemented (MVP) |
| 1 | Foundation and CI: env validation, lint/type/test, CI, PHI-safe logging, health/readiness, error contract, correlation ID | `services/api` (config, logger, error mapper, `/health`, `/ready`), `.github/workflows/ci.yml` | Implemented (MVP) |
| 2 | Identity, OTP auth, RBAC (7 roles → contract roles), MFA hook, revocation, auth audit | `services/api` identity module + policy layer | Implemented (MVP): MFA is a stub hook |
| 3 | Patient, family and consent core: profiles, dependents, emergency contacts, consent ledger, grants, access-check helper | `services/api` patients + consent modules | Implemented (MVP) |
| 4 | Care Episode backbone: state machine, append-only events, ownership, idempotent create | `services/api` episodes module | Implemented (MVP) |
| 5 | Provider registry, credentials, expiry, service zones, availability, capability config | `services/api` providers module; `/ops/providers`, `/admin/staff`, `/admin/service-zones` | Implemented (MVP): capability/scope values await the governance matrix |
| 6 | Doctor discovery and appointment engine: filters, slots, concurrency-safe booking, reschedule/cancel, episode link | `services/api` appointments module; patient app Care tab | Implemented (MVP) |
| 7 | Home-visit operations: serviceability, matching, assign/accept/reject/reassign, ETA, identity + consent, vitals/observations, escalation, completion | `services/api` home-visits module; `apps/provider_app`; ops console | Implemented (MVP): no clinical interpretation of vitals |
| 8 | Health Timeline and records: secure upload, validation hooks, classification, storage abstraction, provenance, sharing, correction/restriction | `services/api` records module (local storage driver; S3 driver for prod) | Implemented (MVP): malware scan is a hook only |
| 9 | AI gateway and audit: provider-agnostic, versioning, timeouts/retry/circuit breaker, cost/latency, AIInteraction | `services/api` ai/gateway (Anthropic + offline provider) | Implemented (MVP) |
| 10 | Structured AI intake: session, patient selection, typed intake with provenance, missing-field prompts, no diagnosis label | `services/api` ai/intake | Implemented (MVP) |
| 11 | Deterministic safety engine: interface, versioned packs, trace, escalation, fail-safe, admin status | `services/api` safety module; `/admin/safety-rule-packs` | Implemented (MVP): **only the non-clinical fixture pack exists** |
| 12 | Reviewed knowledge/RAG: source registry, ingestion, version/status/owner, chunking, citations, expiry | `services/api` ai/knowledge (keyword retrieval) | Implemented (MVP): no approved content loaded |
| 13 | AI Care Assistant and routing: intake + safety + RAG, routing, limitations, episode link, audit | `services/api` ai/assistant; patient app Ask AI | Implemented (MVP) |
| 14 | Clinician snapshot and consultation: source-linked summary, notes, outcome, override, audit | `services/api` clinician routes; `apps/web` `/clinician` | Implemented (MVP) |
| 15 | Care Plan, tasks and follow-up: plan, task types, owners, completion, follow-up, resolution hooks | `services/api` care-plans module; web + patient app | Implemented (MVP) |
| 16 | Notifications: channel abstraction, templates/localization, preferences, critical vs marketing, retry/idempotency, generic lock-screen text | `services/api` notifications module | Implemented (MVP) for in-app + push abstraction. SMS/WhatsApp/email: Adapter/stub |
| 17 | Payments: intent/order, gateway abstraction, webhook verification, idempotency, refunds, receipts, settlement hooks | `services/api` payments module (mock + Razorpay-shaped adapter) | Implemented (MVP) with the mock gateway. Live Razorpay: Adapter/stub |
| 18 | Patient mobile app: onboarding/OTP, consent/language/family, Home, Ask AI, episodes, booking, visit tracking, records, care plan, profile | `apps/patient_app` | Implemented (MVP) |
| 19 | Provider mobile app: auth/status, assignments, arrival, verification/consent, vitals, escalation, completion, offline queue | `apps/provider_app` | Implemented (MVP) |
| 20 | Clinician web app: queue, snapshot, timeline, reports, visit data, notes, care plan, follow-up, AI source inspection/override | `apps/web` | Implemented (MVP) |
| 21 | Operations control tower: live requests, unassigned/late visits, provider status, escalations, overdue tasks, incidents, payments, SLA | `apps/web` `/ops`; `/ops/*` API | Implemented (MVP) |
| 22 | Analytics and instrumentation: event taxonomy, funnel, continuity, safety, finance metrics | `/admin/analytics`; `apps/web` `/admin` | Implemented (MVP): the event dictionary and dashboard owners are to be formalized; de-identified warehouse pending |
| 23 | External integrations: ABDM-ready boundaries, maps, video, SMS/WhatsApp, pharmacy/lab adapters, webhook audit | Adapter interfaces in `services/api` | **Adapter/stub**: ABDM (no sandbox/certification), video (`videoRoomUrl` only), SMS/WhatsApp, maps (pincode + lat/lng only), real payment gateway, pharmacy/lab partners, wearables |
| 24 | Security hardening: threat model, authz regression, rate limiting, validation, file scanning, secrets, SAST/DAST/deps, backup/restore, pen-test tracker | `docs/SECURITY.md`; partial controls in the API | **Pending (human/ops)**: independent pen test, scanners in CI, AWS secrets/KMS, file-scanning service |
| 25 | Reliability, observability and DR: metrics/traces, SLOs, alerting, DLQ monitoring, backups, restore drill, runbooks, flags/kill switches | `docs/product/13_DEPLOYMENT.md`, `docs/runbooks/*`; kill switch in the API | **Pending (human/ops)**: production monitoring, alert routing, restore drill evidence (flags/kill switch implemented) |
| 26 | End-to-end release candidate: synthetic seed, full journeys, AI eval, permission regression, migration rehearsal, release notes | `services/api` seed + tests; `docs/AI_EVALUATION.md` | **Pending (human/ops)**: staging environment, clinician-reviewed evaluation, load test, rehearsal |
| 27 | Production readiness and controlled pilot: config review, key rotation, incident contacts, support runbook, provider roster, **clinical approval**, **legal/privacy approval**, feature-flagged cohort rollout, pilot dashboards | `docs/LAUNCH_CHECKLIST.md` | **Pending (human/ops)** |

## 2. What the humans must do next

From the Launch Groundwork Checklist. None of these can be completed by writing code.

### A. Clinical governance (Groundwork Phases 04–05, 12)
1. Appoint a **medical director / clinical adviser** and form the governance committee (Q-01).
2. Write the **Clinical Governance Charter**, the **provider role-and-scope matrix**, the **escalation ownership matrix** (who acknowledges `urgent`/`emergency`, SLA, 24×7 coverage) and the **clinical incident policy**.
3. Author and approve the **SOP library** (fever, headache, dizziness, BP, diabetes/glucose, respiratory, abdominal, elderly weakness, medication questions, post-discharge, wounds, falls) and the **high-risk pathways** (chest pain, severe breathlessness, altered consciousness/fainting, generic emergency).
4. Convert the SOPs into a **red-flag rule catalogue**, then into a rule pack; approve it through `07_CLINICAL_SAFETY_INTERFACE.md` §5. Until then the AI assistant must stay disabled in production.
5. Approve the **knowledge sources** for RAG and the **clinician-reviewed en/hi/te glossary**.
6. Build the **clinician-reviewed AI evaluation dataset** and set pass/fail thresholds (`docs/AI_EVALUATION.md`).

### B. Legal and regulatory (Groundwork Phase 06–07)
1. India healthcare/regulatory counsel: operating model and liability (Q-03), NMC telemedicine obligations, prescription workflow (Q-13), home-care role requirements.
2. **CDSCO Medical Device Software** intended-use assessment per feature (Regulatory Feature Register), especially the AI assistant, wound, fall and wellness features.
3. **DPDP Act 2023** readiness: notices and consent text (en/hi/te), dependent/child consent (Q-06), retention (Q-15), cross-border AI processing (Q-09), DPAs with vendors, Grievance Officer, breach procedure.
4. Terms of Service, Privacy Policy, AI disclosure, refund/cancellation policy, provider and clinic agreements, professional indemnity, marketing-claims guide.

### C. Provider network (Groundwork Phase 09)
1. Recruit, credential (evidence-based verification, background checks) and train the initial doctors and home-care professionals for the Hyderabad micro-zone (Q-05).
2. Define the SLAs (acceptance, arrival, doctor escalation), operating hours, no-show/replacement procedures, payouts and travel reimbursement.
3. Load the verified roster via `/admin/staff`, with zones and capabilities from the approved scope matrix.

### D. ABDM and interoperability (Groundwork Phase 08)
1. Register for the **ABDM sandbox**; decide the HIP/HIU roles, ABHA linking, and HPR/HFR verification use (Q-18).
2. Draft the FHIR mapping and consent-flow wireframes. **Do not claim ABDM connectivity** until sandbox and certification are complete.

### E. Partners and vendors (Groundwork Phase 10)
Payment gateway contract (Razorpay confirmation), SMS/WhatsApp with DLT and template registration, video, maps, cloud account (Q-08, Q-19), pharmacy/lab/ambulance partners with SLAs and outage fallbacks.

### F. Pricing and economics validation (Groundwork Phases 02, 13)
Customer interviews (30–50 families, 10–15 elderly-care caregivers, ~10 doctors), willingness-to-pay evidence, a pricing sheet (Q-04), a unit-economics model (contribution per visit and consult), and scale thresholds.

### G. Manual pilot → controlled app pilot (Groundwork Phases 14–17)
1. Usability test the prototype and app with 15–20 target users, including elderly users and caregivers.
2. Run **30–50 paid manual/concierge care episodes**; log every manual workaround.
3. Controlled app pilot: 100–200 users, 3–5 partners, 10–20 professionals, 8–12 weeks, numeric success thresholds fixed beforehand (Q-12).
4. Go/No-Go review against `docs/LAUNCH_CHECKLIST.md`.

### H. Engineering follow-through (Phases 24–27)
Provision staging and prod on AWS ap-south-1 with IaC; add security scanning to CI; commission an independent pen test; implement real staff MFA; wire alerts and on-call; run the restore and kill-switch drills; clinician-reviewed evaluation run; load test; release-readiness report (Build Map §26 completion prompt).
