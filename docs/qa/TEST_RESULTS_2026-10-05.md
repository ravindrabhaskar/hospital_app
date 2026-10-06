# CareCompanion Test Checklist - Results (Oct 3-5, 2026)

## Summary

**Not ready to release yet: 5 High bugs are open.** About 150 checklist items were run: roughly 70% passed, 12% partly passed or failed, and the rest could not be tested in this setup or were not reached (mostly the second half of the patient app section and part of the All-in-One section).

Release blockers (High):

- **B1** Patient app: after a failed payment, "Retry payment" never succeeds and the booking is cancelled.
- **B2** Nurse app: the full home address of a visit the nurse has not accepted is shown on the Route tab, in the Maps link and by the server (privacy).
- **B3** Web: Approve on a nurse application fails ("Request validation failed").
- **B4** Web: coupons cannot be created or edited.
- **B5** Web: care-program templates cannot be approved.

Legend: `[x]` passed. Unticked items say **FAILED** (bug number), **PARTLY** or **NOT TESTED** (reason).

## How this run was done

- **Phone checks:** the four demo APKs installed on an Android emulator (Pixel), pointed at the backend on this PC.
- **App feature checks:** the same app code in a headless browser (no real camera, microphone, dialler or sensors).
- **Web portal:** tested in a headless browser.
- **Server checks:** results confirmed through the backend API.
- **Test data:** fresh demo data on Oct 3, plus test users 9811111111, 9822222222, 9833333333, 9844444401 and 9855555502.
- **Not covered:** a real phone (camera, calls, push, battery), a live two-device video call, iPhone.
- **Evidence:** screenshots and raw logs are in the session scratchpad under `qa/patient`, `qa/pro`, `qa/web` and `qa/phone`.

## 1. Install, launch and login (every app)

Install and launch
- [x] APK installs without errors (all four)
- [ ] App icon is the new plum and butter design and its name is correct: **PARTLY**. The icons are correct, but every name shows as "CareCompa…" in the app drawer (B21)
- [x] Launch screen is butter-cream with the brand mark; app opens within about 3 seconds (cold start 0.9-1.4 s; All-in-One 2.6 s)
- [x] App opens again normally after force-closing it
- [x] App survives rotating the phone (patient and nurse apps). The emulator crashed twice when the doctor app was rotated; recheck on a real phone (B28)

Language (patient app)
- [x] First launch shows the language screen with English, Hindi and Telugu
- [x] Choosing Hindi shows the next screens in Hindi; same for Telugu (except Ask AI, B10)
- [x] Language can be changed later in Profile > Language

Server address setting
- [x] Login screen shows "Server: ..." at the bottom
- [x] Tapping it opens the Server address dialog
- [x] Test connection shows a green tick with the version ("Connected. Server version 1.0.0")
- [x] A wrong address shows a clear error, not a crash (Save accepts a garbled address without checking, B22)
- [x] Save keeps the address after closing and reopening the app
- [x] With the server unreachable, login shows "Can't reach the server" with a Change server button

Login
- [x] Send OTP moves to the OTP screen
- [x] Dev OTP hint (123456) is shown
- [ ] A wrong OTP shows an error and does not log in: **PARTLY**. Correct in the patient app; nurse and doctor apps say "Your session has expired" (B6)
- [x] Fewer than 6 digits shows "Enter the 6-digit code"
- [x] Correct OTP opens the home screen
- [x] Resend OTP is disabled during the countdown, then works
- [x] Change number goes back to the phone screen
- [x] Invalid phone numbers are rejected
- [x] After closing and reopening the app, you stay logged in
- [x] Logout returns to the login screen and stays logged out

Note: the server allows 5 OTP requests per number every 15 minutes; heavy testing on one number gets "Too many attempts" for a while.

## 2. Patient / family app

Onboarding (9811111111)
- [x] Consents must be accepted to continue
- [x] Profile (name, date of birth, gender) saves, with validation
- [x] Emergency contact can be added
- [x] Invite code is optional; a wrong code shows "This invite code is not valid" (if the app reloads after the profile step, the emergency-contact and invite steps are skipped, B30)

Home
- [x] Greeting shows the right name and time of day
- [x] Family switcher changes to Ramesh and the home screen updates for him
- [x] Daily check-in with mood saves and shows as done
- [x] Each quick-action tile opens the right screen
- [x] Quick Access grid and the More sheet open every listed feature (the More sheet is partly covered by the bottom bar, B15)
- [x] SOS is visible on Home
- [x] Messages and Notifications badges show unread counts and open the right lists
- [x] Explore Care Plans banner opens the plans tab
- Note: the "How was your care?" rating sheet pops up again after every reload and sits behind the bottom bar (B15)

Ask AI
- [x] Every reply is labelled "AI-generated · not a diagnosis"
- [ ] Voice input fills the message box: **PARTLY**. Microphone permission handling works on the phone; dictation itself not tested
- [ ] Read-aloud plays the reply: **NOT TESTED** (no audio in the test setup; the setting exists)
- [x] "severe chest pain" shows a red alert with Call 108 and SOS (the reason text shows "(fixture)", B9)
- [ ] AI suggests booking and those buttons work: **PARTLY**. Buttons work, but it can suggest a specialty with no doctors (B11)

Doctors and appointments
- [x] Find a doctor: list, specialty filter, detail page
- [ ] Book a slot, apply coupon, use wallet, pay: **PARTLY**. Booking and mock payment work; no coupon applies to doctor visits in the demo data and the wallet balance is 0
- [x] Booking success screen appears and the appointment shows in Care > Appointments
- [ ] A failed payment shows a retry banner and the booking is not confirmed: **FAILED**. The banner shows, but Retry never succeeds and the booking is cancelled (B1)
- [ ] A fully covered booking skips the payment sheet: **NOT TESTED** (no wallet credit or 100% coupon in the demo data)
- [x] Video join card appears from 10 minutes before the start (join itself not tested)
- [x] Ramesh's past appointment with Rs 499 payment is visible

Home checkup and visit tracking
- [x] Service, address with pincode 500034, slot
- [x] Pincode 560001 is refused as not serviceable
- [x] WELCOME100 takes Rs 100 off the first home visit (Rs 499 → Rs 399); a second use is refused
- [x] Tracking screen shows provider, timeline, address and status
- [x] Visit code is shown to the patient

Lab tests
- [x] Search tests and packages; a test inside a package is not charged twice
- [x] Fasting notice appears (10 hours)
- [x] CARE10 gives 10% off, capped at Rs 200
- [ ] Checkout, order timeline and report view: **PARTLY**. Checkout and timeline work; order detail shows the total before discount (B17); report view not tested (no lab results in the demo)

Pharmacy
- [x] Browse, add to cart, change quantities, checkout
- [x] "Order these medicines" from a prescription pre-fills the cart

Records
- [ ] Upload by camera and by file: **PARTLY**. File upload works; camera not tested in the browser, and denying camera permission on the phone shows an unhelpful message (B13)
- [x] Tabs All, Reports, Prescriptions, Images filter correctly
- [ ] Prescription opens as an in-app PDF: **PARTLY**. In the browser build it offers open/download; the phone viewer was not checked
- [x] Timeline, vitals and medications (add a medicine) work (a new medicine shows today's earlier reminder as "Missed", B18)

Care, messages and programs
- [x] Care tab: Episodes, Appointments, Home visits, Care plans all load
- [x] Episode detail shows the stages (episodes of cancelled bookings stay "New", B30)
- [x] Inbox thread: send a message, attach an existing record (an attachment without text can't be sent, B30)
- [ ] Programs: log BP, sugar and weight; out-of-range values flagged: **NOT TESTED** (not reached)
- [ ] Trend charts and weekly PDF: **NOT TESTED** (not reached)
- [ ] Medicine reminders can be set: **NOT TESTED** (not reached)

Wellness and safety: **NOT TESTED** (not reached). The emergency and SOS path was verified in section 7.
- [ ] Preventive care, exercise, diet (Preventive Care shows "[REQUIRES CLINICAL GOVERNANCE]" to users, B9)
- [ ] Wound photo quality check
- [ ] Wearables permission prompt
- [ ] Fall detection opt-in and countdown
- [ ] SOS Call 108; emergency contacts notified
- [ ] Ambulance booking and nearby facilities
- [ ] Safety hub, companion mode consent

Benefits, money and profile: **NOT TESTED** in the app (not reached), except:
- [ ] Schemes disclaimer; second opinion request (the second-opinion flow passed through the API, section 7)
- [ ] ABHA and insurance screens
- [ ] Wallet, invite, Family Care Plan, payment history, invoices (plan descriptions show "[REQUIRES PRICING VALIDATION]", B9)
- [ ] Profile edit, photo, health profile, family members
- [x] Lakshmi (9800000002) has view-only access to Ramesh and cannot book or edit (checked through the API)
- [ ] Notifications and WhatsApp toggles
- [ ] Help and support ticket (support flow passed via web and API, section 7)
- [ ] Download my data
- [ ] Delete account in the app (the web deletion page passed, section 6)

## 3. Nurse app (CareCompanion Pro)

Access gates
- [x] Anil (9800000203) sees the blocked verification screen ("Credential expired on Jun 30, 2026")
- [ ] Expiring credential warning banner: **PARTLY**. Shown on Profile only, not on Home (B16)
- [x] A patient account gets "Apply to join"

Apply to join
- [x] 4-step form: role, qualification, languages and zones by pincode, review
- [x] Document upload works; files over 10 MB are refused
- [x] Status shows Submitted
- [x] Changes requested → edit and resubmit
- [x] After approval the app shows the nurse home (approved through the API because of B3)

Home and duty
- [x] Duty toggle persists after reopening
- [x] Check in/out; Attendance month view
- [x] Counters match the lists
- [x] Today, Upcoming, Completed and Route tabs load ("Completed" cut off at narrow widths, B21)
- [ ] Route stops in order and Start navigation: **FAILED**. Lists completed visits (B7) and shows unaccepted visits' full address (B2)
- [x] Earnings by month

Visit lifecycle
- [ ] Full address hidden until Accept: **FAILED** on the Route tab and in the server response (B2); correct on the visit screen
- [x] Reject removes it (with a reason)
- [x] Accept shows the full address; allergies in red
- [x] En route and Arrived update the patient's tracking
- [x] Wrong visit code refused; correct code accepted (a wrong code also clears the consent tick, B29)
- [x] Consent box required before the checkup
- [ ] Vitals out-of-range flagged, impossible values refused: **PARTLY**. Impossible values refused; abnormal values not highlighted (B8)
- [ ] Observations by typing and voice: **PARTLY**. Typing works; voice not tested
- [ ] Photo consent dialog, camera only: **NOT TESTED** (phone-only feature; check on a real phone)
- [x] Supplies used recorded
- [ ] Sample collection: **PARTLY**. Complete stays disabled until all items are ticked; no fasting note because the test visit had no lab order
- [x] Complete visit; patient sees the result
- [x] Escalate: red button, two-step confirmation, Call 108

Offline
- [x] Recording continues offline
- [x] "Pending sync (n)" banner
- [x] Reconnect: uploads once, in order, no duplicates (automatic)
- [x] Logout clears the offline cache, with a warning

Other screens
- [ ] Supplies low and out-of-stock: **PARTLY**. Low stock shown; no out-of-stock item to check
- [ ] Physio and dietitian plans: **NOT TESTED** (no such demo account)
- [x] Profile: language, photo, support contacts
- [x] Request account closure points to support

## 4. Doctor app

- [x] Date strip, today highlighted, tapping a date changes the list
- [x] Booked appointment appears with patient name and time
- [x] Refresh
- [x] Empty day shows "No consultations on this day"
- [x] Snapshot, history and records load
- [x] Notes save
- [x] AI scribe asks for consent; draft inserted only on tap
- [x] E-prescription interaction warnings (Warfarin + Aspirin; Amoxicillin with penicillin allergy) need an override reason
- [x] Signed prescription appears in the patient's records
- [x] Care plan, programs, exercise and diet plans reach the patient
- [x] Referral submits
- [ ] Video call: **NOT TESTED** (needs two devices at appointment time; join window shown correctly)
- [x] Patients list, snapshot, episodes, records
- [ ] Messages: **PARTLY**. Replies reach the patient, but attached records are not shown (B12)
- [x] Second opinions answered
- [x] Escalations list
- [x] Leave removes that day's slots for patients (16 → 0)
- [x] Earnings, profile, language, Server address

## 5. All-in-One app

- [x] Role chooser with plum header, three role cards and Remember my choice
- [ ] Each card opens the right app: **PARTLY**. The patient card was checked (language screen, login, Home); nurse and doctor cards not reached
- [ ] Switch app returns to the chooser: **NOT TESTED** (not reached)
- [ ] Remember my choice: **NOT TESTED** (not reached)
- [ ] Each role keeps its own login: **NOT TESTED** (not reached)
- [x] Server address set in one role works in the others
- [ ] Key checks inside All-in-One: **PARTLY**. Patient Home only

## 6. Web portal

Login and session
- [x] Patient and nurse numbers refused
- [x] MFA setup: QR code, 10 recovery codes, Skip for now
- [x] Idle warning at 13 minutes, logout at 15 (to /login?idle=1)
- [x] Menus match the role; active item butter with plum text

Clinician
- [x] Queue and patient search
- [x] AI summary Accept / Modify / Reject
- [x] Consultation, Prescription and Messages tabs
- [x] Major interaction needs acknowledgement and a 10+ character reason
- [ ] Refer, AI scribe, video join: **PARTLY**. Video join not tested (room not open yet)
- [x] Escalations, second opinions, schedule (overlaps refused, leaves), earnings, profile

Coordinator and Ops
- [x] Caseload, Log contact, Inbox
- [x] Control tower refreshes about every 15 seconds
- [x] Assign a nurse; the nurse app receives it
- [x] Safety events, episodes, tasks, incidents
- [ ] Refunds and invoices only for ops admin: **PARTLY**. Refunds correct; the coordinator can open invoices (B14, decide the intended rule)
- [ ] Applications approve / reject / request changes: **FAILED**. Approve fails (B3)
- [x] Settlements CSV, reviews moderation, lab orders, ambulance, supplies

Admin
- [x] Users: search, edit roles, Reset MFA
- [x] Audit logs and analytics
- [x] AI kill switch works and was switched back off
- [ ] Admin settings pages save: **FAILED** for coupons (B4) and program approval (B5); the others save
- [x] Tenant branding preview

Hospital and support
- [x] Discharge list Day X/30; 4-step discharge creates a PDF
- [x] Support SLA countdown, Assign to me, internal notes hidden from the patient

Public pages
- [x] Home, Privacy, Terms (draft banner), Support without login
- [x] /account/delete schedules and cancels deletion

## 7. End-to-end journeys

- [x] Home visit: booking with WELCOME100 → Ops assigns → nurse accept, en route, arrive, code, consent, vitals, complete → patient sees it
- [ ] Doctor consultation: **PARTLY**. Everything except the live video call (not tested)
- [ ] Messages: **PARTLY**. Works end to end, but the doctor app hides attachments (B12)
- [ ] AI to care: **PARTLY**. Booking completes, but the suggested ENT specialty has no doctors (B11)
- [x] Emergency: Ask AI red alert → SOS → safety events visible to Ops (that test patient had no emergency contacts to notify)
- [x] Nurse escalation visible to Ops and the doctor (the nurse's reason is missing on the Ops event, B27)
- [x] Offline visit syncs exactly once
- [ ] Nurse application: **PARTLY**. Everything works except the web Approve (B3)
- [x] Hospital discharge: Sarojini and family member Kiran see the 30-day program; other patients refused
- [x] Second opinion answered and visible to the patient
- [x] Support ticket reply visible; internal note hidden
- [x] Account deletion scheduled and cancelled

## 8. Design, dark mode, languages and quality

Design
- [x] Plum buttons with butter text
- [ ] No leftover green: **PARTLY**. Apps clean; web charts use grey-green lines (B19)
- [x] Serif headings; readable body text
- [ ] Butter highlight on selected tabs, chips and bottom bar: **PARTLY**. Missing on the patient app's bottom bar (B20)
- [x] Consistent cards, borders and shadows
- [ ] Nothing unreadable: **PARTLY**. White status-bar icons on the butter header, low-contrast Ask AI button in dark mode, faint disabled button (B26)
- [ ] Payment sheet plum: **NOT TESTED** (Razorpay needs live keys)

Dark mode
- [x] Deep plum backgrounds, readable text
- [x] Butter icons and links
- [x] Home, Care, Records, Profile checked

Languages
- [ ] No English left in Hindi/Telugu: **FAILED** (Ask AI greeting and quick replies, nurse capability chips, B10)
- [ ] Dates, numbers, currency per language: **NOT TESTED**

Accessibility
- [ ] Largest text size: **PARTLY**. Usable, but words break mid-word and tabs are cut off (B21)
- [ ] TalkBack: **NOT TESTED**
- [ ] Tap targets: **NOT TESTED** directly

Network and devices
- [ ] Slow network: **NOT TESTED**
- [x] Network drops: nurse app works offline and syncs
- [x] Server stopped: clear "Can't reach the server"
- [ ] Small and large phones: **NOT TESTED**
- [ ] Android 10, 12, 14: **NOT TESTED** (one emulator only)
- [ ] Notifications: **NOT TESTED** (push not configured)
- [ ] Permission denial messages: **FAILED** for the camera (B13); the microphone is fine; location shows no explanation and asks again on every launch

Performance
- [x] Opens in under 3 seconds
- [x] Smooth scrolling
- [ ] 30 minutes / battery: **NOT TESTED**

Security and privacy
- [x] Patients cannot see other patients' or other hospitals' data
- [x] View-only family access cannot book or edit
- [ ] Back button after logout: **NOT TESTED** (not reached)
- [ ] Lock-screen notification text: **NOT TESTED**
- [x] Staff cannot delete their own accounts
- [x] AI answers always carry the label
- [ ] **Unaccepted visit address leak: FAILED** (B2, found during nurse testing)

## 9. Bug list

| # | Severity | Where | Problem | How to reproduce |
| --- | --- | --- | --- | --- |
| B1 | High | Patient app | Retry after a failed payment never succeeds; booking gets cancelled | Book a doctor → Simulate failure → Retry payment |
| B2 | High | Nurse app + server | Full address of an unaccepted visit shown on Route, in the Maps link and in the API | Assign a visit, don't accept, open Route |
| B3 | High | Web Ops | Approve nurse application fails (date sent without time) | Applications → Approve → set expiry → submit |
| B4 | High | Web Admin | Coupons can't be created or edited (dates sent without time) | Admin → Coupons → New → Save |
| B5 | High | Web Admin | Program template approval fails ("approverName required") | Admin → Care programs → Approve |
| B6 | Medium | Nurse + doctor apps | Wrong OTP says "Your session has expired" | Enter 111111 → Verify |
| B7 | Medium | Nurse app | Route lists completed visits as stops | Complete a visit → Route |
| B8 | Medium | Nurse + doctor apps | Abnormal vitals (BP 185/115, SpO2 89) not highlighted | Record those vitals |
| B9 | Medium | Patient app | Internal placeholders shown to users: "[REQUIRES CLINICAL GOVERNANCE]", "[REQUIRES PRICING VALIDATION]", "(fixture)" | Preventive Care; plan/lab descriptions; emergency card |
| B10 | Medium | Patient + nurse apps | English left in Hindi/Telugu (Ask AI greeting and chips, capability chips) | Switch to Hindi → Ask AI |
| B11 | Medium | Patient app | AI suggests ENT; no ENT doctors, so "No doctors found" | Ask AI about sore throat → Find doctors |
| B12 | Medium | Doctor app | Records attached by the patient aren't shown in the thread | Patient sends a message with a record |
| B13 | Medium | Patient app (phone) | Denying camera shows "Could not open the file", no hint to allow camera | Records → Upload → Take photo → Don't allow |
| B14 | Medium (decide) | Web Ops | Coordinator can open invoices; checklist expected ops-admin only | Log in as 9800000301 → Payments |
| B15 | Low | Patient app | "How was your care?" sheet reappears on every reload and sits behind the bottom bar; More sheet also covered | Open Home, reload |
| B16 | Low | Nurse app | Expiring-credential warning only on Profile | Credential expiring in under 30 days |
| B17 | Low | Patient app | Lab order shows total before discount | Lab order with CARE10 |
| B18 | Low | Patient app | New medicine shows today's earlier reminder as "Missed" | Add a medicine in the afternoon with an 08:00 reminder |
| B19 | Low | Web | Charts use grey-green grid and axis colours | Admin analytics |
| B20 | Low | Patient app | Selected bottom-bar item has no butter pill (other apps do) | Any tab |
| B21 | Low | All apps | Truncation: app names "CareCompa…", nurse tabs, words broken at large text | Large font / launcher |
| B22 | Low | All apps | Server dialog saves a garbled address; tick shown twice | Server dialog |
| B23 | Low | Patient app | One Verify tap sends two OTP checks, using up attempts | Verify OTP |
| B24 | Low | Web Admin | Program description looks optional but is required | Create program without description |
| B25 | Low | Patient app | AI question counter jumps; typed severity ("Moderate") not understood | Ask AI intake |
| B26 | Low | Apps | Contrast: white status-bar icons on butter, Ask AI button in dark mode, faint disabled button | Home header; dark mode |
| B27 | Low | Server / Ops | Nurse's escalation reason missing on the Ops event | Escalate with a reason |
| B28 | To recheck | Doctor app | Rotating crashed the emulator twice; may be the emulator | Rotate on a real phone |
| B29 | Low | Nurse + doctor apps | Small issues: name allows 120 characters (server max 100), apply draft lost on reload, raw codes ("general_physician"), "1 readings", wrong visit code clears consent, logout mentions an authenticator, leave removed without confirmation | Various |
| B30 | Low | Patient app | Small issues: onboarding steps skipped after reload, Enter doesn't send, attachment-only message can't be sent, cancelled-booking episodes stay "New", deep-linked add-medicine error | Various |

## 10. Sign-off

| Section | Status | Open bugs |
| --- | --- | --- |
| 1. Install, launch and login | Passed with issues | B6, B21, B22 |
| 2. Patient app | Failed / incomplete (about half not reached) | B1, B9, B10, B11, B13, B15, B17, B18 |
| 3. Nurse app | Failed | B2, B7, B8, B16 |
| 4. Doctor app | Passed with issues | B6, B12 |
| 5. All-in-One app | Incomplete | none found |
| 6. Web portal | Failed | B3, B4, B5, B14 |
| 7. End-to-end journeys | Passed with issues | B3, B11, B12 |
| 8. Design and quality | Passed with issues | B10, B13, B19, B20, B26 |

Next steps: fix B1-B5, then rerun the unfinished parts of sections 2 and 5 and the phone-only items on a real Android phone.
