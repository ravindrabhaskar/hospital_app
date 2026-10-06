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
  /// **'CareCompanion Doctor'**
  String get appTitle;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

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

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscard;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get commonLogout;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @linkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get linkFailed;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing the last loaded data.'**
  String get offlineBanner;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priorityLabel;

  /// No description provided for @severityLabel.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get severityLabel;

  /// No description provided for @episodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Care episode'**
  String get episodeLabel;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @noneRecorded.
  ///
  /// In en, this message translates to:
  /// **'None recorded'**
  String get noneRecorded;

  /// No description provided for @noneAdded.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet'**
  String get noneAdded;

  /// No description provided for @onePerLine.
  ///
  /// In en, this message translates to:
  /// **'One per line'**
  String get onePerLine;

  /// No description provided for @commaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas'**
  String get commaSeparated;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} y'**
  String ageYears(int age);

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(int count);

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

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach CareCompanion. Check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'The service is having trouble. Please try again shortly.'**
  String get errorServer;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available.'**
  String get errorNotFound;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorMfaRequired.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is required to continue.'**
  String get errorMfaRequired;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your queue, patients and care team in one place.'**
  String get loginSubtitle;

  /// No description provided for @loginPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get loginPhoneLabel;

  /// No description provided for @loginPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'10-digit number'**
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

  /// No description provided for @loginOtpSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {phone}'**
  String loginOtpSentTo(String phone);

  /// No description provided for @loginOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit OTP'**
  String get loginOtpLabel;

  /// No description provided for @loginOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get loginOtpInvalid;

  /// No description provided for @loginDevOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Development OTP: {code}'**
  String loginDevOtpHint(String code);

  /// No description provided for @loginVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get loginVerify;

  /// No description provided for @loginChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get loginChangeNumber;

  /// No description provided for @mfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get mfaTitle;

  /// No description provided for @mfaEnrolIntro.
  ///
  /// In en, this message translates to:
  /// **'Doctor accounts are protected with an authenticator app code in addition to the SMS OTP.'**
  String get mfaEnrolIntro;

  /// No description provided for @mfaStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Add CareCompanion to your authenticator'**
  String get mfaStep1;

  /// No description provided for @mfaStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Enter the 6-digit code it shows'**
  String get mfaStep2;

  /// No description provided for @mfaOpenAppHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the button to add the account automatically, or type the setup key into the app.'**
  String get mfaOpenAppHint;

  /// No description provided for @mfaOpenAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Open authenticator app'**
  String get mfaOpenAuthenticator;

  /// No description provided for @mfaSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'Setup key'**
  String get mfaSecretLabel;

  /// No description provided for @mfaCopySecret.
  ///
  /// In en, this message translates to:
  /// **'Copy setup key'**
  String get mfaCopySecret;

  /// No description provided for @mfaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Authenticator code'**
  String get mfaCodeLabel;

  /// No description provided for @mfaTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Verify and turn on'**
  String get mfaTurnOn;

  /// No description provided for @mfaRecoveryIntro.
  ///
  /// In en, this message translates to:
  /// **'Save these recovery codes somewhere safe. Each works once if you lose your phone. They will not be shown again.'**
  String get mfaRecoveryIntro;

  /// No description provided for @mfaCopyCodes.
  ///
  /// In en, this message translates to:
  /// **'Copy all codes'**
  String get mfaCopyCodes;

  /// No description provided for @mfaSavedCodes.
  ///
  /// In en, this message translates to:
  /// **'I\'ve saved my recovery codes'**
  String get mfaSavedCodes;

  /// No description provided for @mfaVerifyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get mfaVerifyPrompt;

  /// No description provided for @mfaRecoveryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter one of your recovery codes. Each code works only once.'**
  String get mfaRecoveryPrompt;

  /// No description provided for @mfaRecoveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get mfaRecoveryLabel;

  /// No description provided for @mfaVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get mfaVerify;

  /// No description provided for @mfaUseRecovery.
  ///
  /// In en, this message translates to:
  /// **'Use a recovery code instead'**
  String get mfaUseRecovery;

  /// No description provided for @mfaUseAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Use the authenticator app'**
  String get mfaUseAuthenticator;

  /// No description provided for @mfaWrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code is incorrect.'**
  String get mfaWrongCode;

  /// No description provided for @mfaWrongCodeAttempts.
  ///
  /// In en, this message translates to:
  /// **'That code is incorrect. {count} attempts left.'**
  String mfaWrongCodeAttempts(int count);

  /// No description provided for @mfaCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get mfaCodeInvalid;

  /// No description provided for @mfaRecoveryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid recovery code'**
  String get mfaRecoveryInvalid;

  /// No description provided for @mfaLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect codes. Try again in 15 minutes.'**
  String get mfaLocked;

  /// No description provided for @mfaStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On (authenticator app)'**
  String get mfaStatusOn;

  /// No description provided for @mfaStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet. You will be asked when your organisation requires it.'**
  String get mfaStatusOff;

  /// No description provided for @restrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'This app is for doctors'**
  String get restrictedTitle;

  /// No description provided for @restrictedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account does not have a verified doctor profile.'**
  String get restrictedBody;

  /// No description provided for @restrictedPatient.
  ///
  /// In en, this message translates to:
  /// **'Please use the CareCompanion app for patients and families.'**
  String get restrictedPatient;

  /// No description provided for @restrictedProvider.
  ///
  /// In en, this message translates to:
  /// **'Please use the CareCompanion Pro app for home-care visits.'**
  String get restrictedProvider;

  /// No description provided for @restrictedStaff.
  ///
  /// In en, this message translates to:
  /// **'Please use the CareCompanion web portal for your role.'**
  String get restrictedStaff;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Please update the app'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'This version is no longer supported. Update to keep seeing patients safely.'**
  String get updateBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateVersions.
  ///
  /// In en, this message translates to:
  /// **'Installed {current} · required {minimum}'**
  String updateVersions(String current, String minimum);

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportTitle;

  /// No description provided for @supportCall.
  ///
  /// In en, this message translates to:
  /// **'Call support'**
  String get supportCall;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get supportEmail;

  /// No description provided for @supportWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp support'**
  String get supportWhatsapp;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @helloDoctor.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String helloDoctor(String name);

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No consultations on this day.'**
  String get queueEmpty;

  /// No description provided for @queueWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get queueWaiting;

  /// No description provided for @queueInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get queueInProgress;

  /// No description provided for @queueDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get queueDone;

  /// No description provided for @apptPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get apptPendingPayment;

  /// No description provided for @apptConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get apptConfirmed;

  /// No description provided for @apptInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get apptInProgress;

  /// No description provided for @apptCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get apptCompleted;

  /// No description provided for @apptCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get apptCancelled;

  /// No description provided for @apptNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get apptNoShow;

  /// No description provided for @priorityRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get priorityRoutine;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @priorityEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get priorityEmergency;

  /// No description provided for @epNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get epNew;

  /// No description provided for @epIntake.
  ///
  /// In en, this message translates to:
  /// **'Intake'**
  String get epIntake;

  /// No description provided for @epAwaitingCare.
  ///
  /// In en, this message translates to:
  /// **'Awaiting care'**
  String get epAwaitingCare;

  /// No description provided for @epCareScheduled.
  ///
  /// In en, this message translates to:
  /// **'Care scheduled'**
  String get epCareScheduled;

  /// No description provided for @epUnderCare.
  ///
  /// In en, this message translates to:
  /// **'Under care'**
  String get epUnderCare;

  /// No description provided for @epFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get epFollowUp;

  /// No description provided for @epResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get epResolved;

  /// No description provided for @epEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get epEscalated;

  /// No description provided for @epEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get epEmergency;

  /// No description provided for @epTransferred.
  ///
  /// In en, this message translates to:
  /// **'Transferred'**
  String get epTransferred;

  /// No description provided for @epCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get epCancelled;

  /// No description provided for @modeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get modeVideo;

  /// No description provided for @modeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get modeAudio;

  /// No description provided for @modeChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get modeChat;

  /// No description provided for @modeInClinic.
  ///
  /// In en, this message translates to:
  /// **'In clinic'**
  String get modeInClinic;

  /// No description provided for @modeHomeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get modeHomeVisit;

  /// No description provided for @consultTitle.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get consultTitle;

  /// No description provided for @openPatient.
  ///
  /// In en, this message translates to:
  /// **'Open patient record'**
  String get openPatient;

  /// No description provided for @startConsult.
  ///
  /// In en, this message translates to:
  /// **'Start consultation'**
  String get startConsult;

  /// No description provided for @completeConsult.
  ///
  /// In en, this message translates to:
  /// **'Complete consultation'**
  String get completeConsult;

  /// No description provided for @consultStarted.
  ///
  /// In en, this message translates to:
  /// **'Consultation started'**
  String get consultStarted;

  /// No description provided for @consultCompleted.
  ///
  /// In en, this message translates to:
  /// **'Consultation completed'**
  String get consultCompleted;

  /// No description provided for @savedNotes.
  ///
  /// In en, this message translates to:
  /// **'Saved notes'**
  String get savedNotes;

  /// No description provided for @outcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get outcomeLabel;

  /// No description provided for @outcomeCarePlan.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get outcomeCarePlan;

  /// No description provided for @outcomeResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get outcomeResolved;

  /// No description provided for @outcomeRefer.
  ///
  /// In en, this message translates to:
  /// **'Refer'**
  String get outcomeRefer;

  /// No description provided for @outcomeHomeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get outcomeHomeVisit;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinical notes'**
  String get notesTitle;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Type your notes, or use the AI scribe'**
  String get notesHint;

  /// No description provided for @notesSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Notes are saved when you complete the consultation.'**
  String get notesSaveHint;

  /// No description provided for @saveEpisodeNote.
  ///
  /// In en, this message translates to:
  /// **'Add to care episode now'**
  String get saveEpisodeNote;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note added to the care episode'**
  String get noteSaved;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get toolsTitle;

  /// No description provided for @careTeamThread.
  ///
  /// In en, this message translates to:
  /// **'Care-team messages'**
  String get careTeamThread;

  /// No description provided for @joinVideo.
  ///
  /// In en, this message translates to:
  /// **'Join video'**
  String get joinVideo;

  /// No description provided for @videoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video consultation'**
  String get videoTitle;

  /// No description provided for @videoWindow.
  ///
  /// In en, this message translates to:
  /// **'Room open'**
  String get videoWindow;

  /// No description provided for @videoAudioHint.
  ///
  /// In en, this message translates to:
  /// **'Audio consultation: keep your camera off.'**
  String get videoAudioHint;

  /// No description provided for @videoOpensAt.
  ///
  /// In en, this message translates to:
  /// **'The room opens at {time} (10 minutes before the start).'**
  String videoOpensAt(String time);

  /// No description provided for @intakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Presenting complaint (AI intake)'**
  String get intakeTitle;

  /// No description provided for @intakeComplaint.
  ///
  /// In en, this message translates to:
  /// **'Chief complaint'**
  String get intakeComplaint;

  /// No description provided for @intakeDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get intakeDuration;

  /// No description provided for @intakeSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get intakeSeverity;

  /// No description provided for @intakeSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Associated symptoms'**
  String get intakeSymptoms;

  /// No description provided for @allergiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergiesTitle;

  /// No description provided for @allergiesNone.
  ///
  /// In en, this message translates to:
  /// **'No known allergies recorded'**
  String get allergiesNone;

  /// No description provided for @conditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditionsTitle;

  /// No description provided for @activeMedsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active medications'**
  String get activeMedsTitle;

  /// No description provided for @recentVitalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent vitals'**
  String get recentVitalsTitle;

  /// No description provided for @homeVisitFindingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Home-visit findings'**
  String get homeVisitFindingsTitle;

  /// No description provided for @escalatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get escalatedLabel;

  /// No description provided for @aiSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get aiSummaryTitle;

  /// No description provided for @aiAdvisoryLabel.
  ///
  /// In en, this message translates to:
  /// **'AI-generated · advisory, not a diagnosis'**
  String get aiAdvisoryLabel;

  /// No description provided for @aiSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get aiSource;

  /// No description provided for @aiFeedbackPrompt.
  ///
  /// In en, this message translates to:
  /// **'Was this summary accurate?'**
  String get aiFeedbackPrompt;

  /// No description provided for @aiAccept.
  ///
  /// In en, this message translates to:
  /// **'Accurate'**
  String get aiAccept;

  /// No description provided for @aiReject.
  ///
  /// In en, this message translates to:
  /// **'Not accurate'**
  String get aiReject;

  /// No description provided for @aiFeedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks, your feedback was recorded.'**
  String get aiFeedbackThanks;

  /// No description provided for @aiRecordSummary.
  ///
  /// In en, this message translates to:
  /// **'AI record summary'**
  String get aiRecordSummary;

  /// No description provided for @srcRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get srcRecord;

  /// No description provided for @srcVital.
  ///
  /// In en, this message translates to:
  /// **'Vital'**
  String get srcVital;

  /// No description provided for @srcIntake.
  ///
  /// In en, this message translates to:
  /// **'Intake'**
  String get srcIntake;

  /// No description provided for @srcHomeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get srcHomeVisit;

  /// No description provided for @srcPatientEntered.
  ///
  /// In en, this message translates to:
  /// **'Patient entered'**
  String get srcPatientEntered;

  /// No description provided for @scribeTitle.
  ///
  /// In en, this message translates to:
  /// **'AI scribe'**
  String get scribeTitle;

  /// No description provided for @scribeConsent.
  ///
  /// In en, this message translates to:
  /// **'The patient agreed to this consultation being recorded and transcribed'**
  String get scribeConsent;

  /// No description provided for @scribeConsentHint.
  ///
  /// In en, this message translates to:
  /// **'Required before recording or sending a transcript. This is audited.'**
  String get scribeConsentHint;

  /// No description provided for @scribeConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm the patient\'s consent first.'**
  String get scribeConsentRequired;

  /// No description provided for @scribeRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record the consultation'**
  String get scribeRecordTitle;

  /// No description provided for @scribeRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get scribeRecord;

  /// No description provided for @scribeRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get scribeRecording;

  /// No description provided for @scribeStopUpload.
  ///
  /// In en, this message translates to:
  /// **'Stop and create draft'**
  String get scribeStopUpload;

  /// No description provided for @scribeAudioNote.
  ///
  /// In en, this message translates to:
  /// **'Audio is uploaded once, transcribed and then discarded by the server.'**
  String get scribeAudioNote;

  /// No description provided for @scribeTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Or type / paste a transcript'**
  String get scribeTranscriptTitle;

  /// No description provided for @scribeTranscriptHint.
  ///
  /// In en, this message translates to:
  /// **'Doctor: … Patient: …'**
  String get scribeTranscriptHint;

  /// No description provided for @scribeGenerate.
  ///
  /// In en, this message translates to:
  /// **'Create SOAP draft'**
  String get scribeGenerate;

  /// No description provided for @scribeDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'SOAP draft'**
  String get scribeDraftTitle;

  /// No description provided for @scribeInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert into notes'**
  String get scribeInsert;

  /// No description provided for @scribeInserted.
  ///
  /// In en, this message translates to:
  /// **'Draft inserted. Review and edit before completing.'**
  String get scribeInserted;

  /// No description provided for @scribeMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed to record.'**
  String get scribeMicDenied;

  /// No description provided for @scribeTranscriptShort.
  ///
  /// In en, this message translates to:
  /// **'The transcript is too short.'**
  String get scribeTranscriptShort;

  /// No description provided for @scribeTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The recording is larger than 25 MB. Record a shorter segment.'**
  String get scribeTooLarge;

  /// No description provided for @soapS.
  ///
  /// In en, this message translates to:
  /// **'Subjective'**
  String get soapS;

  /// No description provided for @soapO.
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get soapO;

  /// No description provided for @soapA.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get soapA;

  /// No description provided for @soapP.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get soapP;

  /// No description provided for @rxTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get rxTitle;

  /// No description provided for @rxFor.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String rxFor(String name);

  /// No description provided for @rxItems.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get rxItems;

  /// No description provided for @rxNoItems.
  ///
  /// In en, this message translates to:
  /// **'Add at least one medicine.'**
  String get rxNoItems;

  /// No description provided for @rxNeedsStart.
  ///
  /// In en, this message translates to:
  /// **'Start the consultation first'**
  String get rxNeedsStart;

  /// No description provided for @rxItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get rxItemTitle;

  /// No description provided for @rxDrugName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get rxDrugName;

  /// No description provided for @rxStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get rxStrength;

  /// No description provided for @rxForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get rxForm;

  /// No description provided for @rxDose.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get rxDose;

  /// No description provided for @rxFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get rxFrequency;

  /// No description provided for @rxTiming.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get rxTiming;

  /// No description provided for @rxTimingHint.
  ///
  /// In en, this message translates to:
  /// **'After food'**
  String get rxTimingHint;

  /// No description provided for @rxDuration.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get rxDuration;

  /// No description provided for @rxDurationInvalid.
  ///
  /// In en, this message translates to:
  /// **'1–365 days'**
  String get rxDurationInvalid;

  /// No description provided for @rxTimes.
  ///
  /// In en, this message translates to:
  /// **'Reminder times (HH:MM)'**
  String get rxTimes;

  /// No description provided for @rxTimesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 24-hour times like 08:00, 20:00'**
  String get rxTimesInvalid;

  /// No description provided for @rxInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get rxInstructions;

  /// No description provided for @rxChecksTitle.
  ///
  /// In en, this message translates to:
  /// **'Interaction & allergy check'**
  String get rxChecksTitle;

  /// No description provided for @rxCheckIdle.
  ///
  /// In en, this message translates to:
  /// **'Checks run automatically as you add medicines.'**
  String get rxCheckIdle;

  /// No description provided for @rxChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get rxChecking;

  /// No description provided for @rxNoWarnings.
  ///
  /// In en, this message translates to:
  /// **'No interactions or allergy conflicts found.'**
  String get rxNoWarnings;

  /// No description provided for @rxPack.
  ///
  /// In en, this message translates to:
  /// **'Knowledge pack {pack}'**
  String rxPack(String pack);

  /// No description provided for @sevMajor.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get sevMajor;

  /// No description provided for @sevModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get sevModerate;

  /// No description provided for @sevInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get sevInfo;

  /// No description provided for @warnAllergy.
  ///
  /// In en, this message translates to:
  /// **'Allergy'**
  String get warnAllergy;

  /// No description provided for @warnDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate therapy'**
  String get warnDuplicate;

  /// No description provided for @warnInteraction.
  ///
  /// In en, this message translates to:
  /// **'Interaction'**
  String get warnInteraction;

  /// No description provided for @warnDoseForm.
  ///
  /// In en, this message translates to:
  /// **'Dose / form'**
  String get warnDoseForm;

  /// No description provided for @rxAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I have reviewed the major warnings and still want to prescribe'**
  String get rxAcknowledge;

  /// No description provided for @rxOverrideReason.
  ///
  /// In en, this message translates to:
  /// **'Clinical reason for overriding'**
  String get rxOverrideReason;

  /// No description provided for @rxOverrideReasonHint.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters. Audited.'**
  String rxOverrideReasonHint(int min);

  /// No description provided for @rxMajorBlocked.
  ///
  /// In en, this message translates to:
  /// **'Major warnings need your acknowledgement and a reason.'**
  String get rxMajorBlocked;

  /// No description provided for @rxClinicalNote.
  ///
  /// In en, this message translates to:
  /// **'Clinical note (on the prescription)'**
  String get rxClinicalNote;

  /// No description provided for @rxAdvice.
  ///
  /// In en, this message translates to:
  /// **'Advice'**
  String get rxAdvice;

  /// No description provided for @rxFollowUpDays.
  ///
  /// In en, this message translates to:
  /// **'Follow up in (days)'**
  String get rxFollowUpDays;

  /// No description provided for @rxSign.
  ///
  /// In en, this message translates to:
  /// **'Create prescription'**
  String get rxSign;

  /// No description provided for @rxCreated.
  ///
  /// In en, this message translates to:
  /// **'Prescription created and shared with the patient'**
  String get rxCreated;

  /// No description provided for @rxPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescription · {name}'**
  String rxPdfTitle(String name);

  /// No description provided for @formTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get formTablet;

  /// No description provided for @formCapsule.
  ///
  /// In en, this message translates to:
  /// **'Capsule'**
  String get formCapsule;

  /// No description provided for @formSyrup.
  ///
  /// In en, this message translates to:
  /// **'Syrup'**
  String get formSyrup;

  /// No description provided for @formInjection.
  ///
  /// In en, this message translates to:
  /// **'Injection'**
  String get formInjection;

  /// No description provided for @formOintment.
  ///
  /// In en, this message translates to:
  /// **'Ointment'**
  String get formOintment;

  /// No description provided for @formDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get formDrops;

  /// No description provided for @formInhaler.
  ///
  /// In en, this message translates to:
  /// **'Inhaler'**
  String get formInhaler;

  /// No description provided for @formOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get formOther;

  /// No description provided for @pdfDocument.
  ///
  /// In en, this message translates to:
  /// **'PDF document: {title}'**
  String pdfDocument(String title);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pageOf(int page, int total);

  /// No description provided for @fileReady.
  ///
  /// In en, this message translates to:
  /// **'The file is ready. Open it in your browser to view it.'**
  String get fileReady;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// No description provided for @carePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get carePlanTitle;

  /// No description provided for @carePlanSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get carePlanSummary;

  /// No description provided for @carePlanInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions for the patient'**
  String get carePlanInstructions;

  /// No description provided for @carePlanTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get carePlanTasks;

  /// No description provided for @carePlanMeds.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get carePlanMeds;

  /// No description provided for @carePlanSaved.
  ///
  /// In en, this message translates to:
  /// **'Care plan saved'**
  String get carePlanSaved;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskTitle;

  /// No description provided for @taskType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get taskType;

  /// No description provided for @taskOwner.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get taskOwner;

  /// No description provided for @taskDueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in (days, optional)'**
  String get taskDueInDays;

  /// No description provided for @taskMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get taskMedication;

  /// No description provided for @taskTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get taskTest;

  /// No description provided for @taskFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get taskFollowUp;

  /// No description provided for @taskLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get taskLifestyle;

  /// No description provided for @taskMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get taskMonitoring;

  /// No description provided for @taskGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get taskGeneral;

  /// No description provided for @ownerPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get ownerPatient;

  /// No description provided for @ownerCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get ownerCaregiver;

  /// No description provided for @ownerProvider.
  ///
  /// In en, this message translates to:
  /// **'Care provider'**
  String get ownerProvider;

  /// No description provided for @followUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get followUpTitle;

  /// No description provided for @followUpAfterDays.
  ///
  /// In en, this message translates to:
  /// **'After (days)'**
  String get followUpAfterDays;

  /// No description provided for @followUpMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get followUpMode;

  /// No description provided for @followUpNone.
  ///
  /// In en, this message translates to:
  /// **'No follow-up'**
  String get followUpNone;

  /// No description provided for @referTitle.
  ///
  /// In en, this message translates to:
  /// **'Refer to hospital'**
  String get referTitle;

  /// No description provided for @referSearchHospital.
  ///
  /// In en, this message translates to:
  /// **'Search hospitals'**
  String get referSearchHospital;

  /// No description provided for @referNoHospitals.
  ///
  /// In en, this message translates to:
  /// **'No hospitals found.'**
  String get referNoHospitals;

  /// No description provided for @referSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty (optional)'**
  String get referSpecialty;

  /// No description provided for @referReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for referral'**
  String get referReason;

  /// No description provided for @referSummary.
  ///
  /// In en, this message translates to:
  /// **'Clinical summary (optional)'**
  String get referSummary;

  /// No description provided for @referSend.
  ///
  /// In en, this message translates to:
  /// **'Create referral letter'**
  String get referSend;

  /// No description provided for @referSaved.
  ///
  /// In en, this message translates to:
  /// **'Referral created. The patient has been notified.'**
  String get referSaved;

  /// No description provided for @emergency24x7.
  ///
  /// In en, this message translates to:
  /// **'24×7 emergency'**
  String get emergency24x7;

  /// No description provided for @enrolTitle.
  ///
  /// In en, this message translates to:
  /// **'Enrol in care program'**
  String get enrolTitle;

  /// No description provided for @enrolThresholds.
  ///
  /// In en, this message translates to:
  /// **'Alert thresholds'**
  String get enrolThresholds;

  /// No description provided for @enrolSave.
  ///
  /// In en, this message translates to:
  /// **'Enrol patient'**
  String get enrolSave;

  /// No description provided for @enrolSaved.
  ///
  /// In en, this message translates to:
  /// **'Patient enrolled'**
  String get enrolSaved;

  /// No description provided for @fixtureWarning.
  ///
  /// In en, this message translates to:
  /// **'Template not yet clinically approved (fixture).'**
  String get fixtureWarning;

  /// No description provided for @exerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise plan'**
  String get exerciseTitle;

  /// No description provided for @exerciseWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get exerciseWeeks;

  /// No description provided for @exerciseSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get exerciseSets;

  /// No description provided for @exerciseReps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get exerciseReps;

  /// No description provided for @exercisePerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get exercisePerDay;

  /// No description provided for @planSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan shared with the patient'**
  String get planSaved;

  /// No description provided for @dietTitle.
  ///
  /// In en, this message translates to:
  /// **'Diet plan'**
  String get dietTitle;

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

  /// No description provided for @dietConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions (comma separated)'**
  String get dietConditions;

  /// No description provided for @dietCalories.
  ///
  /// In en, this message translates to:
  /// **'Calorie target (optional)'**
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

  /// No description provided for @dietMealsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} meals filled'**
  String dietMealsCount(int count);

  /// No description provided for @dietNeedMeals.
  ///
  /// In en, this message translates to:
  /// **'Choose a template or fill at least one meal.'**
  String get dietNeedMeals;

  /// No description provided for @dietAvoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid (comma separated)'**
  String get dietAvoid;

  /// No description provided for @dietNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get dietNotes;

  /// No description provided for @dietValidWeeks.
  ///
  /// In en, this message translates to:
  /// **'Valid for {weeks} weeks'**
  String dietValidWeeks(int weeks);

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
  /// **'Evening'**
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

  /// No description provided for @patientTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patientTitle;

  /// No description provided for @patientSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search your patients by name'**
  String get patientSearchHint;

  /// No description provided for @patientsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Patients you consult or who share records with you appear here.'**
  String get patientsEmpty;

  /// No description provided for @patientsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No patients match your search.'**
  String get patientsNoMatch;

  /// No description provided for @bloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood group'**
  String get bloodGroup;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get tabRecords;

  /// No description provided for @tabVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get tabVitals;

  /// No description provided for @tabPrograms.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get tabPrograms;

  /// No description provided for @tabPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get tabPrescriptions;

  /// No description provided for @tabEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get tabEpisodes;

  /// No description provided for @recordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records shared.'**
  String get recordsEmpty;

  /// No description provided for @openOriginal.
  ///
  /// In en, this message translates to:
  /// **'Open original file'**
  String get openOriginal;

  /// No description provided for @recLab.
  ///
  /// In en, this message translates to:
  /// **'Lab report'**
  String get recLab;

  /// No description provided for @recPrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get recPrescription;

  /// No description provided for @recImaging.
  ///
  /// In en, this message translates to:
  /// **'Imaging'**
  String get recImaging;

  /// No description provided for @recDischarge.
  ///
  /// In en, this message translates to:
  /// **'Discharge summary'**
  String get recDischarge;

  /// No description provided for @recVisitSummary.
  ///
  /// In en, this message translates to:
  /// **'Visit summary'**
  String get recVisitSummary;

  /// No description provided for @recOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recOther;

  /// No description provided for @vitalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vitals recorded.'**
  String get vitalsEmpty;

  /// No description provided for @vitalRange.
  ///
  /// In en, this message translates to:
  /// **'Range {min}–{max}'**
  String vitalRange(String min, String max);

  /// No description provided for @readingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reading} other{{count} readings}}'**
  String readingsCount(int count);

  /// No description provided for @vitalTrendSemantics.
  ///
  /// In en, this message translates to:
  /// **'{vital} trend: {count, plural, =1{1 reading} other{{count} readings}} between {min} and {max}'**
  String vitalTrendSemantics(String vital, String min, String max, int count);

  /// No description provided for @vitalBpSystolic.
  ///
  /// In en, this message translates to:
  /// **'BP systolic'**
  String get vitalBpSystolic;

  /// No description provided for @vitalBpDiastolic.
  ///
  /// In en, this message translates to:
  /// **'BP diastolic'**
  String get vitalBpDiastolic;

  /// No description provided for @vitalPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get vitalPulse;

  /// No description provided for @vitalSpo2.
  ///
  /// In en, this message translates to:
  /// **'SpO2'**
  String get vitalSpo2;

  /// No description provided for @vitalTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get vitalTemperature;

  /// No description provided for @vitalGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose'**
  String get vitalGlucose;

  /// No description provided for @vitalWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get vitalWeight;

  /// No description provided for @vitalRespiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Respiratory rate'**
  String get vitalRespiratoryRate;

  /// No description provided for @programsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enrolled in any care program.'**
  String get programsEmpty;

  /// No description provided for @programAdherence.
  ///
  /// In en, this message translates to:
  /// **'Adherence (7 days)'**
  String get programAdherence;

  /// No description provided for @programLastReading.
  ///
  /// In en, this message translates to:
  /// **'Last reading'**
  String get programLastReading;

  /// No description provided for @programOpenBreaches.
  ///
  /// In en, this message translates to:
  /// **'Open alerts'**
  String get programOpenBreaches;

  /// No description provided for @progActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get progActive;

  /// No description provided for @progPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get progPaused;

  /// No description provided for @progCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get progCompleted;

  /// No description provided for @prescriptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions yet.'**
  String get prescriptionsEmpty;

  /// No description provided for @episodesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No care episodes.'**
  String get episodesEmpty;

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'No care-team conversations yet.'**
  String get inboxEmpty;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message the care team'**
  String get messageHint;

  /// No description provided for @emergencyNotice.
  ///
  /// In en, this message translates to:
  /// **'Emergency safety notice'**
  String get emergencyNotice;

  /// No description provided for @secondOpinionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Second opinions'**
  String get secondOpinionsTitle;

  /// No description provided for @soTabOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get soTabOpen;

  /// No description provided for @soTabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get soTabMine;

  /// No description provided for @soEmpty.
  ///
  /// In en, this message translates to:
  /// **'No requests here.'**
  String get soEmpty;

  /// No description provided for @soOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get soOpen;

  /// No description provided for @soClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get soClaimed;

  /// No description provided for @soAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get soAnswered;

  /// No description provided for @soClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get soClaim;

  /// No description provided for @soClaimedMsg.
  ///
  /// In en, this message translates to:
  /// **'Request claimed. Records are now shared with you.'**
  String get soClaimedMsg;

  /// No description provided for @soRespond.
  ///
  /// In en, this message translates to:
  /// **'Write opinion'**
  String get soRespond;

  /// No description provided for @soOpinion.
  ///
  /// In en, this message translates to:
  /// **'Opinion'**
  String get soOpinion;

  /// No description provided for @soRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get soRecommendations;

  /// No description provided for @soSuggestTele.
  ///
  /// In en, this message translates to:
  /// **'Suggest a teleconsultation'**
  String get soSuggestTele;

  /// No description provided for @soSent.
  ///
  /// In en, this message translates to:
  /// **'Opinion sent to the patient'**
  String get soSent;

  /// No description provided for @soDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String soDue(String date);

  /// No description provided for @escalationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Escalations'**
  String get escalationsTitle;

  /// No description provided for @escalationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No escalations for your patients.'**
  String get escalationsEmpty;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule & leaves'**
  String get scheduleTitle;

  /// No description provided for @weeklyTab.
  ///
  /// In en, this message translates to:
  /// **'Weekly hours'**
  String get weeklyTab;

  /// No description provided for @leavesTab.
  ///
  /// In en, this message translates to:
  /// **'Leaves'**
  String get leavesTab;

  /// No description provided for @scheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Saving regenerates unbooked slots for the next {days} days. Booked slots are never changed.'**
  String scheduleHint(int days);

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No weekly hours yet.'**
  String get scheduleEmpty;

  /// No description provided for @addBlock.
  ///
  /// In en, this message translates to:
  /// **'Add hours'**
  String get addBlock;

  /// No description provided for @blockTitle.
  ///
  /// In en, this message translates to:
  /// **'Consultation hours'**
  String get blockTitle;

  /// No description provided for @weekday.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get weekday;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTime;

  /// No description provided for @slotLength.
  ///
  /// In en, this message translates to:
  /// **'Slot length'**
  String get slotLength;

  /// No description provided for @slotMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String slotMinutes(int minutes);

  /// No description provided for @blockInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Invalid time'**
  String get blockInvalidTime;

  /// No description provided for @blockEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End must be after start'**
  String get blockEndBeforeStart;

  /// No description provided for @blockTooShort.
  ///
  /// In en, this message translates to:
  /// **'Shorter than one slot'**
  String get blockTooShort;

  /// No description provided for @blockNoModes.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one mode'**
  String get blockNoModes;

  /// No description provided for @blockOverlap.
  ///
  /// In en, this message translates to:
  /// **'Overlaps other hours on this day'**
  String get blockOverlap;

  /// No description provided for @saveSchedule.
  ///
  /// In en, this message translates to:
  /// **'Save weekly hours'**
  String get saveSchedule;

  /// No description provided for @fixProblems.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted hours'**
  String get fixProblems;

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved'**
  String get scheduleSaved;

  /// No description provided for @leavesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No leaves planned.'**
  String get leavesEmpty;

  /// No description provided for @addLeave.
  ///
  /// In en, this message translates to:
  /// **'Add leave'**
  String get addLeave;

  /// No description provided for @leaveReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get leaveReason;

  /// No description provided for @leaveAdded.
  ///
  /// In en, this message translates to:
  /// **'Leave added'**
  String get leaveAdded;

  /// No description provided for @leaveConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} booked consultations on this day'**
  String leaveConflictsTitle(int count);

  /// No description provided for @leaveConflictsBody.
  ///
  /// In en, this message translates to:
  /// **'They are not cancelled automatically. Please ask the care team to reschedule them.'**
  String get leaveConflictsBody;

  /// No description provided for @earningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earningsTitle;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @earnPayable.
  ///
  /// In en, this message translates to:
  /// **'Payable to you'**
  String get earnPayable;

  /// No description provided for @earnServices.
  ///
  /// In en, this message translates to:
  /// **'{count} completed consultations'**
  String earnServices(int count);

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

  /// No description provided for @earnLines.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get earnLines;

  /// No description provided for @earnEmpty.
  ///
  /// In en, this message translates to:
  /// **'No paid consultations this month.'**
  String get earnEmpty;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @photoGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get photoGallery;

  /// No description provided for @photoCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoCamera;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get photoUpdated;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo must be under 5 MB.'**
  String get photoTooLarge;

  /// No description provided for @regNo.
  ///
  /// In en, this message translates to:
  /// **'Reg. {number}'**
  String regNo(String number);

  /// No description provided for @ratingLine.
  ///
  /// In en, this message translates to:
  /// **'★ {rating} ({count} reviews)'**
  String ratingLine(String rating, int count);

  /// No description provided for @acceptingBookings.
  ///
  /// In en, this message translates to:
  /// **'Accepting new bookings'**
  String get acceptingBookings;

  /// No description provided for @acceptingBookingsHint.
  ///
  /// In en, this message translates to:
  /// **'When off, you are hidden from doctor search.'**
  String get acceptingBookingsHint;

  /// No description provided for @bookingsOn.
  ///
  /// In en, this message translates to:
  /// **'You are accepting bookings'**
  String get bookingsOn;

  /// No description provided for @bookingsOff.
  ///
  /// In en, this message translates to:
  /// **'Bookings paused'**
  String get bookingsOff;

  /// No description provided for @feesTitle.
  ///
  /// In en, this message translates to:
  /// **'Consultation fees'**
  String get feesTitle;

  /// No description provided for @qualifications.
  ///
  /// In en, this message translates to:
  /// **'Qualifications'**
  String get qualifications;

  /// No description provided for @languagesSpoken.
  ///
  /// In en, this message translates to:
  /// **'Languages spoken'**
  String get languagesSpoken;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get bio;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will need your phone OTP and authenticator code to sign in again.'**
  String get logoutConfirmBody;

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

  /// No description provided for @otpIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Please check it and try again.'**
  String get otpIncorrect;

  /// No description provided for @otpIncorrectAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Incorrect code. 1 attempt left.} other{Incorrect code. {count} attempts left.}}'**
  String otpIncorrectAttempts(int count);

  /// No description provided for @otpNoAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. No attempts left, please request a new code.'**
  String get otpNoAttemptsLeft;

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Please request a new one.'**
  String get otpExpired;

  /// No description provided for @otpTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect attempts. Please request a new code.'**
  String get otpTooManyAttempts;

  /// No description provided for @vitalHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get vitalHigh;

  /// No description provided for @vitalLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get vitalLow;

  /// No description provided for @vitalFlagSemantics.
  ///
  /// In en, this message translates to:
  /// **'{vital} {value}, {flag}'**
  String vitalFlagSemantics(String vital, String value, String flag);

  /// No description provided for @logoutConfirmBodyOtp.
  ///
  /// In en, this message translates to:
  /// **'You will need your phone OTP to sign in again.'**
  String get logoutConfirmBodyOtp;

  /// No description provided for @leaveRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this leave?'**
  String get leaveRemoveTitle;

  /// No description provided for @leaveRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{date} will be open for bookings again.'**
  String leaveRemoveBody(String date);

  /// No description provided for @attachedRecord.
  ///
  /// In en, this message translates to:
  /// **'Attached record'**
  String get attachedRecord;

  /// No description provided for @attachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attached record unavailable'**
  String get attachmentUnavailable;

  /// No description provided for @attachmentNoFile.
  ///
  /// In en, this message translates to:
  /// **'This record has no file to open.'**
  String get attachmentNoFile;

  /// No description provided for @specGeneralPhysician.
  ///
  /// In en, this message translates to:
  /// **'General Physician'**
  String get specGeneralPhysician;

  /// No description provided for @specDermatologist.
  ///
  /// In en, this message translates to:
  /// **'Dermatologist'**
  String get specDermatologist;

  /// No description provided for @specPediatrician.
  ///
  /// In en, this message translates to:
  /// **'Pediatrician'**
  String get specPediatrician;

  /// No description provided for @specGynecologist.
  ///
  /// In en, this message translates to:
  /// **'Gynecologist'**
  String get specGynecologist;

  /// No description provided for @specCardiologist.
  ///
  /// In en, this message translates to:
  /// **'Cardiologist'**
  String get specCardiologist;

  /// No description provided for @specOrthopedist.
  ///
  /// In en, this message translates to:
  /// **'Orthopedist'**
  String get specOrthopedist;

  /// No description provided for @specPsychiatrist.
  ///
  /// In en, this message translates to:
  /// **'Psychiatrist'**
  String get specPsychiatrist;

  /// No description provided for @specEnt.
  ///
  /// In en, this message translates to:
  /// **'ENT Specialist'**
  String get specEnt;

  /// No description provided for @specDiabetologist.
  ///
  /// In en, this message translates to:
  /// **'Diabetologist'**
  String get specDiabetologist;

  /// No description provided for @specNeurologist.
  ///
  /// In en, this message translates to:
  /// **'Neurologist'**
  String get specNeurologist;
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
