// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CareCompanion Pro';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonLogout => 'Log out';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNotAvailable => 'Not available';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'You appear to be offline. Check your connection and try again.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get loginTitle => 'Provider sign in';

  @override
  String get loginSubtitle =>
      'For verified nurses, technicians and field medical workers.';

  @override
  String get loginPhoneLabel => 'Mobile number';

  @override
  String get loginPhoneHint => '10-digit mobile number';

  @override
  String get loginPhoneInvalid => 'Enter a valid 10-digit mobile number';

  @override
  String get loginSendOtp => 'Send OTP';

  @override
  String get loginOtpLabel => '6-digit OTP';

  @override
  String get loginOtpInvalid => 'Enter the 6-digit OTP';

  @override
  String loginOtpSentTo(String phone) {
    return 'OTP sent to $phone';
  }

  @override
  String get loginVerify => 'Verify and continue';

  @override
  String get loginChangeNumber => 'Change number';

  @override
  String loginDevOtpHint(String otp) {
    return 'Development OTP: $otp';
  }

  @override
  String get restrictedTitle => 'Access restricted to verified care providers';

  @override
  String get restrictedBody =>
      'This app is only for home-care providers registered with CareCompanion. If you are a patient or family member, please use the CareCompanion patient app.';

  @override
  String get blockedTitle => 'You can\'t receive visits right now';

  @override
  String get blockedNoVisits =>
      'No home visits can be assigned to you until your verification is active.';

  @override
  String get blockedPending =>
      'Your professional verification is pending review by the CareCompanion operations team.';

  @override
  String get blockedExpired =>
      'Your professional credential has expired. Please renew it and share the updated document with your coordinator.';

  @override
  String blockedExpiredOn(String date) {
    return 'Credential expired on $date.';
  }

  @override
  String get blockedSuspended =>
      'Your provider account has been suspended. Please contact your care coordinator for details.';

  @override
  String get blockedRejected =>
      'Your verification was not approved. Please contact your care coordinator.';

  @override
  String get blockedCheckAgain => 'Check status again';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeDutyOn => 'On duty';

  @override
  String get homeDutyOff => 'Off duty';

  @override
  String get homeDutyOnHint => 'You can be matched to new home visits.';

  @override
  String get homeDutyOffHint => 'Go on duty to receive new home visits.';

  @override
  String get homeDutyToggleLabel => 'Duty status';

  @override
  String get homeDutyFailed =>
      'Could not update duty status. You need to be online.';

  @override
  String get homeTodaySummary => 'Today';

  @override
  String get homeSummaryTotal => 'Visits';

  @override
  String get homeSummaryActive => 'Active';

  @override
  String get homeSummaryDone => 'Done';

  @override
  String homeNextVisit(String time) {
    return 'Next: $time';
  }

  @override
  String get tabToday => 'Today';

  @override
  String get tabUpcoming => 'Upcoming';

  @override
  String get tabCompleted => 'Completed';

  @override
  String get visitsEmptyToday => 'No visits for today.';

  @override
  String get visitsEmptyUpcoming => 'No upcoming visits.';

  @override
  String get visitsEmptyCompleted => 'No completed visits yet.';

  @override
  String get visitsShowingCached => 'Offline – showing saved data';

  @override
  String get profileTooltip => 'Profile';

  @override
  String get offlineBanner =>
      'You are offline. Actions will be saved and synced later.';

  @override
  String pendingSync(int count) {
    return 'Pending sync ($count)';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncAccessRevoked =>
      'A visit is no longer assigned to you. Its unsynced changes were discarded and saved patient data was removed.';

  @override
  String syncRejected(String message) {
    return 'The server did not accept a saved action: $message';
  }

  @override
  String get actionQueued =>
      'Saved offline. It will sync when you are back online.';

  @override
  String get actionDone => 'Updated';

  @override
  String get statusRequested => 'Requested';

  @override
  String get statusUnassigned => 'Unassigned';

  @override
  String get statusAssigned => 'New assignment';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusEnRoute => 'En route';

  @override
  String get statusArrived => 'Arrived';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusEscalated => 'Escalated';

  @override
  String get visitTitle => 'Home visit';

  @override
  String get visitTimeWindow => 'Time window';

  @override
  String get visitReason => 'Reason for visit';

  @override
  String get visitAddress => 'Address';

  @override
  String visitAreaOnly(String city, String pincode) {
    return '$city – $pincode';
  }

  @override
  String get visitAddressHidden =>
      'Full address is shown after you accept the visit.';

  @override
  String visitLandmark(String landmark) {
    return 'Landmark: $landmark';
  }

  @override
  String get visitNavigate => 'Navigate';

  @override
  String get visitNavigateFailed => 'Could not open maps.';

  @override
  String get visitPatient => 'Patient';

  @override
  String get visitPatientContext => 'Patient context';

  @override
  String visitAgeGender(String age, String gender) {
    return '$age yrs · $gender';
  }

  @override
  String get visitAllergies => 'Allergies';

  @override
  String get visitNoAllergiesRecorded => 'No allergies recorded';

  @override
  String get visitConditions => 'Conditions';

  @override
  String get visitMedications => 'Active medications';

  @override
  String get visitNoneRecorded => 'None recorded';

  @override
  String get visitContextUnavailable =>
      'Patient context is not available for this visit.';

  @override
  String get visitTimeline => 'Status timeline';

  @override
  String get visitPendingSyncChip => 'Pending sync';

  @override
  String visitEta(int minutes) {
    return 'ETA $minutes min';
  }

  @override
  String get visitNotFound => 'This visit is no longer available to you.';

  @override
  String get visitRecordedVitals => 'Recorded vitals';

  @override
  String get visitSummary => 'Visit summary';

  @override
  String get visitEscalation => 'Escalation';

  @override
  String get stepAccept => 'Accept';

  @override
  String get stepTravel => 'Travel';

  @override
  String get stepArrive => 'Arrive';

  @override
  String get stepVerify => 'Verify';

  @override
  String get stepCare => 'Checkup';

  @override
  String get stepComplete => 'Complete';

  @override
  String stepperLabel(int current, int total) {
    return 'Visit progress: step $current of $total';
  }

  @override
  String get actionAccept => 'Accept visit';

  @override
  String get actionReject => 'Reject';

  @override
  String get actionRejectTitle => 'Reject this visit?';

  @override
  String get actionRejectReason => 'Reason';

  @override
  String get actionRejectReasonRequired => 'Please give a reason';

  @override
  String get actionStartTravel => 'Start travel';

  @override
  String get actionEtaLabel => 'Estimated arrival (minutes)';

  @override
  String get actionEtaInvalid => 'Enter minutes between 1 and 240';

  @override
  String get actionArrived => 'I have arrived';

  @override
  String get actionVerifyTitle => 'Verify patient';

  @override
  String get actionVerifyBody =>
      'Ask the patient or guardian to read out the 4-digit visit code shown in their app.';

  @override
  String get actionVisitCode => 'Visit code';

  @override
  String get actionVisitCodeInvalid => 'Enter the 4-digit code';

  @override
  String get actionConsent => 'Patient/guardian consents to the checkup';

  @override
  String get actionConsentRequired =>
      'Consent must be confirmed before starting';

  @override
  String get actionVerify => 'Verify and start checkup';

  @override
  String get actionVerifyOfflineNote =>
      'You are offline. The code will be checked when you reconnect.';

  @override
  String get actionComplete => 'Complete visit';

  @override
  String get actionCompleteTitle => 'Complete visit';

  @override
  String get actionSummaryLabel => 'Visit summary';

  @override
  String get actionSummaryHint =>
      'What was done, observations shared with the patient, any follow-up needed';

  @override
  String get actionSummaryRequired => 'Please write a short summary';

  @override
  String get nextAwaitingAssignment => 'Waiting for assignment.';

  @override
  String get nextNoAction => 'No further action needed.';

  @override
  String get nextCancelled => 'This visit was cancelled.';

  @override
  String get nextReassigned => 'This visit is no longer assigned to you.';

  @override
  String get nextVerifyIntro =>
      'Verify the patient\'s identity and consent before starting.';

  @override
  String get nextCareIntro =>
      'Record vitals and observations, then complete the visit.';

  @override
  String get nextEscalatedIntro =>
      'This visit has been escalated. You can still complete it.';

  @override
  String get escalateButton => 'Escalate';

  @override
  String get escalateTitle => 'Escalate to supervising doctor';

  @override
  String get escalateReason => 'What is the concern?';

  @override
  String get escalateReasonRequired => 'Please describe the concern';

  @override
  String get escalateSeverity => 'Severity';

  @override
  String get escalateUrgent => 'Urgent';

  @override
  String get escalateEmergency => 'Emergency';

  @override
  String get escalateEmergencyHint =>
      'For a life-threatening emergency, call 108 immediately.';

  @override
  String get escalateCall108 => 'Call 108';

  @override
  String get escalateConfirmTitle => 'Confirm escalation';

  @override
  String escalateConfirmBody(String severity) {
    return 'This alerts the clinical team immediately with severity: $severity. Continue?';
  }

  @override
  String get escalateSend => 'Send escalation';

  @override
  String get vitalsTitle => 'Vitals';

  @override
  String get vitalsSave => 'Save vitals';

  @override
  String get vitalsSaved => 'Vitals saved';

  @override
  String get vitalsBpSystolic => 'BP systolic';

  @override
  String get vitalsBpDiastolic => 'BP diastolic';

  @override
  String get vitalsPulse => 'Pulse';

  @override
  String get vitalsSpo2 => 'SpO2';

  @override
  String get vitalsTemperature => 'Temperature';

  @override
  String get vitalsBloodGlucose => 'Blood glucose';

  @override
  String get vitalsWeight => 'Weight';

  @override
  String get vitalsRespiratoryRate => 'Respiratory rate';

  @override
  String get vitalsErrorNumber => 'Enter a number';

  @override
  String vitalsErrorRange(String min, String max) {
    return 'Must be between $min and $max';
  }

  @override
  String get vitalsErrorBpPair => 'Enter both systolic and diastolic';

  @override
  String get vitalsErrorBpOrder => 'Diastolic must be lower than systolic';

  @override
  String get vitalsErrorEmpty => 'Enter at least one vital';

  @override
  String get vitalsNoInterpretation =>
      'Values are recorded as measured. Clinical review is done by the care team.';

  @override
  String get obsTitle => 'Observations';

  @override
  String get obsAlertOriented => 'Patient alert and oriented';

  @override
  String get obsMedicationsReviewed => 'Medications reviewed';

  @override
  String get obsMobilityObserved => 'Mobility observed';

  @override
  String get obsCaregiverPresent => 'Caregiver present';

  @override
  String get obsHomeSafe => 'Home environment safe';

  @override
  String get obsConcernsNoted => 'Patient concerns noted';

  @override
  String get obsNotes => 'Notes';

  @override
  String get obsNotesHint => 'Factual observations only';

  @override
  String get obsSave => 'Save observations';

  @override
  String get obsSaved => 'Observations saved';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileType => 'Role';

  @override
  String get profileQualification => 'Qualification';

  @override
  String get profileVerification => 'Verification';

  @override
  String get profileCredentialExpiry => 'Credential valid until';

  @override
  String profileCredentialExpiring(int days) {
    return 'Your credential expires in $days days. Renew it to keep receiving visits.';
  }

  @override
  String get profileZones => 'Service zones';

  @override
  String get profileCapabilities => 'Capabilities';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profilePhone => 'Phone';

  @override
  String get profileLogoutConfirm => 'Log out?';

  @override
  String profileLogoutPending(int count) {
    return '$count unsynced actions will be discarded if you log out now.';
  }

  @override
  String get profileLogoutBody =>
      'Saved visit data on this device will be removed.';

  @override
  String get typeNurse => 'Nurse';

  @override
  String get typeTechnician => 'Technician';

  @override
  String get typeIntern => 'Intern';

  @override
  String get typePhysiotherapist => 'Physiotherapist';

  @override
  String get verificationVerified => 'Verified';

  @override
  String get verificationPending => 'Pending';

  @override
  String get verificationRejected => 'Rejected';

  @override
  String get verificationSuspended => 'Suspended';

  @override
  String get verificationExpired => 'Expired';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get errorMfaRequired =>
      'This account needs two-step verification, which the provider app doesn\'t support. Please contact support.';

  @override
  String get mfaTitle => 'Extra verification required';

  @override
  String get mfaBody =>
      'Your account is set up to require two-step verification (MFA). CareCompanion Pro does not support this for provider accounts. Please contact your coordinator or support so they can correct your account. Your queued visit updates are kept on this device.';

  @override
  String get updateTitle => 'Update required';

  @override
  String get updateBody =>
      'This version of CareCompanion Pro is no longer supported. Please install the latest version to keep receiving visits.';

  @override
  String updateVersions(String current, String minimum) {
    return 'Installed $current · Required $minimum';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get photoAdd => 'Add photo';

  @override
  String get photoSectionTitle => 'Visit photo (optional)';

  @override
  String get photoSectionHint =>
      'Only if it helps care (for example a wound or a device). Requires the patient\'s consent.';

  @override
  String get photoConsentTitle => 'Patient consent';

  @override
  String get photoConsentBody =>
      'The photo will be saved to the patient\'s health record. Avoid faces and anything not needed for care.';

  @override
  String get photoConsent =>
      'The patient (or their caregiver) has agreed to this photo being taken and saved to their record.';

  @override
  String get photoConsentRequired =>
      'Patient consent is required before taking a photo.';

  @override
  String get photoOpenCamera => 'Open camera';

  @override
  String get photoUploaded => 'Photo uploaded to the patient\'s record.';

  @override
  String get photoQueued =>
      'Photo saved. It will upload when you\'re back online.';

  @override
  String get photoNoPermission =>
      'You don\'t have permission to add photos to this patient\'s record. Please contact your coordinator.';

  @override
  String get photoFileMissing =>
      'A queued photo could not be uploaded because it is no longer on this device. Please take it again.';

  @override
  String get photoCameraFailed => 'Couldn\'t open the camera.';

  @override
  String get profileSupport => 'Help & support';

  @override
  String get profileSupportCall => 'Call support';

  @override
  String get profileSupportEmail => 'Email support';

  @override
  String get profileSupportWhatsapp => 'WhatsApp support';

  @override
  String get profileSupportUnavailable =>
      'Support contacts aren\'t available right now. Please contact your coordinator.';

  @override
  String get profilePrivacy => 'Privacy policy';

  @override
  String get profileTerms => 'Terms of service';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileCloseAccount => 'Request account closure';

  @override
  String get profileCloseAccountBody =>
      'Provider accounts are staff accounts and can\'t be deleted from the app. Contact support to request closure: an administrator will disable your account and handle your data under the retention policy.';

  @override
  String get profileCloseAccountSubject => 'Provider account closure request';

  @override
  String get profileLinkFailed => 'Couldn\'t open the link.';

  @override
  String profileAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String get commonDelete => 'Delete';

  @override
  String get typeDoctor => 'Doctor';

  @override
  String get onbTitle => 'Apply to join as a care provider';

  @override
  String get onbIntro =>
      'This account isn\'t registered as a care provider yet. Apply below: our team verifies every provider before any visit can be assigned.';

  @override
  String get onbEditTitle => 'Edit your application';

  @override
  String get onbStepRole => 'Role';

  @override
  String get onbStepDetails => 'Qualification';

  @override
  String get onbStepAreas => 'Languages and areas';

  @override
  String get onbStepReview => 'Review';

  @override
  String get onbTypeLabel => 'I am applying as';

  @override
  String get onbDoctorNote =>
      'Doctors use the CareCompanion web portal after approval, not this app. You can still apply here.';

  @override
  String get onbFullName => 'Full name (as on your registration)';

  @override
  String get onbQualification => 'Qualification (e.g. GNM, B.Sc Nursing, DMLT)';

  @override
  String get onbRegNumber => 'Registration number';

  @override
  String get onbRegCouncil => 'Registration council (optional)';

  @override
  String get onbSpecialty => 'Specialty';

  @override
  String get onbExperience => 'Experience (years)';

  @override
  String get onbRequired => 'Required';

  @override
  String get onbExperienceInvalid => 'Enter a number of years from 0 to 60';

  @override
  String get onbLanguages => 'Languages you speak';

  @override
  String get onbLanguagesRequired => 'Select at least one language';

  @override
  String get onbAreas => 'Preferred work areas';

  @override
  String get onbAreasHint =>
      'Add the pincodes where you would like to work. Each pincode is matched to one of our service zones. Optional.';

  @override
  String get onbPincode => 'Pincode';

  @override
  String get onbPincodeInvalid => 'Enter a 6-digit pincode';

  @override
  String get onbAddArea => 'Add';

  @override
  String get onbZoneSaved => 'Saved area';

  @override
  String onbAreaNotServiceable(String pincode) {
    return 'We don\'t serve pincode $pincode yet. You can still apply.';
  }

  @override
  String get onbReviewDocsNote =>
      'After you submit, upload your documents. A registration certificate and an ID proof are required for approval.';

  @override
  String get onbNext => 'Next';

  @override
  String get onbSubmit => 'Submit application';

  @override
  String get onbResubmit => 'Resubmit application';

  @override
  String get onbSubmitted => 'Application submitted';

  @override
  String get onbCancelEdit => 'Cancel editing';

  @override
  String get onbStatusSubmittedTitle => 'Application under review';

  @override
  String get onbStatusSubmittedBody =>
      'Our team is reviewing your application. You\'ll be notified when there is a decision.';

  @override
  String get onbStatusChangesTitle => 'Changes requested';

  @override
  String get onbStatusChangesBody =>
      'The reviewer asked for changes. Update your details or documents, then resubmit.';

  @override
  String get onbStatusRejectedTitle => 'Application not approved';

  @override
  String get onbStatusRejectedBody =>
      'Your application was not approved. Contact support if you have questions.';

  @override
  String get onbReviewerNote => 'Reviewer\'s note';

  @override
  String onbReviewerNoteBy(String name) {
    return 'Note from $name';
  }

  @override
  String get onbEditResubmit => 'Edit & resubmit';

  @override
  String get onbEditDetails => 'Edit details';

  @override
  String get onbApprovedTitle => 'You\'re approved';

  @override
  String get onbApprovedBody =>
      'Your application has been approved. Sign out and sign in again to start.';

  @override
  String get onbApprovedDoctorBody =>
      'Your doctor account is approved. Sign in to the CareCompanion web portal to set up your schedule.';

  @override
  String get onbSignOutAndIn => 'Sign out and sign in again';

  @override
  String get onbCheckStatus => 'Check status';

  @override
  String onbUpdatedOn(String date) {
    return 'Last updated $date';
  }

  @override
  String get onbDocuments => 'Documents';

  @override
  String onbDocsMissing(String docs) {
    return 'Still needed: $docs';
  }

  @override
  String get onbDocsComplete => 'All required documents are uploaded.';

  @override
  String get onbDocsHint => 'PDF, JPG or PNG, up to 10 MB each.';

  @override
  String get onbNoDocuments => 'No documents uploaded yet.';

  @override
  String get onbAddDocument => 'Add document';

  @override
  String get onbDocType => 'Document type';

  @override
  String get docRegistrationCertificate => 'Registration certificate';

  @override
  String get docDegree => 'Degree or diploma';

  @override
  String get docIdProof => 'ID proof';

  @override
  String get docExperienceLetter => 'Experience letter';

  @override
  String get docOther => 'Other';

  @override
  String get sourceCamera => 'Take a photo';

  @override
  String get sourceGallery => 'Choose from gallery';

  @override
  String get sourceFiles => 'Choose a file (PDF, JPG, PNG)';

  @override
  String onbUploading(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String onbUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get onbFileTooLarge => 'This file is larger than 10 MB.';

  @override
  String get onbDeleteDocConfirm => 'Delete this document?';

  @override
  String get earnTitle => 'Earnings';

  @override
  String get earnEntrySubtitle => 'Completed services and payouts';

  @override
  String get earnCompleted => 'Completed services';

  @override
  String get earnGross => 'Gross';

  @override
  String get earnPlatformFee => 'Platform fee';

  @override
  String get earnRefunds => 'Refunds';

  @override
  String get earnPayable => 'Payable to you';

  @override
  String get earnLines => 'Services';

  @override
  String get earnEmpty => 'No completed and paid services in this month.';

  @override
  String get earnPrevMonth => 'Previous month';

  @override
  String get earnNextMonth => 'Next month';

  @override
  String get earnNote =>
      'Only completed and paid services count. Payouts are settled by the operations team.';

  @override
  String get earnRefHomeVisit => 'Home visit';

  @override
  String get earnRefAppointment => 'Appointment';

  @override
  String earnLineDetail(String fee, String payable) {
    return 'Fee $fee · Payable $payable';
  }

  @override
  String get avatarChange => 'Change profile photo';

  @override
  String get avatarPreviewTitle => 'Use this photo?';

  @override
  String get avatarPreviewBody =>
      'Patients see this photo when you are assigned to their visit.';

  @override
  String get avatarUse => 'Use photo';

  @override
  String get avatarUploaded => 'Profile photo updated';

  @override
  String get avatarTooLarge => 'The photo must be smaller than 5 MB.';

  @override
  String profileRating(String rating, int count) {
    return '$rating ★ ($count ratings)';
  }

  @override
  String get voiceDictate => 'Dictate notes';

  @override
  String get voiceStop => 'Stop dictation';

  @override
  String get voiceListening => 'Listening… speak now';

  @override
  String get voiceReview =>
      'Dictated text was added to the notes. Review and correct it before saving.';

  @override
  String get voiceUnavailable =>
      'Voice input isn\'t available on this device, or microphone permission was denied.';

  @override
  String get typeDietitian => 'Dietitian';

  @override
  String get tabRoute => 'Route';

  @override
  String get optionalHint => 'Optional';

  @override
  String planFor(String name) {
    return 'For $name';
  }

  @override
  String get routeEmpty => 'No stops on your route today.';

  @override
  String routeSummary(int count, String km) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0 · $km km in total';
  }

  @override
  String get routeFromLastLocation =>
      'Distances start from your last reported location.';

  @override
  String get routeFromCurrentLocation =>
      'Distances start from your service zone centre.';

  @override
  String get routeStartNavigation => 'Start navigation';

  @override
  String routeTooManyStops(int count) {
    return 'Google Maps shows the first $count stops. Open navigation again after them.';
  }

  @override
  String routeFromStart(String km) {
    return '$km km from start';
  }

  @override
  String routeFromPrev(String km) {
    return '$km km from previous stop';
  }

  @override
  String routeEta(String time) {
    return 'ETA $time';
  }

  @override
  String routeStopLabel(
    int index,
    String service,
    String window,
    String details,
  ) {
    return 'Stop $index: $service, $window. $details';
  }

  @override
  String get attTitle => 'Attendance';

  @override
  String get attUnknown => 'Attendance status unavailable';

  @override
  String get attNotCheckedIn => 'Not checked in today';

  @override
  String get attNotCheckedInHint => 'Check in when you start your shift.';

  @override
  String attCheckedInAt(String time) {
    return 'Checked in at $time';
  }

  @override
  String attCheckedOutAt(String time) {
    return 'Checked out at $time';
  }

  @override
  String get attCheckIn => 'Check in';

  @override
  String get attCheckOut => 'Check out';

  @override
  String get attCheckedInToast => 'Checked in.';

  @override
  String get attCheckedOutToast => 'Checked out.';

  @override
  String get attNoLocation => '(Location was not available.)';

  @override
  String get attDaysPresent => 'Days present';

  @override
  String get attHours => 'Hours';

  @override
  String get attVisits => 'Visits';

  @override
  String get attDaily => 'Day by day';

  @override
  String get attEmpty => 'No attendance recorded this month.';

  @override
  String get attAbsent => 'No check-in';

  @override
  String get attOpen => 'not checked out';

  @override
  String attHoursShort(String hours) {
    return '$hours h';
  }

  @override
  String attVisitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
      zero: 'No visits',
    );
    return '$_temp0';
  }

  @override
  String get supTitle => 'Supplies';

  @override
  String get supEmpty => 'No supplies are assigned to you.';

  @override
  String supLowBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are running low. Ask your coordinator to restock.',
      one: '1 item is running low. Ask your coordinator to restock.',
    );
    return '$_temp0';
  }

  @override
  String get supLow => 'Low stock';

  @override
  String get supOut => 'Out of stock';

  @override
  String supReorderAt(String qty) {
    return 'Reorder at $qty';
  }

  @override
  String supOnHand(String qty) {
    return 'On hand: $qty';
  }

  @override
  String get supUsageTitle => 'Supplies used';

  @override
  String get supUsageHint =>
      'Enter what you used at this visit. It is saved even when you are offline.';

  @override
  String get supUsageCardBody =>
      'Record gloves, strips, swabs and other items used at this visit.';

  @override
  String get supUsageButton => 'Record supplies used';

  @override
  String get supUsageSave => 'Save usage';

  @override
  String get supUsageSaved => 'Supplies usage saved';

  @override
  String supIncrease(String name) {
    return 'Add one $name';
  }

  @override
  String supDecrease(String name) {
    return 'Remove one $name';
  }

  @override
  String get sampleTestsTitle => 'Lab tests to collect';

  @override
  String get sampleGeneric => 'Collect samples as per the lab order.';

  @override
  String get sampleFastingShort => 'Fasting';

  @override
  String get sampleFastingRequired =>
      'Fasting required. Confirm with the patient before collecting.';

  @override
  String sampleFastingHours(int hours) {
    return 'Fasting required ($hours h). Confirm with the patient before collecting.';
  }

  @override
  String get sampleNoFasting => 'No fasting needed for these tests.';

  @override
  String get sampleChecklistTitle => 'Before completing: sample checklist';

  @override
  String get samplePatientId => 'Patient ID verified';

  @override
  String get sampleFastingConfirmed =>
      'Fasting status confirmed with the patient';

  @override
  String get sampleFastingNotNeeded =>
      'Fasting not needed (checked with the patient)';

  @override
  String get sampleTubesLabelled => 'All tubes labelled';

  @override
  String get sampleCount => 'Number of samples';

  @override
  String get sampleCollectedConfirm => 'Samples collected';

  @override
  String get sampleCompleteHint => 'Confirm every item to complete the visit.';

  @override
  String sampleSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samples collected.',
      one: '1 sample collected.',
    );
    return '$_temp0 Tubes labelled, patient ID verified, fasting status confirmed.';
  }

  @override
  String get exCardTitle => 'Exercise plan';

  @override
  String get exCreateTitle => 'Create exercise plan';

  @override
  String get exChooseTitle => '1. Choose exercises';

  @override
  String get exAllAreas => 'All';

  @override
  String get exLibraryEmpty => 'No exercises for this body area.';

  @override
  String get exDosageTitle => '2. Sets and repetitions';

  @override
  String get exNoneSelected => 'Pick at least one exercise above.';

  @override
  String get exSets => 'Sets';

  @override
  String get exReps => 'Reps';

  @override
  String get exHold => 'Hold (s)';

  @override
  String get exPerDay => 'Per day';

  @override
  String get exNotes => 'Notes (optional)';

  @override
  String get exScheduleTitle => '3. Schedule';

  @override
  String get exStartDate => 'Start date';

  @override
  String get exWeeks => 'Weeks';

  @override
  String get exSave => 'Save exercise plan';

  @override
  String get exCreated => 'Exercise plan created';

  @override
  String get exErrNoExercises => 'Choose at least one exercise.';

  @override
  String exErrRange(String field, int min, int max) {
    return '$field must be between $min and $max.';
  }

  @override
  String get exErrStartDate => 'The start date cannot be in the past.';

  @override
  String get exNoPlans => 'No exercise plans for this patient yet.';

  @override
  String get exProgressUnavailable => 'Plan progress isn\'t available to you.';

  @override
  String exPlanLine(int count, String author) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
    );
    return '$_temp0 · $author';
  }

  @override
  String exProgressLine(int done, int planned, int pct) {
    return '$done/$planned sessions · $pct% adherence';
  }

  @override
  String exLatestPain(int score) {
    return 'latest pain $score/10';
  }

  @override
  String get dietCardTitle => 'Diet plan';

  @override
  String get dietCardBody => 'Create a meal plan for this patient.';

  @override
  String get dietCreateTitle => 'Create diet plan';

  @override
  String get dietTemplate => 'Template';

  @override
  String get dietNoTemplate => 'No template';

  @override
  String get dietGovernance =>
      '[REQUIRES CLINICAL GOVERNANCE] This template is not yet clinically approved. Review every item.';

  @override
  String get dietConditions => 'Conditions and target';

  @override
  String get dietAddCondition => 'Add condition';

  @override
  String get dietCalories => 'Calorie target (kcal/day)';

  @override
  String get dietMeals => 'Meals';

  @override
  String get dietMealsHint => 'Separate items with commas.';

  @override
  String get dietAvoid => 'Avoid and notes';

  @override
  String get dietAvoidHint => 'Foods to avoid (comma separated)';

  @override
  String get dietNotes => 'Notes (optional)';

  @override
  String get dietValidUntil => 'Valid until';

  @override
  String get dietSave => 'Save diet plan';

  @override
  String get dietCreated => 'Diet plan created';

  @override
  String get dietErrNoMeals => 'Add food items to at least one meal.';

  @override
  String get dietErrNoConditions => 'Add at least one condition.';

  @override
  String dietErrCalories(int min, int max) {
    return 'Calorie target must be between $min and $max.';
  }

  @override
  String get dietErrValidUntil => '\"Valid until\" must be after today.';

  @override
  String get slotEarlyMorning => 'Early morning';

  @override
  String get slotBreakfast => 'Breakfast';

  @override
  String get slotMidMorning => 'Mid-morning';

  @override
  String get slotLunch => 'Lunch';

  @override
  String get slotEvening => 'Evening snack';

  @override
  String get slotDinner => 'Dinner';

  @override
  String get slotBedtime => 'Bedtime';
}
