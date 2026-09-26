# Go-live: accounts and credentials to obtain

All code for these integrations is written and tested with mocked services. Nothing here requires more development: obtain each item and put it where the table says. Until then, the platform runs in development mode with safe fallbacks.

Where values go:
- **API secrets** → AWS Secrets Manager `carecompanion/<env>/api/<NAME>` (listed in `infra/terraform/variables.tf` → `api_secret_names`)
- **API non-secret settings** → `api_extra_environment` in your `.tfvars`
- **Mobile build values** → `--dart-define` values, stored as GitHub repo variables/secrets (see `.github/workflows/mobile-release.yml`)
- Full env reference: `services/api/.env.production.example` and `services/api/README.md` → "Production configuration"

## 1. Accounts and registrations (start these first; some take weeks)
| # | What | Why | Lead time |
|---|---|---|---|
| 1 | **Company registration / GST**, D-U-N-S number | Organisation developer accounts, Razorpay KYC | 1–4 weeks |
| 2 | **Domain name** (e.g. `carecompanion.in`) | API `api.<domain>`, portal, privacy and deletion pages | 1 day |
| 3 | **AWS account** (region ap-south-1, Mumbai) | Hosting; health data stays in India | 1 day |
| 4 | **GitHub** organisation/repo with `staging` + `production` environments | CI/CD | 1 day |
| 5 | **Google Play Console** (organisation, $25) | Android release | 2–7 days of verification |
| 6 | **Apple Developer Program** (organisation, $99/yr) | iOS release | 1–2 weeks |
| 7 | **DLT registration** (Jio/Airtel/Vi portal): entity, sender ID, OTP template | Required by TRAI for any SMS in India | 1–2 weeks |
| 8 | **MSG91** account (or Twilio) | OTP SMS | after DLT |
| 9 | **Razorpay** account with KYC | Payments and refunds | 3–10 days |
| 10 | **Firebase** project (Android + iOS apps added; APNs .p8 key uploaded) | Push notifications | 1 day |
| 11 | **Anthropic** API key (with a data-processing agreement reviewed by counsel) | AI assistant (the offline rule-based assistant works without it) | 1 day |
| 12 | Optional: self-hosted **Jitsi** or JaaS | Private video rooms (public meet.jit.si works without it) | – |

## 2. API secrets (Secrets Manager)
| Secret | Source |
|---|---|
| `DATABASE_URL` | Created during first deploy (runbook §3.4) |
| `JWT_SECRET`, `PAYMENT_WEBHOOK_SECRET`, `MFA_ENCRYPTION_KEY`, `VIDEO_ROOM_SECRET`, `METRICS_TOKEN` | **Generate yourself:** `openssl rand -hex 32` (MFA key: see README for the required format) |
| `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` | Razorpay dashboard → API keys / Webhooks (webhook URL: `https://api.<domain>/api/v1/webhooks/payments`) |
| `MSG91_AUTH_KEY` | MSG91 dashboard (or `TWILIO_AUTH_TOKEN`) |
| `ANTHROPIC_API_KEY` | console.anthropic.com |
| `FCM_PRIVATE_KEY` *(optional)* | Firebase → Service accounts → Generate key |
| `JITSI_APP_SECRET` *(optional)* | Your Jitsi deployment |
| `REVIEW_OTP` *(during store review only)* | Choose a 6-digit code |

## 3. API non-secret settings (`api_extra_environment`)
`RAZORPAY_KEY_ID`, `MSG91_OTP_TEMPLATE_ID`, `MSG91_SENDER_ID`, `MSG91_NOTIFY_TEMPLATE_ID`, `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `SUPPORT_PHONE`, `SUPPORT_EMAIL`, `SUPPORT_WHATSAPP`, `MIN_APP_VERSION_*`, `REVIEW_PHONE` (review only), optional `JITSI_DOMAIN`, `JITSI_APP_ID`, `AI_MODEL`.

## 4. Mobile apps
| Item | Where |
|---|---|
| Upload keystores (one per app): `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload` | GitHub secrets `PATIENT_/PROVIDER_ANDROID_KEYSTORE_BASE64`, `_KEYSTORE_PASSWORD`, `_KEY_ALIAS`, `_KEY_PASSWORD`. **Back up the keystore offline; if you lose it, you cannot update the app.** |
| `API_BASE_URL` | `https://api.<domain>/api/v1` |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID` | Firebase project settings (separate Android/iOS app IDs) |
| Final logo (1024×1024 PNG) | Replace the files in `docs/design/brand/` (and `brand/provider/`), then run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` in each app |
| App Store URL | `apps/patient_app/lib/features/misc/force_update_screen.dart` once listed |
| `PLAY_SERVICE_ACCOUNT_JSON` *(optional)* | For automatic upload to the Play internal track |

## 5. Human approvals (not credentials, but launch-blocking)
- **Medical director** approves the clinical safety rule pack. Production refuses the fixture pack (`docs/product/07_CLINICAL_SAFETY_INTERFACE.md`).
- **Legal counsel** approves the privacy policy, terms, consent texts and retention rules. Then set `NEXT_PUBLIC_LEGAL_DRAFT=false` and fill in the Grievance Officer's name and contact.
- **Penetration test** of the staging environment.
- **Store forms:** Play Data Safety and Health declaration, and the Apple privacy labels. Answers are drafted in `docs/STORE_SUBMISSION.md`.

## 6. Order of go-live
1. Items 1–4 → `terraform apply` for staging (runbook §3) → put the secrets → deploy → `create-admin` → staff enrol MFA.
2. Vendors 7–11 → configure staging → run `node tests/load/smoke.mjs` and the E2E journey against staging.
3. Build the signed apps via `mobile-release.yml` → Play **internal testing** / TestFlight with your team.
4. Clinical plus legal approvals → production `terraform apply` → closed pilot → store review (reviewer login) → public release.
