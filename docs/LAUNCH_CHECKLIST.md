# Launch Checklist

Two parts: **(A) the launch gates** (Build Map §21 + Groundwork Phase 17 + Blueprint §49), which are the Go/No-Go conditions, and **(B) the groundwork checklist**, condensed from the Launch Groundwork Master Checklist. A gate is complete only when its **evidence** exists, not when a meeting happened. If any critical safety, legal or privacy item is red, that functionality does not scale. The rule is: *do not scale because the app is technically finished.*

## A. Launch gates (controlled pilot → public launch)

| ✓ | Gate | Required evidence | Owner |
|---|---|---|---|
| [ ] | Customer | Real target users complete the care workflow; recurring problem evidenced | Product |
| [ ] | Payment | Real paid care episodes completed (not just interest) | Founder |
| [ ] | Retention | A meaningful share return or continue their care journey | Product |
| [ ] | Clinical | SOPs and red-flag rules approved for launch scope; an **approved** rule pack active in prod **[REQUIRES CLINICAL GOVERNANCE]** | Medical director |
| [ ] | Regulatory / Legal | Feature claims, telemedicine and home-care workflows, Terms/Privacy reviewed; Regulatory Feature Register signed **[REQUIRES LEGAL REVIEW]** | Counsel |
| [ ] | AI / Safety | AI and escalation evaluation passes agreed thresholds (`docs/AI_EVALUATION.md`); false-negative review done | Medical director + tech lead |
| [ ] | Provider | Credentialed supply meets target SLAs in the pilot zone | Ops |
| [ ] | Operations | Support, dispatch, refunds and escalation work in simulation and under pilot load | Ops |
| [ ] | Privacy | Consent, access control, revocation, deletion/export and audit work end-to-end | Privacy officer |
| [ ] | Security | No unresolved critical/high findings; independent pen test complete | Tech lead |
| [ ] | Economics | Contribution margin and failure costs measurable and acceptable for the stage | Founder |
| [ ] | Reliability / Technology | SLO monitoring, backup/restore and rollback tested; critical journey reliable incl. degraded modes | Tech lead |
| [ ] | Support | Team can handle incidents and customer escalation; contact sheet filled | Ops |
| [ ] | Partner | Third-party services under contract/SLA matching public promises | Founder |
| [ ] | Governance | Named owners for clinical incidents and AI/model changes | Founder |
| [ ] | Executive | Written launch-risk register and rollback plan approved by founders | Founder |

### A.1 Technical release gates (pilot build)

- [ ] Production refuses the fixture rule pack; `/ready` shows `safetyRules: ok`.
- [ ] `devOtp` absent and `confirm-mock` disabled in production.
- [ ] P1 flags set per the decision on Q-07; `wound_ai_analysis` and `govt_schemes` off.
- [ ] Pilot cohort gating active (only the approved cohort can access care workflows).
- [ ] Staff MFA enforced (real implementation, not the stub).
- [ ] Full test suite + authz regression + AI eval + migration rehearsal green on staging (Phase 26).
- [ ] Kill-switch drill and restore drill evidence recorded.
- [ ] Alerts route to named on-call people; incident contacts filled (`OPERATIONS_RUNBOOK.md` §0).
- [ ] Store listings: Data safety / privacy labels / health declarations submitted **[REQUIRES LEGAL REVIEW]**.

## B. Groundwork checklist (condensed)

### 01 Product definition
- [ ] One-sentence definition, problem, primary and secondary segments frozen (see `01_PRODUCT_MASTER.md`)
- [ ] Launch geography and service radius selected (Hyderabad micro-zone)
- [ ] Flagship care journey defined and diagrammed
- [ ] MVP / Phase 2 / future matrix frozen (`02_MVP_SCOPE.md`)
- [ ] AI allowed/prohibited and mandatory human escalation defined (`08_AI_POLICY.md`)
- [ ] Business type decided (marketplace / coordinator / provider / SaaS) and direct vs partner services
- [ ] 10-second patient promise; primary navigation frozen

### 02 Customer validation
- [ ] 30–50 patient/family interviews incl. 10–15 active elderly caregivers
- [ ] ~10 doctors, nurses/allied health, clinic admins, home-care operators, diagnostics interviewed
- [ ] Current behavior, record storage, family coordinator, trust in AI, home-care and data-sharing willingness documented
- [ ] Voice/local-language value tested
- [ ] Actual willingness to pay tested; top 5 pain points ranked; the trigger to open the app identified

### 03 Competitive research
- [ ] Apollo 24/7, Tata 1mg, Practo, MediBuddy, MFine, Portea (+ local home care), HealthPlix, eSanjeevani, ABHA/ABDM benchmarked
- [ ] App-store complaint review; commodity vs hard-to-replicate capabilities
- [ ] Market-gap statement tested with users and partners

### 04 Clinical governance
- [ ] Medical/clinical adviser appointed; governance committee formed
- [ ] Approvers defined for clinical content, red-flag rule changes and high-risk AI output review
- [ ] Provider roles, permitted scope and prohibited actions defined
- [ ] Doctor/emergency escalation ownership, follow-up ownership defined
- [ ] Clinical incident reporting, adverse-event review, documentation standards, prescription workflow, quality audits, indemnity requirements

### 05 Clinical SOPs and safety pathways
- [ ] SOPs: fever, headache, dizziness, BP, diabetes/glucose, respiratory, abdominal, elderly weakness, medication questions, post-discharge, wound, falls
- [ ] High-risk pathways: chest pain, severe breathlessness, altered consciousness/fainting, generic emergency
- [ ] Each SOP defines required questions, red flags, permitted AI output, clinician escalation, emergency direction, follow-up
- [ ] Validated by qualified clinicians; version-controlled with a change owner

### 06 Legal and regulatory
- [ ] India healthcare/regulatory review; telemedicine obligations; credentialing; home-care roles; prescription workflow
- [ ] Pharmacy and diagnostic partner compliance
- [ ] Medical Device Software (CDSCO/MDR 2017) assessment per feature; wound-image claims reviewed; emergency/SOS claims reviewed
- [ ] Liability allocation; indemnity; provider and clinic/hospital agreements
- [ ] Terms, Privacy Policy, informed consent, AI disclosure, medical disclaimer, refund/cancellation, grievance process, clinical incident policy, marketing-claims review

### 07 Privacy, security and health data
- [ ] Personal/health data inventory with purpose per field; unnecessary data removed (`docs/DATA_PRIVACY.md`)
- [ ] Purpose-specific, caregiver, clinician, field-worker and partner access rules
- [ ] Retention, correction/deletion, account closure workflows
- [ ] RBAC, privileged MFA, encryption in transit and at rest, tamper-evident audit
- [ ] Secrets management and key rotation; backup/restore/DR
- [ ] Breach detection and response plan; vendor AI/API health-data review; no training on production health data
- [ ] Vulnerability scanning and dependency management; independent pen test; security severity levels and SLAs

### 08 ABDM and interoperability
- [ ] ABHA requirements; ABDM sandbox access; HIP/HIU role assessment
- [ ] Consent-based exchange flows; HPR/HFR opportunities; FHIR mapping; record-linking logic; UHI review
- [ ] Certification/security requirements documented; operational vs interoperable data decided; external-outage fallback designed

### 09 Provider network
- [ ] Launch specialties and doctor capacity; home-care categories; service areas and radius; operating hours
- [ ] Acceptance, arrival and doctor-escalation SLAs; weekend/holiday/night coverage decisions
- [ ] Replacement and no-show procedures; credential checklist; background checks
- [ ] Onboarding and training; revalidation schedule; quality scorecards
- [ ] Payout/settlement, travel reimbursement; complaint/suspension procedures; indemnity evidence
- [ ] Capacity dashboard by geography and time slot

### 10 Partner ecosystem
- [ ] Hospitals, clinics, doctor networks, nursing/home-care, phlebotomy, labs, pharmacy, ambulance options identified
- [ ] Payment gateway, SMS/WhatsApp, maps, cloud and video selected
- [ ] Partner scorecard (API, coverage, SLA, pricing, liability, data sharing, support, refunds)
- [ ] Outage/fallback procedures; pilot agreements signed before public promises

### 11 MVP freeze
- [ ] Patient, clinician, provider and admin P0 capabilities confirmed (`02_MVP_SCOPE.md`)
- [ ] Advanced wound AI, automatic fall detection, wearables, AR/VR postponed/flagged
- [ ] Screen inventory, role-permission matrix (`03_USER_ROLES_AND_PERMISSIONS.md`), end-to-end acceptance criteria signed off

### 12 AI groundwork
- [ ] AI use-case list with risk class; outputs needing clinician review defined
- [ ] Knowledge-source policy; RAG design; red-flag rules separate from the LLM
- [ ] Uncertainty behavior; hallucination testing; versioned prompts/policies/models; per-interaction logging of model, sources, safety triggers and escalation outcome
- [ ] Clinician-reviewed evaluation dataset covering common, high-risk, edge, adversarial, missing, contradictory, medication/allergy, elderly/caregiver and multilingual cases
- [ ] Escalation false positives/negatives measured; thresholds defined before production
- [ ] Kill switch; post-launch monitoring cadence

### 13 Business model and unit economics
- [ ] Pricing hypotheses (consult, home visit, family plan); provider payout; travel, consumables, gateway, support, comms and AI cost per episode; refund/no-show leakage
- [ ] Contribution margin per consult, visit and subscription; CAC, AOV, repeat, conversion, utilization and refund tracking
- [ ] Economic thresholds for geographic expansion

### 14 Prototype and usability
- [ ] Prototypes of onboarding, consent, "I am feeling unwell", intake, escalation, booking, home assessment, arrival, clinician summary, care plan, report upload, timeline, family permissions, follow-up, emergency
- [ ] Tested with 15–20 target users incl. elderly and caregivers, uncoached; completion rate and time measured; confusing language fixed

### 15 Manual paid pilot
- [ ] Intake channel, WhatsApp/phone support, ops tracker, small verified provider group
- [ ] 30–50 real paid care episodes; delays, cancellations, coordinator time, visit duration/travel, doctor response, family involvement, complaints, high-risk cases and follow-up adherence tracked
- [ ] Manual workarounds documented; revised MVP requirements

### 16 Controlled app pilot
- [ ] One geography; 100–200 users; 3–5 partners; sufficient provider capacity; 8–12 weeks
- [ ] Measure: registration→first action, AI completion, AI→care, booking and home-checkup conversion, acceptance and arrival time, completion, repeat use, follow-up, safety escalations, false alerts/missed escalations, complaints/refunds, NPS, cost and revenue per episode, contribution margin, security/privacy incidents
- [ ] Formal clinical safety review before expanding

### 17 Go / No-Go
- [ ] Signed Launch Readiness Review, Go/No-Go decision log, launch risk register, rollback and incident communication plan
