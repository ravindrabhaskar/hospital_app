// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CareCompanion Doctor';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonOk => 'OK';

  @override
  String get commonLogout => 'Log out';

  @override
  String get copied => 'Copied';

  @override
  String get send => 'Send';

  @override
  String get fieldRequired => 'Required';

  @override
  String get linkFailed => 'Couldn\'t open the link';

  @override
  String get offlineBanner => 'You\'re offline. Showing the last loaded data.';

  @override
  String get statusLabel => 'Status';

  @override
  String get priorityLabel => 'Priority';

  @override
  String get severityLabel => 'Severity';

  @override
  String get episodeLabel => 'Care episode';

  @override
  String get reasonLabel => 'Reason';

  @override
  String get noneRecorded => 'None recorded';

  @override
  String get noneAdded => 'Nothing added yet';

  @override
  String get onePerLine => 'One per line';

  @override
  String get commaSeparated => 'Separate with commas';

  @override
  String ageYears(int age) {
    return '$age y';
  }

  @override
  String daysCount(int count) {
    return '$count days';
  }

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get errorNetwork =>
      'Can\'t reach CareCompanion. Check your connection.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorServer =>
      'The service is having trouble. Please try again shortly.';

  @override
  String get errorSessionExpired =>
      'Your session expired. Please log in again.';

  @override
  String get errorForbidden => 'You don\'t have access to this.';

  @override
  String get errorNotFound => 'This item is no longer available.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Please wait and try again.';

  @override
  String get errorMfaRequired =>
      'Two-step verification is required to continue.';

  @override
  String get loginTitle => 'Doctor sign in';

  @override
  String get loginSubtitle =>
      'Your queue, patients and care team in one place.';

  @override
  String get loginPhoneLabel => 'Mobile number';

  @override
  String get loginPhoneHint => '10-digit number';

  @override
  String get loginPhoneInvalid => 'Enter a valid 10-digit mobile number';

  @override
  String get loginSendOtp => 'Send OTP';

  @override
  String loginOtpSentTo(String phone) {
    return 'Enter the code sent to $phone';
  }

  @override
  String get loginOtpLabel => '6-digit OTP';

  @override
  String get loginOtpInvalid => 'Enter the 6-digit code';

  @override
  String loginDevOtpHint(String code) {
    return 'Development OTP: $code';
  }

  @override
  String get loginVerify => 'Verify';

  @override
  String get loginChangeNumber => 'Change number';

  @override
  String get mfaTitle => 'Two-step verification';

  @override
  String get mfaEnrolIntro =>
      'Doctor accounts are protected with an authenticator app code in addition to the SMS OTP.';

  @override
  String get mfaStep1 => '1. Add CareCompanion to your authenticator';

  @override
  String get mfaStep2 => '2. Enter the 6-digit code it shows';

  @override
  String get mfaOpenAppHint =>
      'Tap the button to add the account automatically, or type the setup key into the app.';

  @override
  String get mfaOpenAuthenticator => 'Open authenticator app';

  @override
  String get mfaSecretLabel => 'Setup key';

  @override
  String get mfaCopySecret => 'Copy setup key';

  @override
  String get mfaCodeLabel => 'Authenticator code';

  @override
  String get mfaTurnOn => 'Verify and turn on';

  @override
  String get mfaRecoveryIntro =>
      'Save these recovery codes somewhere safe. Each works once if you lose your phone. They will not be shown again.';

  @override
  String get mfaCopyCodes => 'Copy all codes';

  @override
  String get mfaSavedCodes => 'I\'ve saved my recovery codes';

  @override
  String get mfaVerifyPrompt =>
      'Enter the 6-digit code from your authenticator app.';

  @override
  String get mfaRecoveryPrompt =>
      'Enter one of your recovery codes. Each code works only once.';

  @override
  String get mfaRecoveryLabel => 'Recovery code';

  @override
  String get mfaVerify => 'Verify';

  @override
  String get mfaUseRecovery => 'Use a recovery code instead';

  @override
  String get mfaUseAuthenticator => 'Use the authenticator app';

  @override
  String get mfaWrongCode => 'That code is incorrect.';

  @override
  String mfaWrongCodeAttempts(int count) {
    return 'That code is incorrect. $count attempts left.';
  }

  @override
  String get mfaCodeInvalid => 'Enter the 6-digit code';

  @override
  String get mfaRecoveryInvalid => 'Enter a valid recovery code';

  @override
  String get mfaLocked => 'Too many incorrect codes. Try again in 15 minutes.';

  @override
  String get mfaStatusOn => 'On (authenticator app)';

  @override
  String get mfaStatusOff =>
      'Not set up yet. You will be asked when your organisation requires it.';

  @override
  String get restrictedTitle => 'This app is for doctors';

  @override
  String get restrictedBody =>
      'Your account does not have a verified doctor profile.';

  @override
  String get restrictedPatient =>
      'Please use the CareCompanion app for patients and families.';

  @override
  String get restrictedProvider =>
      'Please use the CareCompanion Pro app for home-care visits.';

  @override
  String get restrictedStaff =>
      'Please use the CareCompanion web portal for your role.';

  @override
  String get updateTitle => 'Please update the app';

  @override
  String get updateBody =>
      'This version is no longer supported. Update to keep seeing patients safely.';

  @override
  String get updateNow => 'Update now';

  @override
  String updateVersions(String current, String minimum) {
    return 'Installed $current · required $minimum';
  }

  @override
  String get supportTitle => 'Support';

  @override
  String get supportCall => 'Call support';

  @override
  String get supportEmail => 'Email support';

  @override
  String get supportWhatsapp => 'WhatsApp support';

  @override
  String get navToday => 'Today';

  @override
  String get navPatients => 'Patients';

  @override
  String get navMessages => 'Messages';

  @override
  String get navMore => 'More';

  @override
  String helloDoctor(String name) {
    return 'Hello, $name';
  }

  @override
  String get queueEmpty => 'No consultations on this day.';

  @override
  String get queueWaiting => 'Waiting';

  @override
  String get queueInProgress => 'In progress';

  @override
  String get queueDone => 'Done';

  @override
  String get apptPendingPayment => 'Payment pending';

  @override
  String get apptConfirmed => 'Confirmed';

  @override
  String get apptInProgress => 'In progress';

  @override
  String get apptCompleted => 'Completed';

  @override
  String get apptCancelled => 'Cancelled';

  @override
  String get apptNoShow => 'No-show';

  @override
  String get priorityRoutine => 'Routine';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityEmergency => 'Emergency';

  @override
  String get epNew => 'New';

  @override
  String get epIntake => 'Intake';

  @override
  String get epAwaitingCare => 'Awaiting care';

  @override
  String get epCareScheduled => 'Care scheduled';

  @override
  String get epUnderCare => 'Under care';

  @override
  String get epFollowUp => 'Follow-up';

  @override
  String get epResolved => 'Resolved';

  @override
  String get epEscalated => 'Escalated';

  @override
  String get epEmergency => 'Emergency';

  @override
  String get epTransferred => 'Transferred';

  @override
  String get epCancelled => 'Cancelled';

  @override
  String get modeVideo => 'Video';

  @override
  String get modeAudio => 'Audio';

  @override
  String get modeChat => 'Chat';

  @override
  String get modeInClinic => 'In clinic';

  @override
  String get modeHomeVisit => 'Home visit';

  @override
  String get consultTitle => 'Consultation';

  @override
  String get openPatient => 'Open patient record';

  @override
  String get startConsult => 'Start consultation';

  @override
  String get completeConsult => 'Complete consultation';

  @override
  String get consultStarted => 'Consultation started';

  @override
  String get consultCompleted => 'Consultation completed';

  @override
  String get savedNotes => 'Saved notes';

  @override
  String get outcomeLabel => 'Outcome';

  @override
  String get outcomeCarePlan => 'Care plan';

  @override
  String get outcomeResolved => 'Resolved';

  @override
  String get outcomeRefer => 'Refer';

  @override
  String get outcomeHomeVisit => 'Home visit';

  @override
  String get notesTitle => 'Clinical notes';

  @override
  String get notesHint => 'Type your notes, or use the AI scribe';

  @override
  String get notesSaveHint =>
      'Notes are saved when you complete the consultation.';

  @override
  String get saveEpisodeNote => 'Add to care episode now';

  @override
  String get noteSaved => 'Note added to the care episode';

  @override
  String get toolsTitle => 'Actions';

  @override
  String get careTeamThread => 'Care-team messages';

  @override
  String get joinVideo => 'Join video';

  @override
  String get videoTitle => 'Video consultation';

  @override
  String get videoWindow => 'Room open';

  @override
  String get videoAudioHint => 'Audio consultation: keep your camera off.';

  @override
  String videoOpensAt(String time) {
    return 'The room opens at $time (10 minutes before the start).';
  }

  @override
  String get intakeTitle => 'Presenting complaint (AI intake)';

  @override
  String get intakeComplaint => 'Chief complaint';

  @override
  String get intakeDuration => 'Duration';

  @override
  String get intakeSeverity => 'Severity';

  @override
  String get intakeSymptoms => 'Associated symptoms';

  @override
  String get allergiesTitle => 'Allergies';

  @override
  String get allergiesNone => 'No known allergies recorded';

  @override
  String get conditionsTitle => 'Conditions';

  @override
  String get activeMedsTitle => 'Active medications';

  @override
  String get recentVitalsTitle => 'Recent vitals';

  @override
  String get homeVisitFindingsTitle => 'Home-visit findings';

  @override
  String get escalatedLabel => 'Escalated';

  @override
  String get aiSummaryTitle => 'AI summary';

  @override
  String get aiAdvisoryLabel => 'AI-generated · advisory, not a diagnosis';

  @override
  String get aiSource => 'Source';

  @override
  String get aiFeedbackPrompt => 'Was this summary accurate?';

  @override
  String get aiAccept => 'Accurate';

  @override
  String get aiReject => 'Not accurate';

  @override
  String get aiFeedbackThanks => 'Thanks, your feedback was recorded.';

  @override
  String get aiRecordSummary => 'AI record summary';

  @override
  String get srcRecord => 'Record';

  @override
  String get srcVital => 'Vital';

  @override
  String get srcIntake => 'Intake';

  @override
  String get srcHomeVisit => 'Home visit';

  @override
  String get srcPatientEntered => 'Patient entered';

  @override
  String get scribeTitle => 'AI scribe';

  @override
  String get scribeConsent =>
      'The patient agreed to this consultation being recorded and transcribed';

  @override
  String get scribeConsentHint =>
      'Required before recording or sending a transcript. This is audited.';

  @override
  String get scribeConsentRequired => 'Confirm the patient\'s consent first.';

  @override
  String get scribeRecordTitle => 'Record the consultation';

  @override
  String get scribeRecord => 'Record';

  @override
  String get scribeRecording => 'Recording…';

  @override
  String get scribeStopUpload => 'Stop and create draft';

  @override
  String get scribeAudioNote =>
      'Audio is uploaded once, transcribed and then discarded by the server.';

  @override
  String get scribeTranscriptTitle => 'Or type / paste a transcript';

  @override
  String get scribeTranscriptHint => 'Doctor: … Patient: …';

  @override
  String get scribeGenerate => 'Create SOAP draft';

  @override
  String get scribeDraftTitle => 'SOAP draft';

  @override
  String get scribeInsert => 'Insert into notes';

  @override
  String get scribeInserted =>
      'Draft inserted. Review and edit before completing.';

  @override
  String get scribeMicDenied => 'Microphone permission is needed to record.';

  @override
  String get scribeTranscriptShort => 'The transcript is too short.';

  @override
  String get scribeTooLarge =>
      'The recording is larger than 25 MB. Record a shorter segment.';

  @override
  String get soapS => 'Subjective';

  @override
  String get soapO => 'Objective';

  @override
  String get soapA => 'Assessment';

  @override
  String get soapP => 'Plan';

  @override
  String get rxTitle => 'Prescription';

  @override
  String rxFor(String name) {
    return 'For $name';
  }

  @override
  String get rxItems => 'Medicines';

  @override
  String get rxNoItems => 'Add at least one medicine.';

  @override
  String get rxNeedsStart => 'Start the consultation first';

  @override
  String get rxItemTitle => 'Medicine';

  @override
  String get rxDrugName => 'Medicine name';

  @override
  String get rxStrength => 'Strength';

  @override
  String get rxForm => 'Form';

  @override
  String get rxDose => 'Dose';

  @override
  String get rxFrequency => 'Frequency';

  @override
  String get rxTiming => 'Timing';

  @override
  String get rxTimingHint => 'After food';

  @override
  String get rxDuration => 'Days';

  @override
  String get rxDurationInvalid => '1–365 days';

  @override
  String get rxTimes => 'Reminder times (HH:MM)';

  @override
  String get rxTimesInvalid => 'Use 24-hour times like 08:00, 20:00';

  @override
  String get rxInstructions => 'Instructions';

  @override
  String get rxChecksTitle => 'Interaction & allergy check';

  @override
  String get rxCheckIdle => 'Checks run automatically as you add medicines.';

  @override
  String get rxChecking => 'Checking…';

  @override
  String get rxNoWarnings => 'No interactions or allergy conflicts found.';

  @override
  String rxPack(String pack) {
    return 'Knowledge pack $pack';
  }

  @override
  String get sevMajor => 'Major';

  @override
  String get sevModerate => 'Moderate';

  @override
  String get sevInfo => 'Info';

  @override
  String get warnAllergy => 'Allergy';

  @override
  String get warnDuplicate => 'Duplicate therapy';

  @override
  String get warnInteraction => 'Interaction';

  @override
  String get warnDoseForm => 'Dose / form';

  @override
  String get rxAcknowledge =>
      'I have reviewed the major warnings and still want to prescribe';

  @override
  String get rxOverrideReason => 'Clinical reason for overriding';

  @override
  String rxOverrideReasonHint(int min) {
    return 'At least $min characters. Audited.';
  }

  @override
  String get rxMajorBlocked =>
      'Major warnings need your acknowledgement and a reason.';

  @override
  String get rxClinicalNote => 'Clinical note (on the prescription)';

  @override
  String get rxAdvice => 'Advice';

  @override
  String get rxFollowUpDays => 'Follow up in (days)';

  @override
  String get rxSign => 'Create prescription';

  @override
  String get rxCreated => 'Prescription created and shared with the patient';

  @override
  String rxPdfTitle(String name) {
    return 'Prescription · $name';
  }

  @override
  String get formTablet => 'Tablet';

  @override
  String get formCapsule => 'Capsule';

  @override
  String get formSyrup => 'Syrup';

  @override
  String get formInjection => 'Injection';

  @override
  String get formOintment => 'Ointment';

  @override
  String get formDrops => 'Drops';

  @override
  String get formInhaler => 'Inhaler';

  @override
  String get formOther => 'Other';

  @override
  String pdfDocument(String title) {
    return 'PDF document: $title';
  }

  @override
  String pageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get fileReady =>
      'The file is ready. Open it in your browser to view it.';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get carePlanTitle => 'Care plan';

  @override
  String get carePlanSummary => 'Summary';

  @override
  String get carePlanInstructions => 'Instructions for the patient';

  @override
  String get carePlanTasks => 'Tasks';

  @override
  String get carePlanMeds => 'Medications';

  @override
  String get carePlanSaved => 'Care plan saved';

  @override
  String get taskTitle => 'Task';

  @override
  String get taskType => 'Type';

  @override
  String get taskOwner => 'Who';

  @override
  String get taskDueInDays => 'Due in (days, optional)';

  @override
  String get taskMedication => 'Medication';

  @override
  String get taskTest => 'Test';

  @override
  String get taskFollowUp => 'Follow-up';

  @override
  String get taskLifestyle => 'Lifestyle';

  @override
  String get taskMonitoring => 'Monitoring';

  @override
  String get taskGeneral => 'General';

  @override
  String get ownerPatient => 'Patient';

  @override
  String get ownerCaregiver => 'Caregiver';

  @override
  String get ownerProvider => 'Care provider';

  @override
  String get followUpTitle => 'Follow-up';

  @override
  String get followUpAfterDays => 'After (days)';

  @override
  String get followUpMode => 'Mode';

  @override
  String get followUpNone => 'No follow-up';

  @override
  String get referTitle => 'Refer to hospital';

  @override
  String get referSearchHospital => 'Search hospitals';

  @override
  String get referNoHospitals => 'No hospitals found.';

  @override
  String get referSpecialty => 'Specialty (optional)';

  @override
  String get referReason => 'Reason for referral';

  @override
  String get referSummary => 'Clinical summary (optional)';

  @override
  String get referSend => 'Create referral letter';

  @override
  String get referSaved => 'Referral created. The patient has been notified.';

  @override
  String get emergency24x7 => '24×7 emergency';

  @override
  String get enrolTitle => 'Enrol in care program';

  @override
  String get enrolThresholds => 'Alert thresholds';

  @override
  String get enrolSave => 'Enrol patient';

  @override
  String get enrolSaved => 'Patient enrolled';

  @override
  String get fixtureWarning =>
      'Template not yet clinically approved (fixture).';

  @override
  String get exerciseTitle => 'Exercise plan';

  @override
  String get exerciseWeeks => 'Weeks';

  @override
  String get exerciseSets => 'Sets';

  @override
  String get exerciseReps => 'Reps';

  @override
  String get exercisePerDay => 'Per day';

  @override
  String get planSaved => 'Plan shared with the patient';

  @override
  String get dietTitle => 'Diet plan';

  @override
  String get dietTemplate => 'Template';

  @override
  String get dietNoTemplate => 'No template';

  @override
  String get dietConditions => 'Conditions (comma separated)';

  @override
  String get dietCalories => 'Calorie target (optional)';

  @override
  String get dietMeals => 'Meals';

  @override
  String get dietMealsHint => 'Separate items with commas.';

  @override
  String dietMealsCount(int count) {
    return '$count meals filled';
  }

  @override
  String get dietNeedMeals => 'Choose a template or fill at least one meal.';

  @override
  String get dietAvoid => 'Avoid (comma separated)';

  @override
  String get dietNotes => 'Notes';

  @override
  String dietValidWeeks(int weeks) {
    return 'Valid for $weeks weeks';
  }

  @override
  String get slotEarlyMorning => 'Early morning';

  @override
  String get slotBreakfast => 'Breakfast';

  @override
  String get slotMidMorning => 'Mid-morning';

  @override
  String get slotLunch => 'Lunch';

  @override
  String get slotEvening => 'Evening';

  @override
  String get slotDinner => 'Dinner';

  @override
  String get slotBedtime => 'Bedtime';

  @override
  String get patientTitle => 'Patient';

  @override
  String get patientSearchHint => 'Search your patients by name';

  @override
  String get patientsEmpty =>
      'Patients you consult or who share records with you appear here.';

  @override
  String get patientsNoMatch => 'No patients match your search.';

  @override
  String get bloodGroup => 'Blood group';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabRecords => 'Records';

  @override
  String get tabVitals => 'Vitals';

  @override
  String get tabPrograms => 'Programs';

  @override
  String get tabPrescriptions => 'Prescriptions';

  @override
  String get tabEpisodes => 'Episodes';

  @override
  String get recordsEmpty => 'No records shared.';

  @override
  String get openOriginal => 'Open original file';

  @override
  String get recLab => 'Lab report';

  @override
  String get recPrescription => 'Prescription';

  @override
  String get recImaging => 'Imaging';

  @override
  String get recDischarge => 'Discharge summary';

  @override
  String get recVisitSummary => 'Visit summary';

  @override
  String get recOther => 'Other';

  @override
  String get vitalsEmpty => 'No vitals recorded.';

  @override
  String vitalRange(String min, String max) {
    return 'Range $min–$max';
  }

  @override
  String readingsCount(int count) {
    return '$count readings';
  }

  @override
  String vitalTrendSemantics(String vital, String min, String max, int count) {
    return '$vital trend: $count readings between $min and $max';
  }

  @override
  String get vitalBpSystolic => 'BP systolic';

  @override
  String get vitalBpDiastolic => 'BP diastolic';

  @override
  String get vitalPulse => 'Pulse';

  @override
  String get vitalSpo2 => 'SpO2';

  @override
  String get vitalTemperature => 'Temperature';

  @override
  String get vitalGlucose => 'Blood glucose';

  @override
  String get vitalWeight => 'Weight';

  @override
  String get vitalRespiratoryRate => 'Respiratory rate';

  @override
  String get programsEmpty => 'Not enrolled in any care program.';

  @override
  String get programAdherence => 'Adherence (7 days)';

  @override
  String get programLastReading => 'Last reading';

  @override
  String get programOpenBreaches => 'Open alerts';

  @override
  String get progActive => 'Active';

  @override
  String get progPaused => 'Paused';

  @override
  String get progCompleted => 'Completed';

  @override
  String get prescriptionsEmpty => 'No prescriptions yet.';

  @override
  String get episodesEmpty => 'No care episodes.';

  @override
  String get inboxEmpty => 'No care-team conversations yet.';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String unreadCount(int count) {
    return '$count unread';
  }

  @override
  String get messageHint => 'Message the care team';

  @override
  String get emergencyNotice => 'Emergency safety notice';

  @override
  String get secondOpinionsTitle => 'Second opinions';

  @override
  String get soTabOpen => 'Open';

  @override
  String get soTabMine => 'Mine';

  @override
  String get soEmpty => 'No requests here.';

  @override
  String get soOpen => 'Open';

  @override
  String get soClaimed => 'Claimed';

  @override
  String get soAnswered => 'Answered';

  @override
  String get soClaim => 'Claim';

  @override
  String get soClaimedMsg =>
      'Request claimed. Records are now shared with you.';

  @override
  String get soRespond => 'Write opinion';

  @override
  String get soOpinion => 'Opinion';

  @override
  String get soRecommendations => 'Recommendations';

  @override
  String get soSuggestTele => 'Suggest a teleconsultation';

  @override
  String get soSent => 'Opinion sent to the patient';

  @override
  String soDue(String date) {
    return 'Due $date';
  }

  @override
  String get escalationsTitle => 'Escalations';

  @override
  String get escalationsEmpty => 'No escalations for your patients.';

  @override
  String get scheduleTitle => 'Schedule & leaves';

  @override
  String get weeklyTab => 'Weekly hours';

  @override
  String get leavesTab => 'Leaves';

  @override
  String scheduleHint(int days) {
    return 'Saving regenerates unbooked slots for the next $days days. Booked slots are never changed.';
  }

  @override
  String get scheduleEmpty => 'No weekly hours yet.';

  @override
  String get addBlock => 'Add hours';

  @override
  String get blockTitle => 'Consultation hours';

  @override
  String get weekday => 'Day';

  @override
  String get startTime => 'Start';

  @override
  String get endTime => 'End';

  @override
  String get slotLength => 'Slot length';

  @override
  String slotMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get blockInvalidTime => 'Invalid time';

  @override
  String get blockEndBeforeStart => 'End must be after start';

  @override
  String get blockTooShort => 'Shorter than one slot';

  @override
  String get blockNoModes => 'Choose at least one mode';

  @override
  String get blockOverlap => 'Overlaps other hours on this day';

  @override
  String get saveSchedule => 'Save weekly hours';

  @override
  String get fixProblems => 'Fix the highlighted hours';

  @override
  String get scheduleSaved => 'Schedule saved';

  @override
  String get leavesEmpty => 'No leaves planned.';

  @override
  String get addLeave => 'Add leave';

  @override
  String get leaveReason => 'Reason (optional)';

  @override
  String get leaveAdded => 'Leave added';

  @override
  String leaveConflictsTitle(int count) {
    return '$count booked consultations on this day';
  }

  @override
  String get leaveConflictsBody =>
      'They are not cancelled automatically. Please ask the care team to reschedule them.';

  @override
  String get earningsTitle => 'Earnings';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get earnPayable => 'Payable to you';

  @override
  String earnServices(int count) {
    return '$count completed consultations';
  }

  @override
  String get earnGross => 'Gross';

  @override
  String get earnPlatformFee => 'Platform fee';

  @override
  String get earnRefunds => 'Refunds';

  @override
  String get earnLines => 'Details';

  @override
  String get earnEmpty => 'No paid consultations this month.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get photoGallery => 'Choose photo';

  @override
  String get photoCamera => 'Take photo';

  @override
  String get photoUpdated => 'Photo updated';

  @override
  String get photoTooLarge => 'The photo must be under 5 MB.';

  @override
  String regNo(String number) {
    return 'Reg. $number';
  }

  @override
  String ratingLine(String rating, int count) {
    return '★ $rating ($count reviews)';
  }

  @override
  String get acceptingBookings => 'Accepting new bookings';

  @override
  String get acceptingBookingsHint =>
      'When off, you are hidden from doctor search.';

  @override
  String get bookingsOn => 'You are accepting bookings';

  @override
  String get bookingsOff => 'Bookings paused';

  @override
  String get feesTitle => 'Consultation fees';

  @override
  String get qualifications => 'Qualifications';

  @override
  String get languagesSpoken => 'Languages spoken';

  @override
  String get bio => 'About you';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get languageTitle => 'Language';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmBody =>
      'You will need your phone OTP and authenticator code to sign in again.';

  @override
  String serverChip(String host) {
    return 'Server: $host';
  }

  @override
  String get serverAddressTitle => 'Server address';

  @override
  String get serverAddressHelp =>
      'Enter the CareCompanion server address, for example 10.10.17.134, http://10.10.17.134:4000 or a tunnel link like https://xyz.trycloudflare.com.';

  @override
  String get serverAddressLabel => 'Server URL or IP address';

  @override
  String get serverAddressInvalid =>
      'Enter an address like 10.10.17.134 or https://example.com';

  @override
  String get serverTestConnection => 'Test connection';

  @override
  String get serverTesting => 'Testing connection…';

  @override
  String serverConnectedVersion(String version) {
    return 'Connected. Server version $version';
  }

  @override
  String get serverCantReach =>
      'Can\'t reach the server: check the PC is running START-CARECOMPANION.bat and the phone is on the same network, or use the tunnel link.';

  @override
  String serverNotCareCompanion(String status) {
    return 'The server answered (HTTP $status) but it is not the CareCompanion API. Check the address.';
  }

  @override
  String get serverSave => 'Save';

  @override
  String get serverReset => 'Reset to default';

  @override
  String serverDefaultIs(String url) {
    return 'Default: $url';
  }

  @override
  String get serverSignOutWarning => 'Changing the server signs you out.';

  @override
  String serverCantReachAt(String host) {
    return 'Can\'t reach the server at $host';
  }

  @override
  String get serverChange => 'Change server';
}
