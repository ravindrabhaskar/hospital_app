# Incident Response

Covers technical, security/privacy and clinical-safety incidents. Operational playbooks for specific scenarios are in `OPERATIONS_RUNBOOK.md`. Legal notification obligations (DPDP Act 2023 and Rules, CERT-In directions, contractual notices) are **[REQUIRES LEGAL REVIEW]**. Clinical incident review is owned by the Clinical Governance Board **[REQUIRES CLINICAL GOVERNANCE]**.

## 1. Severity levels

| Sev | Definition (any of) | Examples | Response | Update cadence |
|---|---|---|---|---|
| **SEV-1** | Patient-safety risk from a platform fault; confirmed or likely PHI exposure; emergency pathway broken; full outage | Emergency template not shown; safety rules not evaluated; records bucket public; mass wrong-patient data | Page immediately, 24×7; incident commander within 15 min | every 30 min |
| **SEV-2** | Major degradation of a P0 journey; single-patient data exposure; AI unsafe outputs; payments failing broadly | Booking fails; kill switch used; one grantee saw another patient's records; webhook failures | Page during pilot hours; within 30 min | hourly |
| **SEV-3** | Partial degradation with a workaround | Notifications delayed; one provider app bug; AI fallback elevated | Next business hours | daily |
| **SEV-4** | Minor, cosmetic | Translation error (non-clinical) | Backlog | — |

Any clinical harm or near-miss is also a **clinical incident** (type `clinical_incident` in `/ops/incidents`), whatever the technical severity.

## 2. Roles

| Role | Responsibility |
|---|---|
| Incident Commander (IC) | Owns the incident, decides, delegates; engineering on-call by default, handed over to the medical director for clinical-led incidents |
| Technical lead | Diagnosis, mitigation, fix |
| Clinical lead | Patient-safety assessment, patient outreach decisions, rule/AI decisions |
| Privacy/Grievance Officer | Breach assessment, regulator/user notification decisions with counsel |
| Comms/ops lead | Internal updates, patient/family and partner messaging (approved templates) |
| Scribe | Timeline in the incident doc (UTC and IST) |

## 3. Lifecycle

1. **Detect:** alert, ops report, patient complaint, clinician report, security tool.
2. **Declare:** create the incident record (`/ops/incidents` + incident channel/doc), assign the IC, set the severity.
3. **Triage:** is any patient at risk right now? If yes, the clinical lead starts patient outreach **in parallel** with the technical work.
4. **Contain / mitigate** (fastest safe option first):
   - AI unsafe → `kill_switch_ai` ON.
   - Safety engine fault → the AI is fail-closed; flip `ai_assistant` OFF.
   - Bad deploy → roll back (`DEPLOYMENT_RUNBOOK.md` §5).
   - Credential/key leak → rotate and revoke sessions.
   - Access-control defect → disable the affected endpoint via flag/WAF rule; revoke grants/shares.
   - Provider misconduct → suspend the provider (`/ops/providers/:id/verification`).
5. **Preserve evidence:** audit logs, AIInteraction IDs, CloudTrail, ALB/WAF logs, DB snapshot if data changed. Do not alter the audit tables.
6. **Assess notification duties** (Privacy Officer + counsel): CERT-In (reportable incidents within 6 hours of noticing), the Data Protection Board and affected Data Principals (DPDP), partners/hospitals per contract, payment gateway (payment data). **[REQUIRES LEGAL REVIEW]** for timelines and templates.
7. **Resolve:** service restored and verified; patients contacted where needed.
8. **Post-incident review** within 5 working days (SEV-1/2): blameless; timeline; root cause(s); what detected it; what would have prevented it; action items with owners and dates. Clinical incidents are reviewed at the next Clinical Governance Board.

## 4. Specific playbooks

### 4.1 Safety miss (an emergency not escalated, or a false reassurance)
- IC = medical director. Immediately contact the patient if still relevant.
- Kill switch if the AI contributed. Capture the `AIInteraction` (versions, trace).
- Reproduce against the evaluation harness. Add the case to `docs/AI_EVALUATION.md`.
- Rule changes go **only** through the approval workflow (`07_CLINICAL_SAFETY_INTERFACE.md` §5), expedited, never hot-patched in code.

### 4.2 PHI exposure / unauthorized access
- Follow `OPERATIONS_RUNBOOK.md` §7 first steps. Scope using the audit log (`entityType`, `patientId`, `action`, time window).
- Keep a list of affected Data Principals and data categories for the notification decision.

### 4.3 Payment integrity (double charge, missing confirmation)
- Reconcile the gateway ledger vs the `payments` table by `gatewayOrderId`. Replay missed webhooks. Refund duplicates. Notify affected users.

### 4.4 Provider safety incident (on-site harm, misconduct, patient complaint about behavior)
- Suspend pending investigation; the clinical lead contacts the family; legal review; the credentialing re-check is recorded.

### 4.5 Third-party outage (LLM, SMS, maps, gateway)
- Confirm the graceful degradation (AI fallback, in-app notifications, manual address, payment retry). Status message in-app if the booking flow is affected.

## 5. Communication templates (to finalize with legal)

- **Patient (service disruption):** "Some CareCompanion features are temporarily unavailable. If you have a medical emergency, call 108 now. Your care team can still be reached at <support number>."
- **Patient (data incident):** content per counsel. It must state what happened, what data, what we did, what they can do, and a contact. **[REQUIRES LEGAL REVIEW]**

## 6. Drills

Before the pilot, and quarterly afterwards: (1) kill-switch drill, (2) restore drill, (3) tabletop breach exercise with the Privacy Officer and counsel, (4) emergency-pathway simulation with ops and the on-duty doctor. Record the evidence for the launch gates.
