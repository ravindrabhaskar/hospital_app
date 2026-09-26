# ADR-003: PostgreSQL in production, PGlite in development and tests

- **Status:** Accepted
- **Date:** 2026-09-26
- **Related:** Build Map Phase 1 gate ("A clean clone can install, lint, type-check and test with one documented command"), ADR-001

## Context

The domain is relational and transactional: slot uniqueness, append-only events, audit, idempotency records, payments and state transitions with compare-and-set. All source documents specify PostgreSQL. We also need a zero-dependency developer and CI setup (no Docker requirement on Windows laptops, and fast tests).

## Decision

- **Production/staging:** managed PostgreSQL 16 (AWS RDS, Multi-AZ, KMS encryption; see `13_DEPLOYMENT.md`).
- **Dev and tests:** **PGlite**, the WASM build of real PostgreSQL embedded in Node. It runs as a file-backed database for `npm run dev` and in-memory per test file for vitest.
- **ORM/migrations:** Drizzle ORM with SQL migrations committed to the repo. The same migrations run on PGlite and RDS. Migrations are forward-only with written rollback notes, following the expand/contract pattern.
- **Driver abstraction:** a single `db` factory chooses `pglite` or `node-postgres` from config (`DATABASE_URL` present → Postgres). Application code is identical.
- **Postgres features used deliberately:** unique constraints and partial unique indexes (active grant, slot reservation), `jsonb` (event data, intake), `FOR UPDATE SKIP LOCKED` (outbox worker), transactions, check constraints on enums.
- **Append-only enforcement:** repository layer (no update/delete methods) everywhere. In prod, additionally a DB role without UPDATE/DELETE on `audit_logs` and `care_episode_events`, or triggers raising on UPDATE/DELETE, plus a hash chain on audit rows.

## Consequences

**Positive:** `npm ci && npm test` works on a clean clone with no services. Tests exercise real Postgres semantics (not SQLite). There is a single dialect.

**Negative / risks**
- PGlite is single-connection, so concurrency tests (double booking) do not reproduce true parallel contention. Mitigation: correctness relies on DB constraints, which PGlite enforces. A staging/nightly job runs the concurrency suite against real Postgres (`DATABASE_URL`).
- Extension availability differs (for example `pgvector` for future RAG). Mitigation: keyword RAG for now (ADR-004). Test any extension on both before adopting it.
- PGlite performance is not representative. Performance testing happens only on staging RDS.

## Alternatives considered

Docker Postgres for dev (heavier onboarding; still allowed optionally via `DATABASE_URL`); SQLite (dialect mismatch); testcontainers (needs Docker in CI and locally).
