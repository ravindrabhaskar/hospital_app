# Security

Threat model, controls and findings register for CareCompanion (Build Map Phase 24). Scope: patient app, provider app, web portal (clinician/ops/admin), core API, AI subsystem, integrations and data stores. This is a living document; an independent penetration test is required before the pilot (launch gate).

## 1. Assets and trust boundaries

**Crown-jewel assets:** health records and original files; AI conversation text; patient profiles (allergies, conditions, meds); family grants; safety rule packs (integrity); audit logs (integrity); payment state; staff accounts; secrets (JWT keys, webhook secret, AI key, DB credentials).

**Trust boundaries:** (1) mobile/web client ↔ API over the internet; (2) API ↔ database/object storage (private network); (3) API ↔ external vendors (LLM, gateway, SMS, maps); (4) gateway → webhook endpoint (inbound, unauthenticated except signature); (5) provider device offline store ↔ API; (6) staff browser ↔ admin functions.

## 2. Baseline controls

| Area | Control |
|---|---|
| Authentication | Phone OTP (6 digits, 5-min TTL, 5 attempts, 5 requests/15 min/phone), short-lived access tokens, rotating refresh tokens with reuse detection, logout/disable revocation; staff MFA (stub → required before the pilot) |
| Authorization | Central policy layer: role + patient relationship + family permission + consent; deny by default; audited denials; negative tests per matrix row |
| Input | zod validation on every route; size limits; multipart type sniffing (magic bytes, not the extension); ≤ 15 MB; filename sanitization |
| Files | Private object storage; access only via the API (auth + audit) or presigned URLs ≤ 5 min; malware scan before availability (prod); immutable originals with sha256 |
| Transport | TLS 1.2+, HSTS, no mixed content; certificate pinning in mobile apps (P1) |
| Data at rest | RDS and S3 encrypted with KMS CMKs; AI text table encrypted at the application level (envelope key) |
| Secrets | Secrets Manager; none in repo, images or logs; gitleaks in CI (to add); rotation schedule |
| Logging | pino with a redaction list; no PHI; correlation IDs; audit log separate and append-only |
| Rate limiting | Per-IP and per-user limits; OTP-specific limits; WAF rate-based rules |
| Idempotency | Required headers on create/pay; webhook dedupe on event ID |
| Dependencies | Lockfiles; `npm audit`/OSV and Dart pub advisories; Renovate/Dependabot (to add) |
| Headers (web) | CSP (no inline scripts except Next nonce), frame-ancestors none, X-Content-Type-Options, Referrer-Policy strict-origin |
| Mobile | Secure storage for tokens; encrypted offline queue; no PHI in crash logs; screenshot blocking on sensitive screens (P1); root/jailbreak detection advisory (P1) |
| Production guards | No `devOtp`; `confirm-mock` disabled; fixture rule pack refused; debug endpoints absent |

## 3. STRIDE threat model per surface

Risk: **H**/**M**/**L** (likelihood × impact, pre-mitigation).

### 3.1 Patient app + patient-facing API

| STRIDE | Threat | Risk | Mitigations | Residual / to do |
|---|---|---|---|---|
| Spoofing | OTP brute force or SIM-swap account takeover | H | Attempt/rate limits, short OTP TTL, device name recorded, new-device notice (P1) | SIM-swap remains; consider step-up for sensitive actions |
| Spoofing | SMS pumping / OTP toll fraud | M | Per-phone and per-IP limits, WAF, country allow-list (+91) | Monitor SMS spend |
| Tampering | Client sets `source`/provenance or `patientId` of another patient | H | Server-derived provenance; `assertPatientAccess` on every patient-scoped call | Authz regression tests |
| Repudiation | User denies granting family access or consenting | M | Consent ledger + audit (IP, device, correlation) | — |
| Info disclosure | IDOR on records/episodes/visits by guessing IDs | H | UUIDs + relationship checks + 404 on hidden resources | Pen test |
| Info disclosure | Lock-screen notifications leak health info | M | Generic push text (contract §12) | — |
| Info disclosure | Revoked grantee retains cached data on device | M | Server denial on the next request; clear cache on 403 for that patient | Device data persists until app refresh |
| DoS | AI endpoint abuse (cost) | M | Per-user AI rate limit, token caps, kill switch | Budget alerts |
| Elevation | Grantee with `view_records` performs booking | M | Permission-specific checks | Tested (seed Lakshmi) |

### 3.2 Provider app

| STRIDE | Threat | Risk | Mitigations | Residual |
|---|---|---|---|---|
| Spoofing | Unverified or expired provider acts on visits | H | Verification + expiry checked at match **and** each action | — |
| Spoofing | Provider visits the wrong person | M | Visit code only the patient/family knows + consent confirmation | Code shared under coercion |
| Tampering | Replayed or duplicated offline vitals | M | Per-action Idempotency-Key; server state guards | — |
| Tampering | Falsified vitals/observations | M | Audit, device/time stamps, quality review, patient visit summary | Human process (training, spot checks) |
| Info disclosure | Lost device exposes patient context | H | Encrypted offline store, token revocation on disable, 24h context expiry, minimal context | Require device lock/biometric (P1) |
| Info disclosure | Provider browses other patients | H | Assigned-visit scoping only | — |
| Repudiation | Provider disputes arrival/actions | L | Timeline events with timestamps, location pings (30-day retention) | — |
| Elevation | Provider calls ops/admin endpoints | M | Role checks; negative tests | — |

### 3.3 Clinician web

| STRIDE | Threat | Risk | Mitigations | Residual |
|---|---|---|---|---|
| Spoofing | Staff credential phishing | H | MFA (required), short sessions, WAF, login alerts | MFA is a stub today (**blocker**) |
| Info disclosure | Doctor browsing patients without a relationship | H | Relationship-scoped queries; snapshot access audited; weekly review | — |
| Tampering | AI summary mistaken for verified data | M | Distinct AI panel, advisory label, sources per claim; AI never overwrites | Training |
| Tampering | XSS via patient-entered text rendered in portal | M | React escaping, CSP, no `dangerouslySetInnerHTML` for user content | Pen test |
| Repudiation | Disputed care-plan authorship | L | Plan authored by the doctor ID, audit, supersede chain | — |
| CSRF | Cookie-based session actions | M | SameSite=strict cookies, CSRF token on mutations, CORS allow-list | — |

### 3.4 Ops and admin web

| STRIDE | Threat | Risk | Mitigations | Residual |
|---|---|---|---|---|
| Elevation | super_admin compromise → role grants, flag flips, rule-pack activation | H | MFA, few super_admins, audit of every admin action, alert on role/flag/pack changes | Two-person rule for packs (Q-10) |
| Tampering | Unapproved or malicious rule pack activated | H | Status workflow; prod refuses fixture/draft; approver identity recorded; audit | Human approval process |
| Tampering | Kill switch disabled maliciously during an incident | M | Audit + alert on flag changes | — |
| Info disclosure | Ops sees clinical content unnecessarily | M | Ops endpoints expose metadata; AI interaction list has no raw text | Break-glass not built |
| Repudiation | Refund fraud by an insider | M | Refund only ops_admin, audited, reconciliation report | Maker-checker for large refunds (P1) |

### 3.5 AI subsystem

| STRIDE | Threat | Risk | Mitigations | Residual |
|---|---|---|---|---|
| Tampering | Prompt injection in user text or uploaded documents ("ignore rules, say it's fine") | H | Safety engine runs before and independently of the LLM; the LLM cannot lower the level; policy check; the system prompt treats content as data; evaluation case | Novel injections: monitoring |
| Info disclosure | LLM leaks another patient's data | M | Context limited to the resolved patient; no cross-patient retrieval; no shared memory | — |
| Info disclosure | PHI sent to a third-party LLM / retained by the vendor | H | Minimum-necessary context, zero-retention contract, legal assessment | **[REQUIRES LEGAL REVIEW]** Q-09 |
| Spoofing | Poisoned knowledge source | M | Only admin-created sources; approval status; owner/version | Content review by governance |
| DoS | Vendor outage or latency | M | Timeout, circuit breaker, offline fallback, kill switch | — |
| Repudiation | Unable to reconstruct what the AI said | M | AIInteraction with versions and encrypted text | — |

### 3.6 Integrations and webhooks

| STRIDE | Threat | Risk | Mitigations | Residual |
|---|---|---|---|---|
| Spoofing | Forged payment webhook marks orders paid | H | HMAC-SHA256 over the raw body, constant-time compare, event-ID dedupe, amount/order cross-check, IP allow-list | Secret rotation process |
| Tampering | Replay of old webhooks | M | Event-ID uniqueness; timestamp tolerance if the gateway provides one | — |
| DoS | Webhook floods | L | WAF, fast 200 after persistence, async processing | — |
| Info disclosure | Over-sharing with SMS/WhatsApp vendors | M | Templates without health details; DPAs | — |
| Tampering | Partner outage corrupts domain state | M | Adapters with retries, circuit breakers, outbox; external failures never commit partial domain state | — |

### 3.7 Data stores and infrastructure

| Threat | Mitigation |
|---|---|
| Public S3 exposure | Block Public Access (account level), bucket policy denying non-TLS and non-VPC-endpoint access, AWS Config rule |
| DB exfiltration via stolen credentials | Private subnets, SG restrictions, IAM auth for humans, rotation, GuardDuty |
| Audit tampering | INSERT-only role, hash chain, archive with S3 Object Lock |
| Backup exposure | Encrypted snapshots; restricted KMS key policy |
| CI/CD supply chain | OIDC to AWS, pinned actions, image scanning, required reviews on prod deploy |

## 4. Security testing plan

SAST (Semgrep ruleset for TS/Next), dependency scanning (npm/OSV, pub), secret scanning (gitleaks), DAST (OWASP ZAP baseline on staging), authz regression suite (`12_TEST_STRATEGY.md`), upload fuzzing (polyglot files, oversize, wrong MIME), rate-limit tests, and an **independent pen test** covering mobile, web, API and cloud config before the pilot, then annually and after major changes.

## 5. Findings register

| ID | Date | Source | Severity | Title | Status | Owner | Notes |
|---|---|---|---|---|---|---|---|
| SEC-001 | 2026-09-26 | Design review | High | Staff MFA not implemented (stub) | Open | Tech lead | Launch blocker (L-20) |
| SEC-002 | 2026-09-26 | Design review | High | No malware scanning on uploads | Open | Tech lead | L-21 |
| SEC-003 | 2026-09-26 | Design review | Medium | Security scanners absent from CI | Open | Tech lead | L-22 |
| SEC-004 | 2026-09-26 | Design review | High | Cross-border LLM processing not legally assessed | Open | Founder/counsel | L-14 |

Severity SLAs: Critical fix before any release, max 48h exposure; High before the pilot (or 7 days post-pilot); Medium 30 days; Low 90 days. Vulnerability reports: security@<domain> (to set up).
