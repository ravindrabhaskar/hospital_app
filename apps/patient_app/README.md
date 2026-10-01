# CareCompanion – Patient & Family App (Flutter)

The patient and family mobile app for CareCompanion. It targets Android, iOS and web, is built with Flutter 3.47 and Dart 3.13, and talks to `services/api` through the contract in `docs/api/API_CONTRACT.md`.

## Run

```bash
cd apps/patient_app
flutter pub get

# Web (API on the same machine)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1

# Android emulator (defaults to http://10.0.2.2:4000/api/v1)
flutter run -d emulator-5554

# Physical device on the LAN
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1
```

`API_BASE_URL` defaults to `http://10.0.2.2:4000/api/v1` on Android and to `http://localhost:4000/api/v1` everywhere else.

Start the backend first (`cd services/api && npm run dev`, which listens on port 4000, then `npm run seed`).

### Demo login
- Phone: **+91 9800000001** (enter `9800000001`). The account is Vaibhav, who manages his father Ramesh Kumar.
- OTP: **123456**. In dev the API also returns `devOtp`, which the OTP screen shows as a "Dev OTP" hint with a *Use* button.
- To act for Ramesh, tap the avatar on Home and pick him in the family switcher.

## Testing on a real phone: server address

The backend URL is compiled in (`API_BASE_URL`), but non-production builds also have a runtime **Server address** setting, so a tester can point the app at any backend without rebuilding:

- **Phone-number screen:** a small "Server: <host>" chip at the bottom. If sending the OTP fails because the server can't be reached, the screen says "Can't reach the server at <host>" with a **Change server** button.
- **Profile → Server address** for signed-in users. Changing it signs you out first, because tokens belong to a server.

The dialog accepts `http(s)://host[:port]` (`/api/v1` is appended when missing), a bare IP such as `10.10.17.134` (becomes `http://10.10.17.134:4000/api/v1`) or an https tunnel link such as `https://xyz.trycloudflare.com`. **Test connection** calls `GET <url>/health` and shows the server version, or explains what to check. **Save** applies the address immediately, with no restart. **Reset to default** returns to the compiled URL. The value is stored in shared preferences under the global key `server.baseUrl.override`, so in the all-in-one build the three roles share one setting.

The setting exists only when the compiled `API_BASE_URL` is not https, or when the build passes `--dart-define=ALLOW_SERVER_OVERRIDE=true`. An https production build can't set or use an override (unit-tested in `test/server_settings_test.dart`). The code is in `lib/core/server/`.

Release builds allow cleartext HTTP only to `10.0.2.2`, `localhost` and `127.0.0.1`. For a LAN IP entered at runtime, build with the Gradle property `demoCleartext=true` (`flutter build apk -P demoCleartext=true`, or `ORG_GRADLE_PROJECT_demoCleartext=true` for plain Gradle). It selects `network_security_config_demo.xml` through a manifest placeholder. `scripts/build-android-release.ps1 -Demo` does all of this; see `docs/MOBILE_RELEASE.md`. https tunnel links work in every build that allows the override.

## Quality commands

```bash
flutter analyze          # expected: No issues found
flutter test             # widget + unit tests
flutter build web
flutter build apk --debug
flutter build apk --release && flutter build appbundle --release
python tool/gen_arb.py   # regenerate lib/l10n/app_{en,hi,te}.arb from one table
flutter gen-l10n         # regenerate AppLocalizations after editing the ARB table
```

## Release builds

```bash
flutter pub get
flutter analyze && flutter test

# Android (Play Store upload = the .aab)
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.in/api/v1 [push defines]
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=...   # sideload / QA

# iOS (on macOS with Xcode + an Apple developer account)
flutter build ipa --release --dart-define=API_BASE_URL=...

# Web
flutter build web --release --dart-define=API_BASE_URL=...
```

- **Identity:** Android `applicationId` and iOS bundle id are `com.carecompanion.patient`; the display name is "CareCompanion".
- **Versioning:** `version: 1.0.0+1` in `pubspec.yaml` sets `versionName`/`CFBundleShortVersionString` (1.0.0) and `versionCode`/`CFBundleVersion` (1). Bump the `+N` build number for every store upload. The same version is compared against `minAppVersion` from `/config/public`.
- **R8:** release builds minify and shrink resources; keep rules for Flutter, Razorpay, Firebase and flutter_local_notifications are in `android/app/proguard-rules.pro`.

### Dart defines

| Define | Required | Purpose |
|---|---|---|
| `API_BASE_URL` | yes for release | API root, e.g. `https://api.carecompanion.in/api/v1` |
| `ALLOW_SERVER_OVERRIDE` | demo only | `true` enables the runtime "Server address" setting even when `API_BASE_URL` is https. Never set it for store builds. |
| `FIREBASE_API_KEY` | for push | Firebase Android/iOS app API key |
| `FIREBASE_APP_ID` | for push | Firebase app id (`1:123:android:abc`) — use the iOS app id for iOS builds |
| `FIREBASE_MESSAGING_SENDER_ID` | for push | Sender id (project number) |
| `FIREBASE_PROJECT_ID` | for push | Firebase project id |
| `FIREBASE_IOS_BUNDLE_ID` | optional | iOS bundle id for the Firebase iOS app |

All four `FIREBASE_*` values must be present or push is skipped silently. Razorpay needs **no** client define: the key id and order come from the server (`/config/public` and `Payment.checkout`).

### Adding the release keystore (Android)

```bash
keytool -genkey -v -keystore ~/carecompanion-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` (git-ignored, never commit it or the `.jks`):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/secure/carecompanion-upload.jks
```

Without `key.properties`, release builds are signed with the **debug key** so they still build, but Play will reject them. Enrol in Play App Signing and keep the upload key backed up.

### Adding Firebase push later

1. Create a Firebase project; add an Android app (`com.carecompanion.patient`) and an iOS app (same bundle id).
2. Copy the API key, app id, sender id and project id into the `--dart-define`s above. No `google-services.json`, `GoogleService-Info.plist` or Gradle google-services plugin is needed: `FirebaseOptions` are built in code (`lib/core/push/push_service.dart`).
3. iOS: upload an APNs auth key in Firebase, enable the *Push Notifications* capability in Xcode (adds `aps-environment`); `UIBackgroundModes: remote-notification` is already in `Info.plist`.
4. Backend: set `FCM_PROJECT_ID` and service-account credentials in `services/api`.

Behaviour: after login (and after onboarding) the app shows a short explanation, then the OS prompt (Android 13+ `POST_NOTIFICATIONS`, iOS); the token goes to `POST /devices` and again on refresh; logout calls `DELETE /devices`. Tapping a notification opens its `deepLink`. Channels: `cc_general` (care updates) and `cc_critical` (SOS, fall and safety alerts).

### Adding Razorpay later

Nothing in the app changes: set the gateway to `razorpay` and the key id/secret on the server. The app then opens Razorpay Standard Checkout on Android/iOS, verifies with `POST /payments/:id/verify`, and on cancel/failure offers retry (`POST /payments/:id/retry`). On web it shows "Complete payment in the mobile app". A booking is shown as confirmed only when the payment is `succeeded`.

## Branding

Placeholder artwork lives in `docs/design/brand/` (generated by `python docs/design/brand/generate_icons.py`): `app_icon_1024.png`, `app_icon_1024_ios.png` (no alpha), `app_icon_foreground.png` (adaptive foreground, mark inside the central 66% safe zone) and `splash_logo.png`.

To swap in the final logo: replace those PNGs with the same names and sizes (1024×1024; splash logo 768×768 transparent), adjust colours in `flutter_launcher_icons.yaml` / `flutter_native_splash.yaml` if needed, then run:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## v1.1 features (API_CONTRACT §21–§28)

- **Public config** (`GET /config/public`) loads at startup, is cached in shared preferences and falls back to the cached copy (or seeded defaults) offline. Feature flags come only from it (`featureFlagsProvider`). A blocking **Please update** screen appears when the installed version is below `minAppVersion` for the platform.
- **Help & Support** (Profile) uses the configured phone/WhatsApp/email; privacy and terms links appear in Profile, Privacy & Consents, onboarding consents and account deletion.
- **Download my data / Delete my account** under Profile → Privacy & Consents (§23). Deletion explains the grace period and what is retained, needs `DELETE` typed to confirm, logs out after scheduling, and shows *Cancel deletion* while scheduled.
- **Video consultation** (§26): the appointment detail shows a join card with a countdown; within the window (10 min before start to 60 min after end) a pre-join checklist opens, then the Jitsi link opens externally (Jitsi Meet app if installed). 409 responses show when the room opens.
- **Load more** (cursor pagination) on records, appointments, notifications and the timeline.
- `MFA_REQUIRED` (staff accounts) shows "Use the staff portal".

## v1.2 features (API_CONTRACT §29–§40)

- **e-Prescriptions** (§31): Records → *Prescriptions* tab (doctor-issued e-prescriptions first, then uploads) and the care-episode detail. The detail screen is styled as an Rx pad (doctor, qualifications, registration no., patient, ℞ items with dose/frequency/timing/duration/reminder times, advice, follow-up). *View PDF* opens the in-app viewer. *Order these medicines* → `/prescriptions/:id/pharmacy-match` → the user confirms matched in-stock products → the cart is prefilled and checkout sends `prescriptionId` (no upload needed).
- **In-app PDF viewer** (`pdfx`): prescriptions, invoices and PDF medical records open in-app on Android/iOS with share. On web the app does not load PDF.js from a CDN; the PDF opens in the browser's viewer in a new tab (or downloads).
- **Invoices** (§32): Profile → Payments → *Invoice* on succeeded/refunded payments: rendered in-app, *View PDF* and *Share* (share sheet on mobile, download on web).
- **Ratings & reviews** (§33): a bottom sheet on Home for `/reviews/pending` (stars + optional comment; "a rating on its own is published right away, comments are checked first"). *Not now* is remembered locally (`cc_review_dismissed`); each target is prompted at most once per app session. The doctor Reviews tab shows published reviews (rating-only reviews supported).
- **Care-team messaging** (§34): Inbox (Home header chat icon with unread badge, Care app bar), one thread per episode (`/care-episodes/:id/messages`, also the push deep link) polling every 10 s while open and in the foreground, composer with *attach an existing record*, sender role chips (Doctor, Care coordinator, Care team, Family), system messages in blue and the emergency template in red with *Call 108* / *SOS*.
- **Family Care Plan** (§37): Profile → Family Care Plan: plan cards with a monthly/yearly toggle and savings, subscribe → the existing payment sheet (mock / Razorpay) → active state with period end, benefits and *Cancel at period end*. Home-visit booking shows a plan note and the `discountApplied` line.
- **Govt. Health Schemes** (§38): Home tile → list (state filter defaults to Telangana; central schemes always listed) → detail with summary, benefits, "May be relevant if…" hints, documents, tap-to-call helpline, *Open official website* and a prominent "the app does not determine eligibility" disclaimer. The `govt_schemes` flag defaults to on.
- **ABHA** (§39): Profile → Health Profile → *ABHA (Health ID)*: number with live `XX-XXXX-XXXX-XXXX` formatting and 14-digit validation, `name@abdm`/`name@sbx` address, *Not verified* status and *Verify* (503 → "ABDM verification is coming soon").
- **Wearables** (§40, `health`): Health Connect (Android) / Apple Health (iOS). The user picks each data type (steps, heart rate, sleep, SpO2, BP, glucose, weight) → OS permission sheet → `POST /wearables/connections` (`health_connect`/`apple_health`) → sync of the last 7 days to `POST /wearables/sync` in batches of 200. Steps and sleep are sent as daily totals, heart rate as 30-min averages. Auto-sync on app open/resume at most every 30 min; *Sync now*; *Disconnect* revokes server-side and in Health Connect. Handles Health Connect missing/outdated (Play Store link), permission denial and web (unsupported message).
- **Fall detection** (§40, `sensors_plus`): opt-in switch on the Fall Detection screen (only when the flag is on, Android/iOS). A foreground-only accelerometer listener feeds `FallDetector` (free fall < 0.5 g → impact > 2.5 g within 1 s → ~2 s stillness, 30 s cool-down); a detection posts `/fall-events` and opens the existing "Are you OK?" countdown. No background service; a supportive signal, not a medical device.
- **Voice replies** (§40, `flutter_tts`): assistant replies are read aloud in the UI language (en-IN/hi-IN/te-IN) after voice input or when *Read replies aloud* is on in the chat menu; new input stops speech; safety templates are read only as the text shown in their red bubble.
- **Photos** (§29): doctor/provider photos via `cached_network_image` with initials fallback; tap your avatar in Profile to take/choose a photo, centre-cropped to a square PNG and uploaded to `POST /me/photo`.
- **Dark mode**: Profile → Appearance (System / Light / Dark, persisted as `cc_theme_mode`). Hard-coded light colours on the main screens now use theme-aware tokens (`context.textMuted`, `context.surface`, `context.mintSurface`, … in `core/theme/tokens.dart`).

## v1.3 features (API_CONTRACT §41–§62)

Code lives in `lib/models/{monitoring,services,engagement_v13}.dart`, `lib/data/v13_repositories.dart`, `lib/state/v13_providers.dart` and `lib/features/<feature>/`. The strings are in `tool/arb_v13.py`, which `tool/gen_arb.py` imports. No new packages were added: the charts are drawn with a CustomPainter (`core/widgets/trend_chart.dart`), and map links open Google Maps or OpenStreetMap.

- **Daily check-in** (§41): the Home card offers one tap to check in, plus an optional mood. It has pending, missed and done states, and a status-only view when acting for a family member. It is hidden while disabled or on error. `/checkin` holds the settings (window, escalation, notify toggles; `manage_care`) and a 30-day history strip.
- **Care programs** (§42): `/programs` shows each enrollment with its 7-day adherence, the readings due today (from template metrics and today's vitals) and its open alerts. A "My programs" section on Home appears when enrolled. `/programs/:id` has the 30-day summary, a trend chart per vital with dashed threshold lines, the alerts, and the weekly report PDFs in the in-app viewer. **Log reading** posts BP, sugar or weight to `POST /vitals`, with range validation.
- **WhatsApp** (§43): Profile → Notifications has the opt-in toggle and a **Try it** sheet listing the commands.
- **Lab tests** (§44): Home tile → `/lab` has search, category chips, packages and a cart. A test already in a selected package is not charged twice. The checkout shows a fasting notice, reuses the address, serviceability and window fields (`home_checkup/address_slot_section.dart`), and has coupon + wallet and payment. `/lab/orders/:id` shows a timeline and **View report**.
- **Second opinion** (§49): specialty pricing, the question, a picker for records to share with explicit consent text, coupon + wallet, payment, status and the opinion view (PDF, teleconsult link).
- **ABDM** (§50): Health Profile has **Create ABHA** (mobile OTP) and **Link existing ABHA** (`AbhaFlowController`). **Fetch records** covers record types, a date range and a list of requests. Imported records show an "Imported via ABDM" badge in Records.
- **Insurance** (§51): Profile → Insurance lets you add, edit and delete policies. A card photo is uploaded via `/records`. Policies show an expiring badge. There is a cashless hospitals list and a claim checklist (cashless / reimbursement).
- **Preventive care** (§52): due, overdue, upcoming and done lists per family member, with **Mark as done**.
- **Exercise** (§53): today's exercises with sets, reps and hold timers, instructions and precautions. After a session you give a pain score (0–10), and progress includes a pain trend. You can book a `physiotherapy` home visit.
- **Diet** (§54): meals by slot, followed / not-followed logging (today's choices are cached locally), foods to avoid, and a 14-day adherence chart.
- **Ambulance** (§55): the SOS screen keeps **Call 108** as the primary action and adds **Book private ambulance** (BLS/ALS, GPS pickup, destination hospital). Tracking polls every 5 s and shows the vehicle, ETA, timeline and map links. Every ambulance screen has a Call 108 banner.
- **Dementia safety** (§56): Profile → Safety & location covers:
  - a safe zone: current location as centre, 100 m–5 km radius, active hours, last known location with a map link;
  - **Companion mode**: explicit consent screen, then a foreground-only location every 5 min (`CompanionModeHost` in the shell);
  - SOS button pairing.
- **Company plan** (§57): **Have a company code?** on the Family Care Plan screen, plus a "Sponsored by" badge.
- **White-label** (§58): build with `--dart-define=TENANT_CODE=<code>`. The app then calls `/config/public?tenant=` and applies the display name (app title), the primary colour (seeded ColorScheme, light and dark) and the logo (Home header, Profile). Profile shows a "Powered by CareCompanion" footer. Nothing changes without a tenant.
- **Offers, wallet, invites** (§60): every checkout has a coupon field (`/coupons/validate`) and a "Use wallet balance" switch, with discount / wallet / payable lines. This covers appointments, home visits, lab, pharmacy, subscriptions (a plan checkout sheet) and second opinions. A fully covered payment skips the payment sheet. Profile → Wallet shows the balance and transactions. **Invite family & friends** shows your code and a share sheet. An optional onboarding step (`/onboarding/invite`) and the Invite screen both redeem codes.
- **Support** (§61): Help & Support → **My tickets** lets you create a ticket (category, subject, message, an attached record, a linked booking). The conversation polls every 15 s and hides internal notes, and you can rate after it is resolved. **Health concern** tickets show a care-team note with Call 108.
- **Home grid**: new tiles for Lab Tests, Care Programs, Preventive Care and Second Opinion. SOS stays visible, and Insurance, Exercise, Diet and the older tiles move to a **More** sheet.
- **Flags**: optional keys (`lab_tests`, `care_programs`, `second_opinion`, `insurance`, `preventive_care`, `exercise_plans`, `diet_plans`, `daily_checkin`, `whatsapp_assistant`, `ambulance_booking`, `dementia_safety`, `wallet_offers`, `support_desk`, `abdm`) are read from `/config/public` and default to on.

| Define | Purpose |
|---|---|
| `TENANT_CODE` | Hospital white-label build (§58); empty = CareCompanion |

## Structure

```
lib/
  core/api/        ApiClient (bearer, single-flight refresh-on-401 with rotation,
                   X-Correlation-Id, Idempotency-Key, typed ApiException), TokenStore
  core/theme/      design tokens from docs/product/11_DESIGN_SYSTEM.md
  core/widgets/    cards, state views (loading/empty/error/offline/unauthorized),
                   robot + ECG + banner illustrations (CustomPainter, no assets)
  models/          hand-written fromJson models mirroring the contract
  data/            one repository per API domain
  state/           Riverpod providers: session, locale, family "active patient", data
  features/        onboarding, home, care, ai, doctors, payments, home_checkup,
                   pharmacy, records, wellness, wound, wearables, emergency,
                   facilities, profile
  l10n/            ARB files (en, hi, te) + generated AppLocalizations
```

- **Active patient.** `activePatientProvider`, backed by `GET /patients`, decides which patient every patient-scoped call uses. The family switcher on Home changes it.
- **Idempotency.** `IdempotentAction` creates one key per user action. It reuses that key when a request is retried after a network failure, and it creates a new key once the server returns a definite answer.
- **Payments.** A booking is shown as confirmed only when `payment.status == succeeded`. If the payment fails, the booking stays unconfirmed and the user gets a retry banner.
- **Safety.** The chat always shows emergency safety results as a red alert with *Call 108* and *SOS*. Every piece of AI text is labelled "AI-generated · not a diagnosis". The wound flow only checks image quality.
- **Localization.** Every user-facing string lives in the ARB files. Strings containing medical terminology carry a `GLOSSARY-REVIEW` description in `app_hi.arb` and `app_te.arb`, and those translations must be reviewed against the clinical glossary before release.

## Permissions
- **Android (v1.2)**: `minSdk` is now **26** (required by Health Connect). Health Connect read permissions `READ_STEPS`, `READ_HEART_RATE`, `READ_SLEEP`, `READ_OXYGEN_SATURATION`, `READ_BLOOD_PRESSURE`, `READ_BLOOD_GLUCOSE`, `READ_WEIGHT`; the `ACTION_SHOW_PERMISSIONS_RATIONALE` intent filter on `MainActivity` and the `ViewPermissionUsageActivity` alias (`VIEW_PERMISSION_USAGE` / `HEALTH_PERMISSIONS`), both routed by `MainActivity.getInitialRoute()` to the in-app `/health-privacy` screen; `<queries>` for `com.google.android.apps.healthdata`, the Health Connect rationale action and `TTS_SERVICE`. `MainActivity` extends `FlutterFragmentActivity` (Health Connect permission contract). The accelerometer needs no permission. Play Console: complete the Health Connect declaration form before release.
- **iOS (v1.2)**: `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` in `Info.plist`, `Runner/Runner.entitlements` with `com.apple.developer.healthkit` (wired via `CODE_SIGN_ENTITLEMENTS`); enable the HealthKit capability for the App ID. Deployment target stays 15.0.
- **Android** (`AndroidManifest.xml`): INTERNET, RECORD_AUDIO (voice input), fine and coarse location (SOS and nearby hospitals, fail-soft), CAMERA (reports and wounds), and package-visibility queries for speech, `tel:` and `https`. Cleartext HTTP is allowed only for `10.0.2.2` and `localhost` (`res/xml/network_security_config.xml`).
- **Android** also declares `POST_NOTIFICATIONS` (requested only when push is configured) and queries for `mailto`/WhatsApp (Help & Support).
- **iOS** (`Info.plist`): microphone, speech recognition, location-when-in-use, camera and photo-library usage strings (each says exactly when and why it is used), `LSApplicationQueriesSchemes` for `tel`, `https`, `mailto`, `whatsapp` and Jitsi Meet, `UIBackgroundModes: remote-notification`, and `NSAllowsLocalNetworking`.

## Known gaps
- Push requires the Firebase defines above; web push is not enabled (needs a VAPID key and service worker).
- The App Store URL on the force-update screen is a search link until the app is listed (`lib/features/misc/force_update_screen.dart`).
- PDFs open in-app on Android/iOS; on web they open in a new browser tab (PDF.js is deliberately not loaded from a CDN).
- Fall detection runs only while the app is open (by design); wearable sync also runs only in the foreground (no background fetch).
- Health Connect limits reads to 30 days before the grant; the first sync reads 7 days. Re-syncs resend today's step/sleep totals, so the server should upsert daily totals.
- The emergency template in a care-team thread is recognised as a `system` message that mentions 108 (the contract has no explicit flag).
- iOS HealthKit and the entitlement edit could not be verified on this Windows machine (no Xcode build).
- The doctor "favourite" heart is local only, because the contract has no favourites endpoint.
- v1.3: the contract has no list endpoint for paired SOS buttons, so paired buttons are remembered on the device. It also has no read-back of one day's diet logs, so today's choices are cached locally. The "Imported via ABDM" badge needs source `imported` and "ABDM" in the title (§59 discharge PDFs also use `imported`). Weekly program reports are found by "weekly" in the record title. Companion mode runs only while the app is open.
