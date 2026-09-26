# 10 — API Conventions

**The authoritative API is `docs/api/API_CONTRACT.md` (v1).** This file summarizes its conventions and adds the engineering rules for evolving it. If they differ, the contract wins. Change the contract first, then the code.

## 1. Basics

| Topic | Convention |
|---|---|
| Base URL | `/api/v1` (dev `http://localhost:4000/api/v1`; Android emulator `http://10.0.2.2:4000/api/v1`) |
| Format | JSON, `camelCase`, UUID IDs |
| Time | ISO-8601 UTC timestamps; dates `YYYY-MM-DD`; UI renders Asia/Kolkata |
| Money | Integer **rupees** in payloads; the gateway adapter converts to paise |
| Language | `Accept-Language: en | hi | te` localizes server-generated text |
| Correlation | `X-Correlation-Id` optional on the request; always echoed; present in errors, logs and audit |
| Uploads | `multipart/form-data` (records ≤ 15 MB; pdf/jpg/png/webp/heic) |

## 2. Authentication

- `Authorization: Bearer <accessToken>` on everything except `/auth/*`, `/health`, `/ready`, `/webhooks/*`.
- Phone OTP (6 digits, 5-min expiry, 5 attempts, 5 requests/phone/15 min). Dev OTP `123456`; `devOtp` is returned only when `NODE_ENV != production`.
- Refresh tokens rotate on every refresh. Logout revokes. Staff users have `mfaRequired: true` (stub hook in the MVP).
- Webhooks authenticate with `X-Signature` = hex HMAC-SHA256 over the raw body using `PAYMENT_WEBHOOK_SECRET`, compared in constant time.

## 3. Authorization

RBAC + patient-relationship checks + consent gates, enforced server-side in a policy layer (`03_USER_ROLES_AND_PERMISSIONS.md`). The client never decides access; UI hiding is cosmetic only.

## 4. Errors

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Human readable", "details": {}, "correlationId": "..." } }
```

| Code | HTTP | Typical cause |
|---|---|---|
| `VALIDATION_ERROR` | 400 | zod schema failure (`details` lists field issues) |
| `UNAUTHENTICATED` | 401 | Missing/expired token |
| `FORBIDDEN` | 403 | Role/relationship/permission denial |
| `CONSENT_REQUIRED` | 403 | Missing consent (`details.purpose`) |
| `NOT_FOUND` | 404 | Unknown ID or hidden by policy |
| `CONFLICT` | 409 | Generic conflict |
| `INVALID_STATE_TRANSITION` | 409 | Episode/visit/appointment state guard |
| `SLOT_UNAVAILABLE` | 409 | Slot already reserved |
| `IDEMPOTENCY_MISMATCH` | 422 | Same key, different request |
| `NOT_SERVICEABLE` | 422 | Pincode outside zones |
| `RATE_LIMITED` | 429 | OTP or general limits (`Retry-After` header) |
| `INTERNAL` | 500 | Unexpected; no internals leaked |
| `DEPENDENCY_UNAVAILABLE` | 503 | DB/AI/storage/gateway down |

Messages are safe for display. They never include stack traces, SQL or PHI.

## 5. Lists and pagination

`{ "items": [...], "nextCursor": "opaque-or-null" }` on **every** list endpoint; `?limit=20&cursor=...`, limit ≤ 100. Cursors are opaque (base64 of sort key + id) and stable under inserts. Default sort is newest first unless the endpoint says otherwise.

## 6. Idempotency

`Idempotency-Key` (≤128 chars) is **required** on: `POST /care-episodes`, `POST /appointments`, `POST /home-visits`, `POST /home-visits/:id/vitals`, `POST /pharmacy/orders`, `POST /emergency/sos`, `POST /payments/:id/confirm-mock`.
- Same key + same user + same body hash → the stored original status and body are returned without re-execution.
- Same key + different body → `IDEMPOTENCY_MISMATCH`.
- Keys are stored with a 24h TTL (recommended). Concurrent duplicates are serialized with a unique constraint on (userId, key).
- Webhooks are idempotent on the gateway event ID. The provider app offline queue reuses one key per queued action (ADR-005).

## 7. Concurrency

Slot reservation uses a unique constraint plus a transactional conditional update. State transitions use compare-and-set on the current status. Losers get 409.

## 8. Versioning and evolution

- The URI major version is `/api/v1`. Additive changes (new optional fields, endpoints, enum values documented as extensible) are allowed within v1. Clients must ignore unknown fields.
- Breaking changes (removal, rename, type change, new required field, semantic change) → `/api/v2` alongside v1 with a deprecation window of ≥ 90 days, or ≥ 2 mobile releases, whichever is longer.
- Every change: update `API_CONTRACT.md` first → contract tests → server → clients → `CHANGELOG.md`.
- Enum additions that clients switch on (statuses) must be coordinated because mobile apps in the field lag.

## 9. Health and readiness

`GET /health` → liveness. `GET /ready` → `{ db, ai: ok|degraded, safetyRules: ok|fixture }`. The load balancer uses `/ready` for DB only; AI `degraded` must not remove instances from rotation.

## 10. Rate limits (recommended defaults)

OTP as in the contract. Authenticated: 120 req/min/user. AI messages: 20/min/user. Uploads: 20/hour/user. Webhooks: IP allow-list plus a signature check. All limits return 429 with `Retry-After`.

## 11. Privacy rules for payloads

- Role-filtered views: for example `HomeVisit.visitCode` is only returned to the patient/family, and `patientContext` only to the provider/doctor.
- `phoneMasked` for providers. The patient's phone is not shown to providers (call masking/bridging is an adapter, P1).
- Admin AI-interaction lists never include raw text.
- Push notification text never contains health details.
