# ADR-004: Provider-agnostic AI gateway, deterministic safety engine and keyword RAG

- **Status:** Accepted
- **Date:** 2026-09-26
- **Related:** Build Map §12 and Phases 9–13; `07_CLINICAL_SAFETY_INTERFACE.md`; `08_AI_POLICY.md`

## Context

The Build Map forbids the pattern *User → LLM → Medical answer*. It requires a layered pipeline in which a **deterministic, clinician-approved safety engine** runs independently of the generative model and cannot be overridden by it. Model vendors and versions will change, AI outages must degrade safely, and every interaction must be auditable (model, prompt/policy/rule-pack versions, sources, safety outcome). Clinical rules must not be invented by engineering or AI.

## Decision

1. **AI gateway** (`services/api/src/modules/ai/gateway`): a single interface `generate(request)` with use-case-based configuration (model, max tokens, timeout, prompt version).
   - Providers: **Anthropic Claude** (primary, via the official SDK) and an **offline rule-based provider**. The offline provider covers dev, CI and the outage fallback. It produces a deterministic intake extraction and templated replies.
   - Resilience: per-call timeout, one retry on retryable errors, circuit breaker, `kill_switch_ai` flag.
   - Telemetry: latency, tokens, cost estimate, fallback flag. There is no prompt/response text in logs.
   - Structured outputs: intake extraction uses a JSON schema and is validated with zod. Invalid output falls back to the rule-based extractor.
2. **Safety engine** (`src/modules/safety`): a pure, synchronous evaluator over **versioned rule packs stored as data** (`SafetyRulePack` table + JSON rules per the contract schema). The status lifecycle is `draft → approved → retired`, plus `fixture_unapproved` for tests. There is one active pack. Level aggregation takes the maximum. The orchestrator computes `finalLevel = max(engine, policyCheck)`, and the LLM has no write path to the level. Emergency swaps in a fixed localized template. The engine fails closed. Production refuses fixture packs.
3. **Orchestrator** (`src/modules/ai/assistant`): the fixed pipeline order from the contract (resolution → context → intake → **safety** → RAG → LLM → policy check → routing → episode link → audit). Audit write failure fails the request.
4. **Reviewed knowledge (RAG):** a `KnowledgeSource` registry (owner, version, status, effective/expiry) with chunking and **keyword (BM25-style) retrieval** in Postgres. Only approved, in-date sources are retrieved, and results carry `sourceId@version`. No web ingestion.
5. **Policy check:** a deterministic post-generation filter (diagnosis-label, medication-change and false-reassurance patterns; disclaimer presence). It is versioned as `policyVersion`.

## Consequences

**Positive:** we can switch vendors without touching domain code. The emergency behavior does not depend on LLM availability. Tests are deterministic offline. There is complete traceability.

**Negative / risks**
- Keyword rules are brittle across languages and colloquial phrasing (hi/te, transliteration, code-mixing). Mitigation: governance-supplied multilingual lexicons in packs, the mixed-language evaluation cases, conservative defaults, and human escalation. We will not claim more than the evaluation shows.
- Keyword RAG has lower recall than embeddings. Mitigation: a small curated corpus. Upgrade path: `pgvector` hybrid retrieval once the corpus grows (confirm the extension on RDS and PGlite).
- Offline fallback replies are generic, which is acceptable because they route to a doctor.
- Sending text to an external LLM has privacy implications (Q-09 in `14_DECISIONS.md`) **[REQUIRES LEGAL REVIEW]**.

## Alternatives considered

LLM-only triage (forbidden); an LLM-as-judge for safety (non-deterministic, forbidden as the sole safety mechanism); a vector DB now (premature); self-hosted models (operational cost; revisit for data residency).
