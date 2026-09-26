# Store submission guide: Google Play and Apple App Store (India, health app)

This guide covers the **patient app** (`apps/patient_app`) and the **provider app** (`apps/provider_app`).
Items marked **[REQUIRES LEGAL REVIEW]** must be approved by counsel before submission. Nothing here is legal advice.

Build and upload automation: `.github/workflows/mobile-release.yml`. Backend endpoints referenced: `docs/api/API_CONTRACT.md` §21 to §24.

---

## 1. Accounts to create (founder)

| Item | Where | Notes |
|---|---|---|
| Legal entity + D-U-N-S number | dnb.com (free, about 1 to 2 weeks) | Both stores need an **organisation** account for health apps. Apple requires D-U-N-S; Google requires it for organisation accounts. |
| Google Play Console (organisation) | play.google.com/console | One-time USD 25. Verify the organisation, the website and a contact phone. New personal accounts must run a 14-day closed test with 12+ testers before production; organisation accounts avoid this. |
| Apple Developer Program (organisation) | developer.apple.com/programs | USD 99/year. Enrol as an organisation with D-U-N-S. Add the App Store Connect roles (Admin, App Manager). |
| Google Cloud service account for Play API | Play Console → Setup → API access | Grants "Release manager" on both apps. Store its JSON as GitHub secret `PLAY_SERVICE_ACCOUNT_JSON`. |
| App Store Connect API key | App Store Connect → Users and Access → Integrations | Role "App Manager". Secrets `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_PRIVATE_KEY`. |
| Firebase project (push) | console.firebase.google.com | Android + iOS apps per package name; APNs auth key uploaded to Firebase. The dart-defines are listed in `mobile-release.yml`. |
| Support site pages | the portal domain | `/privacy`, `/terms`, `/support` and **`/account/delete`** already exist in `apps/web`. They must be live on HTTPS before submission. |
| Support email + phone | – | Shown in both store listings and in `GET /config/public`. |

## 2. Package names and bundle IDs

| App | Android `applicationId` | iOS bundle ID | Display name |
|---|---|---|---|
| Patient | `com.carecompanion.patient` | `com.carecompanion.patient` | CareCompanion |
| Provider | `com.carecompanion.provider` | `com.carecompanion.provider` | CareCompanion Provider |

Package names are **permanent** once uploaded to Play. If you have not settled the brand domain, change them before the first upload (`android/app/build.gradle.kts`, `ios/Runner.xcodeproj`).

## 3. App signing

### 3.1 Android: Play App Signing (recommended, mandatory for new apps)
Google holds the **app signing key**. You keep only an **upload key**. If the upload key is lost, Play support can reset it; the app signing key is never lost.

### 3.2 Generate one upload key per app (run locally, never in CI)
```bash
keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 \
  -keystore carecompanion-patient-upload.jks -alias patient-upload \
  -dname "CN=CareCompanion Patient Upload, O=<Legal entity>, L=Hyderabad, C=IN"

keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 \
  -keystore carecompanion-provider-upload.jks -alias provider-upload \
  -dname "CN=CareCompanion Provider Upload, O=<Legal entity>, L=Hyderabad, C=IN"

# certificate fingerprint (register in Firebase / Play if asked)
keytool -list -v -keystore carecompanion-patient-upload.jks -alias patient-upload
```
Store the `.jks` files and passwords in a password manager, with an offline backup. **Never commit them.**

### 3.3 Put them in GitHub (Settings → Secrets and variables → Actions)
| Secret | Value |
|---|---|
| `PATIENT_ANDROID_KEYSTORE_BASE64` | `base64 -w0 carecompanion-patient-upload.jks` (PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("carecompanion-patient-upload.jks"))`) |
| `PATIENT_ANDROID_KEYSTORE_PASSWORD`, `PATIENT_ANDROID_KEY_ALIAS`, `PATIENT_ANDROID_KEY_PASSWORD` | the keystore values |
| `PROVIDER_ANDROID_*` | the same four for the provider app |

The app Gradle files read `android/key.properties` (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`), which the workflow writes. Without that file Gradle falls back to the debug key. The workflow checks the bundle signature and fails if the bundle is debug-signed.

For the **first** upload of each app: in Play Console, create the app, choose "Use Google-generated key" under App integrity, then upload the first AAB (from the workflow artifact, manually, or through the workflow with `upload_to_play=true` and status `draft`).

### 3.4 iOS
Use automatic signing locally, or in CI an "Apple Distribution" certificate (.p12) plus App Store provisioning profiles (secrets listed in `mobile-release.yml`, job `ios`, which is off until `IOS_RELEASE_ENABLED=true`). Add `ios/ExportOptions.plist` (method `app-store`, your team ID). Enable the capabilities: Push Notifications, and Background Modes → Remote notifications.

## 4. Store listings (drafts)

Tone rules for every listing, screenshot caption and in-app text: **no diagnosis, cure, treatment or accuracy claims**, no "AI doctor", no "detects", no emergency-response promises. Use "helps you organise", "connects you with", "reminds". **[REQUIRES LEGAL REVIEW]** for all copy below.

### 4.1 Patient app

**App name (30):** `CareCompanion: Family Care`

**Short description (80):**
`Organise your family's care: book doctors, home checkups, reminders and records.`

**Full description (draft):**
> CareCompanion helps you and your family organise everyday healthcare in one place.
>
> **Describe a concern, get guided to the right care.** Our AI care assistant asks simple questions about what is going on and helps you choose a next step, such as booking a doctor or a home checkup. It does not diagnose conditions or prescribe medicines. If something sounds urgent, the app shows you how to call emergency services (108) and contact your family.
>
> **Talk to a doctor.** Find verified doctors by specialty and language, see their availability and book video, audio or in-clinic consultations.
>
> **Home checkups (Hyderabad).** Book a certified nurse or technician for vitals checks, sample collection or elderly care visits at home, and track the visit.
>
> **Care plans and reminders.** Follow the plan your doctor creates: medicine reminders, tasks and follow-ups, for yourself or for a parent you care for.
>
> **Health records.** Keep lab reports, prescriptions and scans together, and share them with your doctor when you choose.
>
> **Family access.** Manage care for your parents or children, and give family members view-only or booking access that you can revoke at any time.
>
> **Available in English, हिन्दी and తెలుగు.**
>
> Your data is encrypted in transit and at rest, stored in India, and never sold. You can download your data or delete your account at any time in the app or at <portal>/account/delete.
>
> CareCompanion is not a substitute for professional medical advice. In an emergency, call 108.

**Category:** Play: Medical (choose "Health & Fitness" only if counsel prefers it). Apple: Medical (primary), Health & Fitness (secondary).
**Tags/keywords (Apple, 100 chars):** `doctor,appointment,home checkup,medicine reminder,health records,family care,nurse,hyderabad`
**Contact:** support email, phone, website. **Privacy policy URL:** `https://<portal>/privacy`.

### 4.2 Provider app (home-care nurses, technicians, interns)

The provider app is for **credentialed staff only** (login is refused unless the phone belongs to a verified provider). Do not list it publicly:

- **Google Play:** prefer **Managed Google Play private app** (through an EMM such as Google Workspace endpoint management, or any Android Enterprise EMM) if field staff use managed devices. Otherwise publish to a **closed testing track** with the staff email list (a Google Group). A production listing is still reviewed, so keep a minimal listing ready.
- **Apple:** use **Apple Business Manager Custom App** (private distribution to your organisation) or an **Unlisted App** (link-only). Early on, **TestFlight** (up to 10,000 external testers, 90-day builds) is enough.

**Short description:** `For CareCompanion's verified home-care staff: visits, checklists and vitals capture.`
**Full description:** "CareCompanion Provider is the work app for verified CareCompanion home-care professionals. See assigned home visits, navigate to the patient, follow visit checklists, record vitals and notes (works offline and syncs later), and report incidents. Access requires an account created by CareCompanion operations. It is not for patients."

## 5. Screenshots

Sizes: Play: phone 1080×1920 or larger (2 to 8 per device type); feature graphic 1024×500; icon 512×512. Apple: 6.9" (1320×2868) and 6.5" (1284×2778) iPhone sets are required; iPad only if you ship iPad support (disable iPad in Xcode if you do not).

Use **synthetic seed data only** (Vaibhav/Ramesh personas), never real patients. Map to the reference design `docs/design/all_screens_reference.jpeg`:

| # | Reference screen | Ship? | Caption (no clinical claims) |
|---|---|---|---|
| 1 | Home | yes | "Your family's care, in one place" |
| 2 | AI Assistant | yes | "Describe a concern and get guided to the right care" |
| 3 | Doctor Consultation | yes | "Find verified doctors who speak your language" |
| 4 | Book Appointment | yes | "Book video, audio or clinic visits" |
| 5 | Home Checkup | yes | "Book a nurse visit at home (Hyderabad)" |
| 6 | Order Medicines | only if `pharmacy_orders` is on in production | "Order from partner pharmacies" |
| 7 | Medical Records | yes | "Keep reports and prescriptions together" |
| 8 | Mental Wellness | only if `mental_wellness` is on | "Wellness activities and mood tracking" (not therapy) |
| 9 | Wound Analysis | **no** while `wound_ai_analysis` is off; the screen says a clinician reviews photos, never "AI analysis" | – |
| 10 | Wearable Integration | **no** until real integrations ship (P2) | – |
| 11 | Emergency SOS | yes, with care | "Quickly alert your family and call 108" (never imply dispatch) |
| 12 | Profile & Family | yes | "Manage care for parents and children" |

Never show a screenshot of a feature that is off in the production build: reviewers reject that as misleading metadata.

## 6. Google Play Data Safety form (patient app)

Derived from what the code actually collects (API contract, Flutter plugins: `image_picker`, `file_picker`, `speech_to_text`, `geolocator`, `firebase_messaging`, `razorpay_flutter`). Re-check whenever a plugin or SDK is added. **[REQUIRES LEGAL REVIEW]**

General answers: data is **encrypted in transit** (HTTPS/TLS 1.2+): **Yes**. Users can **request deletion**: **Yes** (in app: Profile → Delete account; web: `https://<portal>/account/delete`). Data **sold**: **No**. Independent security review: No (until the pen test report exists; you may then say Yes only if it meets Google's MASA criteria).

| Data type (Play category) | Collected | Shared* | Purpose | Optional? | Notes |
|---|---|---|---|---|---|
| Personal info → Name | Yes | No | App functionality, account management | Required | patient and dependants |
| Personal info → Phone number | Yes | Yes (SMS provider, for OTP delivery) | Account management, app functionality, fraud prevention | Required | OTP login |
| Personal info → Email address | Yes | No | Account management | Optional | |
| Personal info → Address | Yes | Yes (assigned home-care provider) | App functionality | Optional (needed for home visits) | |
| Personal info → Other (date of birth, gender, relation) | Yes | No | App functionality | Required for profiles | |
| Health and fitness → Health info | Yes | Yes (the doctors/providers the user books; AI processor, see below) | App functionality | Required for core use | symptoms, conditions, allergies, medications, vitals, care plans, mood |
| Health and fitness → Fitness info | No (until wearables ship) | – | – | – | |
| Financial info → Purchase history | Yes | No | App functionality | Required for bookings | card data is handled by Razorpay, not us |
| Financial info → Payment info | Collected by the Razorpay SDK | Yes (Razorpay) | Payments | Required to pay | declare as Razorpay's per its disclosure |
| Location → Approximate | Yes | No | App functionality | Optional | nearby facilities, serviceability |
| Location → Precise | Yes | Yes (emergency contacts on SOS; home-care provider for visits) | App functionality | Optional, only when the user uses SOS or books a home visit | foreground only, no background location |
| Photos and videos → Photos | Yes | Yes (treating clinician) | App functionality | Optional | record uploads, wound photos |
| Files and docs | Yes | Yes (treating clinician) | App functionality | Optional | PDFs of reports |
| Audio → Voice or sound recordings | No** | – | – | – | on-device speech-to-text; only the text is sent |
| Messages → Other in-app messages | Yes | Yes (AI processor) | App functionality | Optional | AI assistant conversation text |
| App activity → App interactions | Yes | No | Analytics, app functionality | Required | server audit logs |
| App info and performance → Crash logs, Diagnostics | Yes, if Crashlytics is added | No | Analytics | – | no PHI in crash logs |
| Device or other IDs | Yes | Yes (Google FCM) | App functionality (push) | Required for notifications | FCM registration token |

\* Play does not count transfers to **service providers processing on your behalf** as "sharing" (SMS gateway, cloud hosting, FCM, the LLM API under a DPA), nor transfers the **user initiates** (booking a doctor, SOS to their own contacts). Counsel should confirm the classification; declaring more is safer than less.
\*\* `speech_to_text` uses the platform recogniser (Google / Apple), which may process audio on their servers. Disclose this in the privacy policy. **[REQUIRES LEGAL REVIEW]**

**AI processing:** the assistant sends conversation text and relevant context to Anthropic's API (outside India). This needs explicit consent (`ai_assistance`), a DPA and a privacy-policy disclosure. **[REQUIRES LEGAL REVIEW]** (DPDP cross-border rules)

**Provider app:** name, phone, precise location (during visits), photos (visit evidence), patient health info entered by the provider, device ID (push). Same encryption and deletion answers. Staff accounts are deleted by an admin (the deletion web page tells staff to contact their administrator).

## 7. Play Console declarations

- **Health apps declaration** (App content → Health apps): select the matching features: *Medical* → "Telemedicine / doctor consultation", "Medication and treatment management (reminders)", "Health records management", "Clinical decision support" = **No** (the AI routes, it does not diagnose), "Emergency" features: describe SOS as alerting contacts and calling 108. Attach the privacy policy. The app is not a medical device claim **[REQUIRES LEGAL REVIEW]**.
- **Account deletion** (App content → Data safety → Data deletion): URL `https://<portal>/account/delete`. The page must name the app/developer, explain the steps, and state what is deleted and what is retained (and for how long). The in-app path is Profile → Delete account (`POST /me/deletion-request`, grace period `ACCOUNT_DELETION_GRACE_DAYS`, default 7).
- **Target audience:** 18+ (the account holder manages minors' care). Do not select child age groups; otherwise Families policy applies.
- **Content rating (IARC):** answer "No" to violence, sex, gambling. Medical references: yes. The expected result is Rated 3+/Everyone (Play) and 12+/17+ on Apple (see §10).
- **Ads:** none. **Government app:** no. **Financial features:** none (payments for services only).
- **News app / COVID:** no.
- **Foreground service / exact alarm** declarations: only if the medicine reminders use exact alarms (`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`); justify as "user-set medication reminders".
- **Permissions declarations:** none of the restricted groups (SMS, call log, background location, all-files access) are requested. Keep it that way.

## 8. Permission justifications

| Permission | App | Android | iOS key | User-facing justification (en) |
|---|---|---|---|---|
| Camera | both | `CAMERA` | `NSCameraUsageDescription` | "Take a photo of a report, prescription or wound to share with your care team." |
| Photos | both | photo picker (no `READ_MEDIA_IMAGES` needed on Android 13+) | `NSPhotoLibraryUsageDescription` | "Choose existing photos of reports or prescriptions to upload." |
| Microphone + speech | patient | `RECORD_AUDIO` | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | "Speak to the care assistant instead of typing. Audio is converted to text and not stored." |
| Location (while in use) | both | `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` | Patient: "Share your location with your emergency contacts when you press SOS, and find nearby care." Provider: "Show your route to the visit and confirm arrival." |
| Notifications | both | `POST_NOTIFICATIONS` | runtime prompt | "Medicine reminders, appointment and visit updates." |
| Physical activity / Health Connect / HealthKit | – | **not requested** | **not requested** | Wearables are not shipped. Do not add `ACTIVITY_RECOGNITION`, Health Connect or HealthKit entitlements until they are, because both stores require extra declarations for them. |
| Background location | – | **not requested** | – | – |

Ask each permission **in context** (at the moment of use), never at first launch.

## 9. Apple App Privacy ("nutrition labels")

App Store Connect → App Privacy. For each type: **Linked to the user: Yes**; **Used for tracking: No** (no ad SDKs, no IDFA; do not show the ATT prompt).

| Apple data type | Collected | Purposes |
|---|---|---|
| Contact Info: Name, Email Address, Phone Number, Physical Address | Yes | App Functionality |
| Health & Fitness: Health | Yes | App Functionality |
| Financial Info: Purchase History (and Payment Info through Razorpay) | Yes | App Functionality |
| Location: Precise Location, Coarse Location | Yes | App Functionality |
| User Content: Photos or Videos, Other User Content (records, AI chat text), Customer Support | Yes | App Functionality |
| Identifiers: User ID, Device ID (push token) | Yes | App Functionality |
| Usage Data: Product Interaction | Yes | App Functionality, Analytics (only if analytics exist) |
| Diagnostics: Crash Data | only if Crashlytics is added | App Functionality |
| Audio Data | No (on-device transcription; confirm the speech settings) | – |

Also required: privacy policy URL, and from 2024 the **privacy manifest** (`PrivacyInfo.xcprivacy`) for the app and the required-reason APIs used by plugins (Flutter plugins ship their own; check the Xcode "Generate Privacy Report").

## 10. Apple review

### 10.1 Demo account (both apps)
Reviewers cannot receive an SMS in India. Provide a **review-only phone number with a fixed OTP**:

- Patient: e.g. `+91 90000 00001`, OTP fixed; account pre-populated with a synthetic dependent, records and a care plan.
- Provider: a verified synthetic provider with one assigned visit.
- Staff MFA does not apply to patient/provider roles.

**Backend support: `REVIEW_PHONE` + `REVIEW_OTP`.** For exactly that one phone, the API skips SMS and accepts the fixed 6-digit OTP, audits each login as `auth.review_login`, and logs a warning at startup. To set it up:
- put `REVIEW_PHONE` in `api_extra_environment`;
- put `REVIEW_OTP` in Secrets Manager (add it to `api_secret_names`), never in the repo;
- **remove both again once the review is approved.**

Populate the review account with synthetic data only: a dependent, sample records and a care plan (use the admin UI/CLI). Tell your operations team that bookings from this number are review traffic. Where possible, submit against a staging backend so reviewers never reach real providers or payments.

Only one review phone is supported. For the provider app, use a second environment (for example staging) or rotate the value between the two reviews.

### 10.2 Review notes (paste into App Review Information → Notes)
> CareCompanion is a care-coordination app for families in India. Sign in with phone +91 90000 00001 and OTP <code> (a review-only test account with synthetic data; no SMS is sent).
> The AI assistant collects symptoms and routes the user to a doctor, home visit or emergency guidance using deterministic, clinician-approved rules. It does not diagnose or prescribe. Consultations are with registered medical practitioners in India under the Telemedicine Practice Guidelines 2020. Payments are for real-world services (consultations, home visits) through Razorpay, so In-App Purchase does not apply (guideline 3.1.3(e)/3.1.5).
> Account deletion: Profile → Delete account. Emergency: the SOS screen alerts the user's own contacts and offers to call 108; the app does not dispatch ambulances.
> Location is used only while the app is in use (SOS and home visits). The service is currently available in Hyderabad.

### 10.3 Guideline 1.4.1 (Physical harm: medical apps)
- Apple scrutinises apps that "could provide inaccurate data or information" and requires disclosed **methodology** for health measurements and regulatory clearance where relevant. Do not claim measurement from the camera or sensors. Wound "AI analysis" must stay off (`wound_ai_analysis=false`), since image-based severity output would need clearance.
- Remind users to consult a doctor: the disclaimer is shown in the AI screen, listing and onboarding.
- Doctors are verified (registration number shown; ranking is explainable). Be ready to show evidence of the doctors' registration and the telemedicine arrangement.
- Apple may request documentation that the company is a licensed/qualified health provider or partners with one. **[REQUIRES LEGAL REVIEW]**
- Guideline 5.1.1(ix): apps in highly regulated fields (healthcare) should be submitted by the **legal entity** providing the service, not an individual developer account.

### 10.4 Guideline 5.1.1(v): account deletion
Apps with account creation must let users **initiate deletion in the app**. Implemented: Profile → Delete account → `POST /me/deletion-request` (7-day grace, cancellable), plus the web page. Explain in the flow what is retained for legal reasons (clinical records, payments, audit) **[REQUIRES LEGAL REVIEW]**. A "contact support to delete" flow alone is rejected.

### 10.5 Other Apple points
- **Age rating:** answer "Medical/Treatment Information: Frequent/Intense" → likely **17+** under the old questionnaire, or 16+/18+ under the 2025 rating system; accept what the questionnaire yields. Play (IARC) usually yields Everyone / 3+ with the "medical" note.
- Sign in with Apple is **not** required (phone OTP only; no third-party social login).
- Video consultation opens Jitsi. If embedded, declare the camera and microphone usage for calls too.
- Export compliance: uses only standard HTTPS encryption → `ITSAppUsesNonExemptEncryption = NO`.

## 11. India-specific notes

| Topic | What to do |
|---|---|
| **DPDP Act 2023 + DPDP Rules 2025** | Notice + consent in plain language (en/hi/te), itemised purposes (the consent catalogue already splits terms, privacy, health data, AI, sharing, family, marketing), a grievance officer and contact published in-app and on `/privacy`, erasure and access rights (deletion and export are implemented), breach notification to the Data Protection Board and users, children's data only with verifiable parental consent (parents manage minors). Cross-border transfer of health data (the LLM API) must be checked against notified restrictions. **[REQUIRES LEGAL REVIEW]** |
| **Telemedicine Practice Guidelines 2020 (NMC/Board of Governors)** | Only registered medical practitioners consult; show the registration number; patient identification and consent for teleconsultation; no prescribing of prohibited drug lists via teleconsultation; records retention. The app/platform must not diagnose via AI. **[REQUIRES LEGAL REVIEW]** |
| **DLT SMS registration (TRAI TCCCPR)** | Register the entity, the sender header (e.g. `CARECO`) and every SMS template (OTP, notification) on a DLT portal (Jio, Airtel, Vi, BSNL…) through your SMS provider (MSG91). Unregistered templates are blocked by operators. The template IDs go into `MSG91_OTP_TEMPLATE_ID` / `MSG91_NOTIFY_TEMPLATE_ID`. Lock-screen and SMS text never contain health details. |
| **IT Act + SPDI Rules / CERT-In directions** | Reasonable security practices (encryption, access control, audit logs), incident reporting to CERT-In within 6 hours, log retention 180 days in India (CloudWatch retention is 30 days by default; archive to S3 if counsel confirms the requirement). **[REQUIRES LEGAL REVIEW]** |
| **Drugs and Cosmetics / pharmacy** | Medicine ordering only via licensed partner pharmacies; Rx gate for scheduled drugs; do not list the pharmacy features unless they are enabled and licensed. **[REQUIRES LEGAL REVIEW]** |
| **Payments (RBI)** | Razorpay handles card data (PCI-DSS). Show refund/cancellation policy pages (Razorpay activation also requires them). |
| **Consumer Protection (E-commerce) Rules 2020** | Display the seller/entity details, grievance officer, pricing, refund policy. **[REQUIRES LEGAL REVIEW]** |
| **ABDM** | Not integrated. Do not mention ABHA/ABDM in listings. |

## 12. Pre-submission checklist

Accounts and legal
- [ ] Organisation developer accounts (Play, Apple) under the legal entity; D-U-N-S done
- [ ] Privacy policy, terms, account-deletion and support pages live on the portal domain; `NEXT_PUBLIC_LEGAL_DRAFT=false` only after counsel approval **[REQUIRES LEGAL REVIEW]**
- [ ] Grievance officer named; support email/phone live
- [ ] DLT entity, header and templates approved; MSG91 configured in production
- [ ] DPAs with the AI provider, SMS, cloud, payments **[REQUIRES LEGAL REVIEW]**

Build
- [ ] Production API reachable over HTTPS; `MOBILE_API_BASE_URL` set; `minAppVersion` values set in the API env
- [ ] Clinician-approved safety rule pack active (`/ready` → `safetyRules: ok`)
- [ ] Feature flags reviewed: P1 features the listing does not describe are off
- [ ] Upload keystores generated, backed up, in GitHub secrets; AAB verified not debug-signed
- [ ] Version name/build number bumped; release notes (en/hi/te)
- [ ] Firebase push configured for both platforms; notification text generic
- [ ] Crash reporting has no PHI; logs redact PHI

Store content
- [ ] Listings per §4 reviewed by legal; no diagnosis/cure/accuracy claims
- [ ] Screenshots per §5 from synthetic data only
- [ ] Data Safety (§6) and App Privacy (§9) answers match the actual build and SDKs
- [ ] Health apps declaration, account-deletion URL, target audience 18+, content rating done
- [ ] Permission prompts in context; no unused permissions in the manifest / Info.plist
- [ ] Review-login (§10.1) implemented and tested on the production build; review notes pasted
- [ ] Provider app distributed privately (Managed Play / closed track; ABM custom app / TestFlight)

Rollout
- [ ] Play: internal → closed (pilot cohort) → production staged rollout 10% → 50% → 100%
- [ ] Apple: TestFlight → phased release
- [ ] Monitor crash-free sessions ≥ 99.5% and API alarms during rollout
