# Changelog

All notable changes to CareCompanion are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-09-26

Initial MVP scaffold for the Hyderabad controlled-pilot track. **Not clinically approved and not production-ready.** See `docs/KNOWN_LIMITATIONS.md` and `docs/LAUNCH_CHECKLIST.md`.

### Added
- **Monorepo** layout: `services/api`, `apps/web`, `apps/patient_app`, `apps/provider_app`, `docs/`; one CI workflow (`.github/workflows/ci.yml`) running typecheck, lint, test and build for the API and web, and analyze, test and web build for both Flutter apps.
- **API contract v1** (`docs/api/API_CONTRACT.md`): auth, consent, patients and family access, care episodes, doctors and appointments, home visits, records and timeline, AI assistant, care plans and medications, notifications, payments, pharmacy (partner adapter), flagged extras (wellness, wound, wearables, fall, SOS), clinician, provider, operations and admin endpoints; seed personas.
- **Core API** (TypeScript modular monolith: Fastify 5, Drizzle ORM, PostgreSQL / PGlite, zod, pino, vitest): OTP auth with dev OTP `123456`; RBAC with family access grants; consent ledger; Care Episode state machine with append-only events and audit; provider registry with credential expiry; concurrency-safe slot booking; home-visit lifecycle with auto-matching, visit code and escalation; records with immutable originals and provenance; care plans, tasks, medications and reminders; notifications with generic lock-screen text; mock payment gateway and a Razorpay-shaped adapter with HMAC webhooks and idempotency; ops control-tower and admin endpoints; feature flags including `kill_switch_ai`.
- **AI subsystem:** provider-agnostic gateway (Anthropic Claude plus an offline rule-based fallback), structured intake with per-field provenance, a deterministic versioned safety engine with the **non-clinical fixture pack `fixture-0.1` (`fixture_unapproved`)**, keyword RAG over approved sources, a policy check, and AIInteraction audit.
- **Clients:** Next.js 15 portal (clinician, operations, admin); Flutter patient app (5-tab navigation, en/hi/te); Flutter provider app with an encrypted offline queue.
- **Documentation:** product source-of-truth set `docs/product/01–14` (`11_DESIGN_SYSTEM.md` pre-existing), ADR-001 to ADR-005, operations, deployment and incident runbooks, `BUILD_PLAN.md`, `LAUNCH_CHECKLIST.md`, `KNOWN_LIMITATIONS.md`, `SECURITY.md`, `DATA_PRIVACY.md`, `AI_EVALUATION.md`.

### Security
- PHI-safe structured logging defaults; `devOtp` and `confirm-mock` are dev-only; staff MFA is a stub hook (launch blocker SEC-001).

### Known gaps
- No approved clinical rule pack, knowledge content or evaluation results. ABDM, video, SMS/WhatsApp, maps and live payment integrations are adapters or stubs. No production infrastructure, pen test or restore drill yet.

## [0.2.0] - 2026-09-26: production readiness
### Added
- Backend integrations, all switched on by configuration:
  - Razorpay orders, checkout verification, retry, refunds and signed webhooks;
  - MSG91 and Twilio SMS OTP;
  - FCM HTTP v1 push;
  - S3 storage with SSE-KMS and ClamAV malware scanning;
  - Jitsi video sessions;
  - PDF and image record summaries.
- Security and privacy:
  - staff TOTP MFA with recovery codes;
  - account deletion with a grace period, and data export (store and DPDP requirement);
  - app-store reviewer login and a `create-admin` CLI.
- Operations:
  - public config endpoint with forced app updates;
  - worker leader election for several instances and a Redis rate-limit store;
  - Prometheus `/metrics`, helmet, and production startup refusals for unsafe settings;
  - `verify:pg` real-Postgres check.
- Web portal:
  - MFA enrolment and verification;
  - public Privacy, Terms, Account-deletion and Support pages;
  - doctor video join, CSP and security headers, idle session timeout, standalone build.
- Patient app: Razorpay checkout, push, delete-account and data export, video join, "load more" lists, branding and release signing.
- Provider app: push, consented visit photos with offline queue, branding and release signing.
- Infrastructure:
  - Dockerfiles and a docker-compose production-like stack;
  - Terraform for AWS ap-south-1 (VPC, RDS, S3, ECS Fargate, ALB, WAF, Redis, alarms, GitHub OIDC);
  - CI, deploy and mobile-release workflows;
  - k6 and Node load tests;
  - store submission guide and go-live credentials checklist.

## [0.3.0] - 2026-09-26: functional completeness (API contract v1.2, §29–§40)
### Added
- **Doctors:** self-managed profile, fees, photo, weekly schedule templates and leaves with automatic slot generation; admin schedule management.
- **Onboarding:** nurses, technicians and doctors apply from the provider app with credential documents; ops review and approve them in the portal.
- **e-Prescriptions:** PDF, automatic medicine reminders, "order these medicines" from the prescription.
- **Referrals:** hospital referrals with a referral-letter PDF.
- **Money:** GST invoices (sequential per financial year) with PDFs; doctor and provider earnings; ops settlements with CSV export.
- **Reviews:** ratings and reviews with moderation.
- **Messaging:** secure care-team messaging per care episode, with safety-engine screening and an emergency 108 notice.
- **Coordinators:** workspace with a risk-ordered caseload, contact logs and coordinator assignment.
- **Subscriptions:** Family Care Plan with home-visit discount and dedicated coordinator.
- **Information and IDs:** government health scheme information (never an eligibility decision); ABHA number linking (ABDM verification adapter pending certification).
- **Patient app:** Health Connect and Apple Health sync; foreground fall detection; spoken AI replies; in-app PDF viewer; doctor photos; dark mode.
- **Provider app:** apply-to-join onboarding, earnings, profile photo, voice-to-note with mandatory review.
### Fixed
- Wearable resyncs replaced duplicate daily totals per provider instead of adding them up.
- The coordinator caseload page requested more rows than the API allows.
- Ops admins could not load service zones when approving applications.
- The Prescriptions tab listed e-prescription PDFs twice and mislabelled doctor documents as "Uploaded by you".
- The Leaves form overflowed its panel.
