# CareCompanion Web Portal (`apps/web`)

Role-aware web portal for **clinicians**, **operations** (control tower) and **admins** of the CareCompanion care-orchestration platform.
Built against [`docs/api/API_CONTRACT.md`](../../docs/api/API_CONTRACT.md) only; it uses no endpoints or fields outside the contract.

Stack: Next.js 15 (App Router, fully client-rendered pages), TypeScript strict, Tailwind CSS v4, TanStack Query, react-hook-form + zod, lucide-react, recharts, vitest + Testing Library.

## Run

```bash
cd apps/web
cp .env.example .env.local        # set NEXT_PUBLIC_API_BASE_URL if the API is not on :4000
npm install
npm run dev                       # http://localhost:3100
```

The API (`services/api`) must be running (default `http://localhost:4000/api/v1`) and seeded (`npm run seed` there).

| Script | What it does |
|---|---|
| `npm run dev` | Dev server on port 3100 |
| `npm run build` / `npm start` | Production build / serve with `next start` |
| `npm run start:standalone` | Serve the standalone build (`.next/standalone/server.js`) after copying `.next/static` (and `public/` if present) next to it. `PORT` (default 3100) and `BIND_HOST` (default `0.0.0.0`) are honoured |
| `npm run lint` | ESLint (next/core-web-vitals + typescript) |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Vitest unit tests (API client 401/refresh + error parsing, role-based nav and guard incl. the v1.2 routes, domain helpers, MFA state machine + flow, MFA_REQUIRED redirect, idle timeout, account deletion states, video join window, security headers and env validation; v1.2: schedule overlap validation + editor, prescription form validation + payload shape, application decision rules, caseload flags/sorting, inbox thread polling hook) |

## Demo logins (seed data, contract §20)

All OTPs are **`123456`**. In non-production the login screen also shows `Dev OTP: …` from the API.

| Role | Phone | Lands on |
|---|---|---|
| doctor (Dr. Ananya Rao) | `+919800000101` | `/clinician` |
| coordinator (Meera) | `+919800000301` | `/ops` |
| ops_admin | `+919800000401` | `/ops` (+ read-only Audit logs and Analytics) |
| super_admin | `+919800000501` | `/ops` + all of `/admin` |

Patient-only (and provider-only) accounts are told to use the mobile app and are not kept signed in (they can still use `/account/delete`).

**Staff MFA (§22).** When the API reports `mfaRequired && mfaVerified === false`, login continues at `/mfa`: first-time staff enrol an authenticator app (QR rendered as an `<img>` data URI + manual key), confirm a code, and must save the 10 recovery codes (copy / download, "I saved them" checkbox) before continuing; enrolled staff enter a TOTP code or a recovery code. If the API does not enforce MFA (`MFA_ENFORCED=false`, detected with a probe that does not return `403 MFA_REQUIRED`), a "Skip for now" link is shown. An API without v1.1 (no `mfaVerified` field) skips the step.

## Pages

- **Public (no login, statically rendered, linked in the footer)**: `/` product page with a Staff login link (signed-in staff are redirected to their home); `/privacy` privacy policy draft (DPDP Act 2023); `/terms` terms of use draft; `/account/delete` the **Play Store account-deletion page** (phone + OTP for patient accounts through a private, memory-only API client; shows the current request, schedules or cancels deletion per §23, then signs out; staff are told to contact their admin); `/support` contacts from `GET /config/public` + FAQ. The legal pages show a "Draft, pending legal review" banner while `NEXT_PUBLIC_LEGAL_DRAFT` is `true` (default).
- **MFA**: `/mfa` (see above). Admin → Users has a **Reset MFA** action for super admins.
- **Video consultation (§26)**: the consultation workspace shows a join panel for video/audio appointments with a countdown until the window opens (10 min before start, until 60 min after end, or `details.opensAt` from a 409). Inside the window it fetches `/appointments/:id/video-session` and "Join video call" opens `joinUrl` in a new tab; "Open in this page" embeds it (only for https URLs on `NEXT_PUBLIC_JITSI_DOMAIN`).
- **Auth**: `/login` (phone → OTP, dev OTP hint; staff continue to `/mfa` when MFA is pending).
- **Clinician** (`doctor`): `/clinician` queue (date picker, status chips, priority-sorted); `/clinician/patients` search; `/clinician/patients/[id]` Clinical Snapshot (demographics, allergies/conditions with provenance badges, meds, vitals with sparklines and a table, records with an authenticated "Open original", home-visit findings, intake, mood, wound cases with a review form, a sticky episode timeline, and a **lavender AI summary panel** with clickable source chips and Accept/Modify/Reject feedback); `/clinician/appointments/[id]` consultation workspace (start, notes, complete with outcome, Care Plan builder, episode notes, timeline); `/clinician/escalations`.
- **Operations** (`coordinator`, `ops_admin`, `super_admin`): `/ops` control tower (auto-refresh 15 s); `/ops/home-visits` dispatch board (SLA-breached/late highlighting, assign dialog); `/ops/providers` (verification for ops_admin, credential expiry warnings); `/ops/safety-events`; `/ops/episodes`; `/ops/tasks`; `/ops/incidents`; `/ops/payments` (refund for ops_admin).
- **Admin** (`super_admin`; `ops_admin` may read audit logs and analytics): `/admin/users`, `/admin/audit-logs`, `/admin/safety-rules`, `/admin/ai`, `/admin/knowledge`, `/admin/flags` (AI kill switch), `/admin/analytics`, `/admin/zones`.

## v1.2 pages (contract §29–§39)

- **Clinician**: `/clinician/profile` (bio, languages, qualifications, fees, accepting-bookings toggle, photo upload with local preview → `POST /me/photo`); `/clinician/schedule` (weekly template editor per weekday with multiple blocks, slot length and mode checkboxes, client-side overlap validation mirroring the server rule; leaves list with add/remove and a conflicts dialog listing appointments that are **not** auto-cancelled; a 7-day preview of generated slots from `/doctors/:id/slots`); `/clinician/earnings` (month picker, summary tiles, lines table).
- **Consultation workspace** `/clinician/appointments/[id]` now has tabs: *Consultation* (as before), *Prescription* (Rx writer with a live Rx-pad preview → `POST /clinician/prescriptions`, authenticated PDF download, list of the patient's prescriptions) and *Messages* (the episode's care-team thread). A **Refer to hospital** dialog (facility search, specialty, urgency, reason, summary) creates a referral and downloads its letter. The clinical snapshot lists prescriptions and referrals.
- **Operations**: `/ops/applications` (review queue by status, in-browser document viewer via blob URLs — PDFs in an iframe, images inline — and a decision form: approve needs a future credential expiry and the required documents, plus zones/capabilities; reject / request changes need a note; coordinators read only); `/ops/settlements` (ops_admin/super_admin: date range, per doctor/provider table, lines drill-down, authenticated CSV export); `/ops/reviews` (moderation with publish/reject + note); Payments gains **View invoice** (invoice render + PDF); `/ops/episodes` gains coordinator assignment.
- **Coordinator workspace** `/coordinator` (coordinator; visible to ops_admin/super_admin, but `GET /coordinator/caseload` is coordinator-only): caseload table with flag badges and risk sorting, patient drawer with episodes, tasks, contact-log timeline and a *Log contact* form.
- **Inbox** `/inbox` (doctor, coordinator, ops_admin, super_admin): thread list with unread counts (also shown as a sidebar badge, refreshed every 30 s), thread view polling every 10 s with `?after=`, composer with an optional record attachment, distinct system messages.
- **Admin**: `/admin/doctors` + `/admin/doctors/[id]/schedule` (super_admin, ops_admin; reuses the schedule editor, leaves are read-only because the contract has no admin leave endpoints); `/admin/plans` (subscription plans create/edit, retire with `active=false`); `/admin/schemes` (government schemes create/edit, draft/published toggle, content-review warning).

## Architecture notes

- `src/lib/api/types.ts` mirrors the contract types; `endpoints.ts` holds one typed function per contract row; `http.ts` is the fetch wrapper.
- **Auth tokens** live in memory and are mirrored to `sessionStorage` (per tab, cleared on close). On a `401` the client calls `POST /auth/refresh` **once** (concurrent 401s share one refresh), retries the original request with the same `Idempotency-Key`, and on a second failure clears the session and redirects to `/login?expired=1`.
- Every request sends `X-Correlation-Id`. The error envelope is parsed into `ApiError { status, code, message, details, correlationId }`, and error states show the correlation id as a support reference.
- **Route guarding** is client-side (no middleware): `src/components/app-shell.tsx` redirects to login when there is no session and shows an unauthorized state when the role cannot access the path (`src/lib/roles.ts`). The server remains the source of truth for authorization.
- **Session hardening**: staff sessions sign out after **15 minutes idle** (warning dialog from minute 13; the last-activity time survives reloads). A failed refresh clears the session and the query cache; logout also clears the cache. Any `403 MFA_REQUIRED` routes to `/mfa`.
- **`GET /config/public`** (`src/lib/public-config.ts`) supplies the support contacts on `/support` and the `ai_assistant` flag used to explain an empty AI summary panel.
- Dates are rendered in **Asia/Kolkata**; money is integer rupees rendered as `₹`.

## Production build and security

- `next.config.ts` sets `output: "standalone"` (flat: `.next/standalone/server.js`, `outputFileTracingRoot` is this folder), `productionBrowserSourceMaps: false` and `poweredByHeader: false`.
- To run it by hand: `npm run build`, then copy `.next/static` to `.next/standalone/.next/static` (and `public/` to `.next/standalone/public` if it exists) and run `node .next/standalone/server.js` with `PORT`/`HOSTNAME`. `npm run start:standalone` does exactly that.
- **Security headers** (`src/lib/security-headers.ts`, every route): a Content-Security-Policy limited to `'self'`, the API origin from `NEXT_PUBLIC_API_BASE_URL` and `https://<NEXT_PUBLIC_JITSI_DOMAIN>` as the only frame source (fonts are self-hosted by next/font, so no Google Fonts origin); `frame-ancestors 'none'` + `X-Frame-Options: DENY`; `Referrer-Policy: strict-origin-when-cross-origin`; `Permissions-Policy` (camera/mic/screen share delegated only to the Jitsi frame); `X-Content-Type-Options: nosniff`; COOP; and in production `Strict-Transport-Security` (and `upgrade-insecure-requests` when the API is https). Pages are static, so scripts need `'unsafe-inline'` (no per-request nonce).
- Headers and `NEXT_PUBLIC_*` values are fixed **at build time**: build the image per environment.
- **Env validation**: `src/lib/env.ts` validates every `NEXT_PUBLIC_*` variable (see `.env.example`); an invalid value (or a non-https API URL in a production build, localhost excepted) fails `next build`.

## Launch checklist for the founder

- Production domain for the portal and API (sets `NEXT_PUBLIC_API_BASE_URL`, the CSP and the `legal` URLs the API returns in `/config/public`).
- Legal approval of `/privacy`, `/terms` and `/account/delete`, including the payments/refunds, liability and jurisdiction placeholders; then set `NEXT_PUBLIC_LEGAL_DRAFT=false`.
- Operating entity name and the Grievance Officer's name and email (`NEXT_PUBLIC_LEGAL_ENTITY_NAME`, `NEXT_PUBLIC_GRIEVANCE_OFFICER_*`), and support contacts in the API config.
