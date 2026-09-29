# Mobile release: Android and iOS

All three apps are Flutter, so each codebase produces both the Android and the iOS app:

| App | Android package / iOS bundle ID | Store name |
|---|---|---|
| Patient & family | `com.carecompanion.patient` | CareCompanion |
| Home-care provider | `com.carecompanion.provider` | CareCompanion Pro |
| Doctor | `com.carecompanion.doctor` | CareCompanion Doctor |

Status (2026-09-29): signed Android release builds and unsigned iOS release builds for both apps compile and pass. The Android release APKs were tested on an Android 15 emulator against a local backend. Store submission still needs the accounts and URLs in `docs/GO_LIVE_CREDENTIALS.md`.

## Android (builds on this Windows PC)

### Signing keys
Each app has its own **upload key**, created 2026-09-29 and stored **outside the repository** in:

```
C:\Users\USER\Desktop\ravindra\hos\signing\
  patient-upload.jks    patient-key.properties
  provider-upload.jks   provider-key.properties
  doctor-upload.jks     doctor-key.properties     (passwords are in the .properties files)
```
`apps/<app>/android/key.properties` points to these files and is git-ignored.

> **Back these six files up now** to at least two places you control, for example an encrypted USB drive and a password manager. If the upload key is lost you must ask Google to reset it, and until then you cannot publish updates. Never commit them or share them in chat or email.

When you enrol in **Play App Signing** (recommended; the default for new apps), Google keeps the final app-signing key, and this file is only the upload key.

### Build
```powershell
# Store build (production HTTPS backend):
./scripts/build-android-release.ps1 -ApiUrl https://api.yourdomain.in/api/v1 `
  -DartDefines "FIREBASE_PROJECT_ID=...","FIREBASE_APP_ID=...","FIREBASE_API_KEY=...","FIREBASE_MESSAGING_SENDER_ID=..."

# Test build for the Android emulator against the backend on this PC:
./scripts/build-android-release.ps1 -ApiUrl http://10.0.2.2:4000/api/v1
```
The output goes to `dist/android/<version>/`: `<app>-<version>.aab` (upload this to Play) and `<app>-<version>.apk` (install directly with `adb install`). The script refuses to finish if anything is debug-signed.

> The files in `dist/android/1.0.0+1/` were built against the **local test backend** (`10.0.2.2`). They are fine for emulator testing but **must not be uploaded to Play**. Rebuild with your production URL.

Before each new store upload, raise `version:` in each app's `pubspec.yaml` (e.g. `1.0.1+2`; the number after `+` must increase every upload).

### CI alternative
`.github/workflows/mobile-release.yml` builds signed AABs on GitHub and can upload them to the Play **internal testing** track. It needs these repository secrets and variables:
- `PATIENT_ANDROID_KEYSTORE_BASE64` / `PROVIDER_…` / `DOCTOR_…`: produce with `[Convert]::ToBase64String([IO.File]::ReadAllBytes("patient-upload.jks"))`
- `…_KEYSTORE_PASSWORD`, `…_KEY_ALIAS` (`upload`), `…_KEY_PASSWORD`
- the variable `MOBILE_API_BASE_URL`
- optionally `PLAY_SERVICE_ACCOUNT_JSON`

## iOS (builds on GitHub's Macs)

iOS apps can only be compiled on macOS with Xcode. This PC runs Windows, so iOS builds run on GitHub Actions Mac runners (macOS 26 / Xcode 26; the current plugins use iOS 26 SDK APIs).

### Unsigned builds: work today, no Apple account needed
`.github/workflows/ios-build.yml` runs on every push that touches `apps/` (or manually from **Actions → iOS build → Run workflow**) and produces, per app:
- `<app>-ios-device-unsigned.zip`: the compiled iPhone app. This proves the release build is valid, but it can't be installed until it is signed.
- `<app>-ios-simulator.zip`: unzip on any Mac and drag `Runner.app` onto a running iOS Simulator to try the app. It talks to `http://localhost:4000/api/v1`, so run the backend on that Mac.

Download them from the workflow run page (**Artifacts**), or with `gh run download <run-id> -R ravindrabhaskar/hospital_app -D dist/ios`.

### Signed builds for TestFlight and the App Store: need an Apple Developer account
1. Enrol in the Apple Developer Program as an **organisation** (needs a D-U-N-S number; US$99/yr).
2. In the developer portal create the App IDs `com.carecompanion.patient`, `com.carecompanion.provider` and `com.carecompanion.doctor`. Enable the **Push Notifications** and **HealthKit** capabilities (HealthKit for the patient app only).
3. Create an **Apple Distribution** certificate (.p12) and an **App Store provisioning profile** per app.
4. Create an **App Store Connect API key** (.p8) for uploads.
5. Add `apps/<app>/ios/ExportOptions.plist` (method `app-store-connect`, your team ID, the profile names).
6. Add the repository secrets listed at the top of `mobile-release.yml` (`IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISIONING_PROFILE_PATIENT_BASE64`, `…_PROVIDER_BASE64`, `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_PRIVATE_KEY`), set the variable `IOS_RELEASE_ENABLED=true`, then run **Actions → Mobile release**. It builds the signed `.ipa` and uploads it to **TestFlight**.

## Both platforms: before the first store submission
- A production backend URL (HTTPS) and a Firebase project (push) for the build defines
- Store listings, screenshots, privacy answers and reviewer login: `docs/STORE_SUBMISSION.md`
- Final app icon: replace the files in `docs/design/brand/` and rerun `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` in each app
- Clinical and legal sign-offs: `docs/GO_LIVE_CREDENTIALS.md` §5
