# CareCompanion Pro (provider app)

Store name **CareCompanion Pro**, Android application id / iOS bundle id `com.carecompanion.provider`.

Flutter app for home-care field providers (nurses, technicians, interns, physiotherapists, dietitians). It covers login, verification gating, duty status, assigned home visits and the guided visit lifecycle: accept, travel, arrive, verify patient, checkup, escalate and complete. It works offline and syncs with idempotency. v1.2 adds the apply-to-join onboarding flow, earnings, the profile photo and voice-to-note. v1.3 adds today's route, attendance, supplies, lab sample-collection visits, exercise plans (physiotherapists) and diet plans (dietitians).

API: `docs/api/API_CONTRACT.md` §2 (auth), §8 (home visits), §9 (records, for visit photos), §12/§24 (devices/push), §17 (provider app), §21–§23 (public config, MFA, account) and the v1.2 additions §29 (`/me/photo`), §30 (onboarding applications) and §32 (earnings), and the v1.3 additions §44 (sample-collection visits), §48 (route, attendance, supplies), §53 (exercise plans) and §54 (diet plans). Models are hand-written; no codegen is used.

## Run

```bash
cd apps/provider_app
flutter pub get

# Android emulator (default API: http://10.0.2.2:4000/api/v1)
flutter run

# Web / iOS simulator / desktop browser (default API: http://localhost:4000/api/v1)
flutter run -d chrome

# Custom API
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Start the backend first (`services/api`: `npm run seed && npm run dev`, port 4000).

## Demo logins (dev seed, OTP `123456`)

| Phone | Flow |
|---|---|
| `+919800000201` (enter `9800000201`) | Sunita Devi, verified nurse, sees the full app |
| `+919800000203` (enter `9800000203`) | Anil, intern with an **expired credential**, sees the blocking verification screen |
| `+919800000001` | Patient account (no `provider` role), sees the **apply to join** flow (§30) |

In dev the API returns `devOtp`, and the login screen shows it as a hint.

## Testing on a real phone: server address

The backend URL is compiled in (`API_BASE_URL`), but non-production builds also have a runtime **Server address** setting, so a tester can point the app at any backend without rebuilding:

- **Login screen:** a small "Server: <host>" chip at the bottom. If sending the OTP fails because the server can't be reached, the screen says "Can't reach the server at <host>" with a **Change server** button.
- **Profile → Server address** for signed-in users. Changing it signs you out first, because tokens belong to a server.

The dialog accepts `http(s)://host[:port]` (`/api/v1` is appended when missing), a bare IP such as `10.10.17.134` (becomes `http://10.10.17.134:4000/api/v1`) or an https tunnel link such as `https://xyz.trycloudflare.com`. **Test connection** calls `GET <url>/health` and shows the server version, or explains what to check. **Save** applies the address immediately, with no restart. **Reset to default** returns to the compiled URL. The value is stored in shared preferences under the global key `server.baseUrl.override`, so in the all-in-one build the three roles share one setting.

The setting exists only when the compiled `API_BASE_URL` is not https, or when the build passes `--dart-define=ALLOW_SERVER_OVERRIDE=true`. An https production build can't set or use an override (unit-tested in `test/server_settings_test.dart`). The code is in `lib/core/server/`.

Release builds allow cleartext HTTP only to `10.0.2.2`, `localhost` and `127.0.0.1`. For a LAN IP entered at runtime, build with the Gradle property `demoCleartext=true` (`flutter build apk -P demoCleartext=true`, or `ORG_GRADLE_PROJECT_demoCleartext=true` for plain Gradle). It selects `network_security_config_demo.xml` through a manifest placeholder. `scripts/build-android-release.ps1 -Demo` does all of this; see `docs/MOBILE_RELEASE.md`. https tunnel links work in every build that allows the override.

## Quality gates

```bash
flutter analyze        # clean
flutter test           # unit + widget tests
flutter build web      # compiles for web
flutter build apk --release
```

Tests (`test/`):
- `offline_queue_test.dart`:
  - Enqueue offline, then replay exactly once with the same Idempotency-Key.
  - A lost response replays with the same key, and the server executes it once.
  - The queue persists across restarts, and replay is FIFO.
  - A retryable failure stops the flush.
  - A 409 drops the action.
  - A **403 during replay drops that visit's items, purges its cached data and notifies the user.**
  - Cached visits are retained for 24h.
- `vitals_validation_test.dart`: numeric/range validation, the BP pair and order checks, the request body shape and the form widget.
- `lifecycle_test.dart`: the next action for every status, the optimistic transitions, and the panel's buttons for each status. Also covers the code and consent gate, ETA, stepper semantics and allergy highlighting.
- `verification_gate_test.dart`:
  - The role and verification gating (restricted, blocked or ready).
  - The blocked screen for expired, pending and suspended accounts, plus a Hindi render.
  - The 30-day credential warning.
- `release_readiness_test.dart`:
  - Force update: numeric version comparison; an outdated build is blocked by the update screen; a current build is not gated.
  - Profile shows support contacts, privacy/terms links and "Request account closure" (support only; staff can't self-delete).
  - `MFA_REQUIRED` shows a clear explanation screen.
  - Visit photo: queued offline, restored after restart, replayed **once** as multipart `POST /records` with the same Idempotency-Key, and the local file is then deleted. A lost response replays with the same key. If the file is gone at replay, the item is dropped with a notice. A 403 drops only the photo (the visit and its other queued actions are kept).
  - The photo consent dialog blocks the camera until consent is ticked.
  - Push: initialisation is skipped silently when the Firebase dart-defines are missing (no `/devices` calls); deep-link parsing.
- `app_smoke_test.dart`: the full app with a mocked HTTP client:
  - Home, visit detail, then accept, with the `Idempotency-Key` header sent.
  - The address stays masked until the visit is accepted.
  - Profile shows the expiry warning.
  - The expired-credential provider is blocked.
  - An account without the `provider` role lands on the application form; Profile links to Earnings.
- `onboarding_test.dart` (§30, mock API):
  - Routing rule: 404 → form; `submitted`/`rejected` → status; `changes_requested` → status, then "Edit & resubmit" → prefilled form (PATCH); `approved` → identity refresh exactly once (and `AuthController` leaves the gate once `/me` has the role).
  - The whole multi-step form (validation, languages, pincode → zone, request body).
  - Documents: upload (multipart, progress), required-docs hint, delete, failed upload with retry, the 10 MB limit.
  - Reviewer note, rejected/approved/doctor screens, Telugu rendering.
- `field_ops_test.dart` (§48):
  - The Maps URL builder: waypoints in visiting order, the last stop as destination, the origin from `startLocation`, an address fallback, and the cap at 10 stops.
  - The route list renders ordered stops, distances, ETAs and total km. The route view fetches today's date, and pull-to-refresh refetches it.
  - Attendance state per day. Load, then check-in and check-out with and without location. A failed check-in. The Home card. The monthly totals view.
  - Supplies: low-stock ordering and highlighting, and the offline cache.
  - Usage is **queued offline and replayed once with the same Idempotency-Key**. A lost response is replayed with the same key. A 403 drops only the usage item.
- `care_plans_test.dart`:
  - Sample-collection checklist gating: Complete stays disabled until every item is ticked and the sample count is ≥ 1; the summary is prefilled. Other services have no checklist. The lab-tests card shows the ordered tests with fasting, or the generic instruction.
  - Exercise-plan and diet-plan validation (unit tests and form tests, including the POST bodies).
  - Type-based visibility, tested in the full app: a nurse sees no plan actions; a physiotherapist sees plan progress and "Create exercise plan"; a dietitian sees only "Create diet plan".
- `earnings_voice_test.dart`:
  - Earnings tiles and lines (₹ formatting), empty month, month range, the month selector and pull-to-refresh.
  - Voice-to-note: dictated text is **appended** for review and never submitted automatically; the mic toggles off; locale selection (en-IN / hi-IN / te-IN, then same-language, then device default); an unavailable recognizer shows a message.

## Architecture

```
lib/
  core/            config, theme (design tokens), ApiClient (bearer + refresh-on-401),
                   encrypted KeyValueStore, connectivity, location reporter, Riverpod wiring
  models/          HomeVisit, ProviderProfile, Me (hand-written JSON)
  features/
    auth/          OTP login, AuthController (restricted / blocked / ready gates)
    visits/        repository, domain (lifecycle state machine, vitals validation), UI
    offline/       OfflineQueue, VisitCache, VisitActionService
    profile/       profile, credential warning, language, logout, profile photo
    onboarding/    apply-to-join: ApplicationController (routing), form, documents
    earnings/      monthly earnings (§32)
  l10n/            app_en.arb / app_hi.arb / app_te.arb (generated into l10n/gen)
```

### Apply to join (§30)
- A signed-in account without the `provider` role (`AuthStatus.restricted`) no longer sees "Access restricted": `/restricted` shows the onboarding flow, and `GET /provider-applications/me` decides the screen (`applicationPhaseFor`):
  - **404** → a 4-step form: role (nurse, technician, intern, physiotherapist or doctor; doctors are told they use the web portal after approval, and must pick a specialty from `GET /specialties`), qualification and registration, languages and preferred areas, review. Submit → `POST /provider-applications`.
  - **submitted** → status screen with the documents card and "Edit details".
  - **changes_requested** → the reviewer's note (`decisionNote`, `decidedByName`) and **Edit & resubmit**, which opens the prefilled form and sends `PATCH /provider-applications/me`.
  - **rejected** → the note and support contacts; nothing is editable.
  - **approved** → `/me` is re-read automatically. If the role is there, the router moves to the verification gate or home; otherwise the screen says "Sign out and sign in again" (doctors: use the web portal).
- **Documents** can be added only once the application exists (the upload endpoint needs it), so the review step says so and the status screen shows "Still needed: registration certificate, ID proof" until both are uploaded (approval requires them). Camera, gallery (`image_picker`) or a PDF/JPG/PNG file (`file_picker`); ≤ 10 MB checked on the device; multipart `file` + `docType` with a progress bar; failed uploads stay in the list with retry; delete asks for confirmation.
- **Preferred zones**: there is no public zone list (only `/admin/service-zones`), so the provider types pincodes and each one is resolved with `POST /home-visit/serviceability` into `{zoneId, zoneName}`; `preferredZoneIds` holds those ids. Unserviceable pincodes are explained and not added. When editing, previously saved zones show as "Saved area" (the application stores ids only).

### Today's route (§48)
Home has a fourth tab, **Route**. It calls `GET /provider/route?date=<today>` and shows a list without a map:
- ordered stops, each with a numbered marker, the service, the time window, the address, the km from the previous stop (or from the start), and the ETA;
- a summary: the number of stops and total km;
- pull to refresh. Tapping a stop opens the visit.

**Start navigation** opens a Google Maps URL, `https://www.google.com/maps/dir/?api=1&origin=&destination=&waypoints=a|b&travelmode=driving`, which needs no API key:
- The waypoints are in visiting order, and the last stop is the destination.
- The origin is `startLocation` if the server sends one; otherwise Maps uses the device location.
- Each stop uses its coordinates if it has them, otherwise its address text.
- Maps URLs allow 9 waypoints, so the URL covers only the first 10 stops, and the screen says so.

### Attendance (§48)
A Home card shows today's state: not checked in, checked in at …, or checked out at …. Its **Check in** / **Check out** button calls `POST /provider/attendance`. It adds `lat`/`lng` only when a one-shot, foreground location read succeeds; a missing fix never blocks attendance, and the snackbar says the location was unavailable. The state comes from today's row of `GET /provider/attendance?month=YYYY-MM` and is updated from the POST response. **Attendance** (`/attendance`) has a month selector, totals (days present, hours, visits) and a row per day (in – out, hours, visits).

### Supplies (§48)
**Supplies** (`/supplies`, linked from the attendance card) lists on-hand stock with low-stock items first. Items at or below `reorderLevel` are amber with "Low stock", items at 0 are red with "Out of stock", and a banner counts them. The last list is cached in the encrypted store (wiped on logout), so usage can be recorded offline. During `in_progress`/`escalated`, the visit shows **Record supplies used**. A quantity sheet then queues `POST /provider/supplies/usage {visitId, items:[{code, qty}]}` (zero quantities are left out) as the `suppliesUsage` visit action. It goes through the same encrypted FIFO queue, with one Idempotency-Key for its whole life. It is not visit-scoped: a 403/404 drops only that item.

### Lab sample-collection visits (§44)
For `serviceCode == sample_collection`:
- **Lab tests card.** The visit shows the ordered tests and a fasting banner (with hours) when the visit carries them in `labTests`, `tests` or `labOrder.tests`. §8 `HomeVisit` has no such field, so otherwise the card says "Collect samples as per the lab order".
- **Checklist.** The in-progress step adds a checklist: patient ID verified, fasting status confirmed, all tubes labelled, number of samples (≥ 1), and a final **Samples collected** confirmation. **Complete visit** stays disabled until every item is confirmed.
- **Summary.** The completion summary is prefilled ("3 samples collected. Tubes labelled, …") and stays editable.

### Physiotherapists: exercise plans (§53)
If `/provider/me.type == physiotherapist`, the visit (in progress, escalated or completed) shows an **Exercise plan** card:
- The patient's plans come from `GET /exercise-plans?patientId=`. For each plan, `GET /exercise-plans/:id/progress` gives sessions done/planned, adherence and the latest pain score. If the API refuses, the card says progress isn't available.
- **Create exercise plan** first loads `/exercise-library`, with body-area chips that re-query `?bodyArea=`.
- For each exercise you pick, you set sets (1–10), reps (1–50), an optional hold (0–300 s), times per day (1–6) and notes. The plan also has a start date (today or later) and a number of weeks (1–26).
- Saving sends `POST /exercise-plans` with an Idempotency-Key per form. It works online only.

### Dietitians: diet plans (§54)
If `type == dietitian`, the visit shows **Create diet plan**, which opens a form with these parts:
- a template picker from `/diet-templates` that adds the template's conditions; unapproved fixtures show "[REQUIRES CLINICAL GOVERNANCE]";
- condition chips (at least 1);
- an optional calorie target (800–4000);
- the meal items for each of the 7 slots, comma separated (at least one slot);
- an avoid list, notes, and a "valid until" date (after today).

Saving sends `POST /diet-plans`, online only. The dietitian role is also a type option in apply-to-join (§30).

### Earnings (§32)
Profile → **Earnings** (also the wallet icon on Home) → `/earnings`: a month selector (next is disabled on the current month), tiles (payable, completed services, gross, platform fee, refunds) and the per-service lines; pull to refresh. It calls `GET /provider/earnings?from=YYYY-MM-01&to=<last day of month>`.

### Profile photo (§29)
Tap the avatar on Profile → camera or gallery (downscaled) → preview → `POST /me/photo` (multipart `image`, ≤ 5 MB checked on the device). The returned `photoUrl` is kept in the encrypted store (wiped on logout) and shown on Profile and in the Home app bar, because `/provider/me` has no photo field in the contract. If the server does send `photoUrl`, `rating` or `ratingCount` on `/provider/me`, they are used (rating shows under the name); otherwise they stay hidden.

### Voice-to-note (spec §7)
The observations notes field has a mic button (`speech_to_text`). Final phrases are **appended** to the notes, and a "review and correct before saving" hint appears; saving always needs the explicit **Save observations** tap. The recognizer locale follows the app language (`en_IN` / `hi_IN` / `te_IN`), then any locale of that language, then the device default. Android declares `RECORD_AUDIO` and queries `RecognitionService`; iOS has microphone and speech-recognition usage strings.

### Offline and sync
- Every visit action (accept/reject/en-route/arrived/verify/vitals/observations/escalate/complete) goes through `VisitActionService`. The service does three things:
  1. It creates a `QueuedAction` with a UUID that serves as the **Idempotency-Key** for its whole life.
  2. It applies the action optimistically to the local cache, so the stepper keeps moving offline.
  3. If the device is online, it flushes the queue immediately.
- The queue is JSON in `flutter_secure_storage` (Keystore/Keychain), so it is encrypted at rest. Replay is strictly FIFO and never runs two flushes at once.
- Replay starts when connectivity returns, every 30 s while items are pending, or from the "Sync now" action on the **Pending sync (n)** banner.
- 403/404 on replay means the visit was reassigned or access was revoked. All queued items for that visit are dropped, its cached patient data is purged, and the user is told.
- Other 4xx responses drop the item and show the server message. Network errors, 401, 429 and 5xx keep the item for a later retry.
- The encrypted visit cache is wiped on logout and on session expiry. Completed visits are pruned 24h after completion.

### Public config, force update and support (§21)
- `GET /config/public` is loaded at startup and cached in shared preferences (it is public data), so it also applies when offline.
- If the installed version (`package_info_plus`) is below `minAppVersion.providerAndroid` / `providerIos`, a blocking **Update required** screen replaces everything. On Android it links to the Play listing; on iOS it needs `APP_STORE_URL`.
- Profile shows support phone, e-mail and WhatsApp from the config, the privacy and terms links, and the app version.

### Account (§23)
Providers are staff, so they **cannot self-delete** (the API returns 403). Profile → **Request account closure** explains this and opens the support e-mail (prefilled subject) or phone. An admin then disables the account.

### MFA (§22)
Providers are not MFA-enforced. If the API still answers `403 MFA_REQUIRED`, the app shows an "Extra verification required" screen with support contacts. Queued work is **kept**: `MFA_REQUIRED` counts as retryable and is never treated as "visit reassigned".

### Push notifications (FCM)
- `firebase_core`, `firebase_messaging` and `flutter_local_notifications`. They are initialised **only** when all four Firebase dart-defines are present. The `FirebaseOptions` are built by hand, so no `google-services.json`, `GoogleService-Info.plist` or Gradle plugin is needed. Without the defines (dev, web, tests), push is silently skipped.
- After sign-in (and on every FCM token refresh), the app calls `POST /devices {pushToken, platform}`. On logout it calls `DELETE /devices {pushToken}` while the session is still valid.
- Android uses the high-importance channel `visit_assigned` ("New visit assigned"). It is also the manifest's default FCM channel, so background pushes use it. Foreground pushes are shown locally with the monochrome `ic_stat_notify` icon.
- Tapping a notification with `deepLink` `/provider/visits/<id>` or `/home-visits/<id>` opens that visit (after sign-in if needed). Push text is generic; it never contains health details.

### Visit photos (optional, consented)
- During `in_progress`, the **Visit photo (optional)** card offers **Add photo**. A consent dialog with an explicit checkbox must be ticked before the camera opens. It is camera only: `image_picker` downscales to 2048 px at 75% JPEG quality, which keeps photos well under 15 MB.
- The photo is copied into the app-private support directory and queued in the same encrypted FIFO queue as other actions. The queue item holds the file path and metadata (`patientId`, `type=other`, `title="Home visit photo"`, `recordDate`) and one Idempotency-Key for its whole life. It is uploaded as multipart `POST /records`.
- 403 means the provider may not upload records: that photo alone is dropped and the user is told. It never purges the visit. A missing file at replay drops the item with a notice. Files are deleted after upload or drop, and the photo directory is wiped on logout.
- The feature is hidden on web.

### Location: foreground-only (store-review decision)
Location is posted every 60 s **only while the app is running and the provider is on duty**. The Dart timer stops when the OS suspends the app. There is no `ACCESS_BACKGROUND_LOCATION`, no foreground service and no iOS `location` background mode, and iOS asks only for *When In Use*. We chose this because background location triggers Play's prominent-disclosure and declaration review and Apple's "Always" justification review, and live tracking isn't essential to the visit flow (en-route also calls `reportNow()`). If background tracking is ever required, add a foreground service with a persistent notification and complete the Play background-location declaration first.

### Privacy and safety
- `visitCode` is never modelled. The provider asks the patient for the code, and the checkup cannot start until the explicit consent checkbox is ticked.
- The full address appears only after the visit is accepted. Cards show city and pincode only.
- `patientContext` is displayed exactly as the API returns it, with allergies highlighted in red. The app adds no clinical interpretation of vitals: validation only rejects physically implausible values.
- The red **Escalate** button stays pinned at the bottom of the screen during `in_progress`. It opens a two-step flow (reason and severity, then a confirmation) and offers a "Call 108" shortcut for emergencies.
- Location (`POST /provider/location`) is sent every 60 s while the provider is on duty and the app is in the foreground. It fails softly and stops if permission is denied.

## Branding

The icon is a placeholder: a green medical bag with a white cross on white, the inverse of the patient app's green tile. The source and generator are in `docs/design/brand/provider/` (`python generate_icon.py`), with copies in `assets/branding/` (these copies are not bundled as Flutter assets). To regenerate:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Release

### Build-time configuration (`--dart-define`)
| Define | Required | Purpose |
|---|---|---|
| `API_BASE_URL` | yes (prod) | e.g. `https://api.carecompanion.in/api/v1` |
| `ALLOW_SERVER_OVERRIDE` | demo only | `true` enables the runtime "Server address" setting even when `API_BASE_URL` is https. Never set it for store builds. |
| `FIREBASE_API_KEY` | for push | Firebase app API key |
| `FIREBASE_APP_ID` | for push | Firebase app id (the Android id for Android builds, the iOS id for iOS builds) |
| `FIREBASE_MESSAGING_SENDER_ID` | for push | Firebase project number |
| `FIREBASE_PROJECT_ID` | for push | Firebase project id |
| `FIREBASE_IOS_BUNDLE_ID` | optional | defaults to `com.carecompanion.provider` |
| `APP_STORE_URL` | iOS | App Store link for the force-update screen |

The app id differs per platform, so keep one define file per platform, for example `release.android.json`. Do not commit these files.

```bash
flutter build appbundle --release --dart-define-from-file=release.android.json
flutter build ipa --release --dart-define-from-file=release.ios.json
```

### Android signing
1. Create an upload key (once, and keep a backup):
   `keytool -genkey -v -keystore carecompanion-provider-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `android/key.properties` (git-ignored):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=C:/path/to/carecompanion-provider-upload.jks
   ```
3. Run `flutter build appbundle --release`. Without `key.properties` the release build is signed with the **debug key**; Gradle warns about it, and such a build is fine for testing but can't be uploaded to Play.

Release builds use R8 (`isMinifyEnabled` + `isShrinkResources`); keep rules for Flutter, Firebase, local notifications and secure storage are in `android/app/proguard-rules.pro`. Core library desugaring is enabled for `flutter_local_notifications`. Bump `version:` in `pubspec.yaml` for every upload. To force old installs to update, raise `minAppVersion.providerAndroid` / `providerIos` on the server.

### iOS
The bundle id is `com.carecompanion.provider`, display name "CareCompanion Pro" and deployment target 15.0. Info.plist has these usage strings:
- camera (visit photos);
- photo library (declared because `image_picker` links the API; the library is never read);
- location *When In Use* only.

It also sets `UIBackgroundModes = remote-notification` and `ITSAppUsesNonExemptEncryption = false` (HTTPS/Keychain only; confirm this for export compliance). In Xcode, set the Team and enable the **Push Notifications** capability, which adds `aps-environment`.

### What the founder must supply
- **Firebase project**: register an Android app and an iOS app, both `com.carecompanion.provider`. Supply the four `FIREBASE_*` values for each, and upload the **APNs auth key (.p8)** to Firebase → Cloud Messaging. The backend needs `FCM_PROJECT_ID` plus service-account credentials (§24).
- **Android upload keystore** + `android/key.properties`, and Play App Signing enrolment.
- **Apple**: Developer Team, App Store Connect app record, provisioning with Push, and the App Store URL (`APP_STORE_URL`).
- **Production `API_BASE_URL`**, plus the server's public config values: support phone/e-mail/WhatsApp, privacy/terms URLs and `minAppVersion`.
- Final brand icon and splash artwork to replace the placeholder, then re-run the two generators.
- Store listing inputs:
  - the privacy policy URL;
  - the data-safety / privacy-label answers: location while in use, photos and health data uploaded with consent, device push token;
  - a demo provider account for reviewers.
