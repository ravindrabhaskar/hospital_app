# Operations Runbook

Audience: care coordinators (L2), operations admins, the on-call clinician (L3), and the on-call engineer. Tool: the web control tower (`/ops`). **Do not use direct database access for operations.** If you need it, that is an incident plus a product gap. All support actions are audited.

> Clinical content in this runbook (what to tell a patient, when to direct to 108, clinical thresholds) is **placeholder process** until the Clinical Governance Board approves the SOPs and emergency playbook. **[REQUIRES CLINICAL GOVERNANCE]**. Support staff (L1/L2) must never give clinical advice.

## 0. Support levels and contacts

| Level | Who | Handles | Must not |
|---|---|---|---|
| L1 customer ops | Support agents | Booking, payment, reschedule, app navigation, provider ETA | Give any medical opinion |
| L2 care coordination | `coordinator` | Episodes, visit assignment, overdue tasks, family coordination, incident intake | Interpret symptoms or vitals |
| L3 clinical | On-duty doctor (`doctor`) | Safety events, clinical questions, clinical incidents | — |
| Engineering on-call | Tech lead rota | Outages, AI kill switch, data incidents | Change clinical rules |

Contact sheet (fill before the pilot): medical director ___, on-duty doctor roster ___, ops lead ___, engineering on-call ___, legal/privacy (DPO/Grievance Officer) ___, payment gateway support ___, provider agency coordinators ___.

## 1. Daily checks (start of shift)

1. `/ops/overview`: open safety events = 0 older than the SLA; unassigned visits; late visits; overdue tasks; pending payments; open incidents; providers on duty vs today's bookings.
2. `/ready` badge in admin: `db ok`, `ai ok|degraded`, `safetyRules ok` (prod must never show `fixture`).
3. Provider roster: expiring credentials (next 30 days) → notify ops_admin.
4. Handover notes from the previous shift (incidents in `investigating`).

## 2. Safety escalation handling (`/ops/safety-events`, `/clinician/escalations`)

Triggered by: AI intake (urgent/emergency), provider escalation from a home visit, mood entry, unanswered fall event, SOS.

| Step | Owner | Target time | Action |
|---|---|---|---|
| 1 Detect | System | immediate | SafetyEvent `open`; episode ESCALATED/EMERGENCY; the patient sees the template; family with `receive_alerts` and emergency contacts notified (emergency) |
| 2 Acknowledge | Coordinator (emergency) / on-duty doctor (urgent) | SLA **[REQUIRES CLINICAL GOVERNANCE]** (placeholder: emergency 5 min, urgent 15 min) | Click **Acknowledge** (records who and when) |
| 3 Contact | Coordinator for emergency; doctor for urgent | right after acknowledgement | **Emergency:** call the patient/caregiver and confirm they have called 108 or are going to the nearest emergency facility (shown in the SOS response). Do not provide clinical assessment. If unreachable, call the emergency contacts; log attempts. **Urgent:** the doctor calls, reviews the snapshot, and decides the pathway (teleconsult now, home visit, ER). |
| 4 Act | Doctor / coordinator | — | Book the consult/visit linked to the same episode, or transition the episode (TRANSFERRED if handed to a hospital) |
| 5 Resolve | Whoever closed the loop | — | **Resolve** with a note: outcome, who was contacted, where the patient went. Never resolve without a documented outcome. |
| 6 Review | Clinical lead | weekly | Review all emergency events and any triggered rule for false positives or negatives; create a `clinical_incident` if care was delayed |

Escalate to the medical director immediately if an emergency event is unacknowledged beyond the SLA, the patient cannot be reached, or a provider reports a deteriorating patient on site. **The platform does not dispatch ambulances.** Never tell a family that one has been sent.

## 3. Unassigned or SLA-breached home visit

Signal: `/ops/home-visits?status=unassigned` or `slaBreached: true` (still requested/unassigned > `VISIT_ASSIGN_SLA_MIN`, default 30 min).

1. Open the visit and check the zone, service capability, preferred window and reason (non-clinical view).
2. Filter `/ops/providers?status=available` for the zone. Only **verified**, unexpired, on-duty providers with the capability can be assigned; the API rejects others.
3. `POST /home-visits/:id/assign { providerId }` (Assign button). Phone the provider to confirm acceptance.
4. No provider available within the window: call the family, offer an alternate slot or a teleconsult. If they decline, cancel the visit (refund is created automatically if paid) and note the reason.
5. If the visit reason suggests urgency, do **not** assess it yourself. Ask the on-duty doctor to review the episode.
6. Log the recurring cause (capacity gap by zone and time) in the weekly capacity report.

## 4. Provider no-show or late arrival

Signal: the visit is **late** (not `arrived` by `preferredEnd`), the provider is unreachable, or the patient reports a no-show.

1. Call the provider (masked number). If they are en route with a new ETA, update the family by phone and in-app. The provider updates `en-route { etaMinutes }`.
2. If the provider cannot attend: reassign (step 3 above). The original provider's rejection or reassignment is recorded in the visit timeline.
3. If no replacement is available: apologize, offer reschedule or refund per the refund policy **[REQUIRES LEGAL REVIEW]** of the policy text, and create an `incident` (type `complaint`, severity medium).
4. Provider quality: 2 no-shows in 30 days → ops_admin reviews; consider `suspended` via `/ops/providers/:id/verification`. Suspension removes them from matching immediately.
5. If the patient's condition may have worsened while waiting, involve the on-duty doctor.

## 5. Payment failure

| Situation | Action |
|---|---|
| Payment `failed` | The service is **not** confirmed (appointment stays `pending_payment`). The patient can retry from the app. L1 helps; no manual confirmation. |
| Patient says they were charged but status is `pending`/`failed` | Check `/ops/payments` for the gateway order ID. Check the gateway dashboard. If the gateway shows captured, wait for the webhook retry (idempotent). If there is still no webhook after 30 min, escalate to engineering to replay the webhook event from the gateway. **Never mark paid by hand in the DB.** |
| Duplicate charge | Gateway shows two captures for one order: refund one via `POST /payments/:id/refund` (ops_admin), and create an incident. |
| Refund request | ops_admin: `POST /payments/:id/refund { reason, amount? }`. Partial refunds allowed. Tell the patient the timeline (gateway T+5–7 working days, confirm with gateway). |
| Webhook signature failures spike | Possible secret mismatch or an attack. Engineering on-call: check `PAYMENT_WEBHOOK_SECRET` rotation. Open a security incident if the payloads are not from the gateway. |

## 6. AI outage or unsafe AI behavior: kill switch

| Signal | Action |
|---|---|
| `/ready` `ai: degraded`, AI fallback rate > 20% | Informational. The fallback is working (safe message + doctor routing). Engineering checks the vendor status. No action needed for patients. |
| AI producing unsafe content (diagnosis, medication advice, false reassurance) reported by a clinician or patient | **Flip `kill_switch_ai` ON** (`/admin/feature-flags`, super_admin or engineering on-call). Every AI reply becomes the fallback immediately. The safety engine and emergency template keep working. Create a `clinical_incident` (high), preserve the `AIInteraction` IDs, notify the medical director. |
| Safety rules not loading / `safetyRules` not `ok` in prod | The AI assistant is automatically fail-closed. Also flip `ai_assistant` OFF to hide entry points, and page engineering. Do **not** activate any unapproved pack to "fix" it. |
| Re-enable | Only after root cause, fix, evaluation-suite re-run (`docs/AI_EVALUATION.md`) and medical director approval. Record it in the incident. |

## 7. Data breach or suspected unauthorized access: first steps

1. **Do not** delete logs or data. Do not contact the suspected actor.
2. Page engineering on-call and the Privacy/Grievance Officer. Start an incident (`INCIDENT_RESPONSE.md`, SEV-1 if PHI exposure is plausible). Note the time; **the CERT-In 6-hour clock and the DPDP intimation duties may apply** **[REQUIRES LEGAL REVIEW]**.
3. Contain: disable the affected user or staff accounts (`/admin/users/:id/disable` revokes sessions); revoke leaked keys (Secrets Manager rotate); revoke family grants or record shares if they are the vector; restrict S3 bucket policy if needed.
4. Preserve evidence: export the relevant audit logs (`/admin/audit-logs`, filtered by actor/entity), CloudTrail and ALB logs. Snapshot the affected resources.
5. Scope: which patients, which data categories, time window (audit log `patientId` + `action` such as `record.file.read`).
6. Legal decides on notifications to the Data Protection Board, CERT-In and affected Data Principals, and on partner notifications.

## 8. Other common procedures

| Procedure | Steps |
|---|---|
| Provider credential expiry | The system excludes them automatically at expiry. ops_admin collects the renewed evidence, verifies it, updates via staff admin, and records it. |
| Family says a grantee should no longer have access | Only the patient/manager can revoke in-app. If the patient cannot (capacity or emergency), escalate to ops_admin plus legal. Document it. |
| Complaint intake | `/ops/incidents` type `complaint`; severity per the matrix; acknowledge to the customer within 24h; resolve and close with notes. |
| Clinical incident (any harm or near-miss) | Type `clinical_incident`; notify the medical director the same day; no blame; review at the governance meeting. |
| Overdue care tasks | `/ops/overdue-tasks`: the coordinator calls the family, offers booking help, and logs the outcome. Clinical questions go to the doctor. |
| Account deletion or export request | Log as an incident (type `complaint`, title "DSR"); follow `09_PRIVACY_CONSENT.md` §5; the legal timeline applies. |

## 9. Weekly review

Safety events (counts, acknowledgement times, false positives/negatives), SLA breaches by zone and hour, no-shows, complaints and refunds, AI fallback and policy violations, break-glass accesses, provider expiries. Outputs: capacity actions, SOP feedback to governance, product backlog items.
