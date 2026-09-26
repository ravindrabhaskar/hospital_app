# Known Limitations (v0.1.0)

Accepted limitations and deferred work for the initial MVP scaffold. Each item says whether it **blocks the pilot**. Update this file whenever a limitation is closed or discovered (Build Map Appendix B).

## 1. Clinical and safety

| # | Limitation | Impact | Blocks pilot | Resolution path |
|---|---|---|---|---|
| L-01 | **Only a non-clinical fixture rule pack exists** (`fixture-0.1`, `fixture_unapproved`). No rule in the repo is medically approved. | The AI assistant must not run in production | **Yes** | Governance authors and approves a pack (`07` §5) **[REQUIRES CLINICAL GOVERNANCE]** |
| L-02 | The rule schema is keyword/threshold based (any/all keywords, min severity, single vital comparison, age). No negation, duration logic or vital combinations. | Limited expressiveness and recall; multilingual phrasing depends on the lexicons in the pack | Depends on governance review | Extend the schema only on governance request |
| L-03 | No approved knowledge sources are loaded for RAG | Clinical-information answers are unavailable (the assistant routes to a doctor) | No (degrades safely) | Governance approves content |
| L-04 | Vitals are not clinically interpreted anywhere | Home-visit escalation is a manual provider decision | No (by design) | Only via approved rules |
| L-05 | Emergency pathway directs to 108 and notifies contacts; **no ambulance dispatch integration**, and no call bridging | The user must call themselves | No (by design; must be stated clearly) | Partner integration (P2) **[REQUIRES LEGAL REVIEW]** of claims |
| L-06 | Escalation acknowledgement SLA and duty roster are placeholders | Ops cannot promise response times | **Yes** | Q-02 |
| L-07 | Care-plan medication list is not a legal e-prescription | Doctors may need a separate prescription | Depends (Q-13) | Legal review |

## 2. AI

| # | Limitation | Blocks pilot |
|---|---|---|
| L-10 | The offline fallback provider gives generic, template replies and rule-based intake extraction (lower completeness) | No |
| L-11 | hi/te understanding, transliteration and code-mixing have not been evaluated; voice uses device STT only | Flag `voice_input` for hi/te until evaluated |
| L-12 | The policy-check filter is pattern-based and can miss paraphrased diagnosis or medication advice | No, but monitored via sampled review |
| L-13 | The evaluation suite has scenario templates but no clinician-reviewed expected outputs or results | **Yes** (AI gate) |
| L-14 | Sending conversation text to the external LLM (Anthropic) has not been assessed legally for cross-border transfer | **Yes** (Q-09) **[REQUIRES LEGAL REVIEW]** |
| L-15 | Clinician summary claim-to-source linking is heuristic (it may cite a record that only partially supports a claim) | No (advisory; the doctor reviews the sources) |

## 3. Security and privacy

| # | Limitation | Blocks pilot |
|---|---|---|
| L-20 | Staff MFA is a stub hook (`mfaRequired` flag only) | **Yes** |
| L-21 | File malware scanning is a hook only; local storage driver in dev | **Yes** (prod needs S3 + a scanner) |
| L-22 | No independent pen test; no SAST/DAST/secret scanning in CI yet | **Yes** |
| L-23 | Audit-log tamper evidence (DB grants, hash chain) depends on prod DB configuration | **Yes** |
| L-24 | The target consent gates for `share_with_clinicians` and `family_sharing` are not enforced by the v1 contract | Legal to decide |
| L-25 | Data subject requests (export, erasure, access history) are support-assisted, with no self-serve UI | No (manual process acceptable for pilot, per counsel) |
| L-26 | Adult-dependent consent flow (the dependent's own confirmation) not implemented | Likely yes (Q-06) |
| L-27 | Retention and deletion jobs not implemented; the retention table is a proposal | **Yes** (before real data accumulates) |
| L-28 | Production boot check refusing fixture packs and the release-pipeline fixture check must be verified in code and CI | **Yes** |
| L-29 | Break-glass access for ops to clinical documents is not implemented (ops sees metadata only) | No |

## 4. Integrations (Adapter/stub)

| # | Integration | Current state |
|---|---|---|
| L-30 | ABDM (ABHA, HIP/HIU, HPR/HFR, UHI) | Boundary only; **no connectivity claimed** |
| L-31 | Video teleconsultation | `videoRoomUrl` field; no provider |
| L-32 | SMS / WhatsApp / email | Interfaces; in-app notifications only (+ push abstraction). The OTP SMS provider is needed for prod. |
| L-33 | Maps / geocoding / routing / live tracking | Pincode serviceability + lat/lng; ETA entered by the provider |
| L-34 | Payment gateway | Mock gateway + Razorpay-shaped adapter; live keys, settlement and reconciliation reports not wired |
| L-35 | Pharmacy / lab partners | Seeded catalogue; no partner API |
| L-36 | Wearables | Manual sync endpoint; no OAuth to Apple Health / Health Connect / Fitbit |
| L-37 | Push notifications (FCM/APNs) | Device-token registration; delivery provider to configure |

## 5. Platform and operations

| # | Limitation | Blocks pilot |
|---|---|---|
| L-40 | In-process worker; single-worker assumption; no Redis/BullMQ yet | No, if exactly one worker is deployed |
| L-41 | PGlite in dev/test cannot reproduce true parallel contention; the concurrency suite must run on real Postgres | No (staging job needed) |
| L-42 | No infrastructure-as-code; AWS architecture is a proposal | **Yes** |
| L-43 | No production observability (dashboards, alert routing, on-call) | **Yes** |
| L-44 | No load/performance test results | **Yes** (Phase 26) |
| L-45 | Provider settlement is ledger hooks only; payouts are handled manually | No |
| L-46 | Provider onboarding pipeline (Applied → Documents pending → Under review) is an ops process; the API has pending/verified/rejected/suspended/expired | No |
| L-47 | Reschedule/cancellation policy windows and fees are not configured (policy hooks only) | **Yes** (Q-04) |
| L-48 | Single city and zone config; no multi-tenant or B2B organization model | No |

## 6. Product and UX

| # | Limitation |
|---|---|
| L-50 | The reference UI shows wound, wearables, fall, wellness and pharmacy: all flag-gated and assistive-only; government schemes hidden |
| L-51 | Home quick-action set pending a founder decision (Q-20) |
| L-52 | Medical-term glossary (en/hi/te) is not clinician-reviewed; high-risk terms fall back to English |
| L-53 | No refill reminders, no family-plan subscription, no in-app chat with the care team |
| L-54 | Accessibility has not been validated with elderly users (only automated checks) |
