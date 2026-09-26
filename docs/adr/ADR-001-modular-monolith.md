# ADR-001: TypeScript modular monolith for the core API

- **Status:** Accepted
- **Date:** 2026-09-26
- **Deciders:** Tech lead, founder
- **Related:** Build Map §15 ("Do not prematurely split everything into microservices"), `04_DOMAIN_MODEL.md`

## Context

The platform spans identity, consent, patients/family, care episodes, providers, appointments, home visits, records, care plans, AI, safety, notifications, payments and operations. The team is small, the pilot volume is modest (100–200 users, 10–20 professionals), and most workflows are **transactional across modules**. For example, booking = slot reservation + payment + episode event + audit + notification. The source documents (Spec §10, Blueprint §36) list many "services" as logical components, but the Build Map explicitly prefers a modular monolith unless a split is justified.

## Decision

Build `services/api` as a **single deployable TypeScript modular monolith**:

- **Runtime/framework:** Node 24, Fastify 5 (plugins per module, schema-first routes).
- **Validation:** zod schemas mirror `API_CONTRACT.md`. They validate requests and (in tests) responses.
- **Persistence:** Drizzle ORM with SQL migrations (ADR-003).
- **Logging:** pino, JSON, redaction list for PHI, correlation ID per request.
- **Testing:** vitest (unit, integration via Fastify `inject`, PGlite).
- **Modules** (`src/modules/<name>`): identity, consent, patients, episodes, providers, appointments, home-visits, records, care-plans, ai, safety, notifications, payments, ops, admin, extras. Each module owns its tables and exposes a service interface. Cross-module calls go through those interfaces, never through another module's tables.
- **Cross-cutting platform:** auth/RBAC policy helper, idempotency store, audit writer, error mapper, feature flags, storage abstraction, transactional outbox.
- **Background work:** an **in-process worker** drains the outbox table and runs schedulers (overdue tasks, missed doses, SLA breach, fall timeout, notification retries). The job interface (`enqueue(name, payload, {idempotencyKey, runAt})`) is designed so the implementation can move to **BullMQ on Redis** in a separate worker process without changing module code.

## Consequences

**Positive**
- One transaction can span modules, which gives strong consistency for booking, payment and events.
- Simple local setup and CI; one deployable; one place for the authorization policy.
- Module boundaries keep a later extraction possible (for example the AI gateway or notifications).

**Negative / risks**
- Module-boundary erosion. Mitigation: lint rule or dependency-cruiser config forbidding cross-module imports except `index.ts` service interfaces (to add); code review.
- A shared failure domain (an AI or PDF processing spike can affect the API). Mitigation: timeouts, circuit breaker, concurrency limits; move the worker out first.
- The in-process worker duplicates jobs if several API instances run it. Mitigation: `SELECT … FOR UPDATE SKIP LOCKED` on the outbox and `WORKER_MODE` (`all` | `api-only` | `worker-only`), with exactly one worker deployment in prod until BullMQ.

## Alternatives considered

| Option | Why not now |
|---|---|
| Microservices per domain (Spec/Blueprint service lists) | Distributed transactions, ops overhead, slower iteration for a pilot |
| NestJS | Heavier abstraction; Fastify + explicit modules suffices |
| Django REST (Spec suggestion) | Team and code sharing favour TypeScript across API and web; the Flutter clients are language-neutral |
| Separate Python AI service | Not needed while the AI calls are API-based. Revisit if we host our own models or computer vision. |

## Revisit when

Sustained load needs independent scaling of AI or notification processing; a team split by domain; regulatory need to isolate a component (for example a certified medical-device software module).
