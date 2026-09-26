// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CareCompanion';

  @override
  String get tagline => 'Your health, our priority.';

  @override
  String get yourHealthOurPriority => 'Your health, our priority.';

  @override
  String get homeQuote => '“Small steps today, healthier tomorrow.”';

  @override
  String get goodMorning => 'Good Morning';

  @override
  String get goodAfternoon => 'Good Afternoon';

  @override
  String get goodEvening => 'Good Evening';

  @override
  String get robotSemantic => 'AI health assistant robot';

  @override
  String get loading => 'Loading';

  @override
  String get retry => 'Retry';

  @override
  String get seeAll => 'See All';

  @override
  String get continueLabel => 'Continue';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get skip => 'Skip';

  @override
  String get search => 'Search';

  @override
  String get change => 'Change';

  @override
  String get required => 'Required';

  @override
  String get optional => 'Optional';

  @override
  String get all => 'All';

  @override
  String get active => 'Active';

  @override
  String get closed => 'Closed';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get current => 'current';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get verified => 'Verified';

  @override
  String get unread => 'Unread';

  @override
  String get unavailable => 'unavailable';

  @override
  String get noResults => 'No results';

  @override
  String get results => 'Results';

  @override
  String get selectDate => 'Select date';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get fillRequired => 'Please fill all required fields';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get notNow => 'Not now';

  @override
  String get viewDetails => 'View details';

  @override
  String get goHome => 'Go to Home';

  @override
  String get moreOptions => 'More options';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String ageYears(int age) {
    return '$age years';
  }

  @override
  String durationMins(int minutes) {
    return '$minutes min';
  }

  @override
  String kmAway(String km) {
    return '$km km';
  }

  @override
  String get history => 'History';

  @override
  String get title => 'Title';

  @override
  String get value => 'Value';

  @override
  String get size => 'Size';

  @override
  String get file => 'File';

  @override
  String get image => 'Image';

  @override
  String get reason => 'Reason';

  @override
  String get noReasonGiven => 'No reason given';

  @override
  String get patient => 'Patient';

  @override
  String get call => 'Call';

  @override
  String get directions => 'Directions';

  @override
  String get send => 'Send';

  @override
  String get invite => 'Invite';

  @override
  String get revoke => 'Revoke';

  @override
  String get upload => 'Upload';

  @override
  String get uploaded => 'Uploaded successfully';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorGeneric => 'Please try again in a moment.';

  @override
  String get offlineTitle => 'You are offline';

  @override
  String get errorOffline => 'Check your internet connection and try again.';

  @override
  String get unauthorizedTitle => 'Session expired';

  @override
  String get errorSessionExpired => 'Please sign in again to continue.';

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get forbiddenTitle => 'No access';

  @override
  String get errorForbidden =>
      'You do not have permission for this family member.';

  @override
  String get errorConsentRequired => 'Your consent is needed for this feature.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Please wait and try again.';

  @override
  String get errorServer =>
      'Our service is temporarily unavailable. Please try again shortly.';

  @override
  String get errorNotFound => 'We could not find what you were looking for.';

  @override
  String get chooseLanguageTitle => 'Choose your language';

  @override
  String get chooseLanguageSubtitle =>
      'You can change this any time in Profile.';

  @override
  String get changeLanguage => 'Language';

  @override
  String get phoneTitle => 'Enter your mobile number';

  @override
  String get phoneSubtitle => 'We will send a 6-digit code to verify it.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneInvalid => 'Enter a valid 10-digit mobile number';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get phoneDisclaimer =>
      'By continuing you agree to receive an SMS for verification.';

  @override
  String get otpTitle => 'Verify your number';

  @override
  String otpSubtitle(String phone) {
    return 'Enter the code sent to $phone';
  }

  @override
  String get otpLabel => 'One-time password';

  @override
  String get otpInvalid => 'Enter the 6-digit code';

  @override
  String get otpWrong => 'That code is not correct or has expired';

  @override
  String get otpResent => 'A new code has been sent';

  @override
  String devOtpHint(String code) {
    return 'Dev OTP: $code';
  }

  @override
  String get useCode => 'Use';

  @override
  String get verify => 'Verify';

  @override
  String get resendOtp => 'Resend code';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get consentsTitle => 'Your privacy';

  @override
  String get consentsIntro =>
      'Please review and accept how we handle your health information. Required items are needed to use the app.';

  @override
  String get consentsRequiredHint => 'Tick all required items to continue';

  @override
  String get agreeAndContinue => 'Agree and continue';

  @override
  String get profileSetupTitle => 'About you';

  @override
  String get profileSetupSubtitle =>
      'This helps doctors and care teams know who they are helping.';

  @override
  String get fullName => 'Full name';

  @override
  String get nameRequired => 'Please enter your name';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get dateOfBirth => 'Date of birth';

  @override
  String get gender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get emergencyContactTitle => 'Emergency contact';

  @override
  String get emergencyContactSubtitle =>
      'We will alert this person if you use SOS or a fall is detected.';

  @override
  String get contactName => 'Contact name';

  @override
  String get relationLabel => 'Relation';

  @override
  String get relationHint => 'e.g. Son, Daughter, Spouse';

  @override
  String get relationSelf => 'Self';

  @override
  String get saveAndContinue => 'Save and continue';

  @override
  String get navHome => 'Home';

  @override
  String get navCare => 'Care';

  @override
  String get navAskAi => 'Ask AI';

  @override
  String get navRecords => 'Records';

  @override
  String get navProfile => 'Profile';

  @override
  String get notifications => 'Notifications';

  @override
  String notificationsUnread(int count) {
    return 'Notifications, $count unread';
  }

  @override
  String get switchFamilyMember => 'Switch family member';

  @override
  String actingFor(String name) {
    return 'Acting for $name';
  }

  @override
  String get actingForTitle => 'Who is this for?';

  @override
  String get actingForSubtitle =>
      'Bookings, records and AI chats will be for the selected person.';

  @override
  String get manageFamily => 'Manage family';

  @override
  String get aiHeroTitle => 'Hi, I\'m your\nAI Health Assistant';

  @override
  String get aiHeroSubtitle =>
      'Ask anything about your health, get instant guidance, or book a service.';

  @override
  String get howCanIHelp => 'How can I help you today?';

  @override
  String get openAssistant => 'Open AI assistant';

  @override
  String get voiceInput => 'Voice input';

  @override
  String get qaTalkToDoctor => 'Talk to a Doctor';

  @override
  String get qaTalkToDoctorSub => 'Online Consultation';

  @override
  String get qaHomeCheckup => 'Home Checkup';

  @override
  String get qaHomeCheckupSub => 'Book at your home';

  @override
  String get qaUploadReport => 'Upload Report';

  @override
  String get qaUploadReportSub => 'Get AI insights';

  @override
  String get qaOrderMedicines => 'Order Medicines';

  @override
  String get qaOrderMedicinesSub => 'Fast & Safe Delivery';

  @override
  String get bannerTitle => 'Care for every stage of life';

  @override
  String get bannerSubtitle =>
      'From prevention to recovery — we\'re with you always.';

  @override
  String get bannerScript => 'Healthier\nHappier\nYou ♡';

  @override
  String get exploreCarePlans => 'Explore Care Plans';

  @override
  String get quickAccess => 'Quick Access';

  @override
  String get qxSymptoms => 'Symptoms Checker';

  @override
  String get qxMentalWellness => 'Mental Wellness';

  @override
  String get qxWound => 'Wound Analysis';

  @override
  String get qxMedicineReminders => 'Medicine Reminders';

  @override
  String get qxHealthRecords => 'Health Records';

  @override
  String get qxFallDetection => 'Fall Detection';

  @override
  String get qxGovtSchemes => 'Govt. Health Schemes';

  @override
  String get qxFindHospitals => 'Find Hospitals';

  @override
  String get qxWearables => 'Wearables Connect';

  @override
  String get qxEmergencySos => 'Emergency SOS';

  @override
  String get todaysReminders => 'Today\'s Reminders';

  @override
  String get activeCare => 'Active Care';

  @override
  String nextStep(String action) {
    return 'Next: $action';
  }

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityEmergency => 'Emergency';

  @override
  String get todaysInsights => 'Today\'s Insights';

  @override
  String goalLabel(String goal) {
    return 'Goal: $goal';
  }

  @override
  String get searchHint => 'Search symptoms, doctors, tests...';

  @override
  String get searchEmptyTitle => 'What are you looking for?';

  @override
  String get searchEmptyMessage =>
      'Type at least 2 letters to search doctors, hospitals and medicines.';

  @override
  String askAiAbout(String query) {
    return 'Ask AI about \"$query\"';
  }

  @override
  String get symptomsViaAi => 'Check symptoms safely with guided questions';

  @override
  String get doctors => 'Doctors';

  @override
  String get hospitals => 'Hospitals';

  @override
  String get medicines => 'Medicines';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get aiAssistantTitle => 'AI Health Assistant';

  @override
  String get online => 'Online';

  @override
  String get newChat => 'New conversation';

  @override
  String get aiGeneratedLabel => 'AI-generated · not a diagnosis';

  @override
  String get typeOrSpeak => 'Type or speak...';

  @override
  String get listening => 'Listening...';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get assistantTyping => 'Assistant is typing…';

  @override
  String get messageNotSent => 'Message not sent';

  @override
  String get micPermissionDenied =>
      'Microphone permission is off. You can type your message instead.';

  @override
  String get voiceUnavailable =>
      'Voice input is not available on this device. Please type instead.';

  @override
  String get starterHeadache => 'I have a headache';

  @override
  String get starterSymptoms => 'Check my symptoms';

  @override
  String get starterHomeCheckup => 'Should I get a home checkup?';

  @override
  String get starterReport => 'Explain my test report';

  @override
  String questionProgress(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get emergencyAlertTitle => 'This may be an emergency';

  @override
  String get emergencyTemplate =>
      'Your symptoms may need urgent medical attention. Call 108 for an ambulance now or press SOS to alert your emergency contacts.';

  @override
  String get call108 => 'Call 108';

  @override
  String get sosButton => 'SOS';

  @override
  String routeBookDoctor(String specialty) {
    return 'Book a doctor: $specialty';
  }

  @override
  String get routeBookHomeCheckup => 'Book a home checkup';

  @override
  String get findDoctors => 'Find doctors';

  @override
  String get aiConsentTitle => 'Allow AI assistance?';

  @override
  String get aiConsentBody =>
      'The AI assistant uses the health details you share to ask follow-up questions and guide you to the right care.';

  @override
  String get aiConsentPoint1 =>
      'It does not diagnose — a doctor makes clinical decisions.';

  @override
  String get aiConsentPoint2 =>
      'Emergency warning signs are always checked by safety rules.';

  @override
  String get aiConsentPoint3 =>
      'You can withdraw this consent any time in Privacy settings.';

  @override
  String get allowAiAssistance => 'Allow AI assistance';

  @override
  String get talkToDoctorInstead => 'Talk to a doctor instead';

  @override
  String get askAiNow => 'Ask AI now';

  @override
  String get findADoctor => 'Find a Doctor';

  @override
  String get searchDoctorsHint => 'Search by name, speciality...';

  @override
  String get topDoctorsNearYou => 'Top Doctors Near You';

  @override
  String get noDoctorsTitle => 'No doctors found';

  @override
  String get noDoctorsMessage => 'Try another speciality or clear the filters.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get videoConsult => 'Video Consult';

  @override
  String get homeVisit => 'Home Visit';

  @override
  String yearsExperience(int years) {
    return '$years+ years';
  }

  @override
  String get availableNow => 'Available now';

  @override
  String nextAvailable(String time) {
    return 'Next: $time';
  }

  @override
  String get addFavorite => 'Add to favourites';

  @override
  String get removeFavorite => 'Remove from favourites';

  @override
  String get overview => 'Overview';

  @override
  String get availability => 'Availability';

  @override
  String get reviews => 'Reviews';

  @override
  String reviewsCount(int count) {
    return '($count reviews)';
  }

  @override
  String get about => 'About';

  @override
  String get registrationNumber => 'Registration no.';

  @override
  String get languagesSpoken => 'Languages';

  @override
  String get clinic => 'Clinic';

  @override
  String get whyThisDoctor => 'Why this doctor';

  @override
  String get noReviews => 'No reviews yet';

  @override
  String get verifiedPatient => 'Verified patient';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get noSlots => 'No slots on this day';

  @override
  String get noSlotsMessage => 'Please pick another date.';

  @override
  String get consultationType => 'Consultation Type';

  @override
  String get modeVideo => 'Video';

  @override
  String get modeAudio => 'Audio';

  @override
  String get modeChat => 'Chat';

  @override
  String get modeInClinic => 'In-clinic';

  @override
  String get reasonForVisit => 'Reason for visit';

  @override
  String get reasonHint => 'e.g. Fever since 2 days';

  @override
  String get defaultConsultReason => 'General consultation';

  @override
  String get selectASlot => 'Select a time slot';

  @override
  String confirmAppointmentFee(String amount) {
    return 'Confirm Appointment · $amount';
  }

  @override
  String get rescheduleToSlot => 'Reschedule to this slot';

  @override
  String get rescheduled => 'Appointment rescheduled';

  @override
  String get slotUnavailable =>
      'That slot was just taken. Please choose another time.';

  @override
  String get noBookPermission =>
      'You do not have booking permission for this family member.';

  @override
  String consultationWith(String name) {
    return 'Consultation with $name';
  }

  @override
  String get appointmentConfirmed => 'Appointment confirmed';

  @override
  String get amountPaid => 'Paid';

  @override
  String get viewAppointment => 'View appointment';

  @override
  String get bookingConfirmed => 'Booking confirmed';

  @override
  String get payment => 'Payment';

  @override
  String get totalAmount => 'Total amount';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String retryPaymentAmount(String amount) {
    return 'Retry payment · $amount';
  }

  @override
  String get simulateFailure => 'Simulate failure';

  @override
  String get payLater => 'Pay later';

  @override
  String get mockGatewayNote =>
      'Test payment gateway — no real money is charged.';

  @override
  String get paymentFailedBody =>
      'Payment failed. Your booking is not confirmed yet — please try again.';

  @override
  String get paymentFailedTitle => 'Payment failed';

  @override
  String get paymentPendingTitle => 'Payment pending';

  @override
  String get paymentNotConfirmedBody =>
      'Your booking will be confirmed only after payment succeeds.';

  @override
  String completePayment(String amount) {
    return 'Complete payment · $amount';
  }

  @override
  String get noPendingPayment => 'No pending payment found';

  @override
  String get payIfPending => 'Complete pending payment';

  @override
  String get payments => 'Payments';

  @override
  String get noPayments => 'No payments yet';

  @override
  String refunded(String amount) {
    return 'Refunded $amount';
  }

  @override
  String get payPending => 'Pending';

  @override
  String get paySucceeded => 'Paid';

  @override
  String get payFailed => 'Failed';

  @override
  String get payRefunded => 'Refunded';

  @override
  String get payPartiallyRefunded => 'Partly refunded';

  @override
  String get purposeAppointment => 'Doctor consultation';

  @override
  String get purposeHomeVisit => 'Home visit';

  @override
  String get purposePharmacyOrder => 'Medicine order';

  @override
  String get careEpisodes => 'Episodes';

  @override
  String get careEpisode => 'Care episode';

  @override
  String get appointments => 'Appointments';

  @override
  String get appointment => 'Appointment';

  @override
  String get homeVisits => 'Home visits';

  @override
  String get carePlans => 'Care plans';

  @override
  String get carePlan => 'Care plan';

  @override
  String get medications => 'Medications';

  @override
  String get noEpisodesTitle => 'No care episodes yet';

  @override
  String get noEpisodesMessage =>
      'Start by asking the AI assistant or booking a doctor.';

  @override
  String get noUpcomingAppointments => 'No upcoming appointments';

  @override
  String get noPastAppointments => 'No past appointments';

  @override
  String get bookDoctor => 'Book a doctor';

  @override
  String get noHomeVisits => 'No home visits';

  @override
  String get bookHomeCheckup => 'Book a Home Checkup';

  @override
  String get noCarePlansTitle => 'No care plan yet';

  @override
  String get noCarePlansMessage =>
      'Your doctor will share a care plan after a consultation.';

  @override
  String get openTasks => 'Open tasks';

  @override
  String get noOpenTasks => 'No open tasks — well done!';

  @override
  String get tasks => 'Tasks';

  @override
  String get markDone => 'Mark done';

  @override
  String get taskCompleted => 'Task completed';

  @override
  String get taskOpen => 'Open';

  @override
  String get taskDone => 'Done';

  @override
  String get taskOverdue => 'Overdue';

  @override
  String get taskCancelled => 'Cancelled';

  @override
  String dueOn(String date) {
    return 'Due $date';
  }

  @override
  String doneBy(String name) {
    return 'by $name';
  }

  @override
  String get todaysDoses => 'Today\'s doses';

  @override
  String get markTaken => 'Taken';

  @override
  String get doseTaken => 'Taken';

  @override
  String get doseSkipped => 'Skipped';

  @override
  String get doseMissed => 'Missed';

  @override
  String get dosePending => 'Due';

  @override
  String prescribedBy(String name) {
    return 'Prescribed by $name';
  }

  @override
  String get noMedications => 'No medicines added';

  @override
  String get noMedicationsMessage => 'Add your medicines to get reminders.';

  @override
  String get addMedication => 'Add medication';

  @override
  String get medicineReminders => 'Medicine reminders';

  @override
  String get medicineName => 'Medicine name';

  @override
  String get dose => 'Dose';

  @override
  String get doseHint => 'e.g. 500 mg, 1 tablet';

  @override
  String get frequency => 'Frequency';

  @override
  String get frequencyHint => 'e.g. Twice a day after food';

  @override
  String get reminderTimes => 'Reminder times';

  @override
  String get addTime => 'Add time';

  @override
  String get addAtLeastOneTime => 'Add at least one reminder time';

  @override
  String timesPerDay(int count) {
    return '$count times a day';
  }

  @override
  String get startDate => 'Start date';

  @override
  String get endDateOptional => 'End date (optional)';

  @override
  String get instructionsOptional => 'Instructions (optional)';

  @override
  String get instructionsHint => 'e.g. After breakfast';

  @override
  String get medicationSelfEnteredNote =>
      'Medicines you add are marked as patient-entered. Always follow your doctor\'s advice.';

  @override
  String get medicationAdded => 'Medication added';

  @override
  String careOwner(String name) {
    return 'Care owner: $name';
  }

  @override
  String episodeExceptional(String status) {
    return 'Status: $status. Our care team is handling this with priority.';
  }

  @override
  String get timeline => 'Timeline';

  @override
  String get noEvents => 'No updates yet';

  @override
  String get viewCareEpisode => 'View care episode';

  @override
  String byDoctor(String name) {
    return 'By $name';
  }

  @override
  String followUpDue(String date) {
    return 'Follow-up by $date';
  }

  @override
  String get instructions => 'Instructions';

  @override
  String get epNew => 'New';

  @override
  String get epIntake => 'Understanding your concern';

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
  String get apPendingPayment => 'Payment pending';

  @override
  String get apConfirmed => 'Confirmed';

  @override
  String get apInProgress => 'In progress';

  @override
  String get apCompleted => 'Completed';

  @override
  String get apCancelled => 'Cancelled';

  @override
  String get apNoShow => 'Missed';

  @override
  String get dateTime => 'Date & time';

  @override
  String get fee => 'Fee';

  @override
  String get doctorNotes => 'Doctor\'s notes';

  @override
  String get joinVideo => 'Join video consultation';

  @override
  String get videoLinkLater =>
      'The video link will appear here shortly before your consultation.';

  @override
  String get reschedule => 'Reschedule';

  @override
  String get cancelAppointment => 'Cancel appointment';

  @override
  String get appointmentCancelled => 'Appointment cancelled';

  @override
  String get homeCheckupTitle => 'Complete Healthcare at Home';

  @override
  String get homeCheckupSubtitle =>
      'Book a certified nurse or technician for sample collection, vitals check, and more.';

  @override
  String get myVisits => 'My visits';

  @override
  String get noServices => 'No services available';

  @override
  String get selectService => 'Select a service';

  @override
  String get address => 'Address';

  @override
  String get addressLine1 => 'House / flat, street';

  @override
  String get addressLine2 => 'Area (optional)';

  @override
  String get landmark => 'Landmark (optional)';

  @override
  String get city => 'City';

  @override
  String get pincode => 'Pincode';

  @override
  String get pincodeInvalid => 'Enter a valid 6-digit pincode';

  @override
  String get notServiceable =>
      'Sorry, home visits are not available at this pincode yet.';

  @override
  String serviceable(String zone) {
    return 'Great — we serve $zone';
  }

  @override
  String get preferredTime => 'Preferred time';

  @override
  String get homeVisitReasonHint => 'e.g. Blood sugar check for my father';

  @override
  String bookAndPay(String amount) {
    return 'Book & Pay $amount';
  }

  @override
  String get homeVisitBooked => 'Home visit booked';

  @override
  String get visitCode => 'Visit code';

  @override
  String get visitCodeHint =>
      'Share this code only with your care provider when they arrive.';

  @override
  String visitCodeInline(String code) {
    return 'Visit code: $code';
  }

  @override
  String visitCodeSemantic(String code) {
    return 'Visit code $code';
  }

  @override
  String get trackVisit => 'Track visit';

  @override
  String get viewRequest => 'View request';

  @override
  String get homeVisitTracking => 'Home visit';

  @override
  String etaMinutes(int minutes) {
    return 'Arriving in about $minutes min';
  }

  @override
  String get visitUnassigned =>
      'We are finding an available care provider near you. We will notify you soon.';

  @override
  String get yourCareProvider => 'Your care provider';

  @override
  String get visitStatusTitle => 'Visit status';

  @override
  String get visitSummary => 'Visit summary';

  @override
  String get vitalsRecorded => 'Vitals recorded';

  @override
  String get cancelVisit => 'Cancel visit';

  @override
  String get visitCancelled => 'Visit cancelled';

  @override
  String get hvRequested => 'Requested';

  @override
  String get hvUnassigned => 'Finding provider';

  @override
  String get hvAssigned => 'Provider assigned';

  @override
  String get hvAccepted => 'Accepted';

  @override
  String get hvEnRoute => 'On the way';

  @override
  String get hvArrived => 'Arrived';

  @override
  String get hvInProgress => 'Visit in progress';

  @override
  String get hvCompleted => 'Completed';

  @override
  String get hvCancelled => 'Cancelled';

  @override
  String get hvEscalated => 'Escalated to doctor';

  @override
  String get searchMedicines => 'Search medicines...';

  @override
  String get uploadPrescription => 'Upload Prescription';

  @override
  String get uploadPrescriptionSub => 'Upload a photo or PDF';

  @override
  String get popularCategories => 'Popular Categories';

  @override
  String get frequentlyOrdered => 'Frequently Ordered';

  @override
  String get rxRequired => 'Rx';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String addToCart(String name) {
    return 'Add $name to cart';
  }

  @override
  String get decreaseQty => 'Decrease quantity';

  @override
  String get increaseQty => 'Increase quantity';

  @override
  String get viewCart => 'View Cart';

  @override
  String get cart => 'Cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get browseMedicines => 'Browse medicines';

  @override
  String get prescription => 'Prescription';

  @override
  String get rxRequiredBody =>
      'Some items need a valid prescription. Select one or upload a new one.';

  @override
  String get rxMissing => 'A prescription is required for one or more items.';

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String placeOrderAndPay(String amount) {
    return 'Place order · $amount';
  }

  @override
  String get medicineOrder => 'Medicine order';

  @override
  String get orderPlaced => 'Order placed';

  @override
  String fulfilledBy(String name) {
    return 'Fulfilled by $name';
  }

  @override
  String get healthRecords => 'Health Records';

  @override
  String get healthTimeline => 'Health timeline';

  @override
  String get vitals => 'Vitals';

  @override
  String get reports => 'Reports';

  @override
  String get prescriptions => 'Prescriptions';

  @override
  String get images => 'Images';

  @override
  String get noRecordsTitle => 'No records yet';

  @override
  String get noRecordsMessage =>
      'Upload reports and prescriptions to keep everything in one place.';

  @override
  String get noRecordsPermission =>
      'You do not have permission to view records for this family member.';

  @override
  String get uploadNewReport => 'Upload New Report';

  @override
  String get uploadNewReportSub => 'Add reports, prescriptions, images';

  @override
  String get record => 'Record';

  @override
  String get recordType => 'Type';

  @override
  String get recordDate => 'Report date';

  @override
  String get addedBy => 'Added by';

  @override
  String get uploadedOn => 'Uploaded on';

  @override
  String get openOriginal => 'Open original file';

  @override
  String get aiSummary => 'AI summary';

  @override
  String get summarizeWithAi => 'Summarize with AI';

  @override
  String get aiDisclaimerDefault =>
      'This summary is AI-generated to help you understand your report. It is not a diagnosis — please discuss results with your doctor.';

  @override
  String generatedOn(String date) {
    return 'Generated $date';
  }

  @override
  String get originalImmutableNote =>
      'Your original file is never changed. AI summaries are stored separately.';

  @override
  String get previewUnavailable =>
      'Preview is not available for this file type.';

  @override
  String previewUnavailableMobile(String size) {
    return 'File downloaded ($size). In-app preview supports images only for now.';
  }

  @override
  String sourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String get chooseFile => 'Choose file';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get allowedFiles => 'PDF, JPG, PNG, WEBP or HEIC up to 15 MB';

  @override
  String get fileTooLarge => 'File is larger than 15 MB';

  @override
  String get pickerFailed => 'Could not open the file. Please try again.';

  @override
  String get uploadPrivacyNote =>
      'Files are stored securely and shared only with people you allow.';

  @override
  String get rtLabReport => 'Lab report';

  @override
  String get rtPrescription => 'Prescription';

  @override
  String get rtImaging => 'Scan / X-ray';

  @override
  String get rtDischargeSummary => 'Discharge summary';

  @override
  String get rtVisitSummary => 'Visit summary';

  @override
  String get rtOther => 'Other';

  @override
  String get provPatientEntered => 'Patient entered';

  @override
  String get provClinicianVerified => 'Clinician verified';

  @override
  String get provHomeVisit => 'Home visit';

  @override
  String get provImported => 'Imported';

  @override
  String get provAiExtracted => 'AI extracted';

  @override
  String get provDevice => 'Device';

  @override
  String get provUnknown => 'Unknown';

  @override
  String get timelineEmpty => 'Your health timeline will appear here';

  @override
  String get noVitals => 'No vitals recorded';

  @override
  String get noVitalsMessage =>
      'Add readings like BP, pulse or sugar to track trends.';

  @override
  String get addVital => 'Add vital';

  @override
  String get vitalTypeLabel => 'Measurement';

  @override
  String get vitalSelfEnteredNote =>
      'Readings you add are marked as patient-entered.';

  @override
  String get vitalBpSystolic => 'BP (systolic)';

  @override
  String get vitalBpDiastolic => 'BP (diastolic)';

  @override
  String get vitalPulse => 'Pulse';

  @override
  String get vitalSpo2 => 'SpO₂ (oxygen)';

  @override
  String get vitalTemperature => 'Temperature';

  @override
  String get vitalBloodGlucose => 'Blood sugar';

  @override
  String get vitalWeight => 'Weight';

  @override
  String get vitalRespiratoryRate => 'Breathing rate';

  @override
  String get wellnessHeroTitle => 'A healthier mind for a brighter you';

  @override
  String get wellnessHeroSubtitle =>
      'Talk to a therapist or try our AI-guided support.';

  @override
  String get howAreYouFeeling => 'How are you feeling today?';

  @override
  String get moodVeryLow => 'Very low';

  @override
  String get moodLow => 'Low';

  @override
  String get moodOkay => 'Okay';

  @override
  String get moodGood => 'Good';

  @override
  String get moodGreat => 'Great';

  @override
  String get moodNoteOptional => 'Want to add a note? (optional)';

  @override
  String get shareWithClinician => 'Share with my clinician';

  @override
  String get saveCheckIn => 'Save check-in';

  @override
  String get talkToTherapist => 'Talk to a Therapist';

  @override
  String get talkToTherapistSub => 'Book an online session';

  @override
  String get aiMoodSupport => 'AI Mood Support';

  @override
  String get aiMoodSupportSub => 'Chat anonymously';

  @override
  String get meditationExercises => 'Meditation & Exercises';

  @override
  String get noActivities => 'No activities available';

  @override
  String get moodTracker => 'Mood Tracker';

  @override
  String get noMoodHistory => 'Your mood check-ins will appear here';

  @override
  String get youAreNotAlone => 'You are not alone';

  @override
  String get moodSupportFallback =>
      'If you feel unsafe or might hurt yourself, please call 108 now or reach someone you trust.';

  @override
  String get woundNoDiagnosis =>
      'No AI diagnosis. We only check that the photo is clear; a clinician will review it.';

  @override
  String get uploadWoundPhoto => 'Upload a photo of the wound';

  @override
  String get woundPhotoTips => 'Good light, in focus, whole wound visible';

  @override
  String get bodySite => 'Where is the wound?';

  @override
  String get bodySiteHint => 'e.g. Left ankle';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get sendForReview => 'Send for clinician review';

  @override
  String get retakeAndSubmit => 'Submit new photo';

  @override
  String get woundRetakeTitle => 'Please retake the photo';

  @override
  String get woundRetakeBody => 'The photo could not be used because:';

  @override
  String get woundPendingTitle => 'Sent for clinician review';

  @override
  String get woundPendingBody =>
      'A clinician will review your photo and contact you. If the wound worsens, bleeds heavily or you have fever, seek care immediately.';

  @override
  String get woundIssueTooSmall => 'The image resolution is too low';

  @override
  String get woundIssueFileTooSmall => 'The file is too small or incomplete';

  @override
  String get woundIssueTooDark => 'The photo is too dark';

  @override
  String get woundIssueBlurry => 'The photo is blurry';

  @override
  String get woundStatusRetake => 'Retake needed';

  @override
  String get woundStatusPending => 'Awaiting review';

  @override
  String get woundStatusReviewed => 'Reviewed';

  @override
  String get noWoundHistory => 'No wound photos yet';

  @override
  String clinicianReviewBy(String name) {
    return 'Reviewed by $name';
  }

  @override
  String get connectWearable => 'Connect Wearable';

  @override
  String get trackHealthRealtime => 'Track your health in real time';

  @override
  String get heartRate => 'Heart rate';

  @override
  String get stepsActivity => 'Steps & activity';

  @override
  String get sleep => 'Sleep';

  @override
  String get linkedDevices => 'Linked Devices';

  @override
  String get linkedDevicesSub => 'Wearables & apps';

  @override
  String get selectDevice => 'Select a device';

  @override
  String connectDeviceName(String name) {
    return 'Connect $name';
  }

  @override
  String get deviceConnected => 'Device connected';

  @override
  String get connected => 'Connected';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get disconnectDevice => 'Disconnect device?';

  @override
  String get disconnectDeviceBody =>
      'New readings will stop syncing. Existing readings stay in your records.';

  @override
  String lastSynced(String date) {
    return 'Last synced $date';
  }

  @override
  String get connectedNotSynced => 'Connected · not synced yet';

  @override
  String get noWearableProviders => 'No devices available';

  @override
  String get wearableDataNote =>
      'Device readings are labelled with their source and are not a medical diagnosis.';

  @override
  String get emergency => 'Emergency';

  @override
  String get sosSubtitle =>
      'Get help quickly. We\'ll notify your emergency contacts.';

  @override
  String get sosSentTitle => 'SOS sent. Help is being arranged.';

  @override
  String get holdToSend => 'Press and hold for 3 seconds';

  @override
  String get sosSemantic =>
      'SOS emergency button. Double tap to confirm sending an alert.';

  @override
  String get sendSosTitle => 'Send SOS alert?';

  @override
  String get sendSosBody =>
      'Your emergency contacts and our care team will be alerted with your location.';

  @override
  String get sendSos => 'Send SOS';

  @override
  String get sosFailed => 'Could not send SOS. Call 108 directly.';

  @override
  String get sendLocation => 'Send Location';

  @override
  String get toEmergencyContacts => 'To emergency contacts';

  @override
  String get callAmbulance => 'Call Ambulance';

  @override
  String get helpline108 => 'Helpline: 108';

  @override
  String callNumber(String number) {
    return 'Call $number';
  }

  @override
  String get notifiedContacts => 'Contacts notified';

  @override
  String get noEmergencyContacts => 'No emergency contacts yet';

  @override
  String get addEmergencyContact => 'Add emergency contact';

  @override
  String get nearestEmergencyFacilities => 'Nearest emergency facilities';

  @override
  String get emergencyContacts => 'Emergency Contacts';

  @override
  String emergencyContactsFor(String name) {
    return 'People we alert for $name';
  }

  @override
  String get fallTitle => 'Fall detection';

  @override
  String get fallBody =>
      'If a fall is detected by your phone or wearable, we ask if you are OK. If you don\'t respond, we alert your emergency contacts and care team.';

  @override
  String get fallStep1 => 'A possible fall is detected';

  @override
  String get fallStep2 => 'You get a countdown to respond';

  @override
  String get fallStep3 => 'No response? We alert your contacts';

  @override
  String get fallContactsHint => 'Make sure your contacts are up to date';

  @override
  String get fallWearableHint => 'Connect a watch for better detection';

  @override
  String get simulateFall => 'Simulate fall (test)';

  @override
  String get simulateFallNote =>
      'For testing only. This creates a real fall alert for your care team.';

  @override
  String get areYouOk => 'Are you OK?';

  @override
  String get fallDetectedBody =>
      'We detected a possible fall. If you don\'t respond, we will alert your emergency contacts.';

  @override
  String secondsLeft(int seconds) {
    return '$seconds seconds left';
  }

  @override
  String get imOk => 'I\'m OK';

  @override
  String get needHelp => 'I need help';

  @override
  String get fallGladSafe => 'Glad you\'re safe';

  @override
  String get fallHelpComing => 'We are alerting your contacts';

  @override
  String get fallNoResponse => 'No response — alerting your contacts';

  @override
  String get openSos => 'Open SOS';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get locationUnavailable =>
      'Location is unavailable. Showing all results.';

  @override
  String get noFacilities => 'No facilities found';

  @override
  String get emergency247 => '24x7 Emergency';

  @override
  String get facHospital => 'Hospital';

  @override
  String get facClinic => 'Clinic';

  @override
  String get facLab => 'Lab';

  @override
  String get facPharmacy => 'Pharmacy';

  @override
  String get govtSchemesComingSoon =>
      'Government health scheme guidance is coming soon.';

  @override
  String get myProfile => 'My Profile';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get personalInfoNote =>
      'Your phone number is your login and cannot be changed here.';

  @override
  String get healthProfile => 'Health Profile';

  @override
  String get healthProfileSub => 'Blood group, allergies, conditions';

  @override
  String healthProfileFor(String name) {
    return 'Health details for $name';
  }

  @override
  String healthSettingsFor(String name) {
    return 'Health settings below apply to $name';
  }

  @override
  String get bloodGroup => 'Blood group';

  @override
  String get bloodGroupOptional => 'Blood group (optional)';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get allergies => 'Allergies';

  @override
  String get addAllergy => 'Add allergy';

  @override
  String get noAllergies => 'No known allergies recorded';

  @override
  String get substance => 'Allergic to';

  @override
  String get reactionOptional => 'Reaction (optional)';

  @override
  String get mild => 'Mild';

  @override
  String get moderate => 'Moderate';

  @override
  String get severe => 'Severe';

  @override
  String get conditions => 'Conditions';

  @override
  String get addCondition => 'Add condition';

  @override
  String get noConditions => 'No conditions recorded';

  @override
  String get conditionName => 'Condition';

  @override
  String get sinceYearOptional => 'Since (year, optional)';

  @override
  String since(String year) {
    return 'since $year';
  }

  @override
  String get familyMembers => 'Family Members';

  @override
  String get familyMembersSub => 'Add and manage family';

  @override
  String get familyIntro =>
      'Manage care for your family. Choose who can see records, book care and receive alerts.';

  @override
  String get peopleYouCareFor => 'People you care for';

  @override
  String get addDependent => 'Add';

  @override
  String get addDependentSub =>
      'Add a family member whose care you manage (e.g. a parent or child).';

  @override
  String get actingNow => 'Selected';

  @override
  String caregiversFor(String name) {
    return 'Caregivers for $name';
  }

  @override
  String get noCaregivers => 'No one else has access yet.';

  @override
  String get revokeAccess => 'Revoke access?';

  @override
  String revokeAccessBody(String name) {
    return '$name will immediately lose access.';
  }

  @override
  String get inviteCaregiver => 'Invite a caregiver';

  @override
  String inviteCaregiverSub(String name) {
    return 'They will be able to help with care for $name.';
  }

  @override
  String get permissions => 'Permissions';

  @override
  String get permViewRecords => 'View records';

  @override
  String get permManageCare => 'Manage care';

  @override
  String get permBook => 'Book & pay';

  @override
  String get permReceiveAlerts => 'Receive alerts';

  @override
  String get permViewRecordsDesc => 'See reports, prescriptions and vitals';

  @override
  String get permManageCareDesc => 'Use AI assistant, complete care tasks';

  @override
  String get permBookDesc => 'Book appointments, visits and medicines';

  @override
  String get permReceiveAlertsDesc => 'Get SOS, fall and care alerts';

  @override
  String get sendInvite => 'Send invite';

  @override
  String get caregiverInvited => 'Caregiver invited';

  @override
  String get language => 'Language';

  @override
  String get languageSettingsSub =>
      'The app and AI replies will use this language where available.';

  @override
  String get medicalTermsNote =>
      'Some medical terms may appear in English for safety.';

  @override
  String get langEnglish => 'English';

  @override
  String get langHindi => 'Hindi';

  @override
  String get langTelugu => 'Telugu';

  @override
  String get allNotifications => 'All notifications';

  @override
  String get channels => 'Channels';

  @override
  String get prefPush => 'Push notifications';

  @override
  String get prefSms => 'SMS';

  @override
  String get prefWhatsapp => 'WhatsApp';

  @override
  String get prefEmail => 'Email';

  @override
  String get prefMarketing => 'Offers & updates';

  @override
  String get notificationPrivacyNote =>
      'Lock-screen notifications never show health details.';

  @override
  String get privacyConsents => 'Privacy & Consents';

  @override
  String get privacyIntro =>
      'You are in control. Turn permissions on or off at any time; changes apply immediately.';

  @override
  String grantedOn(String date) {
    return 'Granted on $date';
  }

  @override
  String get revokeConsentTitle => 'Withdraw consent?';

  @override
  String get revokeConsentBody =>
      'Features that depend on this consent will stop working.';

  @override
  String get revokeRequiredConsentBody =>
      'This consent is required to use CareCompanion. Withdrawing it will limit most features until you grant it again.';

  @override
  String get consentTerms => 'Terms of use';

  @override
  String get consentPrivacy => 'Privacy policy';

  @override
  String get consentHealthData => 'Health data processing';

  @override
  String get consentAi => 'AI assistance';

  @override
  String get consentShareClinicians => 'Share with clinicians';

  @override
  String get consentFamilySharing => 'Family sharing';

  @override
  String get consentMarketing => 'Marketing communication';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Log out of CareCompanion on this device?';

  @override
  String get ok => 'OK';

  @override
  String get allow => 'Allow';

  @override
  String get loadMore => 'Load more';

  @override
  String get couldNotOpenLink => 'Could not open the link on this device.';

  @override
  String get featureUnavailable =>
      'This feature is not available right now. Please check again later.';

  @override
  String get errorMfaRequired =>
      'This is a staff account and needs two-step verification. Please use the CareCompanion staff portal.';

  @override
  String get mfaRequiredTitle => 'Use the staff portal';

  @override
  String get aiUnavailableTitle => 'AI assistant is unavailable';

  @override
  String get aiUnavailableBody =>
      'The AI health assistant is switched off for now. You can still book a doctor. In an emergency, call 108.';

  @override
  String get updateRequiredTitle => 'Please update CareCompanion';

  @override
  String get updateRequiredBody =>
      'This version is no longer supported. Update to the latest version to keep your care information safe and up to date.';

  @override
  String updateVersionInfo(String current, String minimum) {
    return 'Installed $current · required $minimum or newer';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get checkAgain => 'Check again';

  @override
  String get pushPermissionTitle => 'Stay on top of your care';

  @override
  String get pushPermissionBody =>
      'Allow notifications for appointment reminders, home-visit updates and urgent safety alerts. Notifications never show health details on the lock screen.';

  @override
  String get paymentUnavailable =>
      'Payment could not be started. Please try again in a moment.';

  @override
  String get paymentCancelled => 'Payment was cancelled. Nothing was charged.';

  @override
  String get razorpaySecureNote =>
      'Secure payment by Razorpay: UPI, cards, net banking and wallets.';

  @override
  String get checkPaymentStatus => 'Check payment status';

  @override
  String get paymentConfirming =>
      'We are confirming your payment with the bank. Your booking is confirmed only after this completes.';

  @override
  String get payInMobileAppTitle => 'Complete payment in the mobile app';

  @override
  String get payInMobileAppBody =>
      'Online payment is not available in the browser yet. Open CareCompanion on your Android or iPhone to pay. Your booking stays reserved until then.';

  @override
  String get yourData => 'Your data';

  @override
  String get myDataExport => 'My CareCompanion data';

  @override
  String get downloadMyData => 'Download my data';

  @override
  String get downloadMyDataSub =>
      'A copy of your profile, records list, appointments and more (JSON file)';

  @override
  String get dataExportReady => 'Your data file is ready.';

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get deleteMyAccountSub =>
      'Permanently delete your account after a grace period';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountIntro =>
      'We are sorry to see you go. Please read what happens before you continue.';

  @override
  String get deletionWhatHappens => 'What happens';

  @override
  String get deletionGracePeriod =>
      'Your account is scheduled for deletion after a grace period (7 days by default). You can cancel any time before then by signing in again.';

  @override
  String get deletionRemoved =>
      'Then you are signed out everywhere, family access is removed, and your name, phone number and email are erased.';

  @override
  String get deletionDependents =>
      'Personal data of family members you manage is deleted too, unless the law requires us to keep it.';

  @override
  String get deletionWhatRetained => 'What we must keep';

  @override
  String get deletionRetainedBody =>
      'Clinical records, payment records and audit logs are kept for the period the law requires, separated from your identity.';

  @override
  String get deletionExportHint =>
      'Want a copy first? Use \"Download my data\" before deleting.';

  @override
  String get deletionReasonOptional => 'Reason (optional)';

  @override
  String typeDeleteToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get deletionScheduledTitle => 'Account deletion scheduled';

  @override
  String deletionScheduledFor(String date) {
    return 'Your account will be deleted on $date.';
  }

  @override
  String get deletionScheduledNoDate =>
      'Your account will be deleted when the grace period ends.';

  @override
  String deletionScheduledLogoutBody(String date) {
    return 'Your account will be deleted on $date. You will now be logged out. To cancel, sign in again before then and tap \"Cancel deletion\".';
  }

  @override
  String get deletionCancelHint =>
      'Changed your mind? Cancel now and keep using CareCompanion as before.';

  @override
  String get cancelDeletion => 'Cancel deletion';

  @override
  String get deletionCancelled =>
      'Deletion cancelled. Your account stays active.';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get helpSupportSub => 'Call, WhatsApp or email our care team';

  @override
  String get helpSupportIntro =>
      'Questions about bookings, payments or the app? Our team is here to help.';

  @override
  String get supportEmergencyNote => 'For a medical emergency, call 108 now.';

  @override
  String get supportUnavailable =>
      'Support contact details are not available right now.';

  @override
  String get supportCall => 'Call us';

  @override
  String get supportWhatsapp => 'Chat on WhatsApp';

  @override
  String get supportEmail => 'Email us';

  @override
  String get supportEmailSubject => 'CareCompanion app support';

  @override
  String get videoConsultation => 'Video consultation';

  @override
  String get audioConsultation => 'Audio consultation';

  @override
  String get joinConsultation => 'Join consultation';

  @override
  String consultationOpensIn(String time) {
    return 'You can join in $time';
  }

  @override
  String consultationOpensAt(String time) {
    return 'Joining opens at $time';
  }

  @override
  String get consultationOpenNow =>
      'Your consultation room is open. Your doctor will join shortly.';

  @override
  String get consultationEnded => 'This consultation has ended.';

  @override
  String get beforeYouJoin => 'Before you join';

  @override
  String get beforeYouJoinSub =>
      'A quick check helps your doctor hear and see you clearly.';

  @override
  String get checklistCameraMic => 'Allow camera and microphone when asked';

  @override
  String get checklistMic =>
      'Allow the microphone when asked (camera stays off)';

  @override
  String get checklistQuietPlace => 'Sit in a quiet, private place';

  @override
  String get checklistConnection =>
      'Use a stable Wi-Fi or mobile data connection';

  @override
  String get checklistReports => 'Keep your reports and medicines nearby';

  @override
  String get joinOpensOutside =>
      'The call opens in the Jitsi Meet app if installed, otherwise in your browser.';

  @override
  String get joinNow => 'Join now';

  @override
  String get download => 'Download';

  @override
  String get share => 'Share';

  @override
  String get viewPdf => 'View PDF';

  @override
  String pdfDocument(String name) {
    return 'PDF document: $name';
  }

  @override
  String pageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String pdfReady(String size) {
    return 'Your PDF is ready ($size)';
  }

  @override
  String get pdfWebNote =>
      'On the web, PDFs open in your browser\'s own viewer.';

  @override
  String get openPdfInNewTab => 'Open in a new tab';

  @override
  String photoOf(String name) {
    return 'Photo of $name';
  }

  @override
  String get ePrescription => 'e-Prescription';

  @override
  String get ePrescriptions => 'From your doctors';

  @override
  String get uploadedPrescriptions => 'Prescription documents';

  @override
  String get noUploadedPrescriptions => 'No uploaded prescriptions yet.';

  @override
  String get noEPrescriptions => 'No e-prescriptions yet';

  @override
  String get noEPrescriptionsBody =>
      'Prescriptions your doctor writes after a consultation appear here.';

  @override
  String rxFromDoctor(String name) {
    return 'Prescription from $name';
  }

  @override
  String medicinesCount(int count) {
    return '$count medicines';
  }

  @override
  String registrationNo(String number) {
    return 'Reg. No. $number';
  }

  @override
  String get doctorsAdvice => 'Advice';

  @override
  String get followUp => 'Follow-up';

  @override
  String followUpInDays(int days) {
    return 'Review after $days days';
  }

  @override
  String get digitallyGenerated => 'Digitally generated prescription';

  @override
  String get rxDose => 'Dose';

  @override
  String get rxFrequency => 'How often';

  @override
  String get rxTiming => 'When';

  @override
  String get rxDuration => 'For';

  @override
  String get rxReminderTimes => 'Reminders';

  @override
  String durationDays(int days) {
    return '$days days';
  }

  @override
  String get rxFormTablet => 'Tablet';

  @override
  String get rxFormCapsule => 'Capsule';

  @override
  String get rxFormSyrup => 'Syrup';

  @override
  String get rxFormInjection => 'Injection';

  @override
  String get rxFormOintment => 'Ointment';

  @override
  String get rxFormDrops => 'Drops';

  @override
  String get rxFormInhaler => 'Inhaler';

  @override
  String get rxFormOther => 'Other';

  @override
  String get orderTheseMedicines => 'Order these medicines';

  @override
  String get pharmacyUnavailable =>
      'Medicine ordering is not available right now.';

  @override
  String get noPharmacyMatches =>
      'This prescription has no medicines to order.';

  @override
  String get pharmacyMatchIntro =>
      'We matched your prescription with our partner pharmacy. Choose what to order.';

  @override
  String get pharmacyMatchNote =>
      'Check the medicine name and strength before paying. Ask your pharmacist or doctor if anything looks different.';

  @override
  String get selectMedicines => 'Select medicines';

  @override
  String addItemsToCart(int count, String amount) {
    return 'Add $count to cart · $amount';
  }

  @override
  String get notInCatalogue => 'Not available from our pharmacy partner';

  @override
  String usingEPrescription(String doctor, String date) {
    return 'Using your e-prescription from $doctor ($date)';
  }

  @override
  String get messageCareTeam => 'Message care team';

  @override
  String get invoice => 'Invoice';

  @override
  String invoiceNo(String number) {
    return 'Invoice $number';
  }

  @override
  String get taxInvoice => 'Tax invoice';

  @override
  String get soldBy => 'Sold by';

  @override
  String get billedTo => 'Billed to';

  @override
  String taxRateLabel(String rate) {
    return 'Tax $rate%';
  }

  @override
  String get subtotal => 'Subtotal';

  @override
  String get tax => 'Tax';

  @override
  String get refundedLabel => 'Refunded';

  @override
  String get invoiceFooter =>
      'This is a computer-generated invoice and needs no signature.';

  @override
  String get purposeSubscription => 'Family Care Plan';

  @override
  String get paymentsSub => 'History and invoices';

  @override
  String get reviewPromptTitle => 'How was your care?';

  @override
  String get yourRating => 'Your rating';

  @override
  String get notRatedYet => 'Not rated yet';

  @override
  String rateStars(int count) {
    return 'Rate $count out of 5';
  }

  @override
  String ratingOutOfFive(int count) {
    return '$count out of 5 stars';
  }

  @override
  String get reviewCommentOptional => 'Tell us more (optional)';

  @override
  String get reviewCommentHint => 'What went well? What could be better?';

  @override
  String get reviewModerationInfo =>
      'A rating on its own is published right away. Comments are checked by our team first.';

  @override
  String get submitReview => 'Submit';

  @override
  String get reviewThanksPublished => 'Thank you! Your rating is published.';

  @override
  String get reviewThanksPending =>
      'Thank you! Your review will appear after a quick check.';

  @override
  String get reviewsModerationNote =>
      'Reviews come from verified patients and are checked before they appear.';

  @override
  String get inbox => 'Messages';

  @override
  String inboxUnread(int count) {
    return 'Messages, $count unread';
  }

  @override
  String get inboxEmpty => 'No conversations yet';

  @override
  String get inboxEmptyBody =>
      'When you have an active care episode, you can message your care team here.';

  @override
  String unreadMessages(int count) {
    return '$count unread';
  }

  @override
  String get careTeamMessages => 'Care team';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get noMessagesYetBody =>
      'Ask your doctor or care coordinator a question about this episode.';

  @override
  String get messageHint => 'Write a message';

  @override
  String get attachRecord => 'Attach a record';

  @override
  String get attachedRecord => 'Attached record';

  @override
  String get messagingNotForEmergencies =>
      'Not for emergencies. In an emergency call 108.';

  @override
  String youSaid(String text) {
    return 'You: $text';
  }

  @override
  String senderSaid(String sender, String text) {
    return '$sender: $text';
  }

  @override
  String get roleDoctor => 'Doctor';

  @override
  String get roleCoordinator => 'Care coordinator';

  @override
  String get roleCareTeam => 'Care team';

  @override
  String get roleFamily => 'Family';

  @override
  String get rolePatient => 'Patient';

  @override
  String get roleSystem => 'CareCompanion';

  @override
  String get familyCarePlan => 'Family Care Plan';

  @override
  String get familyCarePlanSub =>
      'Savings and a care coordinator for your family';

  @override
  String get familyPlanIntro =>
      'One plan for the whole family: discounts on home visits and extra support from our care team.';

  @override
  String get noPlansAvailable => 'No plans are available right now';

  @override
  String get billingMonthly => 'Monthly';

  @override
  String get billingYearly => 'Yearly';

  @override
  String billingYearlySave(int pct) {
    return 'Yearly · save $pct%';
  }

  @override
  String get perMonth => ' / month';

  @override
  String get perYear => ' / year';

  @override
  String planYearlySavings(String amount, int pct) {
    return 'You save $amount ($pct%) a year';
  }

  @override
  String planMembers(int count) {
    return 'Covers up to $count family members';
  }

  @override
  String planHomeVisitDiscount(int pct) {
    return '$pct% off home visits';
  }

  @override
  String get planCoordinatorIncluded => 'A dedicated care coordinator';

  @override
  String subscribeFor(String amount) {
    return 'Subscribe · $amount';
  }

  @override
  String planPaymentTitle(String name) {
    return '$name subscription';
  }

  @override
  String planActivated(String name) {
    return '$name is now active';
  }

  @override
  String planPendingPayment(String name) {
    return 'Your $name payment is not complete yet. Subscribe again to finish.';
  }

  @override
  String get planPrepaidNote =>
      'Plans are prepaid for the period you choose. We remind you 7 days before it ends.';

  @override
  String get planActive => 'Active';

  @override
  String planRenewsOn(String date) {
    return 'Current period ends on $date';
  }

  @override
  String planEndsOn(String date) {
    return 'Ends on $date';
  }

  @override
  String get planBenefits => 'Your benefits';

  @override
  String get planCancelScheduled =>
      'Your plan will not renew. Benefits continue until the end date.';

  @override
  String get cancelAtPeriodEnd => 'Cancel at period end';

  @override
  String get cancelPlanTitle => 'Cancel your plan?';

  @override
  String cancelPlanBody(String date) {
    return 'Your benefits continue until $date. After that the plan will not renew.';
  }

  @override
  String get cancelPlanBodyNoDate =>
      'Your benefits continue until the end of the current period.';

  @override
  String get keepPlan => 'Keep plan';

  @override
  String planDiscountApplied(String amount) {
    return 'Family Care Plan discount: −$amount';
  }

  @override
  String get planDiscountWillApply =>
      'Your Family Care Plan discount is applied when you book.';

  @override
  String get govtSchemes => 'Govt. Health Schemes';

  @override
  String get schemesDisclaimer =>
      'Information only. This app does not decide whether you are eligible; the scheme authority does.';

  @override
  String get yourState => 'Your state';

  @override
  String get allStates => 'All states';

  @override
  String get centralSchemesAlwaysShown =>
      'Central government schemes are always listed.';

  @override
  String get noSchemes => 'No schemes to show';

  @override
  String get centralScheme => 'Central';

  @override
  String stateScheme(String state) {
    return 'State · $state';
  }

  @override
  String get aboutScheme => 'About';

  @override
  String get schemeBenefits => 'Benefits';

  @override
  String get mayBeRelevantIf => 'May be relevant if…';

  @override
  String get eligibilityNotDetermined =>
      'These are hints, not an eligibility check. Confirm with the official source.';

  @override
  String get documentsTypicallyNeeded => 'Documents usually needed';

  @override
  String get helpline => 'Helpline';

  @override
  String get openOfficialWebsite => 'Open official website';

  @override
  String lastReviewedOn(String date) {
    return 'Information last reviewed on $date';
  }

  @override
  String get abhaTitle => 'ABHA (Health ID)';

  @override
  String get abhaIntro =>
      'Add your Ayushman Bharat Health Account number or address to keep it with your profile.';

  @override
  String get abhaNumber => 'ABHA number';

  @override
  String get abhaAddress => 'ABHA address';

  @override
  String get addAbha => 'Add ABHA';

  @override
  String get notVerified => 'Not verified';

  @override
  String get abhaEditHint =>
      'Enter the 14-digit number or the address (for example name@abdm).';

  @override
  String get abhaEnterOne => 'Enter an ABHA number or address';

  @override
  String get abhaNumberInvalid => 'ABHA number must have 14 digits';

  @override
  String get abhaAddressInvalid => 'Use the form name@abdm';

  @override
  String get abhaVerifyComingSoonTitle => 'Coming soon';

  @override
  String get abhaVerifyComingSoon =>
      'ABDM verification is coming soon. Your ABHA details are saved and will be verified once the connection is ready.';

  @override
  String get wearablePurpose =>
      'With your permission we read steps, heart rate, sleep, SpO2, blood pressure, glucose and weight so you and your care team can see trends. You choose each type.';

  @override
  String chooseDataToShare(String name) {
    return 'Choose what to read from $name';
  }

  @override
  String get metricSteps => 'Steps';

  @override
  String get metricSpo2 => 'Blood oxygen (SpO2)';

  @override
  String get metricBloodPressure => 'Blood pressure';

  @override
  String get metricGlucose => 'Blood glucose';

  @override
  String get metricWeight => 'Weight';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Health';

  @override
  String get healthConnectMissingTitle => 'Health Connect is needed';

  @override
  String get healthConnectUpdateTitle => 'Please update Health Connect';

  @override
  String get healthConnectMissingBody =>
      'Your watch and fitness apps share data through Google Health Connect. Install or update it from the Play Store, then come back.';

  @override
  String get openPlayStore => 'Open Play Store';

  @override
  String get healthPermissionDenied =>
      'Access was not allowed. You can allow it any time in Health Connect (Android) or Settings → Health → Data Access (iPhone), then tap Connect again.';

  @override
  String get wearablesUnsupported =>
      'Health data sync works in the CareCompanion app on Android and iPhone. It is not available in the web version.';

  @override
  String syncedReadings(int count) {
    return 'Synced $count readings';
  }

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncNow => 'Sync now';

  @override
  String get autoSyncNote =>
      'We also sync when you open the app (at most every 30 minutes).';

  @override
  String get otherDevices => 'Other devices';

  @override
  String get healthDataPrivacy => 'Health data & privacy';

  @override
  String get healthPrivacyIntro =>
      'How CareCompanion uses the health data you allow';

  @override
  String get healthPrivacyPoint1 =>
      'We only read the types you switch on, and never write to your health store.';

  @override
  String get healthPrivacyPoint2 =>
      'Readings are shown to you and to clinicians caring for you.';

  @override
  String get healthPrivacyPoint3 =>
      'We never sell your data or use it for advertising.';

  @override
  String get healthPrivacyPoint4 =>
      'You can disconnect at any time from Linked devices.';

  @override
  String get readPrivacyPolicy => 'Read the privacy policy';

  @override
  String get fallDetectToggle => 'Detect falls while the app is open';

  @override
  String get fallDetectOn =>
      'On: we watch the phone\'s motion sensor while CareCompanion is open.';

  @override
  String get fallDetectOff => 'Off';

  @override
  String get fallDetectUnsupported => 'Available in the Android and iPhone app';

  @override
  String get fallForegroundOnly =>
      'Works only while the app is open on screen. It does not run in the background.';

  @override
  String get fallNotMedicalDevice =>
      'A supportive feature, not a medical device. It can miss falls or raise false alarms.';

  @override
  String get readRepliesAloud => 'Read replies aloud';

  @override
  String get changePhoto => 'Change profile photo';

  @override
  String get photoUpdated => 'Profile photo updated';

  @override
  String get photoTooLarge => 'The photo is larger than 5 MB';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeSystemSub => 'Follows your phone\'s setting';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }
}
