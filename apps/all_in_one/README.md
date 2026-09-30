# CareCompanion All-in-One (demo build)

**A demo convenience build.** One Android app that contains all three CareCompanion mobile apps behind a role chooser, so a demo needs one install instead of three. **The Play Store uses the separate apps** (`apps/patient_app`, `apps/provider_app`, `apps/doctor_app`); never upload this one.

- Android application id `com.carecompanion.allinone`, display name "CareCompanion All-in-One", minSdk 26 (the highest of the three apps, needed by Health Connect).
- Android is the supported target. The `ios/` and `web/` folders come from `flutter create` and are not polished.

## How it works

On launch a **role chooser** shows three cards:

| Card | Opens |
|---|---|
| I'm a patient / family member | CareCompanion (`apps/patient_app`) |
| I'm a home-care nurse / technician | CareCompanion Pro (`apps/provider_app`) |
| I'm a doctor | CareCompanion Doctor (`apps/doctor_app`) |

- **Remember my choice** (toggle): the chosen app then opens directly on the next launch.
- The chosen app runs **exactly as its standalone build**: it is built by that app's public bootstrap (`buildPatientApp`, `buildProviderApp`, `buildDoctorApp` in each app's `lib/bootstrap.dart`), with its own MaterialApp, router, theme, l10n, API client, push and force-update logic.
- **Switch app** appears in the patient app's Profile, the Pro app's Profile and the Doctor app's More screen (only in this build). It goes back to the chooser and clears the remembered choice. Each app keeps its session, so switching back does not require a new login.
- **Storage isolation:** each app gets a storage prefix (`patient.`, `provider.`, `doctor.`) that is applied to every flutter_secure_storage key (tokens, cached identity, the offline queue, visit and supplies caches), every shared_preferences key (language, theme, public-config cache, feature caches) and the provider app's private photo directory (`provider.visit_photos`). The three apps never read or overwrite each other's data. The standalone apps use an empty prefix, so their keys and existing data are unchanged. The chooser's own key is `all_in_one.rememberedRole`.
- **Shared init:** Firebase is initialised once, in `lib/shared_init.dart`, and only when all four `FIREBASE_*` dart-defines are present. The apps' push services then skip their own `initializeApp`.
- A Health Connect "permission rationale" or "permission usage" launch opens the patient app on its health privacy screen.

## Build

```bash
cd apps/all_in_one
flutter pub get
flutter analyze && flutter test

# Emulator against a backend on this PC
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
# -> build/app/outputs/flutter-apk/app-release.apk
```

`API_BASE_URL` (and the optional `FIREBASE_*` values) are passed through unchanged to all three apps, which read them as usual. Without `API_BASE_URL` the defaults are `http://10.0.2.2:4000/api/v1` on Android and `http://localhost:4000/api/v1` elsewhere.

Or use the release script from the repo root. It builds the APK only (no AAB) into `dist/android/<version>/all_in_one-<version>.apk`, or `dist/phone/...` for a LAN IP, for which it adds that IP to the network security config for the duration of the build:

```powershell
./scripts/build-android-release.ps1 -ApiUrl http://10.0.2.2:4000/api/v1 -Apps all_in_one
./scripts/build-android-release.ps1 -ApiUrl http://192.168.1.20:4000/api/v1 -Apps everything   # 3 store apps + this one
```

`START-CARECOMPANION.bat` / `scripts/start-local.ps1` install this APK on the emulator as well, when it has been built.

**Signing:** `android/key.properties` (same format as the other apps, never committed). Without it, the release build is signed with the debug key and Gradle prints a warning. That is fine for a demo APK, and the release script allows it for this app only. Release builds use R8 with the union of the three apps' keep rules (`android/app/proguard-rules.pro`). Cleartext HTTP is allowed only for `10.0.2.2`, `localhost` and `127.0.0.1` (`android/app/src/main/res/xml/network_security_config.xml`).

**Icon and splash:** generated from the three app icons by `docs/design/brand/all_in_one/generate_icon.py` (needs Pillow). The script also exports the chooser's role icons to `assets/roles/`. To regenerate the icon and splash, run `python generate_icon.py` in that folder, then `dart run flutter_launcher_icons && dart run flutter_native_splash:create` here.

## Demo logins (dev seed, OTP `123456`)

| App | Phone (enter the 10 digits) |
|---|---|
| Patient (CareCompanion) | `9800000001` (Vaibhav, manages his father Ramesh) |
| Nurse (CareCompanion Pro) | `9800000201` (Sunita Devi, verified nurse) |
| Doctor (CareCompanion Doctor) | `9800000101` (Dr. Ananya Rao) |

Start the backend first (`services/api`: `npm run seed && npm run dev`, port 4000), or double-click `START-CARECOMPANION.bat`.

## Tests

- `test/chooser_test.dart`:
  - The chooser shows the three roles.
  - A choice opens the app with its storage prefix.
  - "Remember my choice" is persisted, and the app then opens directly.
  - "Switch app" returns to the chooser, clears the choice and re-launches a fresh app instance.
- `test/storage_isolation_test.dart`:
  - The two prefix primitives don't collide: the namespaced SharedPreferences and the prefixed secure store (the provider and doctor apps use identical key names).
  - All three apps' real providers, signed in at the same time, write only to their own namespaced keys.
  - A logout in one app leaves the others signed in.
  - The empty (standalone) prefix keeps the original keys.

## Known limitations

- It is one process and one FCM token. When push is configured, all three apps register the same device token for their own users, and logging out of one app unregisters it. Background notifications without a channel use the patient app's `cc_general` channel.
- The force-update check uses this build's version (`pubspec.yaml`), and the update screen links to the store listing of `com.carecompanion.allinone`, which doesn't exist.
- The "Switch app" label is English only. The rest of each app is localised as usual.
- `cached_network_image`'s disk cache is shared. It is keyed by URL and holds no tokens or preferences.
- Android runtime permissions are granted to the whole app. If you grant the camera in one role, the other roles have it too.
