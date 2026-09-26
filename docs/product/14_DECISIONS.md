# 14 — Decisions and Open Questions

Living register (Build Map Appendix B). Permanent architecture decisions also have ADRs in `docs/adr/`. Status key: **Decided** · **Proposed** (engineering default, founder to confirm) · **Open** (blocks something; needs a founder or expert decision).

## 1. Decisions made

| ID | Decision | Rationale / source | Status | ADR |
|---|---|---|---|---|
| D-001 | Positioning: care orchestration, **not** an AI doctor | Build Map Part I; Blueprint §1 | Decided | — |
| D-002 | Primary wedge: families coordinating care for elderly/chronic/post-discharge dependents; Hyderabad pilot | Build Map §4; Blueprint §4–5 | Decided | — |
| D-003 | TypeScript modular monolith (`services/api`: Fastify 5, Drizzle, zod, pino, vitest) with bounded modules; in-process worker designed to move to BullMQ/Redis | Build Map §15 (prefer a modular monolith) | Decided | ADR-001 |
| D-004 | Monorepo: `services/api`, `apps/web`, `apps/patient_app`, `apps/provider_app`, `docs/`; per-package lockfiles; one CI workflow | Build Map §15 | Decided | ADR-002 |
| D-005 | PostgreSQL in prod; PGlite embedded Postgres in dev/tests (same SQL dialect, zero-install) | Reproducible clean-clone setup (Phase 1 gate) | Decided | ADR-003 |
| D-006 | Provider-agnostic AI gateway; Anthropic Claude primary; offline rule-based fallback; deterministic versioned safety rule packs separate from the LLM; keyword RAG over approved sources | Build Map §12; Blueprint §11 | Decided | ADR-004 |
| D-007 | Flutter for patient and provider apps (provider app has an offline queue); Next.js 15 for the clinician + ops + admin web portal | Blueprint §36; Spec §11 | Decided | ADR-005 |
| D-008 | Languages at launch: en, hi, te (UI keys; server text via `Accept-Language`); high-risk terms fall back to English | Spec §4.3; design system | Decided | — |
| D-009 | Caregiver is **not a role**: `FamilyAccessGrant` with `view_records`, `manage_care`, `book`, `receive_alerts` | API contract §Roles | Decided | — |
| D-010 | Care Episode states and transitions exactly as in `API_CONTRACT.md` §5, enforced in the domain layer | Build Map §11; Phase 4 | Decided | — |
| D-011 | Safety levels `none/routine/urgent/emergency` map to the Blueprint's S0 Information / S1 Routine / S2 Priority / S3 Emergency. Episode priority uses `routine/urgent/emergency` (Blueprint's "priority" = `urgent`). | Reconciles Blueprint §7/§12 with the contract | Decided | — |
| D-012 | The fixture rule pack `fixture-0.1` is dev/test only; production must refuse it | Build Map §12, Phase 11 | Decided | — |
| D-013 | Emergency = fixed localized template (call 108, SOS, notify contacts, nearest 24×7 facilities). **No ambulance dispatch promise.** | Blueprint §21 | Decided | — |
| D-014 | Mock payment gateway + Razorpay-shaped adapter; HMAC webhook; idempotent on event ID; money as integer rupees at the API | Build Map Phase 17 | Decided | — |
| D-015 | Dev OTP `123456`; `devOtp` only when `NODE_ENV != production` | Contract §2 | Decided | — |
| D-016 | Idempotency-Key required on episode/appointment/visit/vitals/pharmacy/SOS/mock-confirm creation | Build Map master prompt | Decided | — |
| D-017 | Reference-UI features beyond P0 (wound, wearables, fall, wellness, pharmacy, govt schemes) are built behind feature flags as assistive-only; `wound_ai_analysis` and `govt_schemes` off | `02_MVP_SCOPE.md` §4 | Decided (pilot visibility is Q-07) | — |
| D-018 | Provider sees minimum patient context, only for assigned visits, and loses it 24h after completion; the visit code is never shown to the provider | Least privilege (Phase 19) | Decided | — |
| D-019 | Visit SLA-breach threshold `VISIT_ASSIGN_SLA_MIN` defaults to 30 min (configurable) | Contract §18 | Proposed (ops to confirm) | — |
| D-020 | Suggested hosting: AWS ap-south-1 (RDS, S3 SSE-KMS, ECS Fargate, CloudFront, Secrets Manager) | Data residency, managed services | Proposed | — |
| D-021 | Cursor pagination with `{items,nextCursor}` everywhere; `/api/v1` URI versioning | Contract | Decided | — |
| D-022 | AI summaries/extractions never overwrite originals; stored separately with model and timestamp | Build Map Phase 8/14 | Decided | — |
| D-023 | Revenue tied to completed care (consult + home-visit fees); no paid AI-chat subscription | Blueprint §32 | Decided | — |
| D-024 | Staff MFA: stub interface in the MVP; real MFA is a launch gate | Contract §2 | Decided (method is Q-16) | — |
| D-025 | The medication list in a care plan is a coordination list, not a legal e-prescription, in the MVP | `06_CARE_PLAN_SPEC.md` | Proposed (Q-13) | — |

## 2. Source conflicts found and how they were resolved

| Conflict | Sources | Resolution |
|---|---|---|
| Home quick actions: "Doctor, Home Checkup, Upload Report, **My Family**" vs "Doctor, Home Checkup, **Medicines**, Upload Report" | Blueprint §9 vs PRD §7/FRD HOME-04 and design reference | Follow the design reference (Talk to Doctor, Home Checkup, Upload Report, Order Medicines) with family via the header switcher. **Founder to confirm (Q-20).** |
| Provider label "intern" | Spec/PRD use "intern doctor"; Blueprint §15 says replace ambiguous labels with explicit categories | The contract keeps `intern` as a provider type for now. Recommend renaming per the governance scope matrix (Q-14). |
| Wound, fall, wellness, wearables in MVP | Spec/PRD list them (Phase 2 / explore); Build Map, Blueprint and Overview defer them | Deferred as P1/P2 but present behind flags (D-017) |
| Teleconsultation priority | Blueprint "P0/P1 depending partner"; PRD Phase 2 | Appointment modes exist; the video adapter is stubbed (P1) |
| Episode status list | Blueprint §7 (New/active/follow-up/resolved/escalated) vs Build Map §11 | Build Map + contract state model (D-010) |
| Backend stack | Spec suggests Django or NestJS | TypeScript Fastify modular monolith (D-003) |

## 3. Open questions for the founder

Ordered by how soon they block the pilot. "Blocks" names the gate or phase.

| ID | Question | Why it matters / options | Owner | Blocks |
|---|---|---|---|---|
| **Q-01** | Who is the **medical director / clinical governance lead**, and who is authorized to approve safety rule packs, SOPs and patient-facing clinical content? | Without an approver, no approved rule pack exists and the AI assistant cannot run in production (fail-safe). **[REQUIRES CLINICAL GOVERNANCE]** | Founder | Clinical gate; Phase 11/27 |
| **Q-02** | What is the **escalation SLA and 24×7 duty model** for `urgent`/`emergency` safety events (who acknowledges, within how many minutes, and during what operating hours)? | Drives on-call rosters, alerts and the app promise ("a doctor will review within X"). Night/weekend coverage is a provider-network decision. **[REQUIRES CLINICAL GOVERNANCE]** | Founder + medical lead + ops | Operations gate |
| **Q-03** | **Legal operating model:** marketplace/intermediary, care coordinator, or healthcare provider (employing nurses/doctors)? Which services are operated directly vs by partners? | Determines liability allocation, provider contracts, telemedicine obligations, GST and the Terms. **[REQUIRES LEGAL REVIEW]** | Founder + counsel | Legal gate |
| **Q-04** | **Pricing and refund policy:** consult fees (seeded ₹399–₹599), home-visit prices (₹399–₹799), platform fee or commission, cancellation windows, no-show rules, refund timelines, the Family Care Plan price | Needs willingness-to-pay evidence and unit economics (contribution per visit/consult). The refund policy drives the refund workflow configuration. | Founder | Payment/economic gates |
| **Q-05** | **Pilot geography and hours:** confirm the micro-zone pincodes (seed: Hyderabad-Central 500001–500040, 500081/82/84), operating hours, and weekend/holiday coverage | Serviceability config, provider capacity and the SLA promise | Founder + ops | Provider gate |
| **Q-06** | **Consent for dependents:** how does an adult elderly parent consent when a child creates their profile? Parental consent for minors? Guardians where capacity is limited? | DPDP verifiable consent; may require the dependent's own OTP or an attestation flow. **[REQUIRES LEGAL REVIEW]** | Founder + counsel | Privacy gate |
| **Q-07** | Which **flagged features are visible to the pilot cohort** (pharmacy orders, fall events, mental wellness, wound photo review, wearables, voice)? | Each needs a Regulatory Feature Register entry and clinical sign-off. Recommendation: pilot with all P1 flags off except voice input after evaluation. **[REQUIRES LEGAL REVIEW]** **[REQUIRES CLINICAL GOVERNANCE]** | Founder | Regulatory gate |
| **Q-08** | **Vendors:** confirm Razorpay; choose video teleconsult, SMS/WhatsApp (e.g. Gupshup/Twilio/MSG91), maps, and the push provider | Adapters exist; real integrations need contracts, DPAs and templates (WhatsApp template approval, DLT registration for SMS in India) | Founder + tech lead | Phase 23 |
| **Q-09** | **LLM data processing:** is sending de-identified or identified concern text to Anthropic (outside India) acceptable? Zero-data-retention agreement? Region options? | Cross-border transfer and DPDP obligations; the fallback is an offline-only assistant. **[REQUIRES LEGAL REVIEW]** | Founder + counsel | Privacy gate |
| **Q-10** | **Rule-pack approval controls:** adopt a two-person rule (uploader ≠ approver ≠ activator) and a dedicated `clinical_approver` permission instead of the super_admin-only approval? | Today the API records the approver's name/registration, but a super_admin performs the action. Needs a contract change. | Founder + medical lead | Clinical gate |
| Q-11 | Confirm the **north-star definition**: "episodes resolved with ≥1 professional care event and a completed plan/follow-up per month"? | Dashboard and pilot success criteria | Founder | Phase 22 |
| Q-12 | Numeric **pilot success thresholds** (paid conversion, visit arrival SLA, follow-up completion, complaint and refund rate, false-negative tolerance = 0 for emergencies?) | Must be fixed **before** the pilot | Founder + medical lead | Pilot start |
| Q-13 | Is an **in-app prescription** (e-Rx) in pilot scope, or do doctors issue prescriptions outside the app? | NMC telemedicine rules, drug schedules, pharmacy Rx gate. **[REQUIRES LEGAL REVIEW]** | Founder + counsel | Clinician workflow |
| Q-14 | **Provider categories and scope matrix** (nurse, phlebotomist, physiotherapist, attendant; retire "intern"?) and required credentials/background checks | Capability config; matching rules. **[REQUIRES CLINICAL GOVERNANCE]** | Medical lead + ops | Phase 5 config |
| Q-15 | **Retention periods** per data category (proposed table in `09_PRIVACY_CONSENT.md` §6) | Deletion jobs, backups. **[REQUIRES LEGAL REVIEW]** | Counsel | Privacy gate |
| Q-16 | **Staff MFA method** (TOTP app, WebAuthn/passkeys, SMS fallback?) | Privileged access control | Tech lead | Security gate |
| Q-17 | **Family alert defaults:** should `receive_alerts` holders get missed-dose alerts by default? Critical safety alerts always? | Alert fatigue vs safety | Product + medical lead | Notifications |
| Q-18 | **ABDM timing:** pursue HIP/HIU sandbox during the pilot or after? ABHA linking in onboarding? | Sandbox registration lead time; certification. **[REQUIRES LEGAL REVIEW]** | Founder | Phase 23 |
| Q-19 | **Cloud confirmation:** AWS ap-south-1 as suggested, or Azure/GCP India regions (credits, partner preference)? | IaC work in Phases 24–27 | Founder + tech lead | Staging build |
| Q-20 | **Home quick actions:** "My Family" vs "Order Medicines" as the 4th tile (conflict above) | UX freeze | Founder | Patient app polish |
| Q-21 | Should coordinators see clinical documents (break-glass) or metadata only? | Least privilege vs support efficiency. **[REQUIRES LEGAL REVIEW]** | Founder + counsel | Ops console |
| Q-22 | Brand/legal entity name: is "CareCompanion" final (trademark search)? | Store listings, Terms | Founder | Store submission |

## 4. How to record a decision

Add a row to §1 (or move an open question there), link an ADR if it is architectural, update affected `docs/product/*` files in the same change, and add a `CHANGELOG.md` entry if the behavior changes.
