# 08 — AI Policy

AI in CareCompanion is an **assistive navigation and information-management layer around professional care**. It is not a clinician. This policy binds the product, the prompts and the code (`services/api` AI gateway and orchestrator).

## 1. Allowed and forbidden

| AI MAY | AI MUST NOT |
|---|---|
| Understand natural-language concerns (text; voice via STT) in en/hi/te | Diagnose, name a likely disease, or give a differential/"possible causes" list to patients |
| Ask structured follow-up questions for missing intake fields | Prescribe, recommend, stop or change medicines or doses |
| Use **authorized** patient context (allergies, conditions, active meds) | Declare a patient medically safe or symptoms harmless |
| Explain reports and approved content in simple language (with a disclaimer) | Decide emergency treatment or override the safety engine |
| Recommend a **service pathway** (information, doctor + specialty, home visit, emergency) | Replace or overwrite clinician judgment, notes, plans or original records |
| Summarize context for clinicians **with source references** (advisory) | Invent absent clinical data (values, dates, history) |
| Support booking, reminders and follow-up coordination | Use unvalidated image analysis for diagnostic claims (`wound_ai_analysis=false`) |
| Translate and normalize terminology via the clinician-reviewed glossary | Answer clinical-information questions from the open web or outside approved sources |
| Provide non-diagnostic wellness support text (flagged feature) | Diagnose or treat mental-health conditions |
| | Use production health data for model training |

Every patient-visible AI text carries the label **"AI-generated · not a diagnosis"**. Every AI use case is registered in the AI Use-Case Risk Register (§8) and the Regulatory Feature Register **[REQUIRES LEGAL REVIEW]**.

## 2. Pipeline (per message; matches `API_CONTRACT.md` §10)

| # | Stage | Implementation | Failure behavior |
|---|---|---|---|
| 1 | Consent + auth check | `ai_assistance` consent; `manage_care` for others' patients; `kill_switch_ai` | `CONSENT_REQUIRED` / 403 / fallback |
| 2 | Patient resolution | Conversation is bound to one `patientId` | — |
| 3 | Authorized context | Allergies, conditions, active medications only (minimum necessary) | Proceed without context; note it in the interaction |
| 4 | Intake extraction | LLM with a JSON schema (or rule-based extractor offline). Each field has a `source` and `confidence`; unsupported values stay null. | Rule-based extractor |
| 5 | **Deterministic safety engine** | `07_CLINICAL_SAFETY_INTERFACE.md` | Fail closed (urgent) |
| 6 | Reviewed knowledge (RAG) | Keyword retrieval over `approved`, in-date sources; returns source IDs | No retrieval → no clinical-information answer; offer a doctor |
| 7 | LLM reply | Versioned prompt; given intake, missing fields, safety result and retrieved snippets only | Offline fallback template |
| 8 | Policy check | Deterministic post-filter: diagnosis-label patterns, medication-change language, "you are fine" assurances, missing disclaimer, unsupported claims without a source ID | Replace with a safe template; log `policy_violation` |
| 9 | Routing | Engine action for level ≥ urgent; otherwise the intake-completeness + LLM suggestion constrained to the enum; specialty from the allowed list | Default `book_doctor` |
| 10 | Episode link | Create/update the Care Episode; events `ai_intake_*` | — |
| 11 | Audit | `AIInteraction` row (§4) | Write failure = request failure (no unaudited AI output) |

Emergency: level `emergency` replaces the reply with the fixed template. The LLM cannot downgrade the level. AI unavailable: a safe fallback message plus the doctor-consultation routing.

## 3. Model gateway

- Provider-agnostic interface: `generate({ useCase, promptVersion, messages, schema?, maxTokens, timeoutMs })`. Implementations: **Anthropic Claude** (primary) and an **offline rule-based provider** (dev, tests, outage fallback).
- Model and version routing come from configuration per use case (`intake_extraction`, `assistant_reply`, `record_summary`, `clinician_summary`, `wellness_support`). Business code never names a model.
- Timeouts (default 12s reply, 8s extraction), 1 retry on retryable errors, and a circuit breaker (open after 5 failures in 60s, half-open after 30s).
- Telemetry: latency, input/output tokens, cost estimate, fallback flag. Logs never contain prompt or response text.
- The vendor must be contractually barred from training on or retaining our data beyond the minimum necessary, and data residency and cross-border transfer must be assessed **[REQUIRES LEGAL REVIEW]**.

## 4. Logging and audit (AIInteraction)

| Field | Stored | Visible in `/admin/ai-interactions` |
|---|---|---|
| id, useCase, userId, patientId, conversationId, careEpisodeId | ✓ | ✓ |
| model, provider, promptVersion, policyVersion, rulePackVersion (+status) | ✓ | ✓ |
| safetyLevel, triggered rule IDs, routing action | ✓ | safetyLevel |
| retrieved knowledge source IDs + versions | ✓ | via detail (P1) |
| latencyMs, inputTokens, outputTokens, fallbackUsed, policyViolation | ✓ | ✓ |
| input text, output text | ✓ **encrypted, separate table**, access audited, retention per `09_PRIVACY_CONSENT.md` | ✗ (no raw PHI) |
| human review: clinician decision (accept/reject/modify) + note | ✓ via `/clinician/ai-feedback` | P1 |

Application logs (pino) contain only IDs, codes and metrics. They never contain message text, names, phone numbers or clinical values (redaction list enforced in the logger config and tested).

## 5. Human review

| AI output | Review requirement |
|---|---|
| Assistant reply, safety `none`/`routine` | Sampled review by the clinical reviewer (pilot: 100% of the first 200 conversations, then ≥10% weekly) **[REQUIRES CLINICAL GOVERNANCE]** for the rate |
| Safety `urgent`/`emergency` | 100% reviewed. The SafetyEvent must be acknowledged by a clinician/ops within the SLA. |
| Clinician pre-consult summary | Advisory. The doctor sees sources per claim and records accept/reject/modify. The override rate is tracked. |
| Record summary to patient | Disclaimer; the original is always one tap away. Pilot: flagged for sampled clinical review. |
| Wellness support text | 100% template-based or pre-approved text in the pilot. Self-harm signals follow the governance pathway **[REQUIRES CLINICAL GOVERNANCE]**. |
| Wound image | Quality check only; a clinician reviews every case |

## 6. Knowledge (RAG) policy

- Every source has: `owner`, `version`, `status` (draft/approved/deprecated), `effectiveDate` and optional `expiresAt`. Only `approved` and in-date sources are retrievable.
- Sources are **added only by admins after clinical content approval** **[REQUIRES CLINICAL GOVERNANCE]**. Nothing is ingested from the open web automatically.
- Retrieval (MVP): keyword/BM25-style over chunks with language tags. Results carry `sourceId@version`. A vector store is a later option (ADR-004).
- Clinical-information answers without at least one retrieved approved source are not produced. The assistant offers a doctor instead.
- Deprecated or expired sources disappear from retrieval immediately. Past interactions keep their citations.

## 7. Versioning and change control

Prompts (`promptVersion`), the policy-check ruleset (`policyVersion`), model config and rule packs are versioned artifacts in the repo/config. Any change requires: (1) the evaluation suite re-run (`docs/AI_EVALUATION.md`) with no regression on safety cases, (2) a changelog entry, (3) clinical sign-off for changes affecting patient-facing clinical wording **[REQUIRES CLINICAL GOVERNANCE]**, (4) staged rollout via feature flag/cohort.

## 8. AI use-case risk register (initial)

| Use case | Risk class | Human review | Launch |
|---|---|---|---|
| Intake extraction | Medium | Sampled | Pilot |
| Assistant reply / navigation | High | Sampled + all escalations | Pilot (after evaluation gate) |
| Clinician summary | Medium | Doctor reviews each use | Pilot |
| Record summary (patient-facing) | Medium | Sampled | Pilot, flag-controlled |
| Wellness support | High | Template-only | Flag off in pilot unless approved |
| Wound image quality | Low (non-diagnostic) | Every case clinician-reviewed | Flag-controlled |
| Wound analysis | High (regulated claim) | — | **Disabled** |
| Voice STT hi/te | Medium (misrecognition) | Evaluation required | Flag-controlled |

Risk classification and launch decisions are **[REQUIRES CLINICAL GOVERNANCE]** **[REQUIRES LEGAL REVIEW]** (CDSCO Medical Device Software intended-use assessment).

## 9. Evaluation matrix (Build Map §19)

Fourteen mandatory scenario classes are defined in `docs/AI_EVALUATION.md`: common low-risk concern; high-risk/emergency concern; elderly patient with multiple conditions; medication/allergy context; missing data; contradictory data; ambiguous language; mixed-language input; prompt injection; attempt to force a diagnosis; unsupported report type; model unavailable; RAG unavailable; safety rules unavailable. For each case record: input, expected safe behavior, expected escalation, model/prompt/policy version, actual output, pass/fail and clinician reviewer. Pass thresholds (for example 0 false negatives on emergency cases) are set by governance **before** the pilot **[REQUIRES CLINICAL GOVERNANCE]**.

## 10. Kill switches

| Flag | Effect |
|---|---|
| `kill_switch_ai` | All AI generation returns the fallback immediately. The safety engine and emergency template still work. |
| `ai_assistant` | Hides/disables the Ask-AI entry points |
| `voice_input` | Disables the microphone input |
| `wound_ai_analysis` | Must remain off |
| `mental_wellness` | Disables mood/wellness |

Who may flip them: super_admin (any time) and the on-call engineer through the runbook. Every flip is audited. See `docs/runbooks/OPERATIONS_RUNBOOK.md` §6.
