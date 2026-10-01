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
/// import 'l10n/app_localizations.dart';
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

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CareCompanion'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your health, our priority.'**
  String get tagline;

  /// No description provided for @yourHealthOurPriority.
  ///
  /// In en, this message translates to:
  /// **'Your health, our priority.'**
  String get yourHealthOurPriority;

  /// No description provided for @homeQuote.
  ///
  /// In en, this message translates to:
  /// **'“Small steps today, healthier tomorrow.”'**
  String get homeQuote;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @robotSemantic.
  ///
  /// In en, this message translates to:
  /// **'AI health assistant robot'**
  String get robotSemantic;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get current;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get unavailable;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @fillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get fillRequired;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goHome;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String ageYears(int age);

  /// No description provided for @durationMins.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMins(int minutes);

  /// No description provided for @kmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String kmAway(String km);

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @noReasonGiven.
  ///
  /// In en, this message translates to:
  /// **'No reason given'**
  String get noReasonGiven;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded successfully'**
  String get uploaded;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get errorGeneric;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get offlineTitle;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get errorOffline;

  /// No description provided for @unauthorizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get unauthorizedTitle;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get errorSessionExpired;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @forbiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get forbiddenTitle;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this family member.'**
  String get errorForbidden;

  /// No description provided for @errorConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Your consent is needed for this feature.'**
  String get errorConsentRequired;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Our service is temporarily unavailable. Please try again shortly.'**
  String get errorServer;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We could not find what you were looking for.'**
  String get errorNotFound;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguageTitle;

  /// No description provided for @chooseLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Profile.'**
  String get chooseLanguageSubtitle;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get changeLanguage;

  /// No description provided for @phoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number'**
  String get phoneTitle;

  /// No description provided for @phoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code to verify it.'**
  String get phoneSubtitle;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get phoneInvalid;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @phoneDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to receive an SMS for verification.'**
  String get phoneDisclaimer;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your number'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {phone}'**
  String otpSubtitle(String phone);

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'One-time password'**
  String get otpLabel;

  /// No description provided for @otpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get otpInvalid;

  /// No description provided for @otpWrong.
  ///
  /// In en, this message translates to:
  /// **'That code is not correct or has expired'**
  String get otpWrong;

  /// No description provided for @otpResent.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent'**
  String get otpResent;

  /// No description provided for @devOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Dev OTP: {code}'**
  String devOtpHint(String code);

  /// No description provided for @useCode.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendOtp;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @consentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get consentsTitle;

  /// No description provided for @consentsIntro.
  ///
  /// In en, this message translates to:
  /// **'Please review and accept how we handle your health information. Required items are needed to use the app.'**
  String get consentsIntro;

  /// No description provided for @consentsRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Tick all required items to continue'**
  String get consentsRequiredHint;

  /// No description provided for @agreeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get agreeAndContinue;

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get profileSetupTitle;

  /// No description provided for @profileSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps doctors and care teams know who they are helping.'**
  String get profileSetupSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get nameRequired;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

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

  /// No description provided for @emergencyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get emergencyContactTitle;

  /// No description provided for @emergencyContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will alert this person if you use SOS or a fall is detected.'**
  String get emergencyContactSubtitle;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get contactName;

  /// No description provided for @relationLabel.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get relationLabel;

  /// No description provided for @relationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Son, Daughter, Spouse'**
  String get relationHint;

  /// No description provided for @relationSelf.
  ///
  /// In en, this message translates to:
  /// **'Self'**
  String get relationSelf;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCare.
  ///
  /// In en, this message translates to:
  /// **'Care'**
  String get navCare;

  /// No description provided for @navAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get navAskAi;

  /// No description provided for @navRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get navRecords;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Notifications, {count} unread'**
  String notificationsUnread(int count);

  /// No description provided for @switchFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Switch family member'**
  String get switchFamilyMember;

  /// No description provided for @actingFor.
  ///
  /// In en, this message translates to:
  /// **'Acting for {name}'**
  String actingFor(String name);

  /// No description provided for @actingForTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is this for?'**
  String get actingForTitle;

  /// No description provided for @actingForSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bookings, records and AI chats will be for the selected person.'**
  String get actingForSubtitle;

  /// No description provided for @manageFamily.
  ///
  /// In en, this message translates to:
  /// **'Manage family'**
  String get manageFamily;

  /// No description provided for @aiHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m your\nAI Health Assistant'**
  String get aiHeroTitle;

  /// No description provided for @aiHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your health, get instant guidance, or book a service.'**
  String get aiHeroSubtitle;

  /// No description provided for @howCanIHelp.
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get howCanIHelp;

  /// No description provided for @openAssistant.
  ///
  /// In en, this message translates to:
  /// **'Open AI assistant'**
  String get openAssistant;

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceInput;

  /// No description provided for @qaTalkToDoctor.
  ///
  /// In en, this message translates to:
  /// **'Talk to a Doctor'**
  String get qaTalkToDoctor;

  /// No description provided for @qaTalkToDoctorSub.
  ///
  /// In en, this message translates to:
  /// **'Online Consultation'**
  String get qaTalkToDoctorSub;

  /// No description provided for @qaHomeCheckup.
  ///
  /// In en, this message translates to:
  /// **'Home Checkup'**
  String get qaHomeCheckup;

  /// No description provided for @qaHomeCheckupSub.
  ///
  /// In en, this message translates to:
  /// **'Book at your home'**
  String get qaHomeCheckupSub;

  /// No description provided for @qaUploadReport.
  ///
  /// In en, this message translates to:
  /// **'Upload Report'**
  String get qaUploadReport;

  /// No description provided for @qaUploadReportSub.
  ///
  /// In en, this message translates to:
  /// **'Get AI insights'**
  String get qaUploadReportSub;

  /// No description provided for @qaOrderMedicines.
  ///
  /// In en, this message translates to:
  /// **'Order Medicines'**
  String get qaOrderMedicines;

  /// No description provided for @qaOrderMedicinesSub.
  ///
  /// In en, this message translates to:
  /// **'Fast & Safe Delivery'**
  String get qaOrderMedicinesSub;

  /// No description provided for @bannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Care for every stage of life'**
  String get bannerTitle;

  /// No description provided for @bannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From prevention to recovery — we\'re with you always.'**
  String get bannerSubtitle;

  /// No description provided for @bannerScript.
  ///
  /// In en, this message translates to:
  /// **'Healthier\nHappier\nYou ♡'**
  String get bannerScript;

  /// No description provided for @exploreCarePlans.
  ///
  /// In en, this message translates to:
  /// **'Explore Care Plans'**
  String get exploreCarePlans;

  /// No description provided for @quickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quickAccess;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Symptoms Checker'**
  String get qxSymptoms;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Mental Wellness'**
  String get qxMentalWellness;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Wound Analysis'**
  String get qxWound;

  /// No description provided for @qxMedicineReminders.
  ///
  /// In en, this message translates to:
  /// **'Medicine Reminders'**
  String get qxMedicineReminders;

  /// No description provided for @qxHealthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health Records'**
  String get qxHealthRecords;

  /// No description provided for @qxFallDetection.
  ///
  /// In en, this message translates to:
  /// **'Fall Detection'**
  String get qxFallDetection;

  /// No description provided for @qxGovtSchemes.
  ///
  /// In en, this message translates to:
  /// **'Govt. Health Schemes'**
  String get qxGovtSchemes;

  /// No description provided for @qxFindHospitals.
  ///
  /// In en, this message translates to:
  /// **'Find Hospitals'**
  String get qxFindHospitals;

  /// No description provided for @qxWearables.
  ///
  /// In en, this message translates to:
  /// **'Wearables Connect'**
  String get qxWearables;

  /// No description provided for @qxEmergencySos.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get qxEmergencySos;

  /// No description provided for @todaysReminders.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Reminders'**
  String get todaysReminders;

  /// No description provided for @activeCare.
  ///
  /// In en, this message translates to:
  /// **'Active Care'**
  String get activeCare;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next: {action}'**
  String nextStep(String action);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get priorityEmergency;

  /// No description provided for @todaysInsights.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Insights'**
  String get todaysInsights;

  /// No description provided for @goalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal}'**
  String goalLabel(String goal);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search symptoms, doctors, tests...'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you looking for?'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 letters to search doctors, hospitals and medicines.'**
  String get searchEmptyMessage;

  /// No description provided for @askAiAbout.
  ///
  /// In en, this message translates to:
  /// **'Ask AI about \"{query}\"'**
  String askAiAbout(String query);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Check symptoms safely with guided questions'**
  String get symptomsViaAi;

  /// No description provided for @doctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get doctors;

  /// No description provided for @hospitals.
  ///
  /// In en, this message translates to:
  /// **'Hospitals'**
  String get hospitals;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Health Assistant'**
  String get aiAssistantTitle;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newChat;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'AI-generated · not a diagnosis'**
  String get aiGeneratedLabel;

  /// No description provided for @typeOrSpeak.
  ///
  /// In en, this message translates to:
  /// **'Type or speak...'**
  String get typeOrSpeak;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get stopListening;

  /// No description provided for @assistantTyping.
  ///
  /// In en, this message translates to:
  /// **'Assistant is typing…'**
  String get assistantTyping;

  /// No description provided for @messageNotSent.
  ///
  /// In en, this message translates to:
  /// **'Message not sent'**
  String get messageNotSent;

  /// No description provided for @micPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is off. You can type your message instead.'**
  String get micPermissionDenied;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input is not available on this device. Please type instead.'**
  String get voiceUnavailable;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'I have a headache'**
  String get starterHeadache;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Check my symptoms'**
  String get starterSymptoms;

  /// No description provided for @starterHomeCheckup.
  ///
  /// In en, this message translates to:
  /// **'Should I get a home checkup?'**
  String get starterHomeCheckup;

  /// No description provided for @starterReport.
  ///
  /// In en, this message translates to:
  /// **'Explain my test report'**
  String get starterReport;

  /// No description provided for @questionProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionProgress(int current, int total);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'This may be an emergency'**
  String get emergencyAlertTitle;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Your symptoms may need urgent medical attention. Call 108 for an ambulance now or press SOS to alert your emergency contacts.'**
  String get emergencyTemplate;

  /// No description provided for @call108.
  ///
  /// In en, this message translates to:
  /// **'Call 108'**
  String get call108;

  /// No description provided for @sosButton.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sosButton;

  /// No description provided for @routeBookDoctor.
  ///
  /// In en, this message translates to:
  /// **'Book a doctor: {specialty}'**
  String routeBookDoctor(String specialty);

  /// No description provided for @routeBookHomeCheckup.
  ///
  /// In en, this message translates to:
  /// **'Book a home checkup'**
  String get routeBookHomeCheckup;

  /// No description provided for @findDoctors.
  ///
  /// In en, this message translates to:
  /// **'Find doctors'**
  String get findDoctors;

  /// No description provided for @aiConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow AI assistance?'**
  String get aiConsentTitle;

  /// No description provided for @aiConsentBody.
  ///
  /// In en, this message translates to:
  /// **'The AI assistant uses the health details you share to ask follow-up questions and guide you to the right care.'**
  String get aiConsentBody;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'It does not diagnose — a doctor makes clinical decisions.'**
  String get aiConsentPoint1;

  /// No description provided for @aiConsentPoint2.
  ///
  /// In en, this message translates to:
  /// **'Emergency warning signs are always checked by safety rules.'**
  String get aiConsentPoint2;

  /// No description provided for @aiConsentPoint3.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw this consent any time in Privacy settings.'**
  String get aiConsentPoint3;

  /// No description provided for @allowAiAssistance.
  ///
  /// In en, this message translates to:
  /// **'Allow AI assistance'**
  String get allowAiAssistance;

  /// No description provided for @talkToDoctorInstead.
  ///
  /// In en, this message translates to:
  /// **'Talk to a doctor instead'**
  String get talkToDoctorInstead;

  /// No description provided for @askAiNow.
  ///
  /// In en, this message translates to:
  /// **'Ask AI now'**
  String get askAiNow;

  /// No description provided for @findADoctor.
  ///
  /// In en, this message translates to:
  /// **'Find a Doctor'**
  String get findADoctor;

  /// No description provided for @searchDoctorsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, speciality...'**
  String get searchDoctorsHint;

  /// No description provided for @topDoctorsNearYou.
  ///
  /// In en, this message translates to:
  /// **'Top Doctors Near You'**
  String get topDoctorsNearYou;

  /// No description provided for @noDoctorsTitle.
  ///
  /// In en, this message translates to:
  /// **'No doctors found'**
  String get noDoctorsTitle;

  /// No description provided for @noDoctorsMessage.
  ///
  /// In en, this message translates to:
  /// **'Try another speciality or clear the filters.'**
  String get noDoctorsMessage;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @videoConsult.
  ///
  /// In en, this message translates to:
  /// **'Video Consult'**
  String get videoConsult;

  /// No description provided for @homeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home Visit'**
  String get homeVisit;

  /// No description provided for @yearsExperience.
  ///
  /// In en, this message translates to:
  /// **'{years}+ years'**
  String yearsExperience(int years);

  /// No description provided for @availableNow.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get availableNow;

  /// No description provided for @nextAvailable.
  ///
  /// In en, this message translates to:
  /// **'Next: {time}'**
  String nextAvailable(String time);

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFavorite;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'({count} reviews)'**
  String reviewsCount(int count);

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @registrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Registration no.'**
  String get registrationNumber;

  /// No description provided for @languagesSpoken.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languagesSpoken;

  /// No description provided for @clinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get clinic;

  /// No description provided for @whyThisDoctor.
  ///
  /// In en, this message translates to:
  /// **'Why this doctor'**
  String get whyThisDoctor;

  /// No description provided for @noReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviews;

  /// No description provided for @verifiedPatient.
  ///
  /// In en, this message translates to:
  /// **'Verified patient'**
  String get verifiedPatient;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @noSlots.
  ///
  /// In en, this message translates to:
  /// **'No slots on this day'**
  String get noSlots;

  /// No description provided for @noSlotsMessage.
  ///
  /// In en, this message translates to:
  /// **'Please pick another date.'**
  String get noSlotsMessage;

  /// No description provided for @consultationType.
  ///
  /// In en, this message translates to:
  /// **'Consultation Type'**
  String get consultationType;

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
  /// **'In-clinic'**
  String get modeInClinic;

  /// No description provided for @reasonForVisit.
  ///
  /// In en, this message translates to:
  /// **'Reason for visit'**
  String get reasonForVisit;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'e.g. Fever since 2 days'**
  String get reasonHint;

  /// No description provided for @defaultConsultReason.
  ///
  /// In en, this message translates to:
  /// **'General consultation'**
  String get defaultConsultReason;

  /// No description provided for @selectASlot.
  ///
  /// In en, this message translates to:
  /// **'Select a time slot'**
  String get selectASlot;

  /// No description provided for @confirmAppointmentFee.
  ///
  /// In en, this message translates to:
  /// **'Confirm Appointment · {amount}'**
  String confirmAppointmentFee(String amount);

  /// No description provided for @rescheduleToSlot.
  ///
  /// In en, this message translates to:
  /// **'Reschedule to this slot'**
  String get rescheduleToSlot;

  /// No description provided for @rescheduled.
  ///
  /// In en, this message translates to:
  /// **'Appointment rescheduled'**
  String get rescheduled;

  /// No description provided for @slotUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That slot was just taken. Please choose another time.'**
  String get slotUnavailable;

  /// No description provided for @noBookPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have booking permission for this family member.'**
  String get noBookPermission;

  /// No description provided for @consultationWith.
  ///
  /// In en, this message translates to:
  /// **'Consultation with {name}'**
  String consultationWith(String name);

  /// No description provided for @appointmentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Appointment confirmed'**
  String get appointmentConfirmed;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get amountPaid;

  /// No description provided for @viewAppointment.
  ///
  /// In en, this message translates to:
  /// **'View appointment'**
  String get viewAppointment;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed'**
  String get bookingConfirmed;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get totalAmount;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @retryPaymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Retry payment · {amount}'**
  String retryPaymentAmount(String amount);

  /// No description provided for @simulateFailure.
  ///
  /// In en, this message translates to:
  /// **'Simulate failure'**
  String get simulateFailure;

  /// No description provided for @payLater.
  ///
  /// In en, this message translates to:
  /// **'Pay later'**
  String get payLater;

  /// No description provided for @mockGatewayNote.
  ///
  /// In en, this message translates to:
  /// **'Test payment gateway — no real money is charged.'**
  String get mockGatewayNote;

  /// No description provided for @paymentFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Your booking is not confirmed yet — please try again.'**
  String get paymentFailedBody;

  /// No description provided for @paymentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailedTitle;

  /// No description provided for @paymentPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get paymentPendingTitle;

  /// No description provided for @paymentNotConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'Your booking will be confirmed only after payment succeeds.'**
  String get paymentNotConfirmedBody;

  /// No description provided for @completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete payment · {amount}'**
  String completePayment(String amount);

  /// No description provided for @noPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'No pending payment found'**
  String get noPendingPayment;

  /// No description provided for @payIfPending.
  ///
  /// In en, this message translates to:
  /// **'Complete pending payment'**
  String get payIfPending;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @noPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get noPayments;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded {amount}'**
  String refunded(String amount);

  /// No description provided for @payPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get payPending;

  /// No description provided for @paySucceeded.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paySucceeded;

  /// No description provided for @payFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get payFailed;

  /// No description provided for @payRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get payRefunded;

  /// No description provided for @payPartiallyRefunded.
  ///
  /// In en, this message translates to:
  /// **'Partly refunded'**
  String get payPartiallyRefunded;

  /// No description provided for @purposeAppointment.
  ///
  /// In en, this message translates to:
  /// **'Doctor consultation'**
  String get purposeAppointment;

  /// No description provided for @purposeHomeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get purposeHomeVisit;

  /// No description provided for @purposePharmacyOrder.
  ///
  /// In en, this message translates to:
  /// **'Medicine order'**
  String get purposePharmacyOrder;

  /// No description provided for @careEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get careEpisodes;

  /// No description provided for @careEpisode.
  ///
  /// In en, this message translates to:
  /// **'Care episode'**
  String get careEpisode;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @appointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get appointment;

  /// No description provided for @homeVisits.
  ///
  /// In en, this message translates to:
  /// **'Home visits'**
  String get homeVisits;

  /// No description provided for @carePlans.
  ///
  /// In en, this message translates to:
  /// **'Care plans'**
  String get carePlans;

  /// No description provided for @carePlan.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get carePlan;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// No description provided for @noEpisodesTitle.
  ///
  /// In en, this message translates to:
  /// **'No care episodes yet'**
  String get noEpisodesTitle;

  /// No description provided for @noEpisodesMessage.
  ///
  /// In en, this message translates to:
  /// **'Start by asking the AI assistant or booking a doctor.'**
  String get noEpisodesMessage;

  /// No description provided for @noUpcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments'**
  String get noUpcomingAppointments;

  /// No description provided for @noPastAppointments.
  ///
  /// In en, this message translates to:
  /// **'No past appointments'**
  String get noPastAppointments;

  /// No description provided for @bookDoctor.
  ///
  /// In en, this message translates to:
  /// **'Book a doctor'**
  String get bookDoctor;

  /// No description provided for @noHomeVisits.
  ///
  /// In en, this message translates to:
  /// **'No home visits'**
  String get noHomeVisits;

  /// No description provided for @bookHomeCheckup.
  ///
  /// In en, this message translates to:
  /// **'Book a Home Checkup'**
  String get bookHomeCheckup;

  /// No description provided for @noCarePlansTitle.
  ///
  /// In en, this message translates to:
  /// **'No care plan yet'**
  String get noCarePlansTitle;

  /// No description provided for @noCarePlansMessage.
  ///
  /// In en, this message translates to:
  /// **'Your doctor will share a care plan after a consultation.'**
  String get noCarePlansMessage;

  /// No description provided for @openTasks.
  ///
  /// In en, this message translates to:
  /// **'Open tasks'**
  String get openTasks;

  /// No description provided for @noOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'No open tasks — well done!'**
  String get noOpenTasks;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get markDone;

  /// No description provided for @taskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get taskCompleted;

  /// No description provided for @taskOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskOpen;

  /// No description provided for @taskDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskDone;

  /// No description provided for @taskOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get taskOverdue;

  /// No description provided for @taskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskCancelled;

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOn(String date);

  /// No description provided for @doneBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String doneBy(String name);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Today\'s doses'**
  String get todaysDoses;

  /// No description provided for @markTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get markTaken;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get doseTaken;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get doseSkipped;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get doseMissed;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get dosePending;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Prescribed by {name}'**
  String prescribedBy(String name);

  /// No description provided for @noMedications.
  ///
  /// In en, this message translates to:
  /// **'No medicines added'**
  String get noMedications;

  /// No description provided for @noMedicationsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your medicines to get reminders.'**
  String get noMedicationsMessage;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Add medication'**
  String get addMedication;

  /// No description provided for @medicineReminders.
  ///
  /// In en, this message translates to:
  /// **'Medicine reminders'**
  String get medicineReminders;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get medicineName;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get dose;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'e.g. 500 mg, 1 tablet'**
  String get doseHint;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'e.g. Twice a day after food'**
  String get frequencyHint;

  /// No description provided for @reminderTimes.
  ///
  /// In en, this message translates to:
  /// **'Reminder times'**
  String get reminderTimes;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @addAtLeastOneTime.
  ///
  /// In en, this message translates to:
  /// **'Add at least one reminder time'**
  String get addAtLeastOneTime;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'{count} times a day'**
  String timesPerDay(int count);

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDateOptional.
  ///
  /// In en, this message translates to:
  /// **'End date (optional)'**
  String get endDateOptional;

  /// No description provided for @instructionsOptional.
  ///
  /// In en, this message translates to:
  /// **'Instructions (optional)'**
  String get instructionsOptional;

  /// No description provided for @instructionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. After breakfast'**
  String get instructionsHint;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Medicines you add are marked as patient-entered. Always follow your doctor\'s advice.'**
  String get medicationSelfEnteredNote;

  /// No description provided for @medicationAdded.
  ///
  /// In en, this message translates to:
  /// **'Medication added'**
  String get medicationAdded;

  /// No description provided for @careOwner.
  ///
  /// In en, this message translates to:
  /// **'Care owner: {name}'**
  String careOwner(String name);

  /// No description provided for @episodeExceptional.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}. Our care team is handling this with priority.'**
  String episodeExceptional(String status);

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No updates yet'**
  String get noEvents;

  /// No description provided for @viewCareEpisode.
  ///
  /// In en, this message translates to:
  /// **'View care episode'**
  String get viewCareEpisode;

  /// No description provided for @byDoctor.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String byDoctor(String name);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Follow-up by {date}'**
  String followUpDue(String date);

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @epNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get epNew;

  /// No description provided for @epIntake.
  ///
  /// In en, this message translates to:
  /// **'Understanding your concern'**
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

  /// Medical term (translations need clinical glossary review)
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

  /// Medical term (translations need clinical glossary review)
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

  /// No description provided for @apPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get apPendingPayment;

  /// No description provided for @apConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get apConfirmed;

  /// No description provided for @apInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get apInProgress;

  /// No description provided for @apCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get apCompleted;

  /// No description provided for @apCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get apCancelled;

  /// No description provided for @apNoShow.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get apNoShow;

  /// No description provided for @dateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get dateTime;

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s notes'**
  String get doctorNotes;

  /// No description provided for @joinVideo.
  ///
  /// In en, this message translates to:
  /// **'Join video consultation'**
  String get joinVideo;

  /// No description provided for @videoLinkLater.
  ///
  /// In en, this message translates to:
  /// **'The video link will appear here shortly before your consultation.'**
  String get videoLinkLater;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @cancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get cancelAppointment;

  /// No description provided for @appointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled'**
  String get appointmentCancelled;

  /// No description provided for @homeCheckupTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Healthcare at Home'**
  String get homeCheckupTitle;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Book a certified nurse or technician for sample collection, vitals check, and more.'**
  String get homeCheckupSubtitle;

  /// No description provided for @myVisits.
  ///
  /// In en, this message translates to:
  /// **'My visits'**
  String get myVisits;

  /// No description provided for @noServices.
  ///
  /// In en, this message translates to:
  /// **'No services available'**
  String get noServices;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Select a service'**
  String get selectService;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressLine1.
  ///
  /// In en, this message translates to:
  /// **'House / flat, street'**
  String get addressLine1;

  /// No description provided for @addressLine2.
  ///
  /// In en, this message translates to:
  /// **'Area (optional)'**
  String get addressLine2;

  /// No description provided for @landmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get landmark;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @pincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get pincode;

  /// No description provided for @pincodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit pincode'**
  String get pincodeInvalid;

  /// No description provided for @notServiceable.
  ///
  /// In en, this message translates to:
  /// **'Sorry, home visits are not available at this pincode yet.'**
  String get notServiceable;

  /// No description provided for @serviceable.
  ///
  /// In en, this message translates to:
  /// **'Great — we serve {zone}'**
  String serviceable(String zone);

  /// No description provided for @preferredTime.
  ///
  /// In en, this message translates to:
  /// **'Preferred time'**
  String get preferredTime;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'e.g. Blood sugar check for my father'**
  String get homeVisitReasonHint;

  /// No description provided for @bookAndPay.
  ///
  /// In en, this message translates to:
  /// **'Book & Pay {amount}'**
  String bookAndPay(String amount);

  /// No description provided for @homeVisitBooked.
  ///
  /// In en, this message translates to:
  /// **'Home visit booked'**
  String get homeVisitBooked;

  /// No description provided for @visitCode.
  ///
  /// In en, this message translates to:
  /// **'Visit code'**
  String get visitCode;

  /// No description provided for @visitCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Share this code only with your care provider when they arrive.'**
  String get visitCodeHint;

  /// No description provided for @visitCodeInline.
  ///
  /// In en, this message translates to:
  /// **'Visit code: {code}'**
  String visitCodeInline(String code);

  /// No description provided for @visitCodeSemantic.
  ///
  /// In en, this message translates to:
  /// **'Visit code {code}'**
  String visitCodeSemantic(String code);

  /// No description provided for @trackVisit.
  ///
  /// In en, this message translates to:
  /// **'Track visit'**
  String get trackVisit;

  /// No description provided for @viewRequest.
  ///
  /// In en, this message translates to:
  /// **'View request'**
  String get viewRequest;

  /// No description provided for @homeVisitTracking.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get homeVisitTracking;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'Arriving in about {minutes} min'**
  String etaMinutes(int minutes);

  /// No description provided for @visitUnassigned.
  ///
  /// In en, this message translates to:
  /// **'We are finding an available care provider near you. We will notify you soon.'**
  String get visitUnassigned;

  /// No description provided for @yourCareProvider.
  ///
  /// In en, this message translates to:
  /// **'Your care provider'**
  String get yourCareProvider;

  /// No description provided for @visitStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit status'**
  String get visitStatusTitle;

  /// No description provided for @visitSummary.
  ///
  /// In en, this message translates to:
  /// **'Visit summary'**
  String get visitSummary;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Vitals recorded'**
  String get vitalsRecorded;

  /// No description provided for @cancelVisit.
  ///
  /// In en, this message translates to:
  /// **'Cancel visit'**
  String get cancelVisit;

  /// No description provided for @visitCancelled.
  ///
  /// In en, this message translates to:
  /// **'Visit cancelled'**
  String get visitCancelled;

  /// No description provided for @hvRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get hvRequested;

  /// No description provided for @hvUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Finding provider'**
  String get hvUnassigned;

  /// No description provided for @hvAssigned.
  ///
  /// In en, this message translates to:
  /// **'Provider assigned'**
  String get hvAssigned;

  /// No description provided for @hvAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get hvAccepted;

  /// No description provided for @hvEnRoute.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get hvEnRoute;

  /// No description provided for @hvArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get hvArrived;

  /// No description provided for @hvInProgress.
  ///
  /// In en, this message translates to:
  /// **'Visit in progress'**
  String get hvInProgress;

  /// No description provided for @hvCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get hvCompleted;

  /// No description provided for @hvCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get hvCancelled;

  /// No description provided for @hvEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated to doctor'**
  String get hvEscalated;

  /// No description provided for @searchMedicines.
  ///
  /// In en, this message translates to:
  /// **'Search medicines...'**
  String get searchMedicines;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Upload Prescription'**
  String get uploadPrescription;

  /// No description provided for @uploadPrescriptionSub.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo or PDF'**
  String get uploadPrescriptionSub;

  /// No description provided for @popularCategories.
  ///
  /// In en, this message translates to:
  /// **'Popular Categories'**
  String get popularCategories;

  /// No description provided for @frequentlyOrdered.
  ///
  /// In en, this message translates to:
  /// **'Frequently Ordered'**
  String get frequentlyOrdered;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Rx'**
  String get rxRequired;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add {name} to cart'**
  String addToCart(String name);

  /// No description provided for @decreaseQty.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQty;

  /// No description provided for @increaseQty.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQty;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get viewCart;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @browseMedicines.
  ///
  /// In en, this message translates to:
  /// **'Browse medicines'**
  String get browseMedicines;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get prescription;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Some items need a valid prescription. Select one or upload a new one.'**
  String get rxRequiredBody;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'A prescription is required for one or more items.'**
  String get rxMissing;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress;

  /// No description provided for @placeOrderAndPay.
  ///
  /// In en, this message translates to:
  /// **'Place order · {amount}'**
  String placeOrderAndPay(String amount);

  /// No description provided for @medicineOrder.
  ///
  /// In en, this message translates to:
  /// **'Medicine order'**
  String get medicineOrder;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get orderPlaced;

  /// No description provided for @fulfilledBy.
  ///
  /// In en, this message translates to:
  /// **'Fulfilled by {name}'**
  String fulfilledBy(String name);

  /// No description provided for @healthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health Records'**
  String get healthRecords;

  /// No description provided for @healthTimeline.
  ///
  /// In en, this message translates to:
  /// **'Health timeline'**
  String get healthTimeline;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitals;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get prescriptions;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @noRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get noRecordsTitle;

  /// No description provided for @noRecordsMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload reports and prescriptions to keep everything in one place.'**
  String get noRecordsMessage;

  /// No description provided for @noRecordsPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view records for this family member.'**
  String get noRecordsPermission;

  /// No description provided for @uploadNewReport.
  ///
  /// In en, this message translates to:
  /// **'Upload New Report'**
  String get uploadNewReport;

  /// No description provided for @uploadNewReportSub.
  ///
  /// In en, this message translates to:
  /// **'Add reports, prescriptions, images'**
  String get uploadNewReportSub;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @recordType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get recordType;

  /// No description provided for @recordDate.
  ///
  /// In en, this message translates to:
  /// **'Report date'**
  String get recordDate;

  /// No description provided for @addedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by'**
  String get addedBy;

  /// No description provided for @uploadedOn.
  ///
  /// In en, this message translates to:
  /// **'Uploaded on'**
  String get uploadedOn;

  /// No description provided for @openOriginal.
  ///
  /// In en, this message translates to:
  /// **'Open original file'**
  String get openOriginal;

  /// No description provided for @aiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get aiSummary;

  /// No description provided for @summarizeWithAi.
  ///
  /// In en, this message translates to:
  /// **'Summarize with AI'**
  String get summarizeWithAi;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'This summary is AI-generated to help you understand your report. It is not a diagnosis — please discuss results with your doctor.'**
  String get aiDisclaimerDefault;

  /// No description provided for @generatedOn.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String generatedOn(String date);

  /// No description provided for @originalImmutableNote.
  ///
  /// In en, this message translates to:
  /// **'Your original file is never changed. AI summaries are stored separately.'**
  String get originalImmutableNote;

  /// No description provided for @previewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview is not available for this file type.'**
  String get previewUnavailable;

  /// No description provided for @previewUnavailableMobile.
  ///
  /// In en, this message translates to:
  /// **'File downloaded ({size}). In-app preview supports images only for now.'**
  String previewUnavailableMobile(String size);

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String sourceLabel(String source);

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @allowedFiles.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG, PNG, WEBP or HEIC up to 15 MB'**
  String get allowedFiles;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is larger than 15 MB'**
  String get fileTooLarge;

  /// No description provided for @pickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file. Please try again.'**
  String get pickerFailed;

  /// No description provided for @uploadPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Files are stored securely and shared only with people you allow.'**
  String get uploadPrivacyNote;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Lab report'**
  String get rtLabReport;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get rtPrescription;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Scan / X-ray'**
  String get rtImaging;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Discharge summary'**
  String get rtDischargeSummary;

  /// No description provided for @rtVisitSummary.
  ///
  /// In en, this message translates to:
  /// **'Visit summary'**
  String get rtVisitSummary;

  /// No description provided for @rtOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get rtOther;

  /// No description provided for @provPatientEntered.
  ///
  /// In en, this message translates to:
  /// **'Patient entered'**
  String get provPatientEntered;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Clinician verified'**
  String get provClinicianVerified;

  /// No description provided for @provHomeVisit.
  ///
  /// In en, this message translates to:
  /// **'Home visit'**
  String get provHomeVisit;

  /// No description provided for @provImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get provImported;

  /// No description provided for @provAiExtracted.
  ///
  /// In en, this message translates to:
  /// **'AI extracted'**
  String get provAiExtracted;

  /// No description provided for @provDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get provDevice;

  /// No description provided for @provUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get provUnknown;

  /// No description provided for @timelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your health timeline will appear here'**
  String get timelineEmpty;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No vitals recorded'**
  String get noVitals;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Add readings like BP, pulse or sugar to track trends.'**
  String get noVitalsMessage;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Add vital'**
  String get addVital;

  /// No description provided for @vitalTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get vitalTypeLabel;

  /// No description provided for @vitalSelfEnteredNote.
  ///
  /// In en, this message translates to:
  /// **'Readings you add are marked as patient-entered.'**
  String get vitalSelfEnteredNote;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'BP (systolic)'**
  String get vitalBpSystolic;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'BP (diastolic)'**
  String get vitalBpDiastolic;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get vitalPulse;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'SpO₂ (oxygen)'**
  String get vitalSpo2;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get vitalTemperature;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood sugar'**
  String get vitalBloodGlucose;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get vitalWeight;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Breathing rate'**
  String get vitalRespiratoryRate;

  /// No description provided for @wellnessHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'A healthier mind for a brighter you'**
  String get wellnessHeroTitle;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Talk to a therapist or try our AI-guided support.'**
  String get wellnessHeroSubtitle;

  /// No description provided for @howAreYouFeeling.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get howAreYouFeeling;

  /// No description provided for @moodVeryLow.
  ///
  /// In en, this message translates to:
  /// **'Very low'**
  String get moodVeryLow;

  /// No description provided for @moodLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get moodLow;

  /// No description provided for @moodOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get moodOkay;

  /// No description provided for @moodGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get moodGood;

  /// No description provided for @moodGreat.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get moodGreat;

  /// No description provided for @moodNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Want to add a note? (optional)'**
  String get moodNoteOptional;

  /// No description provided for @shareWithClinician.
  ///
  /// In en, this message translates to:
  /// **'Share with my clinician'**
  String get shareWithClinician;

  /// No description provided for @saveCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Save check-in'**
  String get saveCheckIn;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Talk to a Therapist'**
  String get talkToTherapist;

  /// No description provided for @talkToTherapistSub.
  ///
  /// In en, this message translates to:
  /// **'Book an online session'**
  String get talkToTherapistSub;

  /// No description provided for @aiMoodSupport.
  ///
  /// In en, this message translates to:
  /// **'AI Mood Support'**
  String get aiMoodSupport;

  /// No description provided for @aiMoodSupportSub.
  ///
  /// In en, this message translates to:
  /// **'Chat anonymously'**
  String get aiMoodSupportSub;

  /// No description provided for @meditationExercises.
  ///
  /// In en, this message translates to:
  /// **'Meditation & Exercises'**
  String get meditationExercises;

  /// No description provided for @noActivities.
  ///
  /// In en, this message translates to:
  /// **'No activities available'**
  String get noActivities;

  /// No description provided for @moodTracker.
  ///
  /// In en, this message translates to:
  /// **'Mood Tracker'**
  String get moodTracker;

  /// No description provided for @noMoodHistory.
  ///
  /// In en, this message translates to:
  /// **'Your mood check-ins will appear here'**
  String get noMoodHistory;

  /// No description provided for @youAreNotAlone.
  ///
  /// In en, this message translates to:
  /// **'You are not alone'**
  String get youAreNotAlone;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'If you feel unsafe or might hurt yourself, please call 108 now or reach someone you trust.'**
  String get moodSupportFallback;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No AI diagnosis. We only check that the photo is clear; a clinician will review it.'**
  String get woundNoDiagnosis;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of the wound'**
  String get uploadWoundPhoto;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Good light, in focus, whole wound visible'**
  String get woundPhotoTips;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Where is the wound?'**
  String get bodySite;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'e.g. Left ankle'**
  String get bodySiteHint;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @sendForReview.
  ///
  /// In en, this message translates to:
  /// **'Send for clinician review'**
  String get sendForReview;

  /// No description provided for @retakeAndSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit new photo'**
  String get retakeAndSubmit;

  /// No description provided for @woundRetakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Please retake the photo'**
  String get woundRetakeTitle;

  /// No description provided for @woundRetakeBody.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be used because:'**
  String get woundRetakeBody;

  /// No description provided for @woundPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent for clinician review'**
  String get woundPendingTitle;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'A clinician will review your photo and contact you. If the wound worsens, bleeds heavily or you have fever, seek care immediately.'**
  String get woundPendingBody;

  /// No description provided for @woundIssueTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The image resolution is too low'**
  String get woundIssueTooSmall;

  /// No description provided for @woundIssueFileTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The file is too small or incomplete'**
  String get woundIssueFileTooSmall;

  /// No description provided for @woundIssueTooDark.
  ///
  /// In en, this message translates to:
  /// **'The photo is too dark'**
  String get woundIssueTooDark;

  /// No description provided for @woundIssueBlurry.
  ///
  /// In en, this message translates to:
  /// **'The photo is blurry'**
  String get woundIssueBlurry;

  /// No description provided for @woundStatusRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake needed'**
  String get woundStatusRetake;

  /// No description provided for @woundStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get woundStatusPending;

  /// No description provided for @woundStatusReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get woundStatusReviewed;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No wound photos yet'**
  String get noWoundHistory;

  /// No description provided for @clinicianReviewBy.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by {name}'**
  String clinicianReviewBy(String name);

  /// No description provided for @connectWearable.
  ///
  /// In en, this message translates to:
  /// **'Connect Wearable'**
  String get connectWearable;

  /// No description provided for @trackHealthRealtime.
  ///
  /// In en, this message translates to:
  /// **'Track your health in real time'**
  String get trackHealthRealtime;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get heartRate;

  /// No description provided for @stepsActivity.
  ///
  /// In en, this message translates to:
  /// **'Steps & activity'**
  String get stepsActivity;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @linkedDevices.
  ///
  /// In en, this message translates to:
  /// **'Linked Devices'**
  String get linkedDevices;

  /// No description provided for @linkedDevicesSub.
  ///
  /// In en, this message translates to:
  /// **'Wearables & apps'**
  String get linkedDevicesSub;

  /// No description provided for @selectDevice.
  ///
  /// In en, this message translates to:
  /// **'Select a device'**
  String get selectDevice;

  /// No description provided for @connectDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Connect {name}'**
  String connectDeviceName(String name);

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Device connected'**
  String get deviceConnected;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @disconnectDevice.
  ///
  /// In en, this message translates to:
  /// **'Disconnect device?'**
  String get disconnectDevice;

  /// No description provided for @disconnectDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'New readings will stop syncing. Existing readings stay in your records.'**
  String get disconnectDeviceBody;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {date}'**
  String lastSynced(String date);

  /// No description provided for @connectedNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Connected · not synced yet'**
  String get connectedNotSynced;

  /// No description provided for @noWearableProviders.
  ///
  /// In en, this message translates to:
  /// **'No devices available'**
  String get noWearableProviders;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Device readings are labelled with their source and are not a medical diagnosis.'**
  String get wearableDataNote;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @sosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get help quickly. We\'ll notify your emergency contacts.'**
  String get sosSubtitle;

  /// No description provided for @sosSentTitle.
  ///
  /// In en, this message translates to:
  /// **'SOS sent. Help is being arranged.'**
  String get sosSentTitle;

  /// No description provided for @holdToSend.
  ///
  /// In en, this message translates to:
  /// **'Press and hold for 3 seconds'**
  String get holdToSend;

  /// No description provided for @sosSemantic.
  ///
  /// In en, this message translates to:
  /// **'SOS emergency button. Double tap to confirm sending an alert.'**
  String get sosSemantic;

  /// No description provided for @sendSosTitle.
  ///
  /// In en, this message translates to:
  /// **'Send SOS alert?'**
  String get sendSosTitle;

  /// No description provided for @sendSosBody.
  ///
  /// In en, this message translates to:
  /// **'Your emergency contacts and our care team will be alerted with your location.'**
  String get sendSosBody;

  /// No description provided for @sendSos.
  ///
  /// In en, this message translates to:
  /// **'Send SOS'**
  String get sendSos;

  /// No description provided for @sosFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send SOS. Call 108 directly.'**
  String get sosFailed;

  /// No description provided for @sendLocation.
  ///
  /// In en, this message translates to:
  /// **'Send Location'**
  String get sendLocation;

  /// No description provided for @toEmergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'To emergency contacts'**
  String get toEmergencyContacts;

  /// No description provided for @callAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Call Ambulance'**
  String get callAmbulance;

  /// No description provided for @helpline108.
  ///
  /// In en, this message translates to:
  /// **'Helpline: 108'**
  String get helpline108;

  /// No description provided for @callNumber.
  ///
  /// In en, this message translates to:
  /// **'Call {number}'**
  String callNumber(String number);

  /// No description provided for @notifiedContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts notified'**
  String get notifiedContacts;

  /// No description provided for @noEmergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'No emergency contacts yet'**
  String get noEmergencyContacts;

  /// No description provided for @addEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Add emergency contact'**
  String get addEmergencyContact;

  /// No description provided for @nearestEmergencyFacilities.
  ///
  /// In en, this message translates to:
  /// **'Nearest emergency facilities'**
  String get nearestEmergencyFacilities;

  /// No description provided for @emergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get emergencyContacts;

  /// No description provided for @emergencyContactsFor.
  ///
  /// In en, this message translates to:
  /// **'People we alert for {name}'**
  String emergencyContactsFor(String name);

  /// No description provided for @fallTitle.
  ///
  /// In en, this message translates to:
  /// **'Fall detection'**
  String get fallTitle;

  /// No description provided for @fallBody.
  ///
  /// In en, this message translates to:
  /// **'If a fall is detected by your phone or wearable, we ask if you are OK. If you don\'t respond, we alert your emergency contacts and care team.'**
  String get fallBody;

  /// No description provided for @fallStep1.
  ///
  /// In en, this message translates to:
  /// **'A possible fall is detected'**
  String get fallStep1;

  /// No description provided for @fallStep2.
  ///
  /// In en, this message translates to:
  /// **'You get a countdown to respond'**
  String get fallStep2;

  /// No description provided for @fallStep3.
  ///
  /// In en, this message translates to:
  /// **'No response? We alert your contacts'**
  String get fallStep3;

  /// No description provided for @fallContactsHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure your contacts are up to date'**
  String get fallContactsHint;

  /// No description provided for @fallWearableHint.
  ///
  /// In en, this message translates to:
  /// **'Connect a watch for better detection'**
  String get fallWearableHint;

  /// No description provided for @simulateFall.
  ///
  /// In en, this message translates to:
  /// **'Simulate fall (test)'**
  String get simulateFall;

  /// No description provided for @simulateFallNote.
  ///
  /// In en, this message translates to:
  /// **'For testing only. This creates a real fall alert for your care team.'**
  String get simulateFallNote;

  /// No description provided for @areYouOk.
  ///
  /// In en, this message translates to:
  /// **'Are you OK?'**
  String get areYouOk;

  /// No description provided for @fallDetectedBody.
  ///
  /// In en, this message translates to:
  /// **'We detected a possible fall. If you don\'t respond, we will alert your emergency contacts.'**
  String get fallDetectedBody;

  /// No description provided for @secondsLeft.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds left'**
  String secondsLeft(int seconds);

  /// No description provided for @imOk.
  ///
  /// In en, this message translates to:
  /// **'I\'m OK'**
  String get imOk;

  /// No description provided for @needHelp.
  ///
  /// In en, this message translates to:
  /// **'I need help'**
  String get needHelp;

  /// No description provided for @fallGladSafe.
  ///
  /// In en, this message translates to:
  /// **'Glad you\'re safe'**
  String get fallGladSafe;

  /// No description provided for @fallHelpComing.
  ///
  /// In en, this message translates to:
  /// **'We are alerting your contacts'**
  String get fallHelpComing;

  /// No description provided for @fallNoResponse.
  ///
  /// In en, this message translates to:
  /// **'No response — alerting your contacts'**
  String get fallNoResponse;

  /// No description provided for @openSos.
  ///
  /// In en, this message translates to:
  /// **'Open SOS'**
  String get openSos;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location is unavailable. Showing all results.'**
  String get locationUnavailable;

  /// No description provided for @noFacilities.
  ///
  /// In en, this message translates to:
  /// **'No facilities found'**
  String get noFacilities;

  /// No description provided for @emergency247.
  ///
  /// In en, this message translates to:
  /// **'24x7 Emergency'**
  String get emergency247;

  /// No description provided for @facHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get facHospital;

  /// No description provided for @facClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get facClinic;

  /// No description provided for @facLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get facLab;

  /// No description provided for @facPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get facPharmacy;

  /// No description provided for @govtSchemesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Government health scheme guidance is coming soon.'**
  String get govtSchemesComingSoon;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @personalInfoNote.
  ///
  /// In en, this message translates to:
  /// **'Your phone number is your login and cannot be changed here.'**
  String get personalInfoNote;

  /// No description provided for @healthProfile.
  ///
  /// In en, this message translates to:
  /// **'Health Profile'**
  String get healthProfile;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood group, allergies, conditions'**
  String get healthProfileSub;

  /// No description provided for @healthProfileFor.
  ///
  /// In en, this message translates to:
  /// **'Health details for {name}'**
  String healthProfileFor(String name);

  /// No description provided for @healthSettingsFor.
  ///
  /// In en, this message translates to:
  /// **'Health settings below apply to {name}'**
  String healthSettingsFor(String name);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood group'**
  String get bloodGroup;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood group (optional)'**
  String get bloodGroupOptional;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergies;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Add allergy'**
  String get addAllergy;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No known allergies recorded'**
  String get noAllergies;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Allergic to'**
  String get substance;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Reaction (optional)'**
  String get reactionOptional;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get mild;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get severe;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get addCondition;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No conditions recorded'**
  String get noConditions;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get conditionName;

  /// No description provided for @sinceYearOptional.
  ///
  /// In en, this message translates to:
  /// **'Since (year, optional)'**
  String get sinceYearOptional;

  /// No description provided for @since.
  ///
  /// In en, this message translates to:
  /// **'since {year}'**
  String since(String year);

  /// No description provided for @familyMembers.
  ///
  /// In en, this message translates to:
  /// **'Family Members'**
  String get familyMembers;

  /// No description provided for @familyMembersSub.
  ///
  /// In en, this message translates to:
  /// **'Add and manage family'**
  String get familyMembersSub;

  /// No description provided for @familyIntro.
  ///
  /// In en, this message translates to:
  /// **'Manage care for your family. Choose who can see records, book care and receive alerts.'**
  String get familyIntro;

  /// No description provided for @peopleYouCareFor.
  ///
  /// In en, this message translates to:
  /// **'People you care for'**
  String get peopleYouCareFor;

  /// No description provided for @addDependent.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addDependent;

  /// No description provided for @addDependentSub.
  ///
  /// In en, this message translates to:
  /// **'Add a family member whose care you manage (e.g. a parent or child).'**
  String get addDependentSub;

  /// No description provided for @actingNow.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get actingNow;

  /// No description provided for @caregiversFor.
  ///
  /// In en, this message translates to:
  /// **'Caregivers for {name}'**
  String caregiversFor(String name);

  /// No description provided for @noCaregivers.
  ///
  /// In en, this message translates to:
  /// **'No one else has access yet.'**
  String get noCaregivers;

  /// No description provided for @revokeAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke access?'**
  String get revokeAccess;

  /// No description provided for @revokeAccessBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will immediately lose access.'**
  String revokeAccessBody(String name);

  /// No description provided for @inviteCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Invite a caregiver'**
  String get inviteCaregiver;

  /// No description provided for @inviteCaregiverSub.
  ///
  /// In en, this message translates to:
  /// **'They will be able to help with care for {name}.'**
  String inviteCaregiverSub(String name);

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @permViewRecords.
  ///
  /// In en, this message translates to:
  /// **'View records'**
  String get permViewRecords;

  /// No description provided for @permManageCare.
  ///
  /// In en, this message translates to:
  /// **'Manage care'**
  String get permManageCare;

  /// No description provided for @permBook.
  ///
  /// In en, this message translates to:
  /// **'Book & pay'**
  String get permBook;

  /// No description provided for @permReceiveAlerts.
  ///
  /// In en, this message translates to:
  /// **'Receive alerts'**
  String get permReceiveAlerts;

  /// No description provided for @permViewRecordsDesc.
  ///
  /// In en, this message translates to:
  /// **'See reports, prescriptions and vitals'**
  String get permViewRecordsDesc;

  /// No description provided for @permManageCareDesc.
  ///
  /// In en, this message translates to:
  /// **'Use AI assistant, complete care tasks'**
  String get permManageCareDesc;

  /// No description provided for @permBookDesc.
  ///
  /// In en, this message translates to:
  /// **'Book appointments, visits and medicines'**
  String get permBookDesc;

  /// No description provided for @permReceiveAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get SOS, fall and care alerts'**
  String get permReceiveAlertsDesc;

  /// No description provided for @sendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get sendInvite;

  /// No description provided for @caregiverInvited.
  ///
  /// In en, this message translates to:
  /// **'Caregiver invited'**
  String get caregiverInvited;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'The app and AI replies will use this language where available.'**
  String get languageSettingsSub;

  /// No description provided for @medicalTermsNote.
  ///
  /// In en, this message translates to:
  /// **'Some medical terms may appear in English for safety.'**
  String get medicalTermsNote;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get langHindi;

  /// No description provided for @langTelugu.
  ///
  /// In en, this message translates to:
  /// **'Telugu'**
  String get langTelugu;

  /// No description provided for @allNotifications.
  ///
  /// In en, this message translates to:
  /// **'All notifications'**
  String get allNotifications;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @prefPush.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get prefPush;

  /// No description provided for @prefSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get prefSms;

  /// No description provided for @prefWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get prefWhatsapp;

  /// No description provided for @prefEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get prefEmail;

  /// No description provided for @prefMarketing.
  ///
  /// In en, this message translates to:
  /// **'Offers & updates'**
  String get prefMarketing;

  /// No description provided for @notificationPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Lock-screen notifications never show health details.'**
  String get notificationPrivacyNote;

  /// No description provided for @privacyConsents.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Consents'**
  String get privacyConsents;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'You are in control. Turn permissions on or off at any time; changes apply immediately.'**
  String get privacyIntro;

  /// No description provided for @grantedOn.
  ///
  /// In en, this message translates to:
  /// **'Granted on {date}'**
  String grantedOn(String date);

  /// No description provided for @revokeConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw consent?'**
  String get revokeConsentTitle;

  /// No description provided for @revokeConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Features that depend on this consent will stop working.'**
  String get revokeConsentBody;

  /// No description provided for @revokeRequiredConsentBody.
  ///
  /// In en, this message translates to:
  /// **'This consent is required to use CareCompanion. Withdrawing it will limit most features until you grant it again.'**
  String get revokeRequiredConsentBody;

  /// No description provided for @consentTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get consentTerms;

  /// No description provided for @consentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get consentPrivacy;

  /// No description provided for @consentHealthData.
  ///
  /// In en, this message translates to:
  /// **'Health data processing'**
  String get consentHealthData;

  /// No description provided for @consentAi.
  ///
  /// In en, this message translates to:
  /// **'AI assistance'**
  String get consentAi;

  /// No description provided for @consentShareClinicians.
  ///
  /// In en, this message translates to:
  /// **'Share with clinicians'**
  String get consentShareClinicians;

  /// No description provided for @consentFamilySharing.
  ///
  /// In en, this message translates to:
  /// **'Family sharing'**
  String get consentFamilySharing;

  /// No description provided for @consentMarketing.
  ///
  /// In en, this message translates to:
  /// **'Marketing communication'**
  String get consentMarketing;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out of CareCompanion on this device?'**
  String get logoutConfirm;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link on this device.'**
  String get couldNotOpenLink;

  /// No description provided for @featureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This feature is not available right now. Please check again later.'**
  String get featureUnavailable;

  /// No description provided for @errorMfaRequired.
  ///
  /// In en, this message translates to:
  /// **'This is a staff account and needs two-step verification. Please use the CareCompanion staff portal.'**
  String get errorMfaRequired;

  /// No description provided for @mfaRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Use the staff portal'**
  String get mfaRequiredTitle;

  /// No description provided for @aiUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'AI assistant is unavailable'**
  String get aiUnavailableTitle;

  /// No description provided for @aiUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'The AI health assistant is switched off for now. You can still book a doctor. In an emergency, call 108.'**
  String get aiUnavailableBody;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Please update CareCompanion'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version is no longer supported. Update to the latest version to keep your care information safe and up to date.'**
  String get updateRequiredBody;

  /// No description provided for @updateVersionInfo.
  ///
  /// In en, this message translates to:
  /// **'Installed {current} · required {minimum} or newer'**
  String updateVersionInfo(String current, String minimum);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @pushPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay on top of your care'**
  String get pushPermissionTitle;

  /// No description provided for @pushPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications for appointment reminders, home-visit updates and urgent safety alerts. Notifications never show health details on the lock screen.'**
  String get pushPermissionBody;

  /// No description provided for @paymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be started. Please try again in a moment.'**
  String get paymentUnavailable;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment was cancelled. Nothing was charged.'**
  String get paymentCancelled;

  /// No description provided for @razorpaySecureNote.
  ///
  /// In en, this message translates to:
  /// **'Secure payment by Razorpay: UPI, cards, net banking and wallets.'**
  String get razorpaySecureNote;

  /// No description provided for @checkPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Check payment status'**
  String get checkPaymentStatus;

  /// No description provided for @paymentConfirming.
  ///
  /// In en, this message translates to:
  /// **'We are confirming your payment with the bank. Your booking is confirmed only after this completes.'**
  String get paymentConfirming;

  /// No description provided for @payInMobileAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete payment in the mobile app'**
  String get payInMobileAppTitle;

  /// No description provided for @payInMobileAppBody.
  ///
  /// In en, this message translates to:
  /// **'Online payment is not available in the browser yet. Open CareCompanion on your Android or iPhone to pay. Your booking stays reserved until then.'**
  String get payInMobileAppBody;

  /// No description provided for @yourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get yourData;

  /// No description provided for @myDataExport.
  ///
  /// In en, this message translates to:
  /// **'My CareCompanion data'**
  String get myDataExport;

  /// No description provided for @downloadMyData.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get downloadMyData;

  /// No description provided for @downloadMyDataSub.
  ///
  /// In en, this message translates to:
  /// **'A copy of your profile, records list, appointments and more (JSON file)'**
  String get downloadMyDataSub;

  /// No description provided for @dataExportReady.
  ///
  /// In en, this message translates to:
  /// **'Your data file is ready.'**
  String get dataExportReady;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// No description provided for @deleteMyAccountSub.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account after a grace period'**
  String get deleteMyAccountSub;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'We are sorry to see you go. Please read what happens before you continue.'**
  String get deleteAccountIntro;

  /// No description provided for @deletionWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'What happens'**
  String get deletionWhatHappens;

  /// No description provided for @deletionGracePeriod.
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled for deletion after a grace period (7 days by default). You can cancel any time before then by signing in again.'**
  String get deletionGracePeriod;

  /// No description provided for @deletionRemoved.
  ///
  /// In en, this message translates to:
  /// **'Then you are signed out everywhere, family access is removed, and your name, phone number and email are erased.'**
  String get deletionRemoved;

  /// No description provided for @deletionDependents.
  ///
  /// In en, this message translates to:
  /// **'Personal data of family members you manage is deleted too, unless the law requires us to keep it.'**
  String get deletionDependents;

  /// No description provided for @deletionWhatRetained.
  ///
  /// In en, this message translates to:
  /// **'What we must keep'**
  String get deletionWhatRetained;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Clinical records, payment records and audit logs are kept for the period the law requires, separated from your identity.'**
  String get deletionRetainedBody;

  /// No description provided for @deletionExportHint.
  ///
  /// In en, this message translates to:
  /// **'Want a copy first? Use \"Download my data\" before deleting.'**
  String get deletionExportHint;

  /// No description provided for @deletionReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get deletionReasonOptional;

  /// No description provided for @typeDeleteToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String typeDeleteToConfirm(String word);

  /// No description provided for @deletionScheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deletion scheduled'**
  String get deletionScheduledTitle;

  /// No description provided for @deletionScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted on {date}.'**
  String deletionScheduledFor(String date);

  /// No description provided for @deletionScheduledNoDate.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted when the grace period ends.'**
  String get deletionScheduledNoDate;

  /// No description provided for @deletionScheduledLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted on {date}. You will now be logged out. To cancel, sign in again before then and tap \"Cancel deletion\".'**
  String deletionScheduledLogoutBody(String date);

  /// No description provided for @deletionCancelHint.
  ///
  /// In en, this message translates to:
  /// **'Changed your mind? Cancel now and keep using CareCompanion as before.'**
  String get deletionCancelHint;

  /// No description provided for @cancelDeletion.
  ///
  /// In en, this message translates to:
  /// **'Cancel deletion'**
  String get cancelDeletion;

  /// No description provided for @deletionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Deletion cancelled. Your account stays active.'**
  String get deletionCancelled;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @helpSupportSub.
  ///
  /// In en, this message translates to:
  /// **'Call, WhatsApp or email our care team'**
  String get helpSupportSub;

  /// No description provided for @helpSupportIntro.
  ///
  /// In en, this message translates to:
  /// **'Questions about bookings, payments or the app? Our team is here to help.'**
  String get helpSupportIntro;

  /// No description provided for @supportEmergencyNote.
  ///
  /// In en, this message translates to:
  /// **'For a medical emergency, call 108 now.'**
  String get supportEmergencyNote;

  /// No description provided for @supportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Support contact details are not available right now.'**
  String get supportUnavailable;

  /// No description provided for @supportCall.
  ///
  /// In en, this message translates to:
  /// **'Call us'**
  String get supportCall;

  /// No description provided for @supportWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Chat on WhatsApp'**
  String get supportWhatsapp;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email us'**
  String get supportEmail;

  /// No description provided for @supportEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'CareCompanion app support'**
  String get supportEmailSubject;

  /// No description provided for @videoConsultation.
  ///
  /// In en, this message translates to:
  /// **'Video consultation'**
  String get videoConsultation;

  /// No description provided for @audioConsultation.
  ///
  /// In en, this message translates to:
  /// **'Audio consultation'**
  String get audioConsultation;

  /// No description provided for @joinConsultation.
  ///
  /// In en, this message translates to:
  /// **'Join consultation'**
  String get joinConsultation;

  /// No description provided for @consultationOpensIn.
  ///
  /// In en, this message translates to:
  /// **'You can join in {time}'**
  String consultationOpensIn(String time);

  /// No description provided for @consultationOpensAt.
  ///
  /// In en, this message translates to:
  /// **'Joining opens at {time}'**
  String consultationOpensAt(String time);

  /// No description provided for @consultationOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Your consultation room is open. Your doctor will join shortly.'**
  String get consultationOpenNow;

  /// No description provided for @consultationEnded.
  ///
  /// In en, this message translates to:
  /// **'This consultation has ended.'**
  String get consultationEnded;

  /// No description provided for @beforeYouJoin.
  ///
  /// In en, this message translates to:
  /// **'Before you join'**
  String get beforeYouJoin;

  /// No description provided for @beforeYouJoinSub.
  ///
  /// In en, this message translates to:
  /// **'A quick check helps your doctor hear and see you clearly.'**
  String get beforeYouJoinSub;

  /// No description provided for @checklistCameraMic.
  ///
  /// In en, this message translates to:
  /// **'Allow camera and microphone when asked'**
  String get checklistCameraMic;

  /// No description provided for @checklistMic.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone when asked (camera stays off)'**
  String get checklistMic;

  /// No description provided for @checklistQuietPlace.
  ///
  /// In en, this message translates to:
  /// **'Sit in a quiet, private place'**
  String get checklistQuietPlace;

  /// No description provided for @checklistConnection.
  ///
  /// In en, this message translates to:
  /// **'Use a stable Wi-Fi or mobile data connection'**
  String get checklistConnection;

  /// No description provided for @checklistReports.
  ///
  /// In en, this message translates to:
  /// **'Keep your reports and medicines nearby'**
  String get checklistReports;

  /// No description provided for @joinOpensOutside.
  ///
  /// In en, this message translates to:
  /// **'The call opens in the Jitsi Meet app if installed, otherwise in your browser.'**
  String get joinOpensOutside;

  /// No description provided for @joinNow.
  ///
  /// In en, this message translates to:
  /// **'Join now'**
  String get joinNow;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @viewPdf.
  ///
  /// In en, this message translates to:
  /// **'View PDF'**
  String get viewPdf;

  /// No description provided for @pdfDocument.
  ///
  /// In en, this message translates to:
  /// **'PDF document: {name}'**
  String pdfDocument(String name);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pageOf(int page, int total);

  /// No description provided for @pdfReady.
  ///
  /// In en, this message translates to:
  /// **'Your PDF is ready ({size})'**
  String pdfReady(String size);

  /// No description provided for @pdfWebNote.
  ///
  /// In en, this message translates to:
  /// **'On the web, PDFs open in your browser\'s own viewer.'**
  String get pdfWebNote;

  /// No description provided for @openPdfInNewTab.
  ///
  /// In en, this message translates to:
  /// **'Open in a new tab'**
  String get openPdfInNewTab;

  /// No description provided for @photoOf.
  ///
  /// In en, this message translates to:
  /// **'Photo of {name}'**
  String photoOf(String name);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'e-Prescription'**
  String get ePrescription;

  /// No description provided for @ePrescriptions.
  ///
  /// In en, this message translates to:
  /// **'From your doctors'**
  String get ePrescriptions;

  /// No description provided for @uploadedPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescription documents'**
  String get uploadedPrescriptions;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No uploaded prescriptions yet.'**
  String get noUploadedPrescriptions;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No e-prescriptions yet'**
  String get noEPrescriptions;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Prescriptions your doctor writes after a consultation appear here.'**
  String get noEPrescriptionsBody;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Prescription from {name}'**
  String rxFromDoctor(String name);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'{count} medicines'**
  String medicinesCount(int count);

  /// No description provided for @registrationNo.
  ///
  /// In en, this message translates to:
  /// **'Reg. No. {number}'**
  String registrationNo(String number);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Advice'**
  String get doctorsAdvice;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get followUp;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Review after {days} days'**
  String followUpInDays(int days);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Digitally generated prescription'**
  String get digitallyGenerated;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get rxDose;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get rxFrequency;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get rxTiming;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get rxDuration;

  /// No description provided for @rxReminderTimes.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get rxReminderTimes;

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String durationDays(int days);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get rxFormTablet;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Capsule'**
  String get rxFormCapsule;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Syrup'**
  String get rxFormSyrup;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Injection'**
  String get rxFormInjection;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Ointment'**
  String get rxFormOintment;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get rxFormDrops;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Inhaler'**
  String get rxFormInhaler;

  /// No description provided for @rxFormOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get rxFormOther;

  /// No description provided for @orderTheseMedicines.
  ///
  /// In en, this message translates to:
  /// **'Order these medicines'**
  String get orderTheseMedicines;

  /// No description provided for @pharmacyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Medicine ordering is not available right now.'**
  String get pharmacyUnavailable;

  /// No description provided for @noPharmacyMatches.
  ///
  /// In en, this message translates to:
  /// **'This prescription has no medicines to order.'**
  String get noPharmacyMatches;

  /// No description provided for @pharmacyMatchIntro.
  ///
  /// In en, this message translates to:
  /// **'We matched your prescription with our partner pharmacy. Choose what to order.'**
  String get pharmacyMatchIntro;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Check the medicine name and strength before paying. Ask your pharmacist or doctor if anything looks different.'**
  String get pharmacyMatchNote;

  /// No description provided for @selectMedicines.
  ///
  /// In en, this message translates to:
  /// **'Select medicines'**
  String get selectMedicines;

  /// No description provided for @addItemsToCart.
  ///
  /// In en, this message translates to:
  /// **'Add {count} to cart · {amount}'**
  String addItemsToCart(int count, String amount);

  /// No description provided for @notInCatalogue.
  ///
  /// In en, this message translates to:
  /// **'Not available from our pharmacy partner'**
  String get notInCatalogue;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Using your e-prescription from {doctor} ({date})'**
  String usingEPrescription(String doctor, String date);

  /// No description provided for @messageCareTeam.
  ///
  /// In en, this message translates to:
  /// **'Message care team'**
  String get messageCareTeam;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @invoiceNo.
  ///
  /// In en, this message translates to:
  /// **'Invoice {number}'**
  String invoiceNo(String number);

  /// No description provided for @taxInvoice.
  ///
  /// In en, this message translates to:
  /// **'Tax invoice'**
  String get taxInvoice;

  /// No description provided for @soldBy.
  ///
  /// In en, this message translates to:
  /// **'Sold by'**
  String get soldBy;

  /// No description provided for @billedTo.
  ///
  /// In en, this message translates to:
  /// **'Billed to'**
  String get billedTo;

  /// No description provided for @taxRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax {rate}%'**
  String taxRateLabel(String rate);

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @refundedLabel.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refundedLabel;

  /// No description provided for @invoiceFooter.
  ///
  /// In en, this message translates to:
  /// **'This is a computer-generated invoice and needs no signature.'**
  String get invoiceFooter;

  /// No description provided for @purposeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Family Care Plan'**
  String get purposeSubscription;

  /// No description provided for @paymentsSub.
  ///
  /// In en, this message translates to:
  /// **'History and invoices'**
  String get paymentsSub;

  /// No description provided for @reviewPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your care?'**
  String get reviewPromptTitle;

  /// No description provided for @yourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get yourRating;

  /// No description provided for @notRatedYet.
  ///
  /// In en, this message translates to:
  /// **'Not rated yet'**
  String get notRatedYet;

  /// No description provided for @rateStars.
  ///
  /// In en, this message translates to:
  /// **'Rate {count} out of 5'**
  String rateStars(int count);

  /// No description provided for @ratingOutOfFive.
  ///
  /// In en, this message translates to:
  /// **'{count} out of 5 stars'**
  String ratingOutOfFive(int count);

  /// No description provided for @reviewCommentOptional.
  ///
  /// In en, this message translates to:
  /// **'Tell us more (optional)'**
  String get reviewCommentOptional;

  /// No description provided for @reviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'What went well? What could be better?'**
  String get reviewCommentHint;

  /// No description provided for @reviewModerationInfo.
  ///
  /// In en, this message translates to:
  /// **'A rating on its own is published right away. Comments are checked by our team first.'**
  String get reviewModerationInfo;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitReview;

  /// No description provided for @reviewThanksPublished.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your rating is published.'**
  String get reviewThanksPublished;

  /// No description provided for @reviewThanksPending.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your review will appear after a quick check.'**
  String get reviewThanksPending;

  /// No description provided for @reviewsModerationNote.
  ///
  /// In en, this message translates to:
  /// **'Reviews come from verified patients and are checked before they appear.'**
  String get reviewsModerationNote;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get inbox;

  /// No description provided for @inboxUnread.
  ///
  /// In en, this message translates to:
  /// **'Messages, {count} unread'**
  String inboxUnread(int count);

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get inboxEmpty;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When you have an active care episode, you can message your care team here.'**
  String get inboxEmptyBody;

  /// No description provided for @unreadMessages.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadMessages(int count);

  /// No description provided for @careTeamMessages.
  ///
  /// In en, this message translates to:
  /// **'Care team'**
  String get careTeamMessages;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @noMessagesYetBody.
  ///
  /// In en, this message translates to:
  /// **'Ask your doctor or care coordinator a question about this episode.'**
  String get noMessagesYetBody;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get messageHint;

  /// No description provided for @attachRecord.
  ///
  /// In en, this message translates to:
  /// **'Attach a record'**
  String get attachRecord;

  /// No description provided for @attachedRecord.
  ///
  /// In en, this message translates to:
  /// **'Attached record'**
  String get attachedRecord;

  /// No description provided for @messagingNotForEmergencies.
  ///
  /// In en, this message translates to:
  /// **'Not for emergencies. In an emergency call 108.'**
  String get messagingNotForEmergencies;

  /// No description provided for @youSaid.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String youSaid(String text);

  /// No description provided for @senderSaid.
  ///
  /// In en, this message translates to:
  /// **'{sender}: {text}'**
  String senderSaid(String sender, String text);

  /// No description provided for @roleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get roleDoctor;

  /// No description provided for @roleCoordinator.
  ///
  /// In en, this message translates to:
  /// **'Care coordinator'**
  String get roleCoordinator;

  /// No description provided for @roleCareTeam.
  ///
  /// In en, this message translates to:
  /// **'Care team'**
  String get roleCareTeam;

  /// No description provided for @roleFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get roleFamily;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rolePatient;

  /// No description provided for @roleSystem.
  ///
  /// In en, this message translates to:
  /// **'CareCompanion'**
  String get roleSystem;

  /// No description provided for @familyCarePlan.
  ///
  /// In en, this message translates to:
  /// **'Family Care Plan'**
  String get familyCarePlan;

  /// No description provided for @familyCarePlanSub.
  ///
  /// In en, this message translates to:
  /// **'Savings and a care coordinator for your family'**
  String get familyCarePlanSub;

  /// No description provided for @familyPlanIntro.
  ///
  /// In en, this message translates to:
  /// **'One plan for the whole family: discounts on home visits and extra support from our care team.'**
  String get familyPlanIntro;

  /// No description provided for @noPlansAvailable.
  ///
  /// In en, this message translates to:
  /// **'No plans are available right now'**
  String get noPlansAvailable;

  /// No description provided for @billingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get billingMonthly;

  /// No description provided for @billingYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get billingYearly;

  /// No description provided for @billingYearlySave.
  ///
  /// In en, this message translates to:
  /// **'Yearly · save {pct}%'**
  String billingYearlySave(int pct);

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **' / month'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **' / year'**
  String get perYear;

  /// No description provided for @planYearlySavings.
  ///
  /// In en, this message translates to:
  /// **'You save {amount} ({pct}%) a year'**
  String planYearlySavings(String amount, int pct);

  /// No description provided for @planMembers.
  ///
  /// In en, this message translates to:
  /// **'Covers up to {count} family members'**
  String planMembers(int count);

  /// No description provided for @planHomeVisitDiscount.
  ///
  /// In en, this message translates to:
  /// **'{pct}% off home visits'**
  String planHomeVisitDiscount(int pct);

  /// No description provided for @planCoordinatorIncluded.
  ///
  /// In en, this message translates to:
  /// **'A dedicated care coordinator'**
  String get planCoordinatorIncluded;

  /// No description provided for @subscribeFor.
  ///
  /// In en, this message translates to:
  /// **'Subscribe · {amount}'**
  String subscribeFor(String amount);

  /// No description provided for @planPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} subscription'**
  String planPaymentTitle(String name);

  /// No description provided for @planActivated.
  ///
  /// In en, this message translates to:
  /// **'{name} is now active'**
  String planActivated(String name);

  /// No description provided for @planPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Your {name} payment is not complete yet. Subscribe again to finish.'**
  String planPendingPayment(String name);

  /// No description provided for @planPrepaidNote.
  ///
  /// In en, this message translates to:
  /// **'Plans are prepaid for the period you choose. We remind you 7 days before it ends.'**
  String get planPrepaidNote;

  /// No description provided for @planActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planActive;

  /// No description provided for @planRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'Current period ends on {date}'**
  String planRenewsOn(String date);

  /// No description provided for @planEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends on {date}'**
  String planEndsOn(String date);

  /// No description provided for @planBenefits.
  ///
  /// In en, this message translates to:
  /// **'Your benefits'**
  String get planBenefits;

  /// No description provided for @planCancelScheduled.
  ///
  /// In en, this message translates to:
  /// **'Your plan will not renew. Benefits continue until the end date.'**
  String get planCancelScheduled;

  /// No description provided for @cancelAtPeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'Cancel at period end'**
  String get cancelAtPeriodEnd;

  /// No description provided for @cancelPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel your plan?'**
  String get cancelPlanTitle;

  /// No description provided for @cancelPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Your benefits continue until {date}. After that the plan will not renew.'**
  String cancelPlanBody(String date);

  /// No description provided for @cancelPlanBodyNoDate.
  ///
  /// In en, this message translates to:
  /// **'Your benefits continue until the end of the current period.'**
  String get cancelPlanBodyNoDate;

  /// No description provided for @keepPlan.
  ///
  /// In en, this message translates to:
  /// **'Keep plan'**
  String get keepPlan;

  /// No description provided for @planDiscountApplied.
  ///
  /// In en, this message translates to:
  /// **'Family Care Plan discount: −{amount}'**
  String planDiscountApplied(String amount);

  /// No description provided for @planDiscountWillApply.
  ///
  /// In en, this message translates to:
  /// **'Your Family Care Plan discount is applied when you book.'**
  String get planDiscountWillApply;

  /// No description provided for @govtSchemes.
  ///
  /// In en, this message translates to:
  /// **'Govt. Health Schemes'**
  String get govtSchemes;

  /// No description provided for @schemesDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Information only. This app does not decide whether you are eligible; the scheme authority does.'**
  String get schemesDisclaimer;

  /// No description provided for @yourState.
  ///
  /// In en, this message translates to:
  /// **'Your state'**
  String get yourState;

  /// No description provided for @allStates.
  ///
  /// In en, this message translates to:
  /// **'All states'**
  String get allStates;

  /// No description provided for @centralSchemesAlwaysShown.
  ///
  /// In en, this message translates to:
  /// **'Central government schemes are always listed.'**
  String get centralSchemesAlwaysShown;

  /// No description provided for @noSchemes.
  ///
  /// In en, this message translates to:
  /// **'No schemes to show'**
  String get noSchemes;

  /// No description provided for @centralScheme.
  ///
  /// In en, this message translates to:
  /// **'Central'**
  String get centralScheme;

  /// No description provided for @stateScheme.
  ///
  /// In en, this message translates to:
  /// **'State · {state}'**
  String stateScheme(String state);

  /// No description provided for @aboutScheme.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutScheme;

  /// No description provided for @schemeBenefits.
  ///
  /// In en, this message translates to:
  /// **'Benefits'**
  String get schemeBenefits;

  /// No description provided for @mayBeRelevantIf.
  ///
  /// In en, this message translates to:
  /// **'May be relevant if…'**
  String get mayBeRelevantIf;

  /// No description provided for @eligibilityNotDetermined.
  ///
  /// In en, this message translates to:
  /// **'These are hints, not an eligibility check. Confirm with the official source.'**
  String get eligibilityNotDetermined;

  /// No description provided for @documentsTypicallyNeeded.
  ///
  /// In en, this message translates to:
  /// **'Documents usually needed'**
  String get documentsTypicallyNeeded;

  /// No description provided for @helpline.
  ///
  /// In en, this message translates to:
  /// **'Helpline'**
  String get helpline;

  /// No description provided for @openOfficialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Open official website'**
  String get openOfficialWebsite;

  /// No description provided for @lastReviewedOn.
  ///
  /// In en, this message translates to:
  /// **'Information last reviewed on {date}'**
  String lastReviewedOn(String date);

  /// No description provided for @abhaTitle.
  ///
  /// In en, this message translates to:
  /// **'ABHA (Health ID)'**
  String get abhaTitle;

  /// No description provided for @abhaIntro.
  ///
  /// In en, this message translates to:
  /// **'Add your Ayushman Bharat Health Account number or address to keep it with your profile.'**
  String get abhaIntro;

  /// No description provided for @abhaNumber.
  ///
  /// In en, this message translates to:
  /// **'ABHA number'**
  String get abhaNumber;

  /// No description provided for @abhaAddress.
  ///
  /// In en, this message translates to:
  /// **'ABHA address'**
  String get abhaAddress;

  /// No description provided for @addAbha.
  ///
  /// In en, this message translates to:
  /// **'Add ABHA'**
  String get addAbha;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerified;

  /// No description provided for @abhaEditHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 14-digit number or the address (for example name@abdm).'**
  String get abhaEditHint;

  /// No description provided for @abhaEnterOne.
  ///
  /// In en, this message translates to:
  /// **'Enter an ABHA number or address'**
  String get abhaEnterOne;

  /// No description provided for @abhaNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'ABHA number must have 14 digits'**
  String get abhaNumberInvalid;

  /// No description provided for @abhaAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use the form name@abdm'**
  String get abhaAddressInvalid;

  /// No description provided for @abhaVerifyComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get abhaVerifyComingSoonTitle;

  /// No description provided for @abhaVerifyComingSoon.
  ///
  /// In en, this message translates to:
  /// **'ABDM verification is coming soon. Your ABHA details are saved and will be verified once the connection is ready.'**
  String get abhaVerifyComingSoon;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'With your permission we read steps, heart rate, sleep, SpO2, blood pressure, glucose and weight so you and your care team can see trends. You choose each type.'**
  String get wearablePurpose;

  /// No description provided for @chooseDataToShare.
  ///
  /// In en, this message translates to:
  /// **'Choose what to read from {name}'**
  String chooseDataToShare(String name);

  /// No description provided for @metricSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get metricSteps;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood oxygen (SpO2)'**
  String get metricSpo2;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get metricBloodPressure;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood glucose'**
  String get metricGlucose;

  /// No description provided for @metricWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get metricWeight;

  /// No description provided for @healthConnect.
  ///
  /// In en, this message translates to:
  /// **'Health Connect'**
  String get healthConnect;

  /// No description provided for @appleHealth.
  ///
  /// In en, this message translates to:
  /// **'Apple Health'**
  String get appleHealth;

  /// No description provided for @healthConnectMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is needed'**
  String get healthConnectMissingTitle;

  /// No description provided for @healthConnectUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Please update Health Connect'**
  String get healthConnectUpdateTitle;

  /// No description provided for @healthConnectMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Your watch and fitness apps share data through Google Health Connect. Install or update it from the Play Store, then come back.'**
  String get healthConnectMissingBody;

  /// No description provided for @openPlayStore.
  ///
  /// In en, this message translates to:
  /// **'Open Play Store'**
  String get openPlayStore;

  /// No description provided for @healthPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Access was not allowed. You can allow it any time in Health Connect (Android) or Settings → Health → Data Access (iPhone), then tap Connect again.'**
  String get healthPermissionDenied;

  /// No description provided for @wearablesUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Health data sync works in the CareCompanion app on Android and iPhone. It is not available in the web version.'**
  String get wearablesUnsupported;

  /// No description provided for @syncedReadings.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} readings'**
  String syncedReadings(int count);

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @autoSyncNote.
  ///
  /// In en, this message translates to:
  /// **'We also sync when you open the app (at most every 30 minutes).'**
  String get autoSyncNote;

  /// No description provided for @otherDevices.
  ///
  /// In en, this message translates to:
  /// **'Other devices'**
  String get otherDevices;

  /// No description provided for @healthDataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Health data & privacy'**
  String get healthDataPrivacy;

  /// No description provided for @healthPrivacyIntro.
  ///
  /// In en, this message translates to:
  /// **'How CareCompanion uses the health data you allow'**
  String get healthPrivacyIntro;

  /// No description provided for @healthPrivacyPoint1.
  ///
  /// In en, this message translates to:
  /// **'We only read the types you switch on, and never write to your health store.'**
  String get healthPrivacyPoint1;

  /// No description provided for @healthPrivacyPoint2.
  ///
  /// In en, this message translates to:
  /// **'Readings are shown to you and to clinicians caring for you.'**
  String get healthPrivacyPoint2;

  /// No description provided for @healthPrivacyPoint3.
  ///
  /// In en, this message translates to:
  /// **'We never sell your data or use it for advertising.'**
  String get healthPrivacyPoint3;

  /// No description provided for @healthPrivacyPoint4.
  ///
  /// In en, this message translates to:
  /// **'You can disconnect at any time from Linked devices.'**
  String get healthPrivacyPoint4;

  /// No description provided for @readPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Read the privacy policy'**
  String get readPrivacyPolicy;

  /// No description provided for @fallDetectToggle.
  ///
  /// In en, this message translates to:
  /// **'Detect falls while the app is open'**
  String get fallDetectToggle;

  /// No description provided for @fallDetectOn.
  ///
  /// In en, this message translates to:
  /// **'On: we watch the phone\'s motion sensor while CareCompanion is open.'**
  String get fallDetectOn;

  /// No description provided for @fallDetectOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get fallDetectOff;

  /// No description provided for @fallDetectUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Available in the Android and iPhone app'**
  String get fallDetectUnsupported;

  /// No description provided for @fallForegroundOnly.
  ///
  /// In en, this message translates to:
  /// **'Works only while the app is open on screen. It does not run in the background.'**
  String get fallForegroundOnly;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'A supportive feature, not a medical device. It can miss falls or raise false alarms.'**
  String get fallNotMedicalDevice;

  /// No description provided for @readRepliesAloud.
  ///
  /// In en, this message translates to:
  /// **'Read replies aloud'**
  String get readRepliesAloud;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get changePhoto;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated'**
  String get photoUpdated;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo is larger than 5 MB'**
  String get photoTooLarge;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeSystemSub.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone\'s setting'**
  String get themeSystemSub;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

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

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moreServices.
  ///
  /// In en, this message translates to:
  /// **'More services'**
  String get moreServices;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @redeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeem;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @copyCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy {command}'**
  String copyCommand(String command);

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get credit;

  /// No description provided for @debit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get debit;

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String validUntil(String date);

  /// No description provided for @planBy.
  ///
  /// In en, this message translates to:
  /// **'Plan by {name}'**
  String planBy(String name);

  /// No description provided for @planDates.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String planDates(String start, String end);

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptional;

  /// No description provided for @logoOf.
  ///
  /// In en, this message translates to:
  /// **'{name} logo'**
  String logoOf(String name);

  /// No description provided for @poweredByCareCompanion.
  ///
  /// In en, this message translates to:
  /// **'Powered by CareCompanion'**
  String get poweredByCareCompanion;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Adherence'**
  String get adherence;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Lab Tests'**
  String get qxLabTests;

  /// No description provided for @qxCarePrograms.
  ///
  /// In en, this message translates to:
  /// **'Care Programs'**
  String get qxCarePrograms;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Preventive Care'**
  String get qxPreventiveCare;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Second Opinion'**
  String get qxSecondOpinion;

  /// No description provided for @qxInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get qxInsurance;

  /// No description provided for @qxExercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get qxExercise;

  /// No description provided for @qxDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get qxDiet;

  /// No description provided for @dailyCheckin.
  ///
  /// In en, this message translates to:
  /// **'Daily check-in'**
  String get dailyCheckin;

  /// No description provided for @dailyCheckinSub.
  ///
  /// In en, this message translates to:
  /// **'An \"I\'m OK\" tap each morning'**
  String get dailyCheckinSub;

  /// No description provided for @imOkToday.
  ///
  /// In en, this message translates to:
  /// **'I\'m OK today'**
  String get imOkToday;

  /// No description provided for @checkinPrompt.
  ///
  /// In en, this message translates to:
  /// **'One tap lets your family know you are fine today.'**
  String get checkinPrompt;

  /// No description provided for @checkinMissedBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s check-in window has passed. Checking in now still tells your family you\'re OK.'**
  String get checkinMissedBody;

  /// No description provided for @checkinMoodOptional.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling? (optional)'**
  String get checkinMoodOptional;

  /// No description provided for @checkinWindow.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end}'**
  String checkinWindow(String start, String end);

  /// No description provided for @checkinThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your family has been told you are OK.'**
  String get checkinThanks;

  /// No description provided for @checkinDoneAt.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {time}'**
  String checkinDoneAt(String time);

  /// No description provided for @checkinFamilyDone.
  ///
  /// In en, this message translates to:
  /// **'{name} checked in today at {time}'**
  String checkinFamilyDone(String name, String time);

  /// No description provided for @checkinFamilyMissed.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn\'t checked in today'**
  String checkinFamilyMissed(String name);

  /// No description provided for @checkinFamilyPending.
  ///
  /// In en, this message translates to:
  /// **'{name} has not checked in yet (window {window})'**
  String checkinFamilyPending(String name, String window);

  /// No description provided for @checkinOk.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get checkinOk;

  /// No description provided for @checkinLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get checkinLate;

  /// No description provided for @checkinMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get checkinMissed;

  /// No description provided for @checkinPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get checkinPending;

  /// No description provided for @checkinHistorySemantic.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days: {ok} on time, {late} late, {missed} missed'**
  String checkinHistorySemantic(int ok, int late, int missed);

  /// No description provided for @checkinIntro.
  ///
  /// In en, this message translates to:
  /// **'A daily \"I\'m OK\" check-in for {name}. If it is missed, family and the care coordinator are alerted.'**
  String checkinIntro(String name);

  /// No description provided for @checkinNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Only family members with \"Manage care\" permission can change this.'**
  String get checkinNoPermission;

  /// No description provided for @checkinEnable.
  ///
  /// In en, this message translates to:
  /// **'Daily check-in'**
  String get checkinEnable;

  /// No description provided for @checkinEnableSub.
  ///
  /// In en, this message translates to:
  /// **'Show the \"I\'m OK today\" card every morning'**
  String get checkinEnableSub;

  /// No description provided for @checkinWindowStart.
  ///
  /// In en, this message translates to:
  /// **'Window opens'**
  String get checkinWindowStart;

  /// No description provided for @checkinWindowEnd.
  ///
  /// In en, this message translates to:
  /// **'Window closes'**
  String get checkinWindowEnd;

  /// No description provided for @checkinWindowInvalid.
  ///
  /// In en, this message translates to:
  /// **'The window must end after it starts'**
  String get checkinWindowInvalid;

  /// No description provided for @checkinEscalateAfter.
  ///
  /// In en, this message translates to:
  /// **'Alert the care team after'**
  String get checkinEscalateAfter;

  /// No description provided for @minutesCount.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutesCount(int minutes);

  /// No description provided for @checkinNotifyFamily.
  ///
  /// In en, this message translates to:
  /// **'Notify family if missed'**
  String get checkinNotifyFamily;

  /// No description provided for @checkinNotifyCoordinator.
  ///
  /// In en, this message translates to:
  /// **'Notify the care coordinator'**
  String get checkinNotifyCoordinator;

  /// No description provided for @checkinHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'If there is no check-in by the end of the window, family get a notification. If it is still missing after the set time, the care coordinator follows up. Times are in IST.'**
  String get checkinHowItWorks;

  /// No description provided for @checkinLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get checkinLast30Days;

  /// No description provided for @checkinNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet'**
  String get checkinNoHistory;

  /// No description provided for @carePrograms.
  ///
  /// In en, this message translates to:
  /// **'Care programs'**
  String get carePrograms;

  /// No description provided for @myPrograms.
  ///
  /// In en, this message translates to:
  /// **'My programs'**
  String get myPrograms;

  /// No description provided for @programsIntro.
  ///
  /// In en, this message translates to:
  /// **'Your doctor set these up to watch your readings between visits.'**
  String get programsIntro;

  /// No description provided for @noProgramsTitle.
  ///
  /// In en, this message translates to:
  /// **'No care programs yet'**
  String get noProgramsTitle;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Your doctor can enrol you in a BP, diabetes or heart-care program.'**
  String get noProgramsBody;

  /// No description provided for @logReading.
  ///
  /// In en, this message translates to:
  /// **'Log reading'**
  String get logReading;

  /// No description provided for @lastReadingAt.
  ///
  /// In en, this message translates to:
  /// **'Last reading {time}'**
  String lastReadingAt(String time);

  /// No description provided for @adherence7d.
  ///
  /// In en, this message translates to:
  /// **'Readings taken (7 days)'**
  String get adherence7d;

  /// No description provided for @adherence30d.
  ///
  /// In en, this message translates to:
  /// **'Readings taken (30 days)'**
  String get adherence30d;

  /// No description provided for @readingsDueToday.
  ///
  /// In en, this message translates to:
  /// **'{count} readings due today'**
  String readingsDueToday(int count);

  /// No description provided for @readingsDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s readings done'**
  String get readingsDoneToday;

  /// No description provided for @readingsReceived.
  ///
  /// In en, this message translates to:
  /// **'{received} of {expected} readings'**
  String readingsReceived(int received, int expected);

  /// No description provided for @openAlerts.
  ///
  /// In en, this message translates to:
  /// **'{count} open alerts'**
  String openAlerts(int count);

  /// No description provided for @openAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get openAlertsTitle;

  /// No description provided for @noAlerts.
  ///
  /// In en, this message translates to:
  /// **'No alerts in the last 30 days.'**
  String get noAlerts;

  /// No description provided for @programPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get programPaused;

  /// No description provided for @programCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get programCompleted;

  /// No description provided for @trend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get trend;

  /// No description provided for @noReadingsYet.
  ///
  /// In en, this message translates to:
  /// **'No readings yet'**
  String get noReadingsYet;

  /// No description provided for @trendSemantic.
  ///
  /// In en, this message translates to:
  /// **'{type} trend: {count} days, latest average {latest} on {date}'**
  String trendSemantic(String type, int count, String latest, String date);

  /// No description provided for @weeklyReports.
  ///
  /// In en, this message translates to:
  /// **'Weekly reports'**
  String get weeklyReports;

  /// No description provided for @noWeeklyReports.
  ///
  /// In en, this message translates to:
  /// **'Your first weekly report arrives on Monday.'**
  String get noWeeklyReports;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Alerts go to your care team. If you feel unwell, call your doctor or 108 in an emergency.'**
  String get programDisclaimer;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get bloodPressure;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'BP'**
  String get bloodPressureShort;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get glucoseShort;

  /// No description provided for @weightShort.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightShort;

  /// No description provided for @readingOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'That value looks unusual. Please check and re-enter.'**
  String get readingOutOfRange;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'The upper (systolic) number must be higher than the lower one.'**
  String get readingSystolicBelowDiastolic;

  /// No description provided for @readingSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'Readings are shared with your care team. Feeling unwell? Call 108 in an emergency.'**
  String get readingSafetyNote;

  /// No description provided for @readingSaved.
  ///
  /// In en, this message translates to:
  /// **'Reading saved'**
  String get readingSaved;

  /// No description provided for @whatsappAssistant.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp assistant'**
  String get whatsappAssistant;

  /// No description provided for @whatsappExplain.
  ///
  /// In en, this message translates to:
  /// **'Get reminders on WhatsApp and reply to check in, log BP or sugar, or ask a question. No diagnosis is given.'**
  String get whatsappExplain;

  /// No description provided for @whatsappOptIn.
  ///
  /// In en, this message translates to:
  /// **'Use the WhatsApp assistant'**
  String get whatsappOptIn;

  /// No description provided for @whatsappPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Messages go to your registered number. Send STOP at any time to opt out.'**
  String get whatsappPrivacyNote;

  /// No description provided for @whatsappTryIt.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get whatsappTryIt;

  /// No description provided for @whatsappTryIntro.
  ///
  /// In en, this message translates to:
  /// **'Send these messages to our WhatsApp number:'**
  String get whatsappTryIntro;

  /// No description provided for @whatsappOptedIn.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp assistant turned on'**
  String get whatsappOptedIn;

  /// No description provided for @whatsappOptedOut.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp assistant turned off'**
  String get whatsappOptedOut;

  /// No description provided for @waCmdToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s medicine and visit reminders'**
  String get waCmdToday;

  /// No description provided for @waCmdCheckin.
  ///
  /// In en, this message translates to:
  /// **'Daily \"I\'m OK\" check-in'**
  String get waCmdCheckin;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Record a blood pressure reading'**
  String get waCmdBp;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Record a blood sugar reading'**
  String get waCmdSugar;

  /// No description provided for @waCmdBook.
  ///
  /// In en, this message translates to:
  /// **'Get links to book care'**
  String get waCmdBook;

  /// No description provided for @waCmdStop.
  ///
  /// In en, this message translates to:
  /// **'Stop WhatsApp messages'**
  String get waCmdStop;

  /// No description provided for @waCmdStart.
  ///
  /// In en, this message translates to:
  /// **'Start them again'**
  String get waCmdStart;

  /// No description provided for @whatsappNoDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Replies are general guidance, not a diagnosis. In an emergency call 108.'**
  String get whatsappNoDiagnosis;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Lab tests at home'**
  String get labTests;

  /// No description provided for @labIntro.
  ///
  /// In en, this message translates to:
  /// **'A trained technician collects the sample at home. Reports come to your records.'**
  String get labIntro;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Search tests (e.g. HbA1c, lipid)'**
  String get searchLabTests;

  /// No description provided for @healthPackages.
  ///
  /// In en, this message translates to:
  /// **'Health packages'**
  String get healthPackages;

  /// No description provided for @noPackages.
  ///
  /// In en, this message translates to:
  /// **'No packages right now'**
  String get noPackages;

  /// No description provided for @allTests.
  ///
  /// In en, this message translates to:
  /// **'All tests'**
  String get allTests;

  /// No description provided for @resultsFor.
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String resultsFor(String query);

  /// No description provided for @noLabTests.
  ///
  /// In en, this message translates to:
  /// **'No tests found'**
  String get noLabTests;

  /// No description provided for @labPricingNote.
  ///
  /// In en, this message translates to:
  /// **'Prices are indicative and confirmed at booking.'**
  String get labPricingNote;

  /// No description provided for @testsIncluded.
  ///
  /// In en, this message translates to:
  /// **'{count} tests'**
  String testsIncluded(int count);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get fastingRequired;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Fasting {hours} h'**
  String fastingHoursShort(int hours);

  /// No description provided for @reportInHours.
  ///
  /// In en, this message translates to:
  /// **'Report in {hours} h'**
  String reportInHours(int hours);

  /// No description provided for @includedInPackage.
  ///
  /// In en, this message translates to:
  /// **'In package'**
  String get includedInPackage;

  /// No description provided for @removeFromCart.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeFromCart(String name);

  /// No description provided for @labCartBar.
  ///
  /// In en, this message translates to:
  /// **'{count} selected · {amount} · View cart'**
  String labCartBar(int count, String amount);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Blood'**
  String get sampleBlood;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Urine'**
  String get sampleUrine;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Swab'**
  String get sampleSwab;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Other sample'**
  String get sampleOther;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Fasting needed'**
  String get fastingNoticeTitle;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Please do not eat for {hours} hours before the sample is collected. Water is fine. Take regular medicines unless your doctor said otherwise.'**
  String fastingNoticeBody(int hours);

  /// No description provided for @labCart.
  ///
  /// In en, this message translates to:
  /// **'Your tests'**
  String get labCart;

  /// No description provided for @labCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tests selected'**
  String get labCartEmpty;

  /// No description provided for @browseTests.
  ///
  /// In en, this message translates to:
  /// **'Browse tests'**
  String get browseTests;

  /// No description provided for @sampleCollectionAddress.
  ///
  /// In en, this message translates to:
  /// **'Sample collection address'**
  String get sampleCollectionAddress;

  /// No description provided for @sampleCollectionTime.
  ///
  /// In en, this message translates to:
  /// **'Collection time'**
  String get sampleCollectionTime;

  /// No description provided for @youSaveVsMrp.
  ///
  /// In en, this message translates to:
  /// **'You save {amount} on MRP'**
  String youSaveVsMrp(String amount);

  /// No description provided for @labOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Lab test order'**
  String get labOrderTitle;

  /// No description provided for @labBooked.
  ///
  /// In en, this message translates to:
  /// **'Sample collection booked'**
  String get labBooked;

  /// No description provided for @trackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get trackOrder;

  /// No description provided for @myLabOrders.
  ///
  /// In en, this message translates to:
  /// **'My lab orders'**
  String get myLabOrders;

  /// No description provided for @noLabOrders.
  ///
  /// In en, this message translates to:
  /// **'No lab orders yet'**
  String get noLabOrders;

  /// No description provided for @labPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get labPendingPayment;

  /// No description provided for @labScheduled.
  ///
  /// In en, this message translates to:
  /// **'Collection scheduled'**
  String get labScheduled;

  /// No description provided for @labSampleCollected.
  ///
  /// In en, this message translates to:
  /// **'Sample collected'**
  String get labSampleCollected;

  /// No description provided for @labProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing at lab'**
  String get labProcessing;

  /// No description provided for @labReportReady.
  ///
  /// In en, this message translates to:
  /// **'Report ready'**
  String get labReportReady;

  /// No description provided for @labCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get labCancelled;

  /// No description provided for @labPartner.
  ///
  /// In en, this message translates to:
  /// **'Lab partner'**
  String get labPartner;

  /// No description provided for @viewReport.
  ///
  /// In en, this message translates to:
  /// **'View report'**
  String get viewReport;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Lab report'**
  String get labReport;

  /// No description provided for @trackSampleCollection.
  ///
  /// In en, this message translates to:
  /// **'Track sample collection'**
  String get trackSampleCollection;

  /// No description provided for @orderStatus.
  ///
  /// In en, this message translates to:
  /// **'Order status'**
  String get orderStatus;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @labOrderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled. Any payment will be refunded.'**
  String get labOrderCancelled;

  /// No description provided for @labReportNote.
  ///
  /// In en, this message translates to:
  /// **'Your doctor will be able to see the report. Discuss the results with them.'**
  String get labReportNote;

  /// No description provided for @cancelReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you cancelling?'**
  String get cancelReasonTitle;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Second opinion'**
  String get secondOpinion;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Share your reports with a senior specialist and get a written opinion.'**
  String get secondOpinionIntro;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Request a second opinion'**
  String get requestSecondOpinion;

  /// No description provided for @myRequests.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get myRequests;

  /// No description provided for @noSecondOpinions.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get noSecondOpinions;

  /// No description provided for @secondOpinionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Second opinions are not available right now'**
  String get secondOpinionUnavailable;

  /// No description provided for @chooseSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Choose a specialty'**
  String get chooseSpecialty;

  /// No description provided for @opinionWithinHours.
  ///
  /// In en, this message translates to:
  /// **'Written opinion within {hours} hours'**
  String opinionWithinHours(int hours);

  /// No description provided for @yourQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your question'**
  String get yourQuestion;

  /// No description provided for @yourQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'What would you like the specialist to review? Include your main concern and current treatment.'**
  String get yourQuestionHint;

  /// No description provided for @questionTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please write at least {count} characters'**
  String questionTooShort(int count);

  /// No description provided for @recordsToShare.
  ///
  /// In en, this message translates to:
  /// **'Records to share'**
  String get recordsToShare;

  /// No description provided for @noRecordsToShare.
  ///
  /// In en, this message translates to:
  /// **'No records yet. You can still ask your question.'**
  String get noRecordsToShare;

  /// No description provided for @secondOpinionConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to share my question and the {count} selected records, read-only, with the specialist who takes up this request. Access is logged.'**
  String secondOpinionConsent(int count);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'A second opinion is advice based on the records shared. It does not replace an examination. In an emergency call 108.'**
  String get secondOpinionDisclaimer;

  /// No description provided for @secondOpinionSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Request sent to specialists'**
  String get secondOpinionSubmitted;

  /// No description provided for @soPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get soPendingPayment;

  /// No description provided for @soOpen.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a specialist'**
  String get soOpen;

  /// No description provided for @soClaimed.
  ///
  /// In en, this message translates to:
  /// **'Specialist reviewing'**
  String get soClaimed;

  /// No description provided for @soAnswered.
  ///
  /// In en, this message translates to:
  /// **'Opinion ready'**
  String get soAnswered;

  /// No description provided for @soCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get soCancelled;

  /// No description provided for @specialist.
  ///
  /// In en, this message translates to:
  /// **'Specialist'**
  String get specialist;

  /// No description provided for @expectedBy.
  ///
  /// In en, this message translates to:
  /// **'Expected by'**
  String get expectedBy;

  /// No description provided for @recordsShared.
  ///
  /// In en, this message translates to:
  /// **'Records shared'**
  String get recordsShared;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Specialist\'s opinion'**
  String get specialistOpinion;

  /// No description provided for @opinionBy.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String opinionBy(String name);

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @bookTeleconsult.
  ///
  /// In en, this message translates to:
  /// **'Book a video consultation'**
  String get bookTeleconsult;

  /// No description provided for @opinionPendingBody.
  ///
  /// In en, this message translates to:
  /// **'We will notify you when the specialist has answered.'**
  String get opinionPendingBody;

  /// No description provided for @createAbha.
  ///
  /// In en, this message translates to:
  /// **'Create ABHA'**
  String get createAbha;

  /// No description provided for @createAbhaSub.
  ///
  /// In en, this message translates to:
  /// **'Get your Health ID with a mobile OTP'**
  String get createAbhaSub;

  /// No description provided for @createAbhaIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the mobile number to verify. An OTP will be sent to it.'**
  String get createAbhaIntro;

  /// No description provided for @linkAbha.
  ///
  /// In en, this message translates to:
  /// **'Link existing ABHA'**
  String get linkAbha;

  /// No description provided for @linkAbhaSub.
  ///
  /// In en, this message translates to:
  /// **'Already have a 14-digit ABHA number?'**
  String get linkAbhaSub;

  /// No description provided for @linkAbhaIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your ABHA number. An OTP will be sent to the mobile linked with it.'**
  String get linkAbhaIntro;

  /// No description provided for @abhaMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get abhaMobileLabel;

  /// No description provided for @abhaOtpSent.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit OTP we sent.'**
  String get abhaOtpSent;

  /// No description provided for @abhaCreated.
  ///
  /// In en, this message translates to:
  /// **'Your ABHA is ready'**
  String get abhaCreated;

  /// No description provided for @abhaLinked.
  ///
  /// In en, this message translates to:
  /// **'ABHA linked'**
  String get abhaLinked;

  /// No description provided for @abdmPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'ABHA is issued by the National Health Authority (ABDM). We never share your records without your consent.'**
  String get abdmPrivacyNote;

  /// No description provided for @fetchRecords.
  ///
  /// In en, this message translates to:
  /// **'Fetch records from other hospitals'**
  String get fetchRecords;

  /// No description provided for @fetchRecordsSub.
  ///
  /// In en, this message translates to:
  /// **'Via ABDM, with your consent'**
  String get fetchRecordsSub;

  /// No description provided for @fetchRecordsIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask hospitals linked to your ABHA to share your records. You approve the request in your ABHA app.'**
  String get fetchRecordsIntro;

  /// No description provided for @recordTypesToFetch.
  ///
  /// In en, this message translates to:
  /// **'Record types'**
  String get recordTypesToFetch;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get hiPrescription;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Diagnostic reports'**
  String get hiDiagnosticReport;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Discharge summaries'**
  String get hiDischargeSummary;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'OP consultations'**
  String get hiOpConsultation;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// No description provided for @abdmConsentExplain.
  ///
  /// In en, this message translates to:
  /// **'Records are used only for your care (purpose CAREMGT). You can see every request below.'**
  String get abdmConsentExplain;

  /// No description provided for @sendConsentRequest.
  ///
  /// In en, this message translates to:
  /// **'Send consent request'**
  String get sendConsentRequest;

  /// No description provided for @abdmRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. Approve it in your ABHA app.'**
  String get abdmRequestSent;

  /// No description provided for @myConsentRequests.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get myConsentRequests;

  /// No description provided for @noConsentRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get noConsentRequests;

  /// No description provided for @abdmRequested.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get abdmRequested;

  /// No description provided for @abdmGranted.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get abdmGranted;

  /// No description provided for @abdmDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get abdmDenied;

  /// No description provided for @abdmExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get abdmExpired;

  /// No description provided for @abdmDataReceived.
  ///
  /// In en, this message translates to:
  /// **'Records received'**
  String get abdmDataReceived;

  /// No description provided for @recordsImported.
  ///
  /// In en, this message translates to:
  /// **'{count} records imported'**
  String recordsImported(int count);

  /// No description provided for @importedViaAbdm.
  ///
  /// In en, this message translates to:
  /// **'Imported via ABDM'**
  String get importedViaAbdm;

  /// No description provided for @insurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insurance;

  /// No description provided for @insuranceSub.
  ///
  /// In en, this message translates to:
  /// **'Policies, cashless hospitals, claims'**
  String get insuranceSub;

  /// No description provided for @addPolicy.
  ///
  /// In en, this message translates to:
  /// **'Add policy'**
  String get addPolicy;

  /// No description provided for @editPolicy.
  ///
  /// In en, this message translates to:
  /// **'Edit policy'**
  String get editPolicy;

  /// No description provided for @deletePolicy.
  ///
  /// In en, this message translates to:
  /// **'Remove policy'**
  String get deletePolicy;

  /// No description provided for @deletePolicyBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this policy from your profile?'**
  String get deletePolicyBody;

  /// No description provided for @noPolicies.
  ///
  /// In en, this message translates to:
  /// **'No insurance policies'**
  String get noPolicies;

  /// No description provided for @noPoliciesBody.
  ///
  /// In en, this message translates to:
  /// **'Add your health insurance to find cashless hospitals and get renewal reminders.'**
  String get noPoliciesBody;

  /// No description provided for @expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiringSoon;

  /// No description provided for @sumInsuredValue.
  ///
  /// In en, this message translates to:
  /// **'Cover {amount}'**
  String sumInsuredValue(String amount);

  /// No description provided for @findCashlessHospitals.
  ///
  /// In en, this message translates to:
  /// **'Find cashless hospitals'**
  String get findCashlessHospitals;

  /// No description provided for @cashlessHospitals.
  ///
  /// In en, this message translates to:
  /// **'Cashless hospitals'**
  String get cashlessHospitals;

  /// No description provided for @noCashlessHospitals.
  ///
  /// In en, this message translates to:
  /// **'No cashless hospitals listed for this insurer'**
  String get noCashlessHospitals;

  /// No description provided for @cashlessIntro.
  ///
  /// In en, this message translates to:
  /// **'Hospitals with a cashless tie-up with {insurer}.'**
  String cashlessIntro(String insurer);

  /// No description provided for @cashlessVerifyNote.
  ///
  /// In en, this message translates to:
  /// **'Always confirm cashless eligibility with your insurer or TPA before admission.'**
  String get cashlessVerifyNote;

  /// No description provided for @claimHelp.
  ///
  /// In en, this message translates to:
  /// **'Claims'**
  String get claimHelp;

  /// No description provided for @claimChecklist.
  ///
  /// In en, this message translates to:
  /// **'Claim checklist'**
  String get claimChecklist;

  /// No description provided for @claimChecklistSub.
  ///
  /// In en, this message translates to:
  /// **'Steps and documents for cashless and reimbursement'**
  String get claimChecklistSub;

  /// No description provided for @cashless.
  ///
  /// In en, this message translates to:
  /// **'Cashless'**
  String get cashless;

  /// No description provided for @reimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get reimbursement;

  /// No description provided for @claimSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get claimSteps;

  /// No description provided for @insurer.
  ///
  /// In en, this message translates to:
  /// **'Insurer'**
  String get insurer;

  /// No description provided for @policyNumber.
  ///
  /// In en, this message translates to:
  /// **'Policy number'**
  String get policyNumber;

  /// No description provided for @policyNumberKeep.
  ///
  /// In en, this message translates to:
  /// **'Saved: {masked}. Leave empty to keep it.'**
  String policyNumberKeep(String masked);

  /// No description provided for @planNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Plan name (optional)'**
  String get planNameOptional;

  /// No description provided for @policyType.
  ///
  /// In en, this message translates to:
  /// **'Policy type'**
  String get policyType;

  /// No description provided for @policyIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get policyIndividual;

  /// No description provided for @policyFamilyFloater.
  ///
  /// In en, this message translates to:
  /// **'Family floater'**
  String get policyFamilyFloater;

  /// No description provided for @policyCorporate.
  ///
  /// In en, this message translates to:
  /// **'Corporate'**
  String get policyCorporate;

  /// No description provided for @policyGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government scheme'**
  String get policyGovernment;

  /// No description provided for @sumInsuredOptional.
  ///
  /// In en, this message translates to:
  /// **'Sum insured (optional)'**
  String get sumInsuredOptional;

  /// No description provided for @validFrom.
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get validFrom;

  /// No description provided for @validTo.
  ///
  /// In en, this message translates to:
  /// **'Valid to'**
  String get validTo;

  /// No description provided for @tpaOptional.
  ///
  /// In en, this message translates to:
  /// **'TPA name (optional)'**
  String get tpaOptional;

  /// No description provided for @uploadCardPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add insurance card photo'**
  String get uploadCardPhoto;

  /// No description provided for @cardPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Card photo added'**
  String get cardPhotoAdded;

  /// No description provided for @insuranceCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Insurance card'**
  String get insuranceCardTitle;

  /// No description provided for @policyDatesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose valid from and valid to dates (end after start)'**
  String get policyDatesInvalid;

  /// No description provided for @policyPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Policy numbers are stored encrypted and shown masked.'**
  String get policyPrivacyNote;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Preventive care'**
  String get preventiveCare;

  /// No description provided for @pvOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get pvOverdue;

  /// No description provided for @pvDue.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get pvDue;

  /// No description provided for @pvUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get pvUpcoming;

  /// No description provided for @pvDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pvDone;

  /// No description provided for @pvNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Not applicable'**
  String get pvNotApplicable;

  /// No description provided for @noPreventiveItems.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get noPreventiveItems;

  /// No description provided for @markAsDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markAsDone;

  /// No description provided for @markedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked as done'**
  String get markedDone;

  /// No description provided for @whenWasItDone.
  ///
  /// In en, this message translates to:
  /// **'When was \"{name}\" done?'**
  String whenWasItDone(String name);

  /// No description provided for @lastDoneOn.
  ///
  /// In en, this message translates to:
  /// **'Last done {date}'**
  String lastDoneOn(String date);

  /// No description provided for @repeatsEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'Repeats every {months} months'**
  String repeatsEveryMonths(int months);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Based on age and sex. Your doctor may advise a different schedule.'**
  String get preventiveNote;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'A sample schedule based on age and sex, pending clinical review. Please confirm with your doctor.'**
  String get preventiveNoteFixture;

  /// No description provided for @exercisePlan.
  ///
  /// In en, this message translates to:
  /// **'Exercise plan'**
  String get exercisePlan;

  /// No description provided for @noExercisePlan.
  ///
  /// In en, this message translates to:
  /// **'No exercise plan yet'**
  String get noExercisePlan;

  /// No description provided for @noExercisePlanBody.
  ///
  /// In en, this message translates to:
  /// **'A doctor or physiotherapist can create one for you.'**
  String get noExercisePlanBody;

  /// No description provided for @bookPhysioVisit.
  ///
  /// In en, this message translates to:
  /// **'Book a physiotherapy home visit'**
  String get bookPhysioVisit;

  /// No description provided for @bookPhysioVisitSub.
  ///
  /// In en, this message translates to:
  /// **'A physiotherapist visits your home'**
  String get bookPhysioVisitSub;

  /// No description provided for @todaysExercises.
  ///
  /// In en, this message translates to:
  /// **'Today\'s exercises'**
  String get todaysExercises;

  /// No description provided for @setsReps.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets × {reps} reps'**
  String setsReps(int sets, int reps);

  /// No description provided for @holdSeconds.
  ///
  /// In en, this message translates to:
  /// **'Hold {seconds} s'**
  String holdSeconds(int seconds);

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get startTimer;

  /// No description provided for @precautions.
  ///
  /// In en, this message translates to:
  /// **'Precautions'**
  String get precautions;

  /// No description provided for @markExerciseDone.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as done'**
  String markExerciseDone(String name);

  /// No description provided for @finishSession.
  ///
  /// In en, this message translates to:
  /// **'Finish session ({done}/{total})'**
  String finishSession(int done, int total);

  /// No description provided for @sessionsDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {planned} sessions done'**
  String sessionsDone(int done, int planned);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Pain after sessions'**
  String get painTrend;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Pain score trend, latest {score} out of 10'**
  String painTrendSemantic(int score);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'How is your pain now?'**
  String get howIsYourPain;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Pain {score} / 10'**
  String painScoreValue(int score);

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'No pain'**
  String get noPain;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Worst pain'**
  String get worstPain;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'High pain: your therapist will be told. Stop exercising and rest.'**
  String get highPainNote;

  /// No description provided for @sessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Session saved. Well done!'**
  String get sessionSaved;

  /// No description provided for @sessionSavedHighPain.
  ///
  /// In en, this message translates to:
  /// **'Session saved. Your therapist has been told about the pain.'**
  String get sessionSavedHighPain;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Stop if you feel sharp pain, dizziness or breathlessness. Call 108 in an emergency.'**
  String get exerciseSafetyNote;

  /// No description provided for @dietPlan.
  ///
  /// In en, this message translates to:
  /// **'Diet plan'**
  String get dietPlan;

  /// No description provided for @noDietPlan.
  ///
  /// In en, this message translates to:
  /// **'No diet plan yet'**
  String get noDietPlan;

  /// No description provided for @noDietPlanBody.
  ///
  /// In en, this message translates to:
  /// **'A doctor or dietitian can create one for you.'**
  String get noDietPlanBody;

  /// No description provided for @calorieTarget.
  ///
  /// In en, this message translates to:
  /// **'Target {kcal} kcal a day'**
  String calorieTarget(int kcal);

  /// No description provided for @adherence14d.
  ///
  /// In en, this message translates to:
  /// **'Followed (14 days)'**
  String get adherence14d;

  /// No description provided for @dietAdherenceSemantic.
  ///
  /// In en, this message translates to:
  /// **'Diet followed {pct} percent over 14 days'**
  String dietAdherenceSemantic(int pct);

  /// No description provided for @todaysMeals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals'**
  String get todaysMeals;

  /// No description provided for @followed.
  ///
  /// In en, this message translates to:
  /// **'Followed'**
  String get followed;

  /// No description provided for @notFollowed.
  ///
  /// In en, this message translates to:
  /// **'Not followed'**
  String get notFollowed;

  /// No description provided for @foodsToAvoid.
  ///
  /// In en, this message translates to:
  /// **'Foods to avoid'**
  String get foodsToAvoid;

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

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Follow your doctor or dietitian if their advice differs. Tell them about any new symptoms.'**
  String get dietDisclaimer;

  /// No description provided for @bookPrivateAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Book private ambulance'**
  String get bookPrivateAmbulance;

  /// No description provided for @bookPrivateAmbulanceSub.
  ///
  /// In en, this message translates to:
  /// **'Track the vehicle live. Call 108 first in an emergency.'**
  String get bookPrivateAmbulanceSub;

  /// No description provided for @privateAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Private ambulance'**
  String get privateAmbulance;

  /// No description provided for @call108First.
  ///
  /// In en, this message translates to:
  /// **'Life-threatening emergency? Call 108 first. A private ambulance does not replace 108.'**
  String get call108First;

  /// No description provided for @ambulanceType.
  ///
  /// In en, this message translates to:
  /// **'Ambulance type'**
  String get ambulanceType;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Basic (BLS)'**
  String get ambBls;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Advanced (ALS)'**
  String get ambAls;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Oxygen, stretcher and trained staff. For stable patients.'**
  String get ambBlsDesc;

  /// Medical term (translations need clinical glossary review)
  ///
  /// In en, this message translates to:
  /// **'Cardiac monitor, advanced life support and a paramedic. For serious conditions.'**
  String get ambAlsDesc;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get pickupLocation;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get locating;

  /// No description provided for @gpsLocation.
  ///
  /// In en, this message translates to:
  /// **'GPS {lat}, {lng}'**
  String gpsLocation(String lat, String lng);

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @pickupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'House, street, landmark (helps the driver)'**
  String get pickupAddressHint;

  /// No description provided for @destinationHospital.
  ///
  /// In en, this message translates to:
  /// **'Destination hospital'**
  String get destinationHospital;

  /// No description provided for @destinationOptional.
  ///
  /// In en, this message translates to:
  /// **'Hospital (optional)'**
  String get destinationOptional;

  /// No description provided for @nearestSuitable.
  ///
  /// In en, this message translates to:
  /// **'Nearest suitable hospital'**
  String get nearestSuitable;

  /// No description provided for @requestAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Request ambulance'**
  String get requestAmbulance;

  /// No description provided for @ambulanceDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'Transport to hospital'**
  String get ambulanceDefaultReason;

  /// No description provided for @ambulanceNote.
  ///
  /// In en, this message translates to:
  /// **'Charges depend on the partner and distance. The care team is alerted too.'**
  String get ambulanceNote;

  /// No description provided for @ambulanceTracking.
  ///
  /// In en, this message translates to:
  /// **'Ambulance'**
  String get ambulanceTracking;

  /// No description provided for @ambSearching.
  ///
  /// In en, this message translates to:
  /// **'Finding an ambulance'**
  String get ambSearching;

  /// No description provided for @ambAssigned.
  ///
  /// In en, this message translates to:
  /// **'Ambulance assigned'**
  String get ambAssigned;

  /// No description provided for @ambEnRoute.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get ambEnRoute;

  /// No description provided for @ambArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get ambArrived;

  /// No description provided for @ambTransporting.
  ///
  /// In en, this message translates to:
  /// **'Going to hospital'**
  String get ambTransporting;

  /// No description provided for @ambCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reached hospital'**
  String get ambCompleted;

  /// No description provided for @ambCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ambCancelled;

  /// No description provided for @ambNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle available'**
  String get ambNoVehicle;

  /// No description provided for @noVehicleBody.
  ///
  /// In en, this message translates to:
  /// **'No private ambulance is available nearby. Call 108 now.'**
  String get noVehicleBody;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @openInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get openInMaps;

  /// No description provided for @openStreetMap.
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap'**
  String get openStreetMap;

  /// No description provided for @locationUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Location updated {time}'**
  String locationUpdatedAt(String time);

  /// No description provided for @statusTimeline.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusTimeline;

  /// No description provided for @cancelAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Cancel ambulance'**
  String get cancelAmbulance;

  /// No description provided for @cancelAmbulanceBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel only if help is no longer needed.'**
  String get cancelAmbulanceBody;

  /// No description provided for @cancelledByUser.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by the family'**
  String get cancelledByUser;

  /// No description provided for @safetyLocation.
  ///
  /// In en, this message translates to:
  /// **'Safety & location'**
  String get safetyLocation;

  /// No description provided for @safetyLocationSub.
  ///
  /// In en, this message translates to:
  /// **'Safe zone, companion mode, SOS button'**
  String get safetyLocationSub;

  /// No description provided for @safetyIntro.
  ///
  /// In en, this message translates to:
  /// **'For people who may wander or get confused, such as with memory problems.'**
  String get safetyIntro;

  /// No description provided for @safeZone.
  ///
  /// In en, this message translates to:
  /// **'Safe zone'**
  String get safeZone;

  /// No description provided for @safeZoneSub.
  ///
  /// In en, this message translates to:
  /// **'Get an alert if {name} leaves the area'**
  String safeZoneSub(String name);

  /// No description provided for @safeZoneSelfSub.
  ///
  /// In en, this message translates to:
  /// **'Set up by family with care permission'**
  String get safeZoneSelfSub;

  /// No description provided for @safeZoneIntro.
  ///
  /// In en, this message translates to:
  /// **'If {name} leaves this area while companion mode is on, family get an alert with a map link.'**
  String safeZoneIntro(String name);

  /// No description provided for @safeZoneAlerts.
  ///
  /// In en, this message translates to:
  /// **'Safe zone alerts'**
  String get safeZoneAlerts;

  /// No description provided for @safeZoneAlertsSub.
  ///
  /// In en, this message translates to:
  /// **'Alert family when outside the zone'**
  String get safeZoneAlertsSub;

  /// No description provided for @zoneCentre.
  ///
  /// In en, this message translates to:
  /// **'Centre (home)'**
  String get zoneCentre;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @zoneLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Label (e.g. Home)'**
  String get zoneLabelHint;

  /// No description provided for @radius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get radius;

  /// No description provided for @metersValue.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String metersValue(int meters);

  /// No description provided for @activeHoursOnly.
  ///
  /// In en, this message translates to:
  /// **'Only during set hours'**
  String get activeHoursOnly;

  /// No description provided for @alwaysActive.
  ///
  /// In en, this message translates to:
  /// **'Always active'**
  String get alwaysActive;

  /// No description provided for @safeZoneNeedsCenter.
  ///
  /// In en, this message translates to:
  /// **'Set the centre first (use current location)'**
  String get safeZoneNeedsCenter;

  /// No description provided for @safeZoneRadiusInvalid.
  ///
  /// In en, this message translates to:
  /// **'Radius must be between 100 m and 5 km'**
  String get safeZoneRadiusInvalid;

  /// No description provided for @safeZonePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only the latest location is kept; there is no location history.'**
  String get safeZonePrivacy;

  /// No description provided for @lastKnownLocation.
  ///
  /// In en, this message translates to:
  /// **'Last known location'**
  String get lastKnownLocation;

  /// No description provided for @noLocationYet.
  ///
  /// In en, this message translates to:
  /// **'No location shared yet. Turn on companion mode on their phone.'**
  String get noLocationYet;

  /// No description provided for @insideSafeZone.
  ///
  /// In en, this message translates to:
  /// **'Inside the safe zone'**
  String get insideSafeZone;

  /// No description provided for @outsideSafeZone.
  ///
  /// In en, this message translates to:
  /// **'Outside the safe zone'**
  String get outsideSafeZone;

  /// No description provided for @companionMode.
  ///
  /// In en, this message translates to:
  /// **'Companion mode'**
  String get companionMode;

  /// No description provided for @companionModeSub.
  ///
  /// In en, this message translates to:
  /// **'Share this phone\'s location with family'**
  String get companionModeSub;

  /// No description provided for @companionIntro.
  ///
  /// In en, this message translates to:
  /// **'While CareCompanion is open, this phone shares its location every 5 minutes so family can check you are safe.'**
  String get companionIntro;

  /// No description provided for @companionOn.
  ///
  /// In en, this message translates to:
  /// **'On: sharing location while the app is open'**
  String get companionOn;

  /// No description provided for @companionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get companionOff;

  /// No description provided for @companionOwnDevice.
  ///
  /// In en, this message translates to:
  /// **'Companion mode is turned on from the phone of the person being cared for.'**
  String get companionOwnDevice;

  /// No description provided for @companionForegroundOnly.
  ///
  /// In en, this message translates to:
  /// **'Works only while the app is open on screen; it does not track in the background.'**
  String get companionForegroundOnly;

  /// No description provided for @withdrawConsent.
  ///
  /// In en, this message translates to:
  /// **'Withdraw consent'**
  String get withdrawConsent;

  /// No description provided for @companionConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your location?'**
  String get companionConsentTitle;

  /// No description provided for @companionConsent1.
  ///
  /// In en, this message translates to:
  /// **'Your location is sent every 5 minutes while the app is open.'**
  String get companionConsent1;

  /// No description provided for @companionConsent2.
  ///
  /// In en, this message translates to:
  /// **'Family with alert permission and your care coordinator can see your latest location.'**
  String get companionConsent2;

  /// No description provided for @companionConsent3.
  ///
  /// In en, this message translates to:
  /// **'Only the latest location is stored. No history is kept.'**
  String get companionConsent3;

  /// No description provided for @companionConsent4.
  ///
  /// In en, this message translates to:
  /// **'You can turn it off or withdraw consent at any time.'**
  String get companionConsent4;

  /// No description provided for @companionConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I understand and agree to share my location'**
  String get companionConsentAgree;

  /// No description provided for @agreeAndTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Agree and turn on'**
  String get agreeAndTurnOn;

  /// No description provided for @sosButtonPairing.
  ///
  /// In en, this message translates to:
  /// **'SOS button'**
  String get sosButtonPairing;

  /// No description provided for @sosButtonPairingSub.
  ///
  /// In en, this message translates to:
  /// **'Pair a wearable emergency button'**
  String get sosButtonPairingSub;

  /// No description provided for @sosButtonIntro.
  ///
  /// In en, this message translates to:
  /// **'Pressing a paired SOS button alerts emergency contacts, the same as SOS in the app.'**
  String get sosButtonIntro;

  /// No description provided for @deviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceId;

  /// No description provided for @deviceIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Printed on the back of the button or its box'**
  String get deviceIdHelp;

  /// No description provided for @deviceModelOptional.
  ///
  /// In en, this message translates to:
  /// **'Model (optional)'**
  String get deviceModelOptional;

  /// No description provided for @pairDevice.
  ///
  /// In en, this message translates to:
  /// **'Pair button'**
  String get pairDevice;

  /// No description provided for @pairedDevices.
  ///
  /// In en, this message translates to:
  /// **'Paired on this phone'**
  String get pairedDevices;

  /// No description provided for @noPairedDevices.
  ///
  /// In en, this message translates to:
  /// **'No buttons paired from this phone'**
  String get noPairedDevices;

  /// No description provided for @sosButtonPaired.
  ///
  /// In en, this message translates to:
  /// **'SOS button paired'**
  String get sosButtonPaired;

  /// No description provided for @unpair.
  ///
  /// In en, this message translates to:
  /// **'Unpair'**
  String get unpair;

  /// No description provided for @sosButtonNote.
  ///
  /// In en, this message translates to:
  /// **'A supportive device, not a replacement for 108.'**
  String get sosButtonNote;

  /// No description provided for @haveCompanyCode.
  ///
  /// In en, this message translates to:
  /// **'Have a company code?'**
  String get haveCompanyCode;

  /// No description provided for @companyCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'If your employer sponsors CareCompanion, enter the code they gave you.'**
  String get companyCodeHelp;

  /// No description provided for @companyCode.
  ///
  /// In en, this message translates to:
  /// **'Company code'**
  String get companyCode;

  /// No description provided for @companyCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the full code'**
  String get companyCodeInvalid;

  /// No description provided for @companyPlanActivated.
  ///
  /// In en, this message translates to:
  /// **'Plan activated, sponsored by {name}'**
  String companyPlanActivated(String name);

  /// No description provided for @sponsoredBy.
  ///
  /// In en, this message translates to:
  /// **'Sponsored by {name}'**
  String sponsoredBy(String name);

  /// No description provided for @offersAndWallet.
  ///
  /// In en, this message translates to:
  /// **'Offers & wallet'**
  String get offersAndWallet;

  /// No description provided for @couponCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get couponCode;

  /// No description provided for @couponApplied.
  ///
  /// In en, this message translates to:
  /// **'{code} applied'**
  String couponApplied(String code);

  /// No description provided for @couponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get couponDiscount;

  /// No description provided for @useWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Use wallet balance'**
  String get useWalletBalance;

  /// No description provided for @walletAvailable.
  ///
  /// In en, this message translates to:
  /// **'{amount} available'**
  String walletAvailable(String amount);

  /// No description provided for @walletUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletUsedLabel;

  /// No description provided for @payableAmount.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get payableAmount;

  /// No description provided for @fullyCoveredNote.
  ///
  /// In en, this message translates to:
  /// **'Fully covered: no payment needed.'**
  String get fullyCoveredNote;

  /// No description provided for @checkoutSummarySemantic.
  ///
  /// In en, this message translates to:
  /// **'Subtotal {subtotal}, discount {discount}, wallet {wallet}, to pay {payable}'**
  String checkoutSummarySemantic(
    String subtotal,
    String discount,
    String wallet,
    String payable,
  );

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @walletSub.
  ///
  /// In en, this message translates to:
  /// **'Balance and rewards'**
  String get walletSub;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance'**
  String get walletBalance;

  /// No description provided for @walletBalanceSemantic.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance {amount}'**
  String walletBalanceSemantic(String amount);

  /// No description provided for @walletNote.
  ///
  /// In en, this message translates to:
  /// **'Wallet credit can be used on bookings. It cannot be withdrawn and expires after 365 days.'**
  String get walletNote;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// No description provided for @inviteFamilyFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite family & friends'**
  String get inviteFamilyFriends;

  /// No description provided for @inviteRewardSub.
  ///
  /// In en, this message translates to:
  /// **'You both get wallet credit after their first paid service'**
  String get inviteRewardSub;

  /// No description provided for @inviteIntro.
  ///
  /// In en, this message translates to:
  /// **'Share your code. When they complete their first paid service, you both get wallet credit.'**
  String get inviteIntro;

  /// No description provided for @yourInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get yourInviteCode;

  /// No description provided for @shareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get shareInvite;

  /// No description provided for @friendsInvited.
  ///
  /// In en, this message translates to:
  /// **'Joined with your code'**
  String get friendsInvited;

  /// No description provided for @rewardsEarned.
  ///
  /// In en, this message translates to:
  /// **'Rewards earned'**
  String get rewardsEarned;

  /// No description provided for @haveInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code?'**
  String get haveInviteCode;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @inviteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code does not look right'**
  String get inviteCodeInvalid;

  /// No description provided for @inviteRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Invite code applied. Your reward arrives after your first paid service.'**
  String get inviteRedeemed;

  /// No description provided for @inviteTerms.
  ///
  /// In en, this message translates to:
  /// **'Codes can be used once, within 7 days of signing up.'**
  String get inviteTerms;

  /// No description provided for @onboardingInviteBody.
  ///
  /// In en, this message translates to:
  /// **'Were you invited by family or a friend? Enter their code to get a welcome reward. You can skip this.'**
  String get onboardingInviteBody;

  /// No description provided for @purposeLabOrder.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get purposeLabOrder;

  /// No description provided for @purposeSecondOpinion.
  ///
  /// In en, this message translates to:
  /// **'Second opinion'**
  String get purposeSecondOpinion;

  /// No description provided for @purposeAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Ambulance'**
  String get purposeAmbulance;

  /// No description provided for @myTickets.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get myTickets;

  /// No description provided for @myTicketsSub.
  ///
  /// In en, this message translates to:
  /// **'Questions about bookings, payments or the app'**
  String get myTicketsSub;

  /// No description provided for @newTicket.
  ///
  /// In en, this message translates to:
  /// **'New ticket'**
  String get newTicket;

  /// No description provided for @noTickets.
  ///
  /// In en, this message translates to:
  /// **'No tickets'**
  String get noTickets;

  /// No description provided for @noTicketsBody.
  ///
  /// In en, this message translates to:
  /// **'Raise a ticket and our support team will reply here.'**
  String get noTicketsBody;

  /// No description provided for @ticketCategory.
  ///
  /// In en, this message translates to:
  /// **'What is it about?'**
  String get ticketCategory;

  /// No description provided for @tcBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get tcBooking;

  /// No description provided for @tcPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get tcPayment;

  /// No description provided for @tcRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get tcRefund;

  /// No description provided for @tcAppIssue.
  ///
  /// In en, this message translates to:
  /// **'App issue'**
  String get tcAppIssue;

  /// No description provided for @tcClinicalConcern.
  ///
  /// In en, this message translates to:
  /// **'Health concern'**
  String get tcClinicalConcern;

  /// No description provided for @tcOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get tcOther;

  /// No description provided for @clinicalConcernTitle.
  ///
  /// In en, this message translates to:
  /// **'Our care team will review this'**
  String get clinicalConcernTitle;

  /// No description provided for @clinicalConcernBody.
  ///
  /// In en, this message translates to:
  /// **'Health concerns go to a clinician, not only to support. If it is urgent or someone is very unwell, call 108 now.'**
  String get clinicalConcernBody;

  /// No description provided for @describeIssue.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue'**
  String get describeIssue;

  /// No description provided for @linkBooking.
  ///
  /// In en, this message translates to:
  /// **'Link a booking (optional)'**
  String get linkBooking;

  /// No description provided for @noBookingsToLink.
  ///
  /// In en, this message translates to:
  /// **'No recent bookings'**
  String get noBookingsToLink;

  /// No description provided for @submitTicket.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitTicket;

  /// No description provided for @ticketCreated.
  ///
  /// In en, this message translates to:
  /// **'Ticket {number} created'**
  String ticketCreated(String number);

  /// No description provided for @supportNotForEmergencies.
  ///
  /// In en, this message translates to:
  /// **'Support is not for emergencies. Call 108 in an emergency.'**
  String get supportNotForEmergencies;

  /// No description provided for @supportTicket.
  ///
  /// In en, this message translates to:
  /// **'Support ticket'**
  String get supportTicket;

  /// No description provided for @tsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get tsOpen;

  /// No description provided for @tsPendingCustomer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get tsPendingCustomer;

  /// No description provided for @tsResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get tsResolved;

  /// No description provided for @tsClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get tsClosed;

  /// No description provided for @handledBy.
  ///
  /// In en, this message translates to:
  /// **'Handled by {name}'**
  String handledBy(String name);

  /// No description provided for @rateSupport.
  ///
  /// In en, this message translates to:
  /// **'Rate our support'**
  String get rateSupport;

  /// No description provided for @youRated.
  ///
  /// In en, this message translates to:
  /// **'You rated {score} / 5. Thank you!'**
  String youRated(int score);

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);
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
