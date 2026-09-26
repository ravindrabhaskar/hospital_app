# ADR-005: Flutter for mobile apps, Next.js for the web portal

- **Status:** Accepted
- **Date:** 2026-09-26
- **Related:** Blueprint §36, Spec §11, `11_DESIGN_SYSTEM.md`, Build Map Phases 18–21

## Context

Patients and families (often elderly users or remote caregivers) need an Android-first, iOS-capable app in en/hi/te with accessibility (text scaling to 200%, screen readers, voice input). Home-care providers work in the field with unreliable connectivity and need offline capture. Clinicians, coordinators and admins work on desktop browsers with dense data views and keyboard use. All source documents specify Flutter for mobile and React/Next.js for web.

## Decision

- **`apps/patient_app` (Flutter, Dart):** 5-tab navigation (Home, Care, Ask AI, Records, Profile), design tokens from `11_DESIGN_SYSTEM.md` (Inter, primary `#0B5D45`), ARB localization (en/hi/te), and explicit loading/empty/error/offline/unauthorized states. Tokens are kept in secure storage. No PHI in analytics or crash logs. Generic push text.
- **`apps/provider_app` (Flutter):** duty toggle, assigned visits, visit lifecycle actions, identity/consent verification via the visit code, vitals and observations forms, escalation, completion.
  - **Offline queue:** actions captured offline are stored **encrypted** on device (key in Android Keystore / iOS Keychain). Each queued action carries a client-generated **`Idempotency-Key`** that is reused on every retry, so sync is idempotent and `POST /home-visits/:id/vitals` cannot duplicate. The queue replays in order per visit and stops on 403/409 (revoked access or state conflict), surfacing the conflict to the user. Queued data is purged after sync and on logout. The visit code is never displayed from server data because the patient reads it out.
- **`apps/web` (Next.js 15, App Router, TypeScript):** one application with role-based areas: `/clinician` (queue, snapshot, episode, plan, escalations, AI feedback), `/ops` (control tower), `/admin` (users, staff, rule packs, knowledge, flags, zones, audit, AI interactions, analytics). Server-side session handling with the API tokens in httpOnly cookies. AI content is rendered in a visually distinct panel with source chips and the label "AI-generated · not a diagnosis". The fixture-rule banner is shown when `/ready` reports `safetyRules: "fixture"`.
- Clients call only endpoints in `API_CONTRACT.md`. CI builds Flutter web targets as a compile check. Store builds are produced in the release pipeline (`13_DEPLOYMENT.md` §6).

## Consequences

**Positive:** one codebase for Android and iOS per app; a strong ecosystem for accessibility and localization; Next.js suits data-dense internal tools and SSR behind CloudFront.

**Negative / risks**
- Two languages (Dart, TypeScript) and no shared generated client yet. Mitigation: contract fixtures and a future OpenAPI codegen.
- The offline queue adds conflict complexity. Mitigation: it is limited to visit actions; server state guards are authoritative; duplicate-sync and revoked-access tests are required (Build Map Phase 19).
- Background location and notifications have platform constraints. Location is sent only while en route and on duty.

## Alternatives considered

React Native (the team and the documents chose Flutter); native Kotlin/Swift (double effort); separate clinician and ops web apps (duplicated auth/UI; role routing is sufficient).
