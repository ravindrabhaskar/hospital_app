import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CareCompanion Pro'**
  String get appTitle;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get commonLogout;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get commonNotAvailable;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get errorSessionExpired;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For verified nurses, technicians and field medical workers.'**
  String get loginSubtitle;

  /// No description provided for @loginPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get loginPhoneLabel;

  /// No description provided for @loginPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'10-digit mobile number'**
  String get loginPhoneHint;

  /// No description provided for @loginPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get loginPhoneInvalid;

  /// No description provided for @loginSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get loginSendOtp;

  /// No description provided for @loginOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit OTP'**
  String get loginOtpLabel;

  /// No description provided for @loginOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit OTP'**
  String get loginOtpInvalid;

  /// No description provided for @loginOtpSentTo.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to {phone}'**
  String loginOtpSentTo(String phone);

  /// No description provided for @loginVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get loginVerify;

  /// No description provided for @loginChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get loginChangeNumber;

  /// No description provided for @loginDevOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Development OTP: {otp}'**
  String loginDevOtpHint(String otp);

  /// No description provided for @restrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Access restricted to verified care providers'**
  String get restrictedTitle;

  /// No description provided for @restrictedBody.
  ///
  /// In en, this message translates to:
  /// **'This app is only for home-care providers registered with CareCompanion. If you are a patient or family member, please use the CareCompanion patient app.'**
  String get restrictedBody;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'You can\'t receive visits right now'**
  String get blockedTitle;

  /// No description provided for @blockedNoVisits.
  ///
  /// In en, this message translates to:
  /// **'No home visits can be assigned to you until your verification is active.'**
  String get blockedNoVisits;

  /// No description provided for @blockedPending.
  ///
  /// In en, this message translates to:
  /// **'Your professional verification is pending review by the CareCompanion operations team.'**
  String get blockedPending;

  /// No description provided for @blockedExpired.
  ///
  /// In en, this message translates to:
  /// **'Your professional credential has expired. Please renew it and share the updated document with your coordinator.'**
  String get blockedExpired;

  /// No description provided for @blockedExpiredOn.
  ///
  /// In en, this message translates to:
  /// **'Credential expired on {date}.'**
  String blockedExpiredOn(String date);

  /// No description provided for @blockedSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your provider account has been suspended. Please contact your care coordinator for details.'**
  String get blockedSuspended;

  /// No description provided for @blockedRejected.
  ///
  /// In en, this message translates to:
  /// **'Your verification was not approved. Please contact your care coordinator.'**
  String get blockedRejected;

  /// No description provided for @blockedCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check status again'**
  String get blockedCheckAgain;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeDutyOn.
  ///
  /// In en, this message translates to:
  /// **'On duty'**
  String get homeDutyOn;

  /// No description provided for @homeDutyOff.
  ///
  /// In en, this message translates to:
  /// **'Off duty'**
  String get homeDutyOff;

  /// No description provided for @homeDutyOnHint.
  ///
  /// In en, this message translates to:
  /// **'You can be matched to new home visits.'**
  String get homeDutyOnHint;

  /// No description provided for @homeDutyOffHint.
  ///
  /// In en, this message translates to:
  /// **'Go on duty to receive new home visits.'**
  String get homeDutyOffHint;

  /// No description provided for @homeDutyToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Duty status'**
  String get homeDutyToggleLabel;

  /// No description provided for @homeDutyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update duty status. You need to be online.'**
  String get homeDutyFailed;

  /// No description provided for @homeTodaySummary.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTodaySummary;

  /// No description provided for @homeSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get homeSummaryTotal;

  /// No description provided for @homeSummaryActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get homeSummaryActive;

  /// No description provided for @homeSummaryDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homeSummaryDone;

  /// No description provided for @homeNextVisit.
  ///
  /// In en, this message translates to:
  /// **'Next: {time}'**
  String homeNextVisit(String time);

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tabUpcoming;

  /// No description provided for @tabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tabCompleted;

  /// No description provided for @visitsEmptyToday.
  ///
  /// In en, this message translates to:
  /// **'No visits for today.'**
  String get visitsEmptyToday;

  /// No description provided for @visitsEmptyUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming visits.'**
  String get visitsEmptyUpcoming;

  /// No description provided for @visitsEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed visits yet.'**
  String get visitsEmptyCompleted;

  /// No description provided for @visitsShowingCached.
  ///
  /// In en, this message translates to:
  /// **'Offline – showing saved data'**
  String get visitsShowingCached;

  /// No description provided for @profileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTooltip;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Actions will be saved and synced later.'**
  String get offlineBanner;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync ({count})'**
  String pendingSync(int count);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncAccessRevoked.
  ///
  /// In en, this message translates to:
  /// **'A visit is no longer assigned to you. Its unsynced changes were discarded and saved patient data was removed.'**
  String get syncAccessRevoked;

  /// No description provided for @syncRejected.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept a saved action: {message}'**
  String syncRejected(String message);

  /// No description provided for @actionQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved offline. It will sync when you are back online.'**
  String get actionQueued;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get actionDone;

  /// No description provided for @statusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get statusRequested;

  /// No description provided for @statusUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get statusUnassigned;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'New assignment'**
  String get statusAssigned;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAccepted;

  /// No description provided for @statusEnRoute.
  ///
  /// In en, this message translates to:
  /// **'En route'**
  String get statusEnRoute;

  /// No description provided for @statusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get statusArrived;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get statusEscalated;

  /// No description provided for @visitTitle.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get visitTitle;

  /// No description provided for @visitTimeWindow.
  ///
  /// In en, this message translates to:
  /// **'Time window'**
  String get visitTimeWindow;

  /// No description provided for @visitReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for visit'**
  String get visitReason;

  /// No description provided for @visitAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get visitAddress;

  /// No description provided for @visitAreaOnly.
  ///
  /// In en, this message translates to:
  /// **'{city} – {pincode}'**
  String visitAreaOnly(String city, String pincode);

  /// No description provided for @visitAddressHidden.
  ///
  /// In en, this message translates to:
  /// **'Full address is shown after you accept the visit.'**
  String get visitAddressHidden;

  /// No description provided for @visitLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark: {landmark}'**
  String visitLandmark(String landmark);

  /// No description provided for @visitNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get visitNavigate;

  /// No description provided for @visitNavigateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps.'**
  String get visitNavigateFailed;

  /// No description provided for @visitPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get visitPatient;

  /// No description provided for @visitPatientContext.
  ///
  /// In en, this message translates to:
  /// **'Patient context'**
  String get visitPatientContext;

  /// No description provided for @visitAgeGender.
  ///
  /// In en, this message translates to:
  /// **'{age} yrs · {gender}'**
  String visitAgeGender(String age, String gender);

  /// No description provided for @visitAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get visitAllergies;

  /// No description provided for @visitNoAllergiesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No allergies recorded'**
  String get visitNoAllergiesRecorded;

  /// No description provided for @visitConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get visitConditions;

  /// No description provided for @visitMedications.
  ///
  /// In en, this message translates to:
  /// **'Active medications'**
  String get visitMedications;

  /// No description provided for @visitNoneRecorded.
  ///
  /// In en, this message translates to:
  /// **'None recorded'**
  String get visitNoneRecorded;

  /// No description provided for @visitContextUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Patient context is not available for this visit.'**
  String get visitContextUnavailable;

  /// No description provided for @visitTimeline.
  ///
  /// In en, this message translates to:
  /// **'Status timeline'**
  String get visitTimeline;

  /// No description provided for @visitPendingSyncChip.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get visitPendingSyncChip;

  /// No description provided for @visitEta.
  ///
  /// In en, this message translates to:
  /// **'ETA {minutes} min'**
  String visitEta(int minutes);

  /// No description provided for @visitNotFound.
  ///
  /// In en, this message translates to:
  /// **'This visit is no longer available to you.'**
  String get visitNotFound;

  /// No description provided for @visitRecordedVitals.
  ///
  /// In en, this message translates to:
  /// **'Recorded vitals'**
  String get visitRecordedVitals;

  /// No description provided for @visitSummary.
  ///
  /// In en, this message translates to:
  /// **'Visit summary'**
  String get visitSummary;

  /// No description provided for @visitEscalation.
  ///
  /// In en, this message translates to:
  /// **'Escalation'**
  String get visitEscalation;

  /// No description provided for @stepAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get stepAccept;

  /// No description provided for @stepTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get stepTravel;

  /// No description provided for @stepArrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get stepArrive;

  /// No description provided for @stepVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get stepVerify;

  /// No description provided for @stepCare.
  ///
  /// In en, this message translates to:
  /// **'Checkup'**
  String get stepCare;

  /// No description provided for @stepComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get stepComplete;

  /// No description provided for @stepperLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit progress: step {current} of {total}'**
  String stepperLabel(int current, int total);

  /// No description provided for @actionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept visit'**
  String get actionAccept;

  /// No description provided for @actionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get actionReject;

  /// No description provided for @actionRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject this visit?'**
  String get actionRejectTitle;

  /// No description provided for @actionRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get actionRejectReason;

  /// No description provided for @actionRejectReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please give a reason'**
  String get actionRejectReasonRequired;

  /// No description provided for @actionStartTravel.
  ///
  /// In en, this message translates to:
  /// **'Start travel'**
  String get actionStartTravel;

  /// No description provided for @actionEtaLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated arrival (minutes)'**
  String get actionEtaLabel;

  /// No description provided for @actionEtaInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter minutes between 1 and 240'**
  String get actionEtaInvalid;

  /// No description provided for @actionArrived.
  ///
  /// In en, this message translates to:
  /// **'I have arrived'**
  String get actionArrived;

  /// No description provided for @actionVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify patient'**
  String get actionVerifyTitle;

  /// No description provided for @actionVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'Ask the patient or guardian to read out the 4-digit visit code shown in their app.'**
  String get actionVerifyBody;

  /// No description provided for @actionVisitCode.
  ///
  /// In en, this message translates to:
  /// **'Visit code'**
  String get actionVisitCode;

  /// No description provided for @actionVisitCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit code'**
  String get actionVisitCodeInvalid;

  /// No description provided for @actionConsent.
  ///
  /// In en, this message translates to:
  /// **'Patient/guardian consents to the checkup'**
  String get actionConsent;

  /// No description provided for @actionConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Consent must be confirmed before starting'**
  String get actionConsentRequired;

  /// No description provided for @actionVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify and start checkup'**
  String get actionVerify;

  /// No description provided for @actionVerifyOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'You are offline. The code will be checked when you reconnect.'**
  String get actionVerifyOfflineNote;

  /// No description provided for @actionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete visit'**
  String get actionComplete;

  /// No description provided for @actionCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete visit'**
  String get actionCompleteTitle;

  /// No description provided for @actionSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit summary'**
  String get actionSummaryLabel;

  /// No description provided for @actionSummaryHint.
  ///
  /// In en, this message translates to:
  /// **'What was done, observations shared with the patient, any follow-up needed'**
  String get actionSummaryHint;

  /// No description provided for @actionSummaryRequired.
  ///
  /// In en, this message translates to:
  /// **'Please write a short summary'**
  String get actionSummaryRequired;

  /// No description provided for @nextAwaitingAssignment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for assignment.'**
  String get nextAwaitingAssignment;

  /// No description provided for @nextNoAction.
  ///
  /// In en, this message translates to:
  /// **'No further action needed.'**
  String get nextNoAction;

  /// No description provided for @nextCancelled.
  ///
  /// In en, this message translates to:
  /// **'This visit was cancelled.'**
  String get nextCancelled;

  /// No description provided for @nextReassigned.
  ///
  /// In en, this message translates to:
  /// **'This visit is no longer assigned to you.'**
  String get nextReassigned;

  /// No description provided for @nextVerifyIntro.
  ///
  /// In en, this message translates to:
  /// **'Verify the patient\'s identity and consent before starting.'**
  String get nextVerifyIntro;

  /// No description provided for @nextCareIntro.
  ///
  /// In en, this message translates to:
  /// **'Record vitals and observations, then complete the visit.'**
  String get nextCareIntro;

  /// No description provided for @nextEscalatedIntro.
  ///
  /// In en, this message translates to:
  /// **'This visit has been escalated. You can still complete it.'**
  String get nextEscalatedIntro;

  /// No description provided for @escalateButton.
  ///
  /// In en, this message translates to:
  /// **'Escalate'**
  String get escalateButton;

  /// No description provided for @escalateTitle.
  ///
  /// In en, this message translates to:
  /// **'Escalate to supervising doctor'**
  String get escalateTitle;

  /// No description provided for @escalateReason.
  ///
  /// In en, this message translates to:
  /// **'What is the concern?'**
  String get escalateReason;

  /// No description provided for @escalateReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe the concern'**
  String get escalateReasonRequired;

  /// No description provided for @escalateSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get escalateSeverity;

  /// No description provided for @escalateUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get escalateUrgent;

  /// No description provided for @escalateEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get escalateEmergency;

  /// No description provided for @escalateEmergencyHint.
  ///
  /// In en, this message translates to:
  /// **'For a life-threatening emergency, call 108 immediately.'**
  String get escalateEmergencyHint;

  /// No description provided for @escalateCall108.
  ///
  /// In en, this message translates to:
  /// **'Call 108'**
  String get escalateCall108;

  /// No description provided for @escalateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm escalation'**
  String get escalateConfirmTitle;

  /// No description provided for @escalateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This alerts the clinical team immediately with severity: {severity}. Continue?'**
  String escalateConfirmBody(String severity);

  /// No description provided for @escalateSend.
  ///
  /// In en, this message translates to:
  /// **'Send escalation'**
  String get escalateSend;

  /// No description provided for @vitalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitalsTitle;

  /// No description provided for @vitalsSave.
  ///
  /// In en, this message translates to:
  /// **'Save vitals'**
  String get vitalsSave;

  /// No description provided for @vitalsSaved.
  ///
  /// In en, this message translates to:
  /// **'Vitals saved'**
  String get vitalsSaved;

  /// No description provided for @vitalsBpSystolic.
  ///
  /// In en, this message translates to:
  /// **'BP systolic'**
  String get vitalsBpSystolic;

  /// No description provided for @vitalsBpDiastolic.
  ///
  /// In en, this message translates to:
  /// **'BP diastolic'**
  String get vitalsBpDiastolic;

  /// No description provided for @vitalsPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get vitalsPulse;

  /// No description provided for @vitalsSpo2.
  ///
  /// In en, this message translates to:
  /// **'SpO2'**
  String get vitalsSpo2;

  /// No description provided for @vitalsTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get vitalsTemperature;

  /// No description provided for @vitalsBloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose'**
  String get vitalsBloodGlucose;

  /// No description provided for @vitalsWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get vitalsWeight;

  /// No description provided for @vitalsRespiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Respiratory rate'**
  String get vitalsRespiratoryRate;

  /// No description provided for @vitalsErrorNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get vitalsErrorNumber;

  /// No description provided for @vitalsErrorRange.
  ///
  /// In en, this message translates to:
  /// **'Must be between {min} and {max}'**
  String vitalsErrorRange(String min, String max);

  /// No description provided for @vitalsErrorBpPair.
  ///
  /// In en, this message translates to:
  /// **'Enter both systolic and diastolic'**
  String get vitalsErrorBpPair;

  /// No description provided for @vitalsErrorBpOrder.
  ///
  /// In en, this message translates to:
  /// **'Diastolic must be lower than systolic'**
  String get vitalsErrorBpOrder;

  /// No description provided for @vitalsErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one vital'**
  String get vitalsErrorEmpty;

  /// No description provided for @vitalsNoInterpretation.
  ///
  /// In en, this message translates to:
  /// **'Values outside the usual adult range are highlighted as High or Low. Clinical review is done by the care team.'**
  String get vitalsNoInterpretation;

  /// No description provided for @obsTitle.
  ///
  /// In en, this message translates to:
  /// **'Observations'**
  String get obsTitle;

  /// No description provided for @obsAlertOriented.
  ///
  /// In en, this message translates to:
  /// **'Patient alert and oriented'**
  String get obsAlertOriented;

  /// No description provided for @obsMedicationsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Medications reviewed'**
  String get obsMedicationsReviewed;

  /// No description provided for @obsMobilityObserved.
  ///
  /// In en, this message translates to:
  /// **'Mobility observed'**
  String get obsMobilityObserved;

  /// No description provided for @obsCaregiverPresent.
  ///
  /// In en, this message translates to:
  /// **'Caregiver present'**
  String get obsCaregiverPresent;

  /// No description provided for @obsHomeSafe.
  ///
  /// In en, this message translates to:
  /// **'Home environment safe'**
  String get obsHomeSafe;

  /// No description provided for @obsConcernsNoted.
  ///
  /// In en, this message translates to:
  /// **'Patient concerns noted'**
  String get obsConcernsNoted;

  /// No description provided for @obsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get obsNotes;

  /// No description provided for @obsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Factual observations only'**
  String get obsNotesHint;

  /// No description provided for @obsSave.
  ///
  /// In en, this message translates to:
  /// **'Save observations'**
  String get obsSave;

  /// No description provided for @obsSaved.
  ///
  /// In en, this message translates to:
  /// **'Observations saved'**
  String get obsSaved;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileType.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profileType;

  /// No description provided for @profileQualification.
  ///
  /// In en, this message translates to:
  /// **'Qualification'**
  String get profileQualification;

  /// No description provided for @profileVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get profileVerification;

  /// No description provided for @profileCredentialExpiry.
  ///
  /// In en, this message translates to:
  /// **'Credential valid until'**
  String get profileCredentialExpiry;

  /// No description provided for @profileCredentialExpiring.
  ///
  /// In en, this message translates to:
  /// **'Your credential expires in {days} days. Renew it to keep receiving visits.'**
  String profileCredentialExpiring(int days);

  /// No description provided for @profileZones.
  ///
  /// In en, this message translates to:
  /// **'Service zones'**
  String get profileZones;

  /// No description provided for @profileCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get profileCapabilities;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhone;

  /// No description provided for @profileLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get profileLogoutConfirm;

  /// No description provided for @profileLogoutPending.
  ///
  /// In en, this message translates to:
  /// **'{count} unsynced actions will be discarded if you log out now.'**
  String profileLogoutPending(int count);

  /// No description provided for @profileLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'Saved visit data on this device will be removed.'**
  String get profileLogoutBody;

  /// No description provided for @typeNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get typeNurse;

  /// No description provided for @typeTechnician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get typeTechnician;

  /// No description provided for @typeIntern.
  ///
  /// In en, this message translates to:
  /// **'Intern'**
  String get typeIntern;

  /// No description provided for @typePhysiotherapist.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist'**
  String get typePhysiotherapist;

  /// No description provided for @verificationVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verificationVerified;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get verificationPending;

  /// No description provided for @verificationRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get verificationRejected;

  /// No description provided for @verificationSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get verificationSuspended;

  /// No description provided for @verificationExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get verificationExpired;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @errorMfaRequired.
  ///
  /// In en, this message translates to:
  /// **'This account needs two-step verification, which the provider app doesn\'t support. Please contact support.'**
  String get errorMfaRequired;

  /// No description provided for @mfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Extra verification required'**
  String get mfaTitle;

  /// No description provided for @mfaBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is set up to require two-step verification (MFA). CareCompanion Pro does not support this for provider accounts. Please contact your coordinator or support so they can correct your account. Your queued visit updates are kept on this device.'**
  String get mfaBody;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'This version of CareCompanion Pro is no longer supported. Please install the latest version to keep receiving visits.'**
  String get updateBody;

  /// No description provided for @updateVersions.
  ///
  /// In en, this message translates to:
  /// **'Installed {current} · Required {minimum}'**
  String updateVersions(String current, String minimum);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @photoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get photoAdd;

  /// No description provided for @photoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit photo (optional)'**
  String get photoSectionTitle;

  /// No description provided for @photoSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Only if it helps care (for example a wound or a device). Requires the patient\'s consent.'**
  String get photoSectionHint;

  /// No description provided for @photoConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient consent'**
  String get photoConsentTitle;

  /// No description provided for @photoConsentBody.
  ///
  /// In en, this message translates to:
  /// **'The photo will be saved to the patient\'s health record. Avoid faces and anything not needed for care.'**
  String get photoConsentBody;

  /// No description provided for @photoConsent.
  ///
  /// In en, this message translates to:
  /// **'The patient (or their caregiver) has agreed to this photo being taken and saved to their record.'**
  String get photoConsent;

  /// No description provided for @photoConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Patient consent is required before taking a photo.'**
  String get photoConsentRequired;

  /// No description provided for @photoOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get photoOpenCamera;

  /// No description provided for @photoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded to the patient\'s record.'**
  String get photoUploaded;

  /// No description provided for @photoQueued.
  ///
  /// In en, this message translates to:
  /// **'Photo saved. It will upload when you\'re back online.'**
  String get photoQueued;

  /// No description provided for @photoNoPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to add photos to this patient\'s record. Please contact your coordinator.'**
  String get photoNoPermission;

  /// No description provided for @photoFileMissing.
  ///
  /// In en, this message translates to:
  /// **'A queued photo could not be uploaded because it is no longer on this device. Please take it again.'**
  String get photoFileMissing;

  /// No description provided for @photoCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera.'**
  String get photoCameraFailed;

  /// No description provided for @profileSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get profileSupport;

  /// No description provided for @profileSupportCall.
  ///
  /// In en, this message translates to:
  /// **'Call support'**
  String get profileSupportCall;

  /// No description provided for @profileSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get profileSupportEmail;

  /// No description provided for @profileSupportWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp support'**
  String get profileSupportWhatsapp;

  /// No description provided for @profileSupportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Support contacts aren\'t available right now. Please contact your coordinator.'**
  String get profileSupportUnavailable;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get profilePrivacy;

  /// No description provided for @profileTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get profileTerms;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileCloseAccount.
  ///
  /// In en, this message translates to:
  /// **'Request account closure'**
  String get profileCloseAccount;

  /// No description provided for @profileCloseAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Provider accounts are staff accounts and can\'t be deleted from the app. Contact support to request closure: an administrator will disable your account and handle your data under the retention policy.'**
  String get profileCloseAccountBody;

  /// No description provided for @profileCloseAccountSubject.
  ///
  /// In en, this message translates to:
  /// **'Provider account closure request'**
  String get profileCloseAccountSubject;

  /// No description provided for @profileLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get profileLinkFailed;

  /// No description provided for @profileAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String profileAppVersion(String version);

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @typeDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get typeDoctor;

  /// No description provided for @onbTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply to join as a care provider'**
  String get onbTitle;

  /// No description provided for @onbIntro.
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t registered as a care provider yet. Apply below: our team verifies every provider before any visit can be assigned.'**
  String get onbIntro;

  /// No description provided for @onbEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit your application'**
  String get onbEditTitle;

  /// No description provided for @onbStepRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get onbStepRole;

  /// No description provided for @onbStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Qualification'**
  String get onbStepDetails;

  /// No description provided for @onbStepAreas.
  ///
  /// In en, this message translates to:
  /// **'Languages and areas'**
  String get onbStepAreas;

  /// No description provided for @onbStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get onbStepReview;

  /// No description provided for @onbTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'I am applying as'**
  String get onbTypeLabel;

  /// No description provided for @onbDoctorNote.
  ///
  /// In en, this message translates to:
  /// **'Doctors use the CareCompanion web portal after approval, not this app. You can still apply here.'**
  String get onbDoctorNote;

  /// No description provided for @onbFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name (as on your registration)'**
  String get onbFullName;

  /// No description provided for @onbQualification.
  ///
  /// In en, this message translates to:
  /// **'Qualification (e.g. GNM, B.Sc Nursing, DMLT)'**
  String get onbQualification;

  /// No description provided for @onbRegNumber.
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get onbRegNumber;

  /// No description provided for @onbRegCouncil.
  ///
  /// In en, this message translates to:
  /// **'Registration council (optional)'**
  String get onbRegCouncil;

  /// No description provided for @onbSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get onbSpecialty;

  /// No description provided for @onbExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience (years)'**
  String get onbExperience;

  /// No description provided for @onbRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get onbRequired;

  /// No description provided for @onbExperienceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of years from 0 to 60'**
  String get onbExperienceInvalid;

  /// No description provided for @onbLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages you speak'**
  String get onbLanguages;

  /// No description provided for @onbLanguagesRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one language'**
  String get onbLanguagesRequired;

  /// No description provided for @onbAreas.
  ///
  /// In en, this message translates to:
  /// **'Preferred work areas'**
  String get onbAreas;

  /// No description provided for @onbAreasHint.
  ///
  /// In en, this message translates to:
  /// **'Add the pincodes where you would like to work. Each pincode is matched to one of our service zones. Optional.'**
  String get onbAreasHint;

  /// No description provided for @onbPincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get onbPincode;

  /// No description provided for @onbPincodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit pincode'**
  String get onbPincodeInvalid;

  /// No description provided for @onbAddArea.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get onbAddArea;

  /// No description provided for @onbZoneSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved area'**
  String get onbZoneSaved;

  /// No description provided for @onbAreaNotServiceable.
  ///
  /// In en, this message translates to:
  /// **'We don\'t serve pincode {pincode} yet. You can still apply.'**
  String onbAreaNotServiceable(String pincode);

  /// No description provided for @onbReviewDocsNote.
  ///
  /// In en, this message translates to:
  /// **'After you submit, upload your documents. A registration certificate and an ID proof are required for approval.'**
  String get onbReviewDocsNote;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @onbSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get onbSubmit;

  /// No description provided for @onbResubmit.
  ///
  /// In en, this message translates to:
  /// **'Resubmit application'**
  String get onbResubmit;

  /// No description provided for @onbSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted'**
  String get onbSubmitted;

  /// No description provided for @onbCancelEdit.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get onbCancelEdit;

  /// No description provided for @onbStatusSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Application under review'**
  String get onbStatusSubmittedTitle;

  /// No description provided for @onbStatusSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Our team is reviewing your application. You\'ll be notified when there is a decision.'**
  String get onbStatusSubmittedBody;

  /// No description provided for @onbStatusChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes requested'**
  String get onbStatusChangesTitle;

  /// No description provided for @onbStatusChangesBody.
  ///
  /// In en, this message translates to:
  /// **'The reviewer asked for changes. Update your details or documents, then resubmit.'**
  String get onbStatusChangesBody;

  /// No description provided for @onbStatusRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Application not approved'**
  String get onbStatusRejectedTitle;

  /// No description provided for @onbStatusRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your application was not approved. Contact support if you have questions.'**
  String get onbStatusRejectedBody;

  /// No description provided for @onbReviewerNote.
  ///
  /// In en, this message translates to:
  /// **'Reviewer\'s note'**
  String get onbReviewerNote;

  /// No description provided for @onbReviewerNoteBy.
  ///
  /// In en, this message translates to:
  /// **'Note from {name}'**
  String onbReviewerNoteBy(String name);

  /// No description provided for @onbEditResubmit.
  ///
  /// In en, this message translates to:
  /// **'Edit & resubmit'**
  String get onbEditResubmit;

  /// No description provided for @onbEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get onbEditDetails;

  /// No description provided for @onbApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re approved'**
  String get onbApprovedTitle;

  /// No description provided for @onbApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Your application has been approved. Sign out and sign in again to start.'**
  String get onbApprovedBody;

  /// No description provided for @onbApprovedDoctorBody.
  ///
  /// In en, this message translates to:
  /// **'Your doctor account is approved. Sign in to the CareCompanion web portal to set up your schedule.'**
  String get onbApprovedDoctorBody;

  /// No description provided for @onbSignOutAndIn.
  ///
  /// In en, this message translates to:
  /// **'Sign out and sign in again'**
  String get onbSignOutAndIn;

  /// No description provided for @onbCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get onbCheckStatus;

  /// No description provided for @onbUpdatedOn.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String onbUpdatedOn(String date);

  /// No description provided for @onbDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get onbDocuments;

  /// No description provided for @onbDocsMissing.
  ///
  /// In en, this message translates to:
  /// **'Still needed: {docs}'**
  String onbDocsMissing(String docs);

  /// No description provided for @onbDocsComplete.
  ///
  /// In en, this message translates to:
  /// **'All required documents are uploaded.'**
  String get onbDocsComplete;

  /// No description provided for @onbDocsHint.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG or PNG, up to 10 MB each.'**
  String get onbDocsHint;

  /// No description provided for @onbNoDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents uploaded yet.'**
  String get onbNoDocuments;

  /// No description provided for @onbAddDocument.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get onbAddDocument;

  /// No description provided for @onbDocType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get onbDocType;

  /// No description provided for @docRegistrationCertificate.
  ///
  /// In en, this message translates to:
  /// **'Registration certificate'**
  String get docRegistrationCertificate;

  /// No description provided for @docDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree or diploma'**
  String get docDegree;

  /// No description provided for @docIdProof.
  ///
  /// In en, this message translates to:
  /// **'ID proof'**
  String get docIdProof;

  /// No description provided for @docExperienceLetter.
  ///
  /// In en, this message translates to:
  /// **'Experience letter'**
  String get docExperienceLetter;

  /// No description provided for @docOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get docOther;

  /// No description provided for @sourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get sourceCamera;

  /// No description provided for @sourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get sourceGallery;

  /// No description provided for @sourceFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose a file (PDF, JPG, PNG)'**
  String get sourceFiles;

  /// No description provided for @onbUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading… {percent}%'**
  String onbUploading(int percent);

  /// No description provided for @onbUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String onbUploadFailed(String error);

  /// No description provided for @onbFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than 10 MB.'**
  String get onbFileTooLarge;

  /// No description provided for @onbDeleteDocConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get onbDeleteDocConfirm;

  /// No description provided for @earnTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnTitle;

  /// No description provided for @earnEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed services and payouts'**
  String get earnEntrySubtitle;

  /// No description provided for @earnCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed services'**
  String get earnCompleted;

  /// No description provided for @earnGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get earnGross;

  /// No description provided for @earnPlatformFee.
  ///
  /// In en, this message translates to:
  /// **'Platform fee'**
  String get earnPlatformFee;

  /// No description provided for @earnRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get earnRefunds;

  /// No description provided for @earnPayable.
  ///
  /// In en, this message translates to:
  /// **'Payable to you'**
  String get earnPayable;

  /// No description provided for @earnLines.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get earnLines;

  /// No description provided for @earnEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed and paid services in this month.'**
  String get earnEmpty;

  /// No description provided for @earnPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get earnPrevMonth;

  /// No description provided for @earnNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get earnNextMonth;

  /// No description provided for @earnNote.
  ///
  /// In en, this message translates to:
  /// **'Only completed and paid services count. Payouts are settled by the operations team.'**
  String get earnNote;

  /// No description provided for @earnRefHomeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get earnRefHomeVisit;

  /// No description provided for @earnRefAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get earnRefAppointment;

  /// No description provided for @earnLineDetail.
  ///
  /// In en, this message translates to:
  /// **'Fee {fee} · Payable {payable}'**
  String earnLineDetail(String fee, String payable);

  /// No description provided for @avatarChange.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get avatarChange;

  /// No description provided for @avatarPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Use this photo?'**
  String get avatarPreviewTitle;

  /// No description provided for @avatarPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'Patients see this photo when you are assigned to their visit.'**
  String get avatarPreviewBody;

  /// No description provided for @avatarUse.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get avatarUse;

  /// No description provided for @avatarUploaded.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated'**
  String get avatarUploaded;

  /// No description provided for @avatarTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo must be smaller than 5 MB.'**
  String get avatarTooLarge;

  /// No description provided for @profileRating.
  ///
  /// In en, this message translates to:
  /// **'{rating} ★ ({count} ratings)'**
  String profileRating(String rating, int count);

  /// No description provided for @voiceDictate.
  ///
  /// In en, this message translates to:
  /// **'Dictate notes'**
  String get voiceDictate;

  /// No description provided for @voiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop dictation'**
  String get voiceStop;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening… speak now'**
  String get voiceListening;

  /// No description provided for @voiceReview.
  ///
  /// In en, this message translates to:
  /// **'Dictated text was added to the notes. Review and correct it before saving.'**
  String get voiceReview;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input isn\'t available on this device, or microphone permission was denied.'**
  String get voiceUnavailable;

  /// No description provided for @typeDietitian.
  ///
  /// In en, this message translates to:
  /// **'Dietitian'**
  String get typeDietitian;

  /// No description provided for @tabRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get tabRoute;

  /// No description provided for @optionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalHint;

  /// No description provided for @planFor.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String planFor(String name);

  /// No description provided for @routeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stops on your route today.'**
  String get routeEmpty;

  /// No description provided for @routeSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}} · {km} km in total'**
  String routeSummary(int count, String km);

  /// No description provided for @routeFromLastLocation.
  ///
  /// In en, this message translates to:
  /// **'Distances start from your last reported location.'**
  String get routeFromLastLocation;

  /// No description provided for @routeFromCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Distances start from your service zone centre.'**
  String get routeFromCurrentLocation;

  /// No description provided for @routeStartNavigation.
  ///
  /// In en, this message translates to:
  /// **'Start navigation'**
  String get routeStartNavigation;

  /// No description provided for @routeTooManyStops.
  ///
  /// In en, this message translates to:
  /// **'Google Maps shows the first {count} stops. Open navigation again after them.'**
  String routeTooManyStops(int count);

  /// No description provided for @routeFromStart.
  ///
  /// In en, this message translates to:
  /// **'{km} km from start'**
  String routeFromStart(String km);

  /// No description provided for @routeFromPrev.
  ///
  /// In en, this message translates to:
  /// **'{km} km from previous stop'**
  String routeFromPrev(String km);

  /// No description provided for @routeEta.
  ///
  /// In en, this message translates to:
  /// **'ETA {time}'**
  String routeEta(String time);

  /// No description provided for @routeStopLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop {index}: {service}, {window}. {details}'**
  String routeStopLabel(
    int index,
    String service,
    String window,
    String details,
  );

  /// No description provided for @attTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attTitle;

  /// No description provided for @attUnknown.
  ///
  /// In en, this message translates to:
  /// **'Attendance status unavailable'**
  String get attUnknown;

  /// No description provided for @attNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not checked in today'**
  String get attNotCheckedIn;

  /// No description provided for @attNotCheckedInHint.
  ///
  /// In en, this message translates to:
  /// **'Check in when you start your shift.'**
  String get attNotCheckedInHint;

  /// No description provided for @attCheckedInAt.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {time}'**
  String attCheckedInAt(String time);

  /// No description provided for @attCheckedOutAt.
  ///
  /// In en, this message translates to:
  /// **'Checked out at {time}'**
  String attCheckedOutAt(String time);

  /// No description provided for @attCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get attCheckIn;

  /// No description provided for @attCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get attCheckOut;

  /// No description provided for @attCheckedInToast.
  ///
  /// In en, this message translates to:
  /// **'Checked in.'**
  String get attCheckedInToast;

  /// No description provided for @attCheckedOutToast.
  ///
  /// In en, this message translates to:
  /// **'Checked out.'**
  String get attCheckedOutToast;

  /// No description provided for @attNoLocation.
  ///
  /// In en, this message translates to:
  /// **'(Location was not available.)'**
  String get attNoLocation;

  /// No description provided for @attDaysPresent.
  ///
  /// In en, this message translates to:
  /// **'Days present'**
  String get attDaysPresent;

  /// No description provided for @attHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get attHours;

  /// No description provided for @attVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get attVisits;

  /// No description provided for @attDaily.
  ///
  /// In en, this message translates to:
  /// **'Day by day'**
  String get attDaily;

  /// No description provided for @attEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attendance recorded this month.'**
  String get attEmpty;

  /// No description provided for @attAbsent.
  ///
  /// In en, this message translates to:
  /// **'No check-in'**
  String get attAbsent;

  /// No description provided for @attOpen.
  ///
  /// In en, this message translates to:
  /// **'not checked out'**
  String get attOpen;

  /// No description provided for @attHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String attHoursShort(String hours);

  /// No description provided for @attVisitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No visits} =1{1 visit} other{{count} visits}}'**
  String attVisitsCount(int count);

  /// No description provided for @supTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get supTitle;

  /// No description provided for @supEmpty.
  ///
  /// In en, this message translates to:
  /// **'No supplies are assigned to you.'**
  String get supEmpty;

  /// No description provided for @supLowBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item is running low. Ask your coordinator to restock.} other{{count} items are running low. Ask your coordinator to restock.}}'**
  String supLowBanner(int count);

  /// No description provided for @supLow.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get supLow;

  /// No description provided for @supOut.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get supOut;

  /// No description provided for @supReorderAt.
  ///
  /// In en, this message translates to:
  /// **'Reorder at {qty}'**
  String supReorderAt(String qty);

  /// No description provided for @supOnHand.
  ///
  /// In en, this message translates to:
  /// **'On hand: {qty}'**
  String supOnHand(String qty);

  /// No description provided for @supUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplies used'**
  String get supUsageTitle;

  /// No description provided for @supUsageHint.
  ///
  /// In en, this message translates to:
  /// **'Enter what you used at this visit. It is saved even when you are offline.'**
  String get supUsageHint;

  /// No description provided for @supUsageCardBody.
  ///
  /// In en, this message translates to:
  /// **'Record gloves, strips, swabs and other items used at this visit.'**
  String get supUsageCardBody;

  /// No description provided for @supUsageButton.
  ///
  /// In en, this message translates to:
  /// **'Record supplies used'**
  String get supUsageButton;

  /// No description provided for @supUsageSave.
  ///
  /// In en, this message translates to:
  /// **'Save usage'**
  String get supUsageSave;

  /// No description provided for @supUsageSaved.
  ///
  /// In en, this message translates to:
  /// **'Supplies usage saved'**
  String get supUsageSaved;

  /// No description provided for @supIncrease.
  ///
  /// In en, this message translates to:
  /// **'Add one {name}'**
  String supIncrease(String name);

  /// No description provided for @supDecrease.
  ///
  /// In en, this message translates to:
  /// **'Remove one {name}'**
  String supDecrease(String name);

  /// No description provided for @sampleTestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lab tests to collect'**
  String get sampleTestsTitle;

  /// No description provided for @sampleGeneric.
  ///
  /// In en, this message translates to:
  /// **'Collect samples as per the lab order.'**
  String get sampleGeneric;

  /// No description provided for @sampleFastingShort.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get sampleFastingShort;

  /// No description provided for @sampleFastingRequired.
  ///
  /// In en, this message translates to:
  /// **'Fasting required. Confirm with the patient before collecting.'**
  String get sampleFastingRequired;

  /// No description provided for @sampleFastingHours.
  ///
  /// In en, this message translates to:
  /// **'Fasting required ({hours} h). Confirm with the patient before collecting.'**
  String sampleFastingHours(int hours);

  /// No description provided for @sampleNoFasting.
  ///
  /// In en, this message translates to:
  /// **'No fasting needed for these tests.'**
  String get sampleNoFasting;

  /// No description provided for @sampleChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Before completing: sample checklist'**
  String get sampleChecklistTitle;

  /// No description provided for @samplePatientId.
  ///
  /// In en, this message translates to:
  /// **'Patient ID verified'**
  String get samplePatientId;

  /// No description provided for @sampleFastingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Fasting status confirmed with the patient'**
  String get sampleFastingConfirmed;

  /// No description provided for @sampleFastingNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'Fasting not needed (checked with the patient)'**
  String get sampleFastingNotNeeded;

  /// No description provided for @sampleTubesLabelled.
  ///
  /// In en, this message translates to:
  /// **'All tubes labelled'**
  String get sampleTubesLabelled;

  /// No description provided for @sampleCount.
  ///
  /// In en, this message translates to:
  /// **'Number of samples'**
  String get sampleCount;

  /// No description provided for @sampleCollectedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Samples collected'**
  String get sampleCollectedConfirm;

  /// No description provided for @sampleCompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm every item to complete the visit.'**
  String get sampleCompleteHint;

  /// No description provided for @sampleSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sample collected.} other{{count} samples collected.}} Tubes labelled, patient ID verified, fasting status confirmed.'**
  String sampleSummary(int count);

  /// No description provided for @exCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise plan'**
  String get exCardTitle;

  /// No description provided for @exCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create exercise plan'**
  String get exCreateTitle;

  /// No description provided for @exChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Choose exercises'**
  String get exChooseTitle;

  /// No description provided for @exAllAreas.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get exAllAreas;

  /// No description provided for @exLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No exercises for this body area.'**
  String get exLibraryEmpty;

  /// No description provided for @exDosageTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Sets and repetitions'**
  String get exDosageTitle;

  /// No description provided for @exNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one exercise above.'**
  String get exNoneSelected;

  /// No description provided for @exSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get exSets;

  /// No description provided for @exReps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get exReps;

  /// No description provided for @exHold.
  ///
  /// In en, this message translates to:
  /// **'Hold (s)'**
  String get exHold;

  /// No description provided for @exPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get exPerDay;

  /// No description provided for @exNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get exNotes;

  /// No description provided for @exScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Schedule'**
  String get exScheduleTitle;

  /// No description provided for @exStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get exStartDate;

  /// No description provided for @exWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get exWeeks;

  /// No description provided for @exSave.
  ///
  /// In en, this message translates to:
  /// **'Save exercise plan'**
  String get exSave;

  /// No description provided for @exCreated.
  ///
  /// In en, this message translates to:
  /// **'Exercise plan created'**
  String get exCreated;

  /// No description provided for @exErrNoExercises.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one exercise.'**
  String get exErrNoExercises;

  /// No description provided for @exErrRange.
  ///
  /// In en, this message translates to:
  /// **'{field} must be between {min} and {max}.'**
  String exErrRange(String field, int min, int max);

  /// No description provided for @exErrStartDate.
  ///
  /// In en, this message translates to:
  /// **'The start date cannot be in the past.'**
  String get exErrStartDate;

  /// No description provided for @exNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No exercise plans for this patient yet.'**
  String get exNoPlans;

  /// No description provided for @exProgressUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plan progress isn\'t available to you.'**
  String get exProgressUnavailable;

  /// No description provided for @exPlanLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}} · {author}'**
  String exPlanLine(int count, String author);

  /// No description provided for @exProgressLine.
  ///
  /// In en, this message translates to:
  /// **'{done}/{planned} sessions · {pct}% adherence'**
  String exProgressLine(int done, int planned, int pct);

  /// No description provided for @exLatestPain.
  ///
  /// In en, this message translates to:
  /// **'latest pain {score}/10'**
  String exLatestPain(int score);

  /// No description provided for @dietCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Diet plan'**
  String get dietCardTitle;

  /// No description provided for @dietCardBody.
  ///
  /// In en, this message translates to:
  /// **'Create a meal plan for this patient.'**
  String get dietCardBody;

  /// No description provided for @dietCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create diet plan'**
  String get dietCreateTitle;

  /// No description provided for @dietTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get dietTemplate;

  /// No description provided for @dietNoTemplate.
  ///
  /// In en, this message translates to:
  /// **'No template'**
  String get dietNoTemplate;

  /// No description provided for @dietGovernance.
  ///
  /// In en, this message translates to:
  /// **'[REQUIRES CLINICAL GOVERNANCE] This template is not yet clinically approved. Review every item.'**
  String get dietGovernance;

  /// No description provided for @dietConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions and target'**
  String get dietConditions;

  /// No description provided for @dietAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get dietAddCondition;

  /// No description provided for @dietCalories.
  ///
  /// In en, this message translates to:
  /// **'Calorie target (kcal/day)'**
  String get dietCalories;

  /// No description provided for @dietMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get dietMeals;

  /// No description provided for @dietMealsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate items with commas.'**
  String get dietMealsHint;

  /// No description provided for @dietAvoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid and notes'**
  String get dietAvoid;

  /// No description provided for @dietAvoidHint.
  ///
  /// In en, this message translates to:
  /// **'Foods to avoid (comma separated)'**
  String get dietAvoidHint;

  /// No description provided for @dietNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get dietNotes;

  /// No description provided for @dietValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get dietValidUntil;

  /// No description provided for @dietSave.
  ///
  /// In en, this message translates to:
  /// **'Save diet plan'**
  String get dietSave;

  /// No description provided for @dietCreated.
  ///
  /// In en, this message translates to:
  /// **'Diet plan created'**
  String get dietCreated;

  /// No description provided for @dietErrNoMeals.
  ///
  /// In en, this message translates to:
  /// **'Add food items to at least one meal.'**
  String get dietErrNoMeals;

  /// No description provided for @dietErrNoConditions.
  ///
  /// In en, this message translates to:
  /// **'Add at least one condition.'**
  String get dietErrNoConditions;

  /// No description provided for @dietErrCalories.
  ///
  /// In en, this message translates to:
  /// **'Calorie target must be between {min} and {max}.'**
  String dietErrCalories(int min, int max);

  /// No description provided for @dietErrValidUntil.
  ///
  /// In en, this message translates to:
  /// **'\"Valid until\" must be after today.'**
  String get dietErrValidUntil;

  /// No description provided for @slotEarlyMorning.
  ///
  /// In en, this message translates to:
  /// **'Early morning'**
  String get slotEarlyMorning;

  /// No description provided for @slotBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get slotBreakfast;

  /// No description provided for @slotMidMorning.
  ///
  /// In en, this message translates to:
  /// **'Mid-morning'**
  String get slotMidMorning;

  /// No description provided for @slotLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get slotLunch;

  /// No description provided for @slotEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening snack'**
  String get slotEvening;

  /// No description provided for @slotDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get slotDinner;

  /// No description provided for @slotBedtime.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get slotBedtime;

  /// No description provided for @serverChip.
  ///
  /// In en, this message translates to:
  /// **'Server: {host}'**
  String serverChip(String host);

  /// No description provided for @serverAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddressTitle;

  /// No description provided for @serverAddressHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the CareCompanion server address, for example 10.10.17.134, http://10.10.17.134:4000 or a tunnel link like https://xyz.trycloudflare.com.'**
  String get serverAddressHelp;

  /// No description provided for @serverAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL or IP address'**
  String get serverAddressLabel;

  /// No description provided for @serverAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an address like 10.10.17.134 or https://example.com'**
  String get serverAddressInvalid;

  /// No description provided for @serverTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get serverTestConnection;

  /// No description provided for @serverTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing connection…'**
  String get serverTesting;

  /// No description provided for @serverConnectedVersion.
  ///
  /// In en, this message translates to:
  /// **'Connected. Server version {version}'**
  String serverConnectedVersion(String version);

  /// No description provided for @serverCantReach.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server: check the PC is running START-CARECOMPANION.bat and the phone is on the same network, or use the tunnel link.'**
  String get serverCantReach;

  /// No description provided for @serverNotCareCompanion.
  ///
  /// In en, this message translates to:
  /// **'The server answered (HTTP {status}) but it is not the CareCompanion API. Check the address.'**
  String serverNotCareCompanion(String status);

  /// No description provided for @serverSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get serverSave;

  /// No description provided for @serverReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get serverReset;

  /// No description provided for @serverDefaultIs.
  ///
  /// In en, this message translates to:
  /// **'Default: {url}'**
  String serverDefaultIs(String url);

  /// No description provided for @serverSignOutWarning.
  ///
  /// In en, this message translates to:
  /// **'Changing the server signs you out.'**
  String get serverSignOutWarning;

  /// No description provided for @serverCantReachAt.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server at {host}'**
  String serverCantReachAt(String host);

  /// No description provided for @serverChange.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get serverChange;

  /// No description provided for @errorOtpIncorrectAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Incorrect OTP. 1 attempt left.} other{Incorrect OTP. {count} attempts left.}}'**
  String errorOtpIncorrectAttempts(int count);

  /// No description provided for @errorOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'This OTP has expired. Please request a new OTP.'**
  String get errorOtpExpired;

  /// No description provided for @errorOtpTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect attempts. Please request a new OTP.'**
  String get errorOtpTooManyAttempts;

  /// No description provided for @vitalsFlagHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get vitalsFlagHigh;

  /// No description provided for @vitalsFlagLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get vitalsFlagLow;

  /// No description provided for @vitalsFlagWithRange.
  ///
  /// In en, this message translates to:
  /// **'{flag} · usual adult range {range}'**
  String vitalsFlagWithRange(String flag, String range);

  /// No description provided for @capVitalsCheck.
  ///
  /// In en, this message translates to:
  /// **'Vitals check'**
  String get capVitalsCheck;

  /// No description provided for @capSampleCollection.
  ///
  /// In en, this message translates to:
  /// **'Sample collection'**
  String get capSampleCollection;

  /// No description provided for @capElderlyCare.
  ///
  /// In en, this message translates to:
  /// **'Elderly care'**
  String get capElderlyCare;

  /// No description provided for @capPostReportConsult.
  ///
  /// In en, this message translates to:
  /// **'Post-report consult'**
  String get capPostReportConsult;

  /// No description provided for @capPhysiotherapy.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapy'**
  String get capPhysiotherapy;

  /// No description provided for @credentialBannerAction.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get credentialBannerAction;

  /// No description provided for @locRationaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Use your location?'**
  String get locRationaleTitle;

  /// No description provided for @locRationaleBody.
  ///
  /// In en, this message translates to:
  /// **'While you are on duty, CareCompanion Pro shares your location with your care team to plan your route and show patients your arrival time. It is not shared when you are off duty.'**
  String get locRationaleBody;

  /// No description provided for @locRationaleAllow.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get locRationaleAllow;

  /// No description provided for @locRationaleNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get locRationaleNotNow;

  /// No description provided for @locDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Location is off, so route times and live tracking won\'t work. You can turn it on from the Route tab or your Profile.'**
  String get locDeniedMessage;

  /// No description provided for @locOffBanner.
  ///
  /// In en, this message translates to:
  /// **'Location is off. Turn it on for accurate route times and patient tracking.'**
  String get locOffBanner;

  /// No description provided for @locTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on location'**
  String get locTurnOn;

  /// No description provided for @locBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for this app. Allow it in Settings.'**
  String get locBlocked;

  /// No description provided for @locOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get locOpenSettings;

  /// No description provided for @locSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get locSettingTitle;

  /// No description provided for @locSettingOn.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get locSettingOn;

  /// No description provided for @locSettingOff.
  ///
  /// In en, this message translates to:
  /// **'Off. Tap to turn on'**
  String get locSettingOff;

  /// No description provided for @locServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location (GPS) is turned off on this phone.'**
  String get locServiceOff;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
