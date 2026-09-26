# 01 — Product Master

> Source of truth for what CareCompanion is, who it is for, and the words we use. Derived from the founder's Build Map (controlling document), Complete Product Blueprint, Product Overview & Market, BRD, PRD, FRD, Complete Specification and Pitch Deck (`docs/source_extracts/`). If this file conflicts with the Build Map, the Build Map wins. Raise the conflict in `14_DECISIONS.md` and do not guess.

## 1. Product definition

**CareCompanion is an AI-powered healthcare companion and care-orchestration platform.** A patient or family member explains a health concern once. The platform gathers relevant context, routes the person toward appropriate professional care, coordinates home and digital care, keeps longitudinal health information, and manages follow-up until the care episode is complete.

**Strategic category:** AI-powered care orchestration.

**One-line promise (consumer):** *"Tell us what is happening. We help you understand the next step, connect you to the right care, organize everything, and stay with you through follow-up."*
Short form: *"From health concern to care to recovery: one connected companion."*

**B2B positioning:** A care-orchestration layer that connects patients, clinicians, home healthcare and longitudinal health context.

**Public regulatory posture:** "AI-assisted healthcare with qualified human oversight." **[REQUIRES LEGAL REVIEW]** before we use it in any external claim.

## 2. What CareCompanion is NOT

| We are not | Why this matters |
|---|---|
| An AI doctor or autonomous diagnosis system | AI output is assistive. The generative model never makes the final safety or emergency decision, and it never returns a diagnosis label. |
| A generic symptom checker | Every conversation must end in a clear next state (information, doctor, home visit, emergency) linked to a Care Episode. |
| A pharmacy, lab or doctor marketplace | These are partner integrations. Doctor booking alone is not the moat. |
| A medical-records locker | Records exist to give context to a care journey. ABDM/ABHA is national infrastructure that we integrate with, not replace. |
| An emergency dispatch service | We show the emergency guidance (call 108) and notify permitted contacts. We **never promise ambulance dispatch** without a contractual and technical integration. **[REQUIRES LEGAL REVIEW]** |

## 3. The problem: care fragmentation

The problem is not a lack of healthcare apps. It is a lack of **continuity**: what should happen next, who should do it, what information they need, and whether the next step actually happened. A typical Indian family journey moves across search, general-purpose AI, doctor apps, hospital systems, WhatsApp, lab apps, pharmacies and paper prescriptions, and nobody coordinates the whole episode.

Pain points (BRD/PRD):
1. Uncertainty about what level of care is needed.
2. Health information scattered across providers, documents and apps.
3. Difficulty arranging routine care at home.
4. Families coordinate appointments, medicines, reports and follow-ups by hand.
5. Language and health-literacy barriers.
6. Limited continuity after a consultation. The prescription is where the digital workflow ends.

## 4. Market gap

India already has strong players for individual transactions (Apollo 24/7, Tata 1mg, Practo, MediBuddy, MFine, Portea, HealthPlix, eSanjeevani, and ABDM/Aarogya Setu 2.0 as public infrastructure). **We do not claim that nobody offers these features.** The gap is the orchestration and continuity gap *across* those categories.

| Gap | Current friction | CareCompanion response |
|---|---|---|
| Care navigation | The user has to know whether they need a doctor, test, home care or urgent care | Start with a natural-language concern and route it through a controlled workflow |
| Digital-to-physical bridge | Teleconsults lack vitals and physical observations | A qualified home assessment feeds structured observations to the clinician |
| Care-episode continuity | Appointments, reports, medicines and follow-ups are disconnected | The **Care Episode** is the central object that links every event |
| Family coordination | Caregivers coordinate parents by hand | Permission-based family access grants, alerts and managed dependents |
| Post-consultation execution | The prescription ends the workflow | Care Plan → Care Tasks → reminders → follow-up completion |
| Clinician context | The doctor rebuilds the history manually | A source-linked pre-consultation Clinical Snapshot |
| Regional language | A translated UI is not the same as understandable navigation | Conversational en/hi/te mapped to a structured intake |

**Commodity features (not a moat):** doctor discovery, pharmacy, diagnostics, record storage, generic AI health information.
**Moat hypothesis:** trusted orchestration + a qualified provider network with geographic density + clinical SOPs and governance + family relationships + longitudinal, care-episode-linked context + operational reliability (SLAs).

## 5. Customer wedge

**Primary launch segment:** families coordinating recurring healthcare for parents or dependent adults, especially **elderly, chronic-care, mobility-limited and post-discharge** patients.

| Segment | Primary need |
|---|---|
| Adults managing elderly parents (often remotely) | Remote coordination, medicines, appointments, reports |
| Chronic-care families (for example hypertension, diabetes) | Repeat consultations, vitals, reports, follow-up |
| Post-discharge patients | Follow-up, home care, medicines, warning signs |
| Mobility-limited patients | Routine care without travel |
| Multilingual / low-digital-literacy users | Voice and natural-language navigation |

Secondary customers: doctors, clinics and hospitals (post-discharge continuity), then employers and insurers/TPAs.

**Launch geography:** Hyderabad pilot. Start with a 5–10 km micro-zone (seeded as zone "Hyderabad-Central"), grow to 15–20 km, and go city-wide only after SLAs are stable.

**Flagship journey:** A 66-year-old father feels dizzy. His daughter describes it in Telugu → the AI gathers structured context (age, onset, duration, conditions, medicines, associated symptoms, available vitals) → the deterministic safety engine checks the clinician-approved red flags → if suitable, a home visit captures approved vitals → the doctor receives a source-linked snapshot and consults → a Care Plan becomes tasks, medication reminders and a follow-up → authorized family members are kept informed → the episode stays open until it is resolved, escalated or transferred.

## 6. Product layers and hierarchy

| Layer | Capabilities |
|---|---|
| **Intelligence** | AI Care Assistant, structured intake, authorized context retrieval, deterministic safety rules, reviewed-knowledge RAG, report summaries, voice/translation, clinician summaries |
| **Care delivery** | Doctor discovery and booking, teleconsult (adapter), home assessment, provider matching and tracking, partner pharmacy/diagnostics/hospital routing |
| **Continuity** | Care Episodes, Health Timeline, Care Plans, Care Tasks, family access, medications, follow-ups, reminders; monitoring later |

Final hierarchy: AI companion (understands) → care navigation (decides the pathway) → doctor/home care (professional care happens) → Care Plan (what must happen next) → Health Timeline (context) → family coordination → follow-up (did it happen?) → continuous care (later).

**Product principle:** do not give users more healthcare options. Reduce the number of decisions the patient has to make, and help them complete the whole care journey safely.

## 7. Applications

| Application | Users | Repo location |
|---|---|---|
| Patient mobile app (Flutter) | Patients, family caregivers | `apps/patient_app` |
| Provider mobile app (Flutter, offline queue) | Home-care field professionals | `apps/provider_app` |
| Web portal (Next.js 15): clinician, operations control tower, admin | Doctors, coordinators, ops admins, super admins | `apps/web` |
| Core API (TypeScript modular monolith) | All clients | `services/api` |

Patient navigation, fixed at five tabs: **Home · Care · Ask AI · Records · Profile.** The home screen has one dominant CTA (Ask AI) and four quick actions (Talk to Doctor, Home Checkup, Upload Report, My Family / Order Medicines per the design reference). See `11_DESIGN_SYSTEM.md`.

## 8. North star and KPIs

**North-star metric: completed care journeys.** A patient or family explains a concern once; the platform turns it safely into an appropriate care workflow; professionals receive the context they need; the care plan becomes executable tasks; the family stays appropriately informed; and the episode reaches follow-up or resolution without the user rebuilding the journey across disconnected systems.

Operational definition (to confirm; see `14_DECISIONS.md`): *number of Care Episodes reaching `RESOLVED` with at least one professional care event and a completed care plan or follow-up, per month.*

| Category | KPI | Source in API (`/admin/analytics`) |
|---|---|---|
| Activation | Registration → first care action; onboarding completion | `activation.*` |
| AI | Conversation → completed intake | `funnel.conversationsStarted`, `intakesCompleted` |
| Navigation | AI → appropriate care conversion | `funnel.routedToCare` |
| Doctor / home care | Booking and completion | `funnel.appointments*`, `homeVisits*` |
| SLA | Assignment time, on-time arrival | `/ops/overview.sla` |
| Continuity | Care-task, follow-up and medication adherence rates | `continuity.*` |
| Family | Family grants activated | `activation.familyGrants` |
| Safety | Safety events, emergencies, acknowledgement time, AI fallback rate, false positives/negatives (from evaluation) | `safety.*` |
| Clinical | Doctor override rate of AI suggestions | `/clinician/ai-feedback` |
| Economics | Revenue per episode, refunds, contribution margin | `finance.*` (+ offline cost model) |

Illustrative funnel (not a target): 1,000 ask for help → 700 complete intake → 300 need professional care → 250 receive care → 220 get an actionable plan → 190 complete next steps → 150 return. **Real targets must be set from pilot data before the pilot starts.** The goalposts do not move afterwards.

## 9. Validation hypotheses (not facts)

These are treated as hypotheses until paid pilots prove them. They must never appear in investor or marketing material as established facts.

1. Families will pay for coordination beyond the cost of the underlying services.
2. A reliable home-assessment network can deliver within promised SLAs at Hyderabad density.
3. Clinicians will consistently use a structured pre-consultation summary.
4. AI-first navigation improves conversion to appropriate care without unsafe over-reliance.
5. Repeat care and family subscriptions can produce a positive contribution margin.
6. Hospitals and clinics will use the platform as a post-discharge continuity layer.

## 10. Business model (launch)

Revenue is tied to completed care, **not AI access**. MVP: doctor consultation fee/commission and home-visit fee/margin (seeded prices ₹399–₹799). Early post-pilot: Family Care Plan subscription (price to be validated). Later: clinic/provider SaaS, hospital post-discharge programmes, corporate plans, remote monitoring, API. The business must not depend on a paid AI-chat subscription.

## 11. Terminology glossary

| Term | Definition | API / code name |
|---|---|---|
| **Care Episode** | One health concern from start to resolution. It is the backbone object, and every appointment, visit, record, plan, AI conversation and safety event links to it. | `CareEpisode` |
| **Episode Event** | Append-only chronological entry within an episode | `EpisodeEvent` |
| **Patient** | The person receiving care. Every user gets a self patient; dependents are separate Patient records. | `Patient` |
| **Dependent / managed patient** | A patient profile created and managed by a user (for example "Father"). The creator holds all four family permissions. | `POST /patients` |
| **Family Access Grant** | An explicit, revocable delegation from a patient to another user with named permissions. **Caregiver is not a role.** | `FamilyAccessGrant` |
| **Family permissions** | `view_records`, `manage_care`, `book`, `receive_alerts` | `FamilyPermission` |
| **Consent** | Purpose-, version- and scope-specific permission recorded in the consent ledger | `Consent` |
| **Provider** | Home-care field professional (nurse, technician, intern, physiotherapist). The `provider` role. The same table also backs doctors' professional records. | `Provider` |
| **Doctor / Clinician** | Registered Medical Practitioner using the clinician portal | role `doctor` |
| **Care Coordinator** | Staff member who manages families, episodes, tasks and provider coordination (L2 support) | role `coordinator` |
| **Home Visit / Home Checkup** | A home assessment fulfilled by a verified provider | `HomeVisit` |
| **Visit code** | A 4-digit code shown only to the patient/family. The provider enters it to verify identity. | `visitCode` |
| **Structured Intake** | Typed fields extracted from the conversation, each with a provenance source and confidence | `Intake`, `IntakeField` |
| **Safety Engine** | Deterministic, versioned rule evaluation that runs independently of the LLM | `SafetyResult` |
| **Rule Pack** | A versioned set of safety rules. It must be clinically approved before production. | `SafetyRulePack` |
| **Fixture pack** | A non-clinical test rule pack (`fixture-0.1`, status `fixture_unapproved`). **Never valid for production.** | — |
| **Safety Event** | A persisted escalation from AI intake, home visit, mood, fall or SOS | `SafetyEvent` |
| **Safety level** | `none` / `routine` / `urgent` / `emergency` (maps to the Blueprint's S0–S3 routing classes, which are **not diagnoses**) | `SafetyResult.level` |
| **Routing** | The next action chosen for a conversation: continue intake, information, book doctor, home visit, emergency | `Routing` |
| **Clinical Snapshot** | Compact source-linked pre-consultation view for the doctor | `ClinicalSnapshot` |
| **Care Plan** | Clinician-authored next-step plan. It supersedes the previous active plan for the episode. | `CarePlan` |
| **Care Task** | An executable, trackable action derived from a Care Plan | `CareTask` |
| **Provenance** | Where a data item came from: `patient_entered`, `clinician_verified`, `home_visit`, `imported`, `ai_extracted`, `device` | `Provenance` |
| **Health Timeline** | Chronological, provenance-labelled view of records, visits, vitals, plans and episodes | `TimelineItem` |
| **AI Interaction** | Audit record of one AI call: model, prompt, policy and rule-pack versions, safety level, tokens, latency, fallback | `AIInteraction` |
| **Knowledge Source** | A reviewed document in the RAG registry with owner, version, status and effective/expiry dates | `KnowledgeSource` |
| **Control Tower** | The operations web console (`/ops/*`) | — |
| **Kill switch** | Feature flag `kill_switch_ai`. When on, the AI returns the safe fallback immediately. | — |
| **SLA-breached visit** | Still `requested`/`unassigned` more than `VISIT_ASSIGN_SLA_MIN` (default 30) minutes after creation | `slaBreached` |
| **Late visit** | Has not reached `arrived` by `preferredEnd` | — |
| **Idempotency key** | A client-supplied header that makes create/pay operations safe to retry | `Idempotency-Key` |
| **ABDM / ABHA / HPR / HFR** | Ayushman Bharat Digital Mission; Health Account ID; Healthcare Professional Registry; Health Facility Registry | adapter boundary only in MVP |
| **DPDP Act** | Digital Personal Data Protection Act, 2023 (India) and its Rules | see `09_PRIVACY_CONSENT.md` |
| **RMP** | Registered Medical Practitioner (NMC telemedicine guidelines) | — |
