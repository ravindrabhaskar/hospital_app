# ADR-002: Monorepo with per-package toolchains

- **Status:** Accepted
- **Date:** 2026-09-26
- **Related:** Build Map §15, ADR-001, ADR-005

## Context

Four deliverables share one API contract and must evolve together: the API, the web portal (clinician + ops + admin), the patient app and the provider app. The Build Map suggests `/apps`, `/services`, `/packages`, `/docs`, `/infra`, `/tests`. The clients use two ecosystems (npm for TypeScript, pub for Flutter/Dart), so a single JavaScript workspace cannot manage everything.

## Decision

One Git repository `care-companion/`:

```
services/api            TypeScript modular monolith (npm, own package-lock)
apps/web                Next.js 15 portal (npm, own package-lock)
apps/patient_app        Flutter
apps/provider_app       Flutter
docs/product            source-of-truth product docs (01–14)
docs/api/API_CONTRACT.md  single API contract, changed first
docs/adr, docs/runbooks, docs/design, docs/source_extracts
.github/workflows/ci.yml  one workflow, one job per package (matrix for Flutter)
infra/ (planned)        IaC for AWS (Phase 24–27)
```

- **Per-package lockfiles and scripts** (`typecheck`, `lint`, `test`, `build`) rather than a root npm workspace. This keeps the CI cache keys simple (`cache-dependency-path` per package) and lets the Flutter apps sit alongside.
- **Contract sharing:** `docs/api/API_CONTRACT.md` is the human-readable contract. The TypeScript API holds zod schemas. Web and Flutter clients hand-write typed models from the contract. An OpenAPI document generated from the Fastify schemas, with generated clients, is a later improvement (`packages/api-contracts`).
- **Naming:** Flutter packages use snake_case directory names (`patient_app`, `provider_app`). The Build Map's suggested names (`patient-mobile`, `clinician-web`, `ops-web`) are superseded: clinician, ops and admin share one Next.js app with role-based routing.
- **Commit discipline:** one phase per milestone; tag after each phase (Build Map §17). Conventional commits are recommended.

## Consequences

- Atomic changes across contract, API and clients in one PR, with CI running all affected jobs.
- There is no cross-language code generation yet, so clients can drift from the contract. Mitigation: API contract tests validate responses against schemas, and client model tests use recorded JSON fixtures.
- CI runs every job on every PR. Path filters can be added when CI time matters.

## Alternatives considered

Polyrepo (contract drift, harder atomic changes); Nx/Turborepo root workspace (useful later for TS packages, but adds tooling before it pays off; Flutter still sits outside it).
