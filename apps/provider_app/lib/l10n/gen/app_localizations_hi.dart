// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'केयरकम्पैनियन प्रो';

  @override
  String get commonRetry => 'फिर से कोशिश करें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonConfirm => 'पुष्टि करें';

  @override
  String get commonSubmit => 'जमा करें';

  @override
  String get commonLogout => 'लॉग आउट';

  @override
  String get commonRefresh => 'रीफ़्रेश करें';

  @override
  String get commonLoading => 'लोड हो रहा है…';

  @override
  String get commonBack => 'वापस';

  @override
  String get commonNotAvailable => 'उपलब्ध नहीं';

  @override
  String get errorGeneric => 'कुछ गलत हो गया। कृपया फिर से कोशिश करें।';

  @override
  String get errorNetwork =>
      'आप ऑफ़लाइन लगते हैं। कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get errorSessionExpired =>
      'आपका सत्र समाप्त हो गया है। कृपया फिर से लॉग इन करें।';

  @override
  String get loginTitle => 'प्रोवाइडर साइन इन';

  @override
  String get loginSubtitle =>
      'सत्यापित नर्स, तकनीशियन और फ़ील्ड मेडिकल कर्मियों के लिए।';

  @override
  String get loginPhoneLabel => 'मोबाइल नंबर';

  @override
  String get loginPhoneHint => '10 अंकों का मोबाइल नंबर';

  @override
  String get loginPhoneInvalid => 'सही 10 अंकों का मोबाइल नंबर डालें';

  @override
  String get loginSendOtp => 'OTP भेजें';

  @override
  String get loginOtpLabel => '6 अंकों का OTP';

  @override
  String get loginOtpInvalid => '6 अंकों का OTP डालें';

  @override
  String loginOtpSentTo(String phone) {
    return 'OTP $phone पर भेजा गया';
  }

  @override
  String get loginVerify => 'सत्यापित करें और आगे बढ़ें';

  @override
  String get loginChangeNumber => 'नंबर बदलें';

  @override
  String loginDevOtpHint(String otp) {
    return 'डेवलपमेंट OTP: $otp';
  }

  @override
  String get restrictedTitle =>
      'पहुँच केवल सत्यापित केयर प्रोवाइडर्स के लिए है';

  @override
  String get restrictedBody =>
      'यह ऐप केवल केयरकम्पैनियन में पंजीकृत होम-केयर प्रोवाइडर्स के लिए है। यदि आप मरीज़ या परिवार के सदस्य हैं, तो कृपया केयरकम्पैनियन पेशेंट ऐप का उपयोग करें।';

  @override
  String get blockedTitle => 'अभी आपको विज़िट नहीं मिल सकतीं';

  @override
  String get blockedNoVisits =>
      'जब तक आपका सत्यापन सक्रिय नहीं होता, आपको कोई होम विज़िट नहीं दी जा सकती।';

  @override
  String get blockedPending =>
      'आपका पेशेवर सत्यापन केयरकम्पैनियन ऑपरेशंस टीम द्वारा समीक्षा में है।';

  @override
  String get blockedExpired =>
      'आपका पेशेवर प्रमाणपत्र समाप्त हो गया है। कृपया इसे नवीनीकृत करें और अपने कोऑर्डिनेटर को नया दस्तावेज़ दें।';

  @override
  String blockedExpiredOn(String date) {
    return 'प्रमाणपत्र $date को समाप्त हुआ।';
  }

  @override
  String get blockedSuspended =>
      'आपका प्रोवाइडर खाता निलंबित कर दिया गया है। विवरण के लिए अपने केयर कोऑर्डिनेटर से संपर्क करें।';

  @override
  String get blockedRejected =>
      'आपका सत्यापन स्वीकृत नहीं हुआ। कृपया अपने केयर कोऑर्डिनेटर से संपर्क करें।';

  @override
  String get blockedCheckAgain => 'स्थिति फिर से जाँचें';

  @override
  String homeGreeting(String name) {
    return 'नमस्ते, $name';
  }

  @override
  String get homeDutyOn => 'ड्यूटी पर';

  @override
  String get homeDutyOff => 'ड्यूटी से बाहर';

  @override
  String get homeDutyOnHint => 'आपको नई होम विज़िट मिल सकती हैं।';

  @override
  String get homeDutyOffHint => 'नई होम विज़िट पाने के लिए ड्यूटी पर आएँ।';

  @override
  String get homeDutyToggleLabel => 'ड्यूटी स्थिति';

  @override
  String get homeDutyFailed =>
      'ड्यूटी स्थिति अपडेट नहीं हो सकी। आपको ऑनलाइन होना होगा।';

  @override
  String get homeTodaySummary => 'आज';

  @override
  String get homeSummaryTotal => 'विज़िट';

  @override
  String get homeSummaryActive => 'सक्रिय';

  @override
  String get homeSummaryDone => 'पूर्ण';

  @override
  String homeNextVisit(String time) {
    return 'अगली: $time';
  }

  @override
  String get tabToday => 'आज';

  @override
  String get tabUpcoming => 'आगामी';

  @override
  String get tabCompleted => 'पूर्ण';

  @override
  String get visitsEmptyToday => 'आज कोई विज़िट नहीं है।';

  @override
  String get visitsEmptyUpcoming => 'कोई आगामी विज़िट नहीं है।';

  @override
  String get visitsEmptyCompleted => 'अभी तक कोई पूर्ण विज़िट नहीं।';

  @override
  String get visitsShowingCached => 'ऑफ़लाइन – सहेजा गया डेटा दिखाया जा रहा है';

  @override
  String get profileTooltip => 'प्रोफ़ाइल';

  @override
  String get offlineBanner =>
      'आप ऑफ़लाइन हैं। कार्य सहेजे जाएँगे और बाद में सिंक होंगे।';

  @override
  String pendingSync(int count) {
    return 'सिंक बाकी ($count)';
  }

  @override
  String get syncNow => 'अभी सिंक करें';

  @override
  String get syncAccessRevoked =>
      'एक विज़िट अब आपको सौंपी नहीं गई है। उसके बिना सिंक हुए बदलाव हटा दिए गए और सहेजा गया मरीज़ डेटा मिटा दिया गया।';

  @override
  String syncRejected(String message) {
    return 'सर्वर ने एक सहेजा गया कार्य स्वीकार नहीं किया: $message';
  }

  @override
  String get actionQueued => 'ऑफ़लाइन सहेजा गया। ऑनलाइन होने पर सिंक होगा।';

  @override
  String get actionDone => 'अपडेट हो गया';

  @override
  String get statusRequested => 'अनुरोधित';

  @override
  String get statusUnassigned => 'असाइन नहीं';

  @override
  String get statusAssigned => 'नई असाइनमेंट';

  @override
  String get statusAccepted => 'स्वीकृत';

  @override
  String get statusEnRoute => 'रास्ते में';

  @override
  String get statusArrived => 'पहुँच गए';

  @override
  String get statusInProgress => 'जारी';

  @override
  String get statusCompleted => 'पूर्ण';

  @override
  String get statusCancelled => 'रद्द';

  @override
  String get statusEscalated => 'एस्केलेट किया गया';

  @override
  String get visitTitle => 'होम विज़िट';

  @override
  String get visitTimeWindow => 'समय';

  @override
  String get visitReason => 'विज़िट का कारण';

  @override
  String get visitAddress => 'पता';

  @override
  String visitAreaOnly(String city, String pincode) {
    return '$city – $pincode';
  }

  @override
  String get visitAddressHidden =>
      'विज़िट स्वीकार करने के बाद पूरा पता दिखेगा।';

  @override
  String visitLandmark(String landmark) {
    return 'लैंडमार्क: $landmark';
  }

  @override
  String get visitNavigate => 'नेविगेट करें';

  @override
  String get visitNavigateFailed => 'मैप नहीं खुल सका।';

  @override
  String get visitPatient => 'मरीज़';

  @override
  String get visitPatientContext => 'मरीज़ की जानकारी';

  @override
  String visitAgeGender(String age, String gender) {
    return '$age वर्ष · $gender';
  }

  @override
  String get visitAllergies => 'एलर्जी';

  @override
  String get visitNoAllergiesRecorded => 'कोई एलर्जी दर्ज नहीं';

  @override
  String get visitConditions => 'स्वास्थ्य स्थितियाँ';

  @override
  String get visitMedications => 'चल रही दवाएँ';

  @override
  String get visitNoneRecorded => 'कुछ दर्ज नहीं';

  @override
  String get visitContextUnavailable =>
      'इस विज़िट के लिए मरीज़ की जानकारी उपलब्ध नहीं है।';

  @override
  String get visitTimeline => 'स्थिति टाइमलाइन';

  @override
  String get visitPendingSyncChip => 'सिंक बाकी';

  @override
  String visitEta(int minutes) {
    return 'ETA $minutes मिनट';
  }

  @override
  String get visitNotFound => 'यह विज़िट अब आपके लिए उपलब्ध नहीं है।';

  @override
  String get visitRecordedVitals => 'दर्ज वाइटल्स';

  @override
  String get visitSummary => 'विज़िट सारांश';

  @override
  String get visitEscalation => 'एस्केलेशन';

  @override
  String get stepAccept => 'स्वीकार';

  @override
  String get stepTravel => 'यात्रा';

  @override
  String get stepArrive => 'पहुँचें';

  @override
  String get stepVerify => 'सत्यापन';

  @override
  String get stepCare => 'जाँच';

  @override
  String get stepComplete => 'पूर्ण';

  @override
  String stepperLabel(int current, int total) {
    return 'विज़िट प्रगति: चरण $current / $total';
  }

  @override
  String get actionAccept => 'विज़िट स्वीकार करें';

  @override
  String get actionReject => 'अस्वीकार करें';

  @override
  String get actionRejectTitle => 'यह विज़िट अस्वीकार करें?';

  @override
  String get actionRejectReason => 'कारण';

  @override
  String get actionRejectReasonRequired => 'कृपया कारण बताएँ';

  @override
  String get actionStartTravel => 'यात्रा शुरू करें';

  @override
  String get actionEtaLabel => 'अनुमानित पहुँचने का समय (मिनट)';

  @override
  String get actionEtaInvalid => '1 से 240 के बीच मिनट डालें';

  @override
  String get actionArrived => 'मैं पहुँच गया/गई';

  @override
  String get actionVerifyTitle => 'मरीज़ का सत्यापन';

  @override
  String get actionVerifyBody =>
      'मरीज़ या अभिभावक से उनके ऐप में दिखाया गया 4 अंकों का विज़िट कोड पढ़ने को कहें।';

  @override
  String get actionVisitCode => 'विज़िट कोड';

  @override
  String get actionVisitCodeInvalid => '4 अंकों का कोड डालें';

  @override
  String get actionConsent => 'मरीज़/अभिभावक जाँच के लिए सहमति देते हैं';

  @override
  String get actionConsentRequired =>
      'शुरू करने से पहले सहमति की पुष्टि आवश्यक है';

  @override
  String get actionVerify => 'सत्यापित करें और जाँच शुरू करें';

  @override
  String get actionVerifyOfflineNote =>
      'आप ऑफ़लाइन हैं। दोबारा कनेक्ट होने पर कोड जाँचा जाएगा।';

  @override
  String get actionComplete => 'विज़िट पूरी करें';

  @override
  String get actionCompleteTitle => 'विज़िट पूरी करें';

  @override
  String get actionSummaryLabel => 'विज़िट सारांश';

  @override
  String get actionSummaryHint =>
      'क्या किया गया, मरीज़ को बताई गई बातें, कोई फ़ॉलो-अप';

  @override
  String get actionSummaryRequired => 'कृपया छोटा सारांश लिखें';

  @override
  String get nextAwaitingAssignment => 'असाइनमेंट की प्रतीक्षा है।';

  @override
  String get nextNoAction => 'आगे कोई कार्य आवश्यक नहीं।';

  @override
  String get nextCancelled => 'यह विज़िट रद्द कर दी गई।';

  @override
  String get nextReassigned => 'यह विज़िट अब आपको सौंपी नहीं गई है।';

  @override
  String get nextVerifyIntro =>
      'शुरू करने से पहले मरीज़ की पहचान और सहमति सत्यापित करें।';

  @override
  String get nextCareIntro =>
      'वाइटल्स और अवलोकन दर्ज करें, फिर विज़िट पूरी करें।';

  @override
  String get nextEscalatedIntro =>
      'यह विज़िट एस्केलेट की गई है। आप इसे अभी भी पूरा कर सकते हैं।';

  @override
  String get escalateButton => 'एस्केलेट करें';

  @override
  String get escalateTitle => 'सुपरवाइज़िंग डॉक्टर को एस्केलेट करें';

  @override
  String get escalateReason => 'चिंता क्या है?';

  @override
  String get escalateReasonRequired => 'कृपया चिंता बताएँ';

  @override
  String get escalateSeverity => 'गंभीरता';

  @override
  String get escalateUrgent => 'अत्यावश्यक';

  @override
  String get escalateEmergency => 'आपातकाल';

  @override
  String get escalateEmergencyHint =>
      'जानलेवा आपात स्थिति में तुरंत 108 पर कॉल करें।';

  @override
  String get escalateCall108 => '108 पर कॉल करें';

  @override
  String get escalateConfirmTitle => 'एस्केलेशन की पुष्टि करें';

  @override
  String escalateConfirmBody(String severity) {
    return 'इससे क्लिनिकल टीम को गंभीरता $severity के साथ तुरंत सूचना जाएगी। जारी रखें?';
  }

  @override
  String get escalateSend => 'एस्केलेशन भेजें';

  @override
  String get vitalsTitle => 'वाइटल्स';

  @override
  String get vitalsSave => 'वाइटल्स सहेजें';

  @override
  String get vitalsSaved => 'वाइटल्स सहेजे गए';

  @override
  String get vitalsBpSystolic => 'BP सिस्टोलिक';

  @override
  String get vitalsBpDiastolic => 'BP डायस्टोलिक';

  @override
  String get vitalsPulse => 'नाड़ी';

  @override
  String get vitalsSpo2 => 'SpO2';

  @override
  String get vitalsTemperature => 'तापमान';

  @override
  String get vitalsBloodGlucose => 'ब्लड ग्लूकोज़';

  @override
  String get vitalsWeight => 'वज़न';

  @override
  String get vitalsRespiratoryRate => 'श्वसन दर';

  @override
  String get vitalsErrorNumber => 'एक संख्या डालें';

  @override
  String vitalsErrorRange(String min, String max) {
    return '$min और $max के बीच होना चाहिए';
  }

  @override
  String get vitalsErrorBpPair => 'सिस्टोलिक और डायस्टोलिक दोनों डालें';

  @override
  String get vitalsErrorBpOrder => 'डायस्टोलिक सिस्टोलिक से कम होना चाहिए';

  @override
  String get vitalsErrorEmpty => 'कम से कम एक वाइटल डालें';

  @override
  String get vitalsNoInterpretation =>
      'मान जैसे मापे गए वैसे ही दर्ज होते हैं। क्लिनिकल समीक्षा केयर टीम करती है।';

  @override
  String get obsTitle => 'अवलोकन';

  @override
  String get obsAlertOriented => 'मरीज़ सजग और सचेत है';

  @override
  String get obsMedicationsReviewed => 'दवाओं की समीक्षा की गई';

  @override
  String get obsMobilityObserved => 'चलने-फिरने का अवलोकन किया गया';

  @override
  String get obsCaregiverPresent => 'देखभालकर्ता उपस्थित';

  @override
  String get obsHomeSafe => 'घर का वातावरण सुरक्षित';

  @override
  String get obsConcernsNoted => 'मरीज़ की चिंताएँ दर्ज की गईं';

  @override
  String get obsNotes => 'नोट्स';

  @override
  String get obsNotesHint => 'केवल तथ्यात्मक अवलोकन';

  @override
  String get obsSave => 'अवलोकन सहेजें';

  @override
  String get obsSaved => 'अवलोकन सहेजे गए';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get profileType => 'भूमिका';

  @override
  String get profileQualification => 'योग्यता';

  @override
  String get profileVerification => 'सत्यापन';

  @override
  String get profileCredentialExpiry => 'प्रमाणपत्र मान्य है';

  @override
  String profileCredentialExpiring(int days) {
    return 'आपका प्रमाणपत्र $days दिनों में समाप्त होगा। विज़िट मिलती रहें, इसके लिए इसे नवीनीकृत करें।';
  }

  @override
  String get profileZones => 'सेवा क्षेत्र';

  @override
  String get profileCapabilities => 'क्षमताएँ';

  @override
  String get profileLanguage => 'भाषा';

  @override
  String get profilePhone => 'फ़ोन';

  @override
  String get profileLogoutConfirm => 'लॉग आउट करें?';

  @override
  String profileLogoutPending(int count) {
    return 'अभी लॉग आउट करने पर $count बिना सिंक हुए कार्य हट जाएँगे।';
  }

  @override
  String get profileLogoutBody =>
      'इस डिवाइस पर सहेजा गया विज़िट डेटा हटा दिया जाएगा।';

  @override
  String get typeNurse => 'नर्स';

  @override
  String get typeTechnician => 'तकनीशियन';

  @override
  String get typeIntern => 'इंटर्न';

  @override
  String get typePhysiotherapist => 'फ़िज़ियोथेरेपिस्ट';

  @override
  String get verificationVerified => 'सत्यापित';

  @override
  String get verificationPending => 'लंबित';

  @override
  String get verificationRejected => 'अस्वीकृत';

  @override
  String get verificationSuspended => 'निलंबित';

  @override
  String get verificationExpired => 'समाप्त';

  @override
  String get genderMale => 'पुरुष';

  @override
  String get genderFemale => 'महिला';

  @override
  String get genderOther => 'अन्य';

  @override
  String get errorMfaRequired =>
      'इस खाते के लिए दो-चरणीय सत्यापन आवश्यक है, जो प्रोवाइडर ऐप में उपलब्ध नहीं है। कृपया सहायता से संपर्क करें।';

  @override
  String get mfaTitle => 'अतिरिक्त सत्यापन आवश्यक';

  @override
  String get mfaBody =>
      'आपके खाते में दो-चरणीय सत्यापन (MFA) आवश्यक है। केयरकम्पैनियन प्रो प्रोवाइडर खातों के लिए इसका समर्थन नहीं करता। कृपया अपने कोऑर्डिनेटर या सहायता टीम से संपर्क करें ताकि वे आपका खाता ठीक कर सकें। आपके कतार में रखे विज़िट अपडेट इस डिवाइस पर सुरक्षित हैं।';

  @override
  String get updateTitle => 'अपडेट आवश्यक';

  @override
  String get updateBody =>
      'केयरकम्पैनियन प्रो का यह संस्करण अब समर्थित नहीं है। विज़िट मिलते रहने के लिए कृपया नवीनतम संस्करण इंस्टॉल करें।';

  @override
  String updateVersions(String current, String minimum) {
    return 'इंस्टॉल $current · आवश्यक $minimum';
  }

  @override
  String get updateNow => 'अभी अपडेट करें';

  @override
  String get photoAdd => 'फ़ोटो जोड़ें';

  @override
  String get photoSectionTitle => 'विज़िट फ़ोटो (वैकल्पिक)';

  @override
  String get photoSectionHint =>
      'केवल तभी जब यह देखभाल में मदद करे (जैसे घाव या उपकरण)। मरीज़ की सहमति आवश्यक है।';

  @override
  String get photoConsentTitle => 'मरीज़ की सहमति';

  @override
  String get photoConsentBody =>
      'फ़ोटो मरीज़ के स्वास्थ्य रिकॉर्ड में सहेजी जाएगी। चेहरे और देखभाल के लिए अनावश्यक चीज़ों से बचें।';

  @override
  String get photoConsent =>
      'मरीज़ (या उनके देखभालकर्ता) ने यह फ़ोटो लेने और उनके रिकॉर्ड में सहेजने की सहमति दी है।';

  @override
  String get photoConsentRequired =>
      'फ़ोटो लेने से पहले मरीज़ की सहमति आवश्यक है।';

  @override
  String get photoOpenCamera => 'कैमरा खोलें';

  @override
  String get photoUploaded => 'फ़ोटो मरीज़ के रिकॉर्ड में अपलोड हो गई।';

  @override
  String get photoQueued => 'फ़ोटो सहेजी गई। ऑनलाइन होने पर अपलोड होगी।';

  @override
  String get photoNoPermission =>
      'आपको इस मरीज़ के रिकॉर्ड में फ़ोटो जोड़ने की अनुमति नहीं है। कृपया अपने कोऑर्डिनेटर से संपर्क करें।';

  @override
  String get photoFileMissing =>
      'कतार में रखी एक फ़ोटो अपलोड नहीं हो सकी क्योंकि वह अब इस डिवाइस पर नहीं है। कृपया फिर से लें।';

  @override
  String get photoCameraFailed => 'कैमरा नहीं खुल सका।';

  @override
  String get profileSupport => 'सहायता';

  @override
  String get profileSupportCall => 'सहायता को कॉल करें';

  @override
  String get profileSupportEmail => 'सहायता को ईमेल करें';

  @override
  String get profileSupportWhatsapp => 'व्हाट्सऐप सहायता';

  @override
  String get profileSupportUnavailable =>
      'सहायता संपर्क अभी उपलब्ध नहीं हैं। कृपया अपने कोऑर्डिनेटर से संपर्क करें।';

  @override
  String get profilePrivacy => 'गोपनीयता नीति';

  @override
  String get profileTerms => 'सेवा की शर्तें';

  @override
  String get profileAccount => 'खाता';

  @override
  String get profileCloseAccount => 'खाता बंद करने का अनुरोध';

  @override
  String get profileCloseAccountBody =>
      'प्रोवाइडर खाते स्टाफ़ खाते हैं और ऐप से हटाए नहीं जा सकते। बंद करने के अनुरोध के लिए सहायता से संपर्क करें: एक व्यवस्थापक आपका खाता निष्क्रिय करेगा और आपके डेटा को रिटेंशन नीति के अनुसार संभालेगा।';

  @override
  String get profileCloseAccountSubject => 'प्रोवाइडर खाता बंद करने का अनुरोध';

  @override
  String get profileLinkFailed => 'लिंक नहीं खुल सका।';

  @override
  String profileAppVersion(String version) {
    return 'संस्करण $version';
  }

  @override
  String get commonDelete => 'हटाएँ';

  @override
  String get typeDoctor => 'डॉक्टर';

  @override
  String get onbTitle => 'केयर प्रोवाइडर के रूप में जुड़ने के लिए आवेदन करें';

  @override
  String get onbIntro =>
      'यह खाता अभी केयर प्रोवाइडर के रूप में पंजीकृत नहीं है। नीचे आवेदन करें: किसी भी विज़िट के असाइन होने से पहले हमारी टीम हर प्रोवाइडर का सत्यापन करती है।';

  @override
  String get onbEditTitle => 'अपना आवेदन संपादित करें';

  @override
  String get onbStepRole => 'भूमिका';

  @override
  String get onbStepDetails => 'योग्यता';

  @override
  String get onbStepAreas => 'भाषाएँ और क्षेत्र';

  @override
  String get onbStepReview => 'समीक्षा';

  @override
  String get onbTypeLabel => 'मैं इस रूप में आवेदन कर रहा/रही हूँ';

  @override
  String get onbDoctorNote =>
      'स्वीकृति के बाद डॉक्टर इस ऐप का नहीं, CareCompanion वेब पोर्टल का उपयोग करते हैं। आप यहाँ फिर भी आवेदन कर सकते हैं।';

  @override
  String get onbFullName => 'पूरा नाम (पंजीकरण के अनुसार)';

  @override
  String get onbQualification => 'योग्यता (जैसे GNM, B.Sc नर्सिंग, DMLT)';

  @override
  String get onbRegNumber => 'पंजीकरण संख्या';

  @override
  String get onbRegCouncil => 'पंजीकरण परिषद (वैकल्पिक)';

  @override
  String get onbSpecialty => 'विशेषज्ञता';

  @override
  String get onbExperience => 'अनुभव (वर्ष)';

  @override
  String get onbRequired => 'आवश्यक';

  @override
  String get onbExperienceInvalid => '0 से 60 के बीच वर्ष दर्ज करें';

  @override
  String get onbLanguages => 'आप कौन-सी भाषाएँ बोलते हैं';

  @override
  String get onbLanguagesRequired => 'कम से कम एक भाषा चुनें';

  @override
  String get onbAreas => 'पसंदीदा कार्य क्षेत्र';

  @override
  String get onbAreasHint =>
      'वे पिनकोड जोड़ें जहाँ आप काम करना चाहते हैं। हर पिनकोड हमारे किसी सेवा क्षेत्र से मिलाया जाता है। वैकल्पिक।';

  @override
  String get onbPincode => 'पिनकोड';

  @override
  String get onbPincodeInvalid => '6 अंकों का पिनकोड दर्ज करें';

  @override
  String get onbAddArea => 'जोड़ें';

  @override
  String get onbZoneSaved => 'सहेजा गया क्षेत्र';

  @override
  String onbAreaNotServiceable(String pincode) {
    return 'हम अभी पिनकोड $pincode में सेवा नहीं देते। आप फिर भी आवेदन कर सकते हैं।';
  }

  @override
  String get onbReviewDocsNote =>
      'सबमिट करने के बाद अपने दस्तावेज़ अपलोड करें। स्वीकृति के लिए पंजीकरण प्रमाणपत्र और पहचान प्रमाण आवश्यक हैं।';

  @override
  String get onbNext => 'आगे';

  @override
  String get onbSubmit => 'आवेदन सबमिट करें';

  @override
  String get onbResubmit => 'आवेदन फिर से सबमिट करें';

  @override
  String get onbSubmitted => 'आवेदन सबमिट हो गया';

  @override
  String get onbCancelEdit => 'संपादन रद्द करें';

  @override
  String get onbStatusSubmittedTitle => 'आवेदन की समीक्षा हो रही है';

  @override
  String get onbStatusSubmittedBody =>
      'हमारी टीम आपके आवेदन की समीक्षा कर रही है। निर्णय होने पर आपको सूचित किया जाएगा।';

  @override
  String get onbStatusChangesTitle => 'बदलाव का अनुरोध किया गया';

  @override
  String get onbStatusChangesBody =>
      'समीक्षक ने बदलाव माँगे हैं। अपना विवरण या दस्तावेज़ अपडेट करें, फिर दोबारा सबमिट करें।';

  @override
  String get onbStatusRejectedTitle => 'आवेदन स्वीकृत नहीं हुआ';

  @override
  String get onbStatusRejectedBody =>
      'आपका आवेदन स्वीकृत नहीं हुआ। कोई प्रश्न हो तो सहायता से संपर्क करें।';

  @override
  String get onbReviewerNote => 'समीक्षक की टिप्पणी';

  @override
  String onbReviewerNoteBy(String name) {
    return '$name की टिप्पणी';
  }

  @override
  String get onbEditResubmit => 'संपादित करें और फिर सबमिट करें';

  @override
  String get onbEditDetails => 'विवरण संपादित करें';

  @override
  String get onbApprovedTitle => 'आप स्वीकृत हो गए हैं';

  @override
  String get onbApprovedBody =>
      'आपका आवेदन स्वीकृत हो गया है। शुरू करने के लिए लॉग आउट करके फिर से साइन इन करें।';

  @override
  String get onbApprovedDoctorBody =>
      'आपका डॉक्टर खाता स्वीकृत हो गया है। अपना शेड्यूल सेट करने के लिए CareCompanion वेब पोर्टल में साइन इन करें।';

  @override
  String get onbSignOutAndIn => 'लॉग आउट करके फिर से साइन इन करें';

  @override
  String get onbCheckStatus => 'स्थिति जाँचें';

  @override
  String onbUpdatedOn(String date) {
    return 'अंतिम अपडेट $date';
  }

  @override
  String get onbDocuments => 'दस्तावेज़';

  @override
  String onbDocsMissing(String docs) {
    return 'अभी आवश्यक: $docs';
  }

  @override
  String get onbDocsComplete => 'सभी आवश्यक दस्तावेज़ अपलोड हो गए हैं।';

  @override
  String get onbDocsHint => 'PDF, JPG या PNG, हर फ़ाइल 10 MB तक।';

  @override
  String get onbNoDocuments => 'अभी कोई दस्तावेज़ अपलोड नहीं हुआ।';

  @override
  String get onbAddDocument => 'दस्तावेज़ जोड़ें';

  @override
  String get onbDocType => 'दस्तावेज़ का प्रकार';

  @override
  String get docRegistrationCertificate => 'पंजीकरण प्रमाणपत्र';

  @override
  String get docDegree => 'डिग्री या डिप्लोमा';

  @override
  String get docIdProof => 'पहचान प्रमाण';

  @override
  String get docExperienceLetter => 'अनुभव पत्र';

  @override
  String get docOther => 'अन्य';

  @override
  String get sourceCamera => 'फ़ोटो लें';

  @override
  String get sourceGallery => 'गैलरी से चुनें';

  @override
  String get sourceFiles => 'फ़ाइल चुनें (PDF, JPG, PNG)';

  @override
  String onbUploading(int percent) {
    return 'अपलोड हो रहा है… $percent%';
  }

  @override
  String onbUploadFailed(String error) {
    return 'अपलोड विफल: $error';
  }

  @override
  String get onbFileTooLarge => 'यह फ़ाइल 10 MB से बड़ी है।';

  @override
  String get onbDeleteDocConfirm => 'यह दस्तावेज़ हटाएँ?';

  @override
  String get earnTitle => 'कमाई';

  @override
  String get earnEntrySubtitle => 'पूरी हुई सेवाएँ और भुगतान';

  @override
  String get earnCompleted => 'पूरी हुई सेवाएँ';

  @override
  String get earnGross => 'कुल राशि';

  @override
  String get earnPlatformFee => 'प्लेटफ़ॉर्म शुल्क';

  @override
  String get earnRefunds => 'रिफ़ंड';

  @override
  String get earnPayable => 'आपको देय';

  @override
  String get earnLines => 'सेवाएँ';

  @override
  String get earnEmpty => 'इस महीने कोई पूरी और भुगतान की गई सेवा नहीं।';

  @override
  String get earnPrevMonth => 'पिछला महीना';

  @override
  String get earnNextMonth => 'अगला महीना';

  @override
  String get earnNote =>
      'केवल पूरी और भुगतान की गई सेवाएँ गिनी जाती हैं। भुगतान ऑपरेशंस टीम द्वारा निपटाया जाता है।';

  @override
  String get earnRefHomeVisit => 'होम विज़िट';

  @override
  String get earnRefAppointment => 'अपॉइंटमेंट';

  @override
  String earnLineDetail(String fee, String payable) {
    return 'शुल्क $fee · देय $payable';
  }

  @override
  String get avatarChange => 'प्रोफ़ाइल फ़ोटो बदलें';

  @override
  String get avatarPreviewTitle => 'यह फ़ोटो उपयोग करें?';

  @override
  String get avatarPreviewBody =>
      'जब आपको किसी मरीज़ की विज़िट असाइन होती है, तो मरीज़ यह फ़ोटो देखते हैं।';

  @override
  String get avatarUse => 'फ़ोटो उपयोग करें';

  @override
  String get avatarUploaded => 'प्रोफ़ाइल फ़ोटो अपडेट हो गई';

  @override
  String get avatarTooLarge => 'फ़ोटो 5 MB से छोटी होनी चाहिए।';

  @override
  String profileRating(String rating, int count) {
    return '$rating ★ ($count रेटिंग)';
  }

  @override
  String get voiceDictate => 'नोट्स बोलकर लिखें';

  @override
  String get voiceStop => 'बोलकर लिखना बंद करें';

  @override
  String get voiceListening => 'सुन रहा है… अब बोलें';

  @override
  String get voiceReview =>
      'बोला गया टेक्स्ट नोट्स में जोड़ दिया गया है। सहेजने से पहले इसकी समीक्षा करें और सुधारें।';

  @override
  String get voiceUnavailable =>
      'इस डिवाइस पर वॉइस इनपुट उपलब्ध नहीं है, या माइक्रोफ़ोन की अनुमति नहीं दी गई।';

  @override
  String get typeDietitian => 'डाइटीशियन';

  @override
  String get tabRoute => 'रूट';

  @override
  String get optionalHint => 'वैकल्पिक';

  @override
  String planFor(String name) {
    return '$name के लिए';
  }

  @override
  String get routeEmpty => 'आज आपके रूट पर कोई स्टॉप नहीं है।';

  @override
  String routeSummary(int count, String km) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count स्टॉप',
      one: '1 स्टॉप',
    );
    return '$_temp0 · कुल $km कि.मी.';
  }

  @override
  String get routeFromLastLocation =>
      'दूरी आपकी पिछली भेजी गई लोकेशन से गिनी गई है।';

  @override
  String get routeFromCurrentLocation =>
      'दूरी आपके सेवा क्षेत्र के केंद्र से गिनी गई है।';

  @override
  String get routeStartNavigation => 'नेविगेशन शुरू करें';

  @override
  String routeTooManyStops(int count) {
    return 'Google Maps पहले $count स्टॉप दिखाता है। उनके बाद नेविगेशन फिर से खोलें।';
  }

  @override
  String routeFromStart(String km) {
    return 'शुरुआत से $km कि.मी.';
  }

  @override
  String routeFromPrev(String km) {
    return 'पिछले स्टॉप से $km कि.मी.';
  }

  @override
  String routeEta(String time) {
    return 'पहुँचने का समय $time';
  }

  @override
  String routeStopLabel(
    int index,
    String service,
    String window,
    String details,
  ) {
    return 'स्टॉप $index: $service, $window. $details';
  }

  @override
  String get attTitle => 'उपस्थिति';

  @override
  String get attUnknown => 'उपस्थिति की स्थिति उपलब्ध नहीं';

  @override
  String get attNotCheckedIn => 'आज चेक-इन नहीं किया';

  @override
  String get attNotCheckedInHint => 'शिफ़्ट शुरू होने पर चेक-इन करें।';

  @override
  String attCheckedInAt(String time) {
    return '$time पर चेक-इन किया';
  }

  @override
  String attCheckedOutAt(String time) {
    return '$time पर चेक-आउट किया';
  }

  @override
  String get attCheckIn => 'चेक-इन';

  @override
  String get attCheckOut => 'चेक-आउट';

  @override
  String get attCheckedInToast => 'चेक-इन हो गया।';

  @override
  String get attCheckedOutToast => 'चेक-आउट हो गया।';

  @override
  String get attNoLocation => '(लोकेशन उपलब्ध नहीं थी।)';

  @override
  String get attDaysPresent => 'उपस्थित दिन';

  @override
  String get attHours => 'घंटे';

  @override
  String get attVisits => 'विज़िट';

  @override
  String get attDaily => 'दिन-प्रतिदिन';

  @override
  String get attEmpty => 'इस महीने कोई उपस्थिति दर्ज नहीं।';

  @override
  String get attAbsent => 'कोई चेक-इन नहीं';

  @override
  String get attOpen => 'चेक-आउट नहीं किया';

  @override
  String attHoursShort(String hours) {
    return '$hours घं.';
  }

  @override
  String attVisitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count विज़िट',
      one: '1 विज़िट',
      zero: 'कोई विज़िट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get supTitle => 'सामग्री';

  @override
  String get supEmpty => 'आपको कोई सामग्री नहीं दी गई है।';

  @override
  String supLowBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सामग्रियाँ कम हैं। कोऑर्डिनेटर से दोबारा भरवाएँ।',
      one: '1 सामग्री कम है। कोऑर्डिनेटर से दोबारा भरवाएँ।',
    );
    return '$_temp0';
  }

  @override
  String get supLow => 'स्टॉक कम';

  @override
  String get supOut => 'स्टॉक खत्म';

  @override
  String supReorderAt(String qty) {
    return '$qty पर दोबारा मँगाएँ';
  }

  @override
  String supOnHand(String qty) {
    return 'उपलब्ध: $qty';
  }

  @override
  String get supUsageTitle => 'इस्तेमाल की गई सामग्री';

  @override
  String get supUsageHint =>
      'इस विज़िट में जो इस्तेमाल किया वह दर्ज करें। ऑफ़लाइन होने पर भी सहेजा जाता है।';

  @override
  String get supUsageCardBody =>
      'इस विज़िट में इस्तेमाल हुए दस्ताने, स्ट्रिप, स्वैब आदि दर्ज करें।';

  @override
  String get supUsageButton => 'इस्तेमाल की गई सामग्री दर्ज करें';

  @override
  String get supUsageSave => 'सहेजें';

  @override
  String get supUsageSaved => 'सामग्री का उपयोग सहेजा गया';

  @override
  String supIncrease(String name) {
    return 'एक $name जोड़ें';
  }

  @override
  String supDecrease(String name) {
    return 'एक $name हटाएँ';
  }

  @override
  String get sampleTestsTitle => 'लेने वाले लैब टेस्ट';

  @override
  String get sampleGeneric => 'लैब ऑर्डर के अनुसार सैंपल लें।';

  @override
  String get sampleFastingShort => 'खाली पेट';

  @override
  String get sampleFastingRequired =>
      'खाली पेट ज़रूरी है। सैंपल लेने से पहले मरीज़ से पुष्टि करें।';

  @override
  String sampleFastingHours(int hours) {
    return 'खाली पेट ज़रूरी है ($hours घं.)। सैंपल लेने से पहले मरीज़ से पुष्टि करें।';
  }

  @override
  String get sampleNoFasting => 'इन टेस्ट के लिए खाली पेट ज़रूरी नहीं।';

  @override
  String get sampleChecklistTitle => 'पूरा करने से पहले: सैंपल चेकलिस्ट';

  @override
  String get samplePatientId => 'मरीज़ की पहचान सत्यापित';

  @override
  String get sampleFastingConfirmed => 'मरीज़ से खाली पेट की पुष्टि की';

  @override
  String get sampleFastingNotNeeded => 'खाली पेट ज़रूरी नहीं (मरीज़ से पूछा)';

  @override
  String get sampleTubesLabelled => 'सभी ट्यूब पर लेबल लगाया';

  @override
  String get sampleCount => 'सैंपल की संख्या';

  @override
  String get sampleCollectedConfirm => 'सैंपल ले लिए गए';

  @override
  String get sampleCompleteHint =>
      'विज़िट पूरी करने के लिए हर बिंदु की पुष्टि करें।';

  @override
  String sampleSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सैंपल लिए गए।',
      one: '1 सैंपल लिया गया।',
    );
    return '$_temp0 ट्यूब पर लेबल लगाया, मरीज़ की पहचान सत्यापित, खाली पेट की पुष्टि की।';
  }

  @override
  String get exCardTitle => 'व्यायाम योजना';

  @override
  String get exCreateTitle => 'व्यायाम योजना बनाएँ';

  @override
  String get exChooseTitle => '1. व्यायाम चुनें';

  @override
  String get exAllAreas => 'सभी';

  @override
  String get exLibraryEmpty => 'इस हिस्से के लिए कोई व्यायाम नहीं।';

  @override
  String get exDosageTitle => '2. सेट और दोहराव';

  @override
  String get exNoneSelected => 'ऊपर से कम से कम एक व्यायाम चुनें।';

  @override
  String get exSets => 'सेट';

  @override
  String get exReps => 'दोहराव';

  @override
  String get exHold => 'रोकें (से.)';

  @override
  String get exPerDay => 'प्रति दिन';

  @override
  String get exNotes => 'नोट्स (वैकल्पिक)';

  @override
  String get exScheduleTitle => '3. समय-सारिणी';

  @override
  String get exStartDate => 'शुरू होने की तारीख';

  @override
  String get exWeeks => 'सप्ताह';

  @override
  String get exSave => 'व्यायाम योजना सहेजें';

  @override
  String get exCreated => 'व्यायाम योजना बन गई';

  @override
  String get exErrNoExercises => 'कम से कम एक व्यायाम चुनें।';

  @override
  String exErrRange(String field, int min, int max) {
    return '$field $min से $max के बीच होना चाहिए।';
  }

  @override
  String get exErrStartDate => 'शुरू होने की तारीख बीती हुई नहीं हो सकती।';

  @override
  String get exNoPlans => 'इस मरीज़ के लिए अभी कोई व्यायाम योजना नहीं।';

  @override
  String get exProgressUnavailable =>
      'योजना की प्रगति आपके लिए उपलब्ध नहीं है।';

  @override
  String exPlanLine(int count, String author) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count व्यायाम',
      one: '1 व्यायाम',
    );
    return '$_temp0 · $author';
  }

  @override
  String exProgressLine(int done, int planned, int pct) {
    return '$done/$planned सत्र · $pct% पालन';
  }

  @override
  String exLatestPain(int score) {
    return 'हाल का दर्द $score/10';
  }

  @override
  String get dietCardTitle => 'डाइट प्लान';

  @override
  String get dietCardBody => 'इस मरीज़ के लिए भोजन योजना बनाएँ।';

  @override
  String get dietCreateTitle => 'डाइट प्लान बनाएँ';

  @override
  String get dietTemplate => 'टेम्पलेट';

  @override
  String get dietNoTemplate => 'कोई टेम्पलेट नहीं';

  @override
  String get dietGovernance =>
      '[क्लिनिकल समीक्षा आवश्यक] यह टेम्पलेट अभी क्लिनिकल रूप से स्वीकृत नहीं है। हर बिंदु की समीक्षा करें।';

  @override
  String get dietConditions => 'स्थितियाँ और लक्ष्य';

  @override
  String get dietAddCondition => 'स्थिति जोड़ें';

  @override
  String get dietCalories => 'कैलोरी लक्ष्य (kcal/दिन)';

  @override
  String get dietMeals => 'भोजन';

  @override
  String get dietMealsHint => 'चीज़ों को कॉमा से अलग करें।';

  @override
  String get dietAvoid => 'परहेज़ और नोट्स';

  @override
  String get dietAvoidHint => 'परहेज़ वाले खाद्य (कॉमा से अलग)';

  @override
  String get dietNotes => 'नोट्स (वैकल्पिक)';

  @override
  String get dietValidUntil => 'कब तक मान्य';

  @override
  String get dietSave => 'डाइट प्लान सहेजें';

  @override
  String get dietCreated => 'डाइट प्लान बन गया';

  @override
  String get dietErrNoMeals => 'कम से कम एक भोजन में खाद्य जोड़ें।';

  @override
  String get dietErrNoConditions => 'कम से कम एक स्थिति जोड़ें।';

  @override
  String dietErrCalories(int min, int max) {
    return 'कैलोरी लक्ष्य $min से $max के बीच होना चाहिए।';
  }

  @override
  String get dietErrValidUntil =>
      '\"कब तक मान्य\" आज के बाद की तारीख होनी चाहिए।';

  @override
  String get slotEarlyMorning => 'सुबह जल्दी';

  @override
  String get slotBreakfast => 'नाश्ता';

  @override
  String get slotMidMorning => 'दोपहर से पहले';

  @override
  String get slotLunch => 'दोपहर का भोजन';

  @override
  String get slotEvening => 'शाम का नाश्ता';

  @override
  String get slotDinner => 'रात का भोजन';

  @override
  String get slotBedtime => 'सोने से पहले';

  @override
  String serverChip(String host) {
    return 'सर्वर: $host';
  }

  @override
  String get serverAddressTitle => 'सर्वर पता';

  @override
  String get serverAddressHelp =>
      'केयरकम्पैनियन सर्वर का पता डालें, जैसे 10.10.17.134, http://10.10.17.134:4000 या टनल लिंक https://xyz.trycloudflare.com।';

  @override
  String get serverAddressLabel => 'सर्वर URL या IP पता';

  @override
  String get serverAddressInvalid =>
      'ऐसा पता डालें: 10.10.17.134 या https://example.com';

  @override
  String get serverTestConnection => 'कनेक्शन जाँचें';

  @override
  String get serverTesting => 'कनेक्शन जाँचा जा रहा है…';

  @override
  String serverConnectedVersion(String version) {
    return 'कनेक्ट हो गया। सर्वर संस्करण $version';
  }

  @override
  String get serverCantReach =>
      'सर्वर तक नहीं पहुँच पा रहे: जाँचें कि PC पर START-CARECOMPANION.bat चल रहा है और फ़ोन उसी नेटवर्क पर है, या टनल लिंक इस्तेमाल करें।';

  @override
  String serverNotCareCompanion(String status) {
    return 'सर्वर ने जवाब दिया (HTTP $status), लेकिन यह केयरकम्पैनियन API नहीं है। पता जाँचें।';
  }

  @override
  String get serverSave => 'सहेजें';

  @override
  String get serverReset => 'डिफ़ॉल्ट पर लौटाएँ';

  @override
  String serverDefaultIs(String url) {
    return 'डिफ़ॉल्ट: $url';
  }

  @override
  String get serverSignOutWarning => 'सर्वर बदलने पर आप लॉग आउट हो जाएँगे।';

  @override
  String serverCantReachAt(String host) {
    return '$host पर सर्वर तक नहीं पहुँच पा रहे';
  }

  @override
  String get serverChange => 'सर्वर बदलें';
}
