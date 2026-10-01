# CareCompanion Doctor (Flutter)

The mobile app for doctors: the daily queue, consultations (snapshot, notes, AI scribe, e-prescriptions with interaction checks, care plans, referrals, care programs, exercise/diet plans, video), patient records, care-team messaging, second opinions, escalations, schedule and leaves, earnings and profile.

- Android application id / iOS bundle id: `com.carecompanion.doctor`. Display name: "CareCompanion Doctor".
- Android minSdk 24, iOS deployment target 15.0. Platforms: Android, iOS and web (web is for development/demo).
- API: `docs/api/API_CONTRACT.md`. The app only calls endpoints listed there (§2, §16, §21, §22, §24, §26, §29, §31, §32, §34, §36, §42, §46, §47, §49, §53, §54).

## Run

```bash
cd apps/doctor_app
flutter pub get
flutter run                        # Android emulator -> http://10.0.2.2:4000/api/v1
flutter run -d chrome              # web -> http://localhost:4000/api/v1
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Start the API first (`services/api`, port 4000, seeded with `npm run seed`).

**Demo login** (dev seed): phone `9800000101` (Dr. Ananya Rao, +91 prefix is added), OTP `123456` (shown as a dev hint). MFA is not enforced in dev (`MFA_ENFORCED=false`); in production the first data call returns `403 MFA_REQUIRED` and the app shows two-step verification.

## Dart defines

| Define | Purpose |
|---|---|
| `API_BASE_URL` | API base, e.g. `https://api.carecompanion.in/api/v1` |
| `ALLOW_SERVER_OVERRIDE` | Demo only: `true` enables the runtime "Server address" setting even when `API_BASE_URL` is https. Never set it for store builds. |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_IOS_BUNDLE_ID` | Push (FCM). Push initialises **only** when the first four are set; otherwise it is a silent no-op. No google-services files are needed. |
| `APP_STORE_URL` | iOS store link for the force-update screen (Android uses the Play listing of the application id). |

## Testing on a real phone: server address

The backend URL is compiled in (`API_BASE_URL`), but non-production builds also have a runtime **Server address** setting, so a tester can point the app at any backend without rebuilding:

- **Login screen:** a small "Server: <host>" chip at the bottom. If sending the OTP fails because the server can't be reached, the screen says "Can't reach the server at <host>" with a **Change server** button.
- **More → Server address** for signed-in users. Changing it signs you out first, because tokens belong to a server.

The dialog accepts `http(s)://host[:port]` (`/api/v1` is appended when missing), a bare IP such as `10.10.17.134` (becomes `http://10.10.17.134:4000/api/v1`) or an https tunnel link such as `https://xyz.trycloudflare.com`. **Test connection** calls `GET <url>/health` and shows the server version, or explains what to check. **Save** applies the address immediately, with no restart. **Reset to default** returns to the compiled URL. The value is stored in shared preferences under the global key `server.baseUrl.override`, so in the all-in-one build the three roles share one setting.

The setting exists only when the compiled `API_BASE_URL` is not https, or when the build passes `--dart-define=ALLOW_SERVER_OVERRIDE=true`. An https production build can't set or use an override (unit-tested in `test/server_settings_test.dart`). The code is in `lib/core/server/`.

Release builds allow cleartext HTTP only to `10.0.2.2`, `localhost` and `127.0.0.1`. For a LAN IP entered at runtime, build with the Gradle property `demoCleartext=true` (`flutter build apk -P demoCleartext=true`, or `ORG_GRADLE_PROJECT_demoCleartext=true` for plain Gradle). It selects `network_security_config_demo.xml` through a manifest placeholder. `scripts/build-android-release.ps1 -Demo` does all of this; see `docs/MOBILE_RELEASE.md`. https tunnel links work in every build that allows the override.

## Architecture

Same conventions as `apps/provider_app` / `apps/patient_app` (patterns copied, no cross-app imports):

- `lib/core/api/api_client.dart`: bearer auth, `X-Correlation-Id` per request, `Accept-Language`, optional `Idempotency-Key` (create actions reuse one key per user action via `IdempotentAction`), single-flight refresh-on-401 with token rotation, typed `ApiException`, and `onMfaRequired` for `403 MFA_REQUIRED`.
- Riverpod providers (`lib/core/providers.dart`), go_router with a `StatefulShellRoute` (Today, Patients, Messages, More) and auth gates (`/login`, `/mfa`, `/restricted`, `/startup-error`, `/update`).
- Tokens and the cached identity live in `flutter_secure_storage`; language and public config in shared preferences.
- `features/auth/mfa_controller.dart`: the TOTP state machine (enrol -> recovery codes -> done; verify; recovery-code fallback; wrong-code attempts and rate-limit lockout). Enrolment shows the setup key and an "Open authenticator app" button (`otpauth://` link) instead of a QR code.
- Force update: `GET /config/public` `minAppVersion.doctorAndroid` / `doctorIos` (see "Contract notes").
- l10n: English, Hindi and Telugu. Strings live in `tool/gen_arb.py`; run `python tool/gen_arb.py` then `flutter pub get` (or `flutter gen-l10n`). Clinical terms in hi/te are marked `GLOSSARY-REVIEW` in the ARB files.
- AI content (snapshot summary, scribe draft, record summaries) is always in the lavender "AI-generated · advisory" card; the scribe draft is only inserted into the notes on an explicit tap and is never saved automatically.

## Tests and checks

```bash
flutter analyze
flutter test          # MFA, API client, app gates, queue, prescription gating, scribe consent, schedule, messaging, snapshot
flutter build web
flutter build apk --release
```

With several concurrent Gradle builds on a low-RAM machine, run `./gradlew --stop` in `android/` and retry if the build runs out of memory.

## Release

### Android
Signing reads `android/key.properties` (never committed):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/doctor-upload.jks
```

Without it, the release build is signed with the **debug key** (a Gradle warning is printed); such builds cannot go to Play. Release builds use R8 (`proguard-rules.pro`) with resource shrinking. `network_security_config.xml` allows cleartext only for `10.0.2.2`, `localhost` and `127.0.0.1`.

CI: `.github/workflows/mobile-release.yml` builds the signed AAB with prefix `DOCTOR` (`DOCTOR_ANDROID_KEYSTORE_BASE64`, `DOCTOR_ANDROID_KEYSTORE_PASSWORD`, `DOCTOR_ANDROID_KEY_ALIAS`, `DOCTOR_ANDROID_KEY_PASSWORD`, optional `DOCTOR_DART_DEFINES`), package `com.carecompanion.doctor`.

### iOS
`.github/workflows/ios-build.yml` builds unsigned device and simulator apps. For TestFlight, create the App ID `com.carecompanion.doctor` and add `IOS_PROVISIONING_PROFILE_DOCTOR_BASE64` (see `mobile-release.yml`). Info.plist declares microphone (AI scribe), camera and photo-library (profile photo) usage and `ITSAppUsesNonExemptEncryption=false`.

### Icons and splash
Placeholder brand in `docs/design/brand/doctor/` (`python generate_icon.py`, needs Pillow). Copy the PNGs to `assets/branding/` and run `dart run flutter_launcher_icons && dart run flutter_native_splash:create`. The notification glyphs are copied to `android/app/src/main/res/drawable-*/ic_stat_notify.png`.

## Contract notes / known gaps

- `PublicConfig.minAppVersion` (§21) lists only patient/provider keys; the app reads `doctorAndroid`/`doctorIos` if the server adds them, otherwise it is never force-updated.
- Whether a doctor may call `GET /care-episodes?patientId=` is not stated; the Episodes tab falls back to the snapshot's active episodes on error.
- The scribe (§46) audio part is uploaded as `audio/mp4` (`.m4a`) on mobile and `audio/webm` on web.
- PDFs render in-app with pdfx on Android/iOS; on web they open in the browser's viewer.
- Messaging attachments (`attachmentRecordId`) are not yet displayed or sent.
