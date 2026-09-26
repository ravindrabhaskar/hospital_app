# CareCompanion

An AI-powered **care-orchestration** platform for families in India. It turns a health concern into a safe, tracked care journey: concern → structured AI intake → deterministic safety routing → doctor or home checkup → care plan → tasks and reminders → follow-up.
It is **not an AI doctor**. AI output is assistive, and emergencies are decided by versioned, clinician-approved rules, never by the language model.

| Part | Path | Stack | Who uses it |
|---|---|---|---|
| Backend API | `services/api` | TypeScript, Fastify 5, Drizzle ORM, PostgreSQL (embedded PGlite in dev), vitest | everything |
| Web portal | `apps/web` | Next.js 15, Tailwind 4, TanStack Query | doctors, care coordinators, operations, super admin |
| Patient app | `apps/patient_app` | Flutter (Android/iOS/Web), Riverpod, go_router, en/hi/te | patients and family caregivers |
| Provider app | `apps/provider_app` | Flutter, offline sync queue | home-care nurses, technicians, interns |
| Docs | `docs/` | – | product, API contract, ADRs, runbooks, launch checklist |

## Run it locally (Windows / macOS / Linux)

You need **Node 22+** and **Flutter 3.x**. No Docker or database install is needed, because dev uses embedded Postgres (PGlite).

```bash
# 1. Install and seed the demo data (all OTPs are 123456)
npm run setup

# 2. Start the API → http://localhost:4000/api/v1
npm run dev:api

# 3. Start the web portal (new terminal) → http://localhost:3000
npm run dev:web

# 4. Start the patient app (new terminal)
cd apps/patient_app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
#   on an Android emulator: flutter run   (defaults to http://10.0.2.2:4000/api/v1)

# 5. Start the provider app (new terminal)
cd apps/provider_app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

### Demo logins (OTP `123456`)
| Phone | Role | Use in |
|---|---|---|
| 9800000001 | Patient **Vaibhav**, who manages his father **Ramesh** (68, BP + diabetes) | patient app |
| 9800000002 | Lakshmi, family caregiver with view-only access to Ramesh | patient app |
| 9800000101 | Dr. Ananya Rao (General Physician) | web portal → Clinician |
| 9800000201 | Sunita Devi (nurse) | provider app |
| 9800000203 | Anil (intern, **expired credential**, shows the blocked flow) | provider app |
| 9800000301 | Care coordinator | web portal → Operations |
| 9800000401 | Operations admin | web portal → Operations |
| 9800000501 | Super admin | web portal → Admin |

Home visits are serviceable in Hyderabad pincodes 500001–500040 (500034 works well). 560001 demonstrates "not serviceable".

### Turn on real AI
The assistant works offline with a deterministic rule-based model. To use Claude, create `services/api/.env` (copy `.env.example`) and set `ANTHROPIC_API_KEY=...`. The model is configurable with `AI_MODEL`. The safety engine always runs first, and the model cannot downgrade an emergency.

## Quality checks

```bash
npm run check        # API: typecheck + lint + 226 unit/integration tests; Web: typecheck + lint + 174 tests
npm run test:e2e     # full cross-role care journey against a running, freshly seeded API (83 checks)
npm --prefix services/api run verify:pg   # proves the real PostgreSQL (node-postgres) driver path (20 checks)
cd apps/patient_app  && flutter analyze && flutter test   # 66 tests
cd apps/provider_app && flutter analyze && flutter test   # 103 tests
node tests/load/smoke.mjs                                 # load smoke test
```
CI runs all of these (`.github/workflows/ci.yml`).

Run `npm run seed` before `test:e2e` to reset the demo data.

## Deploying to production
- **Everything you must obtain** (accounts, keys, approvals) → `docs/GO_LIVE_CREDENTIALS.md`
- AWS infrastructure (Mumbai) → `infra/terraform/`; first-deploy steps → `docs/runbooks/DEPLOYMENT_RUNBOOK.md`
- Local production-like stack (Postgres, MinIO, ClamAV, Redis) → `docker compose up` (see `docker-compose.yml`)
- CI/CD → `.github/workflows/` (`ci.yml`, `deploy.yml`, `mobile-release.yml`)
- Play Store / App Store submission → `docs/STORE_SUBMISSION.md`
- First admin account → `npm --prefix services/api run create-admin -- --phone +91XXXXXXXXXX --name "Name"`

## Where to read next
- `docs/api/API_CONTRACT.md`: every endpoint, field, state machine and seed record (the source of truth for all four apps)
- `docs/BUILD_PLAN.md`: the 28 build phases from the product Build Map and their status
- `docs/product/14_DECISIONS.md`: **open decisions the founders must make**
- `docs/LAUNCH_CHECKLIST.md`, `docs/KNOWN_LIMITATIONS.md`, `docs/SECURITY.md`, `docs/DATA_PRIVACY.md`
- `docs/product/07_CLINICAL_SAFETY_INTERFACE.md`: how clinicians supply and approve the real safety rules
- Each app's own README for architecture details

## Before any real patient uses this
The shipped safety rule pack `fixture-0.1` is a **non-clinical test fixture**. Production refuses to use it. Launch requires the human workstreams in `docs/LAUNCH_CHECKLIST.md`:
- clinical governance-approved rules and content;
- legal/regulatory review (telemedicine guidelines, DPDP Act);
- real SMS, payment, video, storage and push vendors;
- a penetration test;
- a controlled pilot.
