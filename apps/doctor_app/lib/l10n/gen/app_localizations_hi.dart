// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'केयरकम्पैनियन डॉक्टर';

  @override
  String get commonLoading => 'लोड हो रहा है';

  @override
  String get commonRetry => 'फिर से कोशिश करें';

  @override
  String get commonRefresh => 'रीफ़्रेश करें';

  @override
  String get commonSave => 'सहेजें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonConfirm => 'पुष्टि करें';

  @override
  String get commonContinue => 'जारी रखें';

  @override
  String get commonDiscard => 'हटाएँ';

  @override
  String get commonAdd => 'जोड़ें';

  @override
  String get commonRemove => 'हटाएँ';

  @override
  String get commonOk => 'ठीक है';

  @override
  String get commonLogout => 'लॉग आउट';

  @override
  String get copied => 'कॉपी हो गया';

  @override
  String get send => 'भेजें';

  @override
  String get fieldRequired => 'आवश्यक';

  @override
  String get linkFailed => 'लिंक नहीं खुल सका';

  @override
  String get offlineBanner =>
      'आप ऑफ़लाइन हैं। पिछला लोड किया गया डेटा दिख रहा है।';

  @override
  String get statusLabel => 'स्थिति';

  @override
  String get priorityLabel => 'प्राथमिकता';

  @override
  String get severityLabel => 'गंभीरता';

  @override
  String get episodeLabel => 'केयर एपिसोड';

  @override
  String get reasonLabel => 'कारण';

  @override
  String get noneRecorded => 'कुछ दर्ज नहीं';

  @override
  String get noneAdded => 'अभी कुछ नहीं जोड़ा गया';

  @override
  String get onePerLine => 'हर पंक्ति में एक';

  @override
  String get commaSeparated => 'कॉमा से अलग करें';

  @override
  String ageYears(int age) {
    return '$age वर्ष';
  }

  @override
  String daysCount(int count) {
    return '$count दिन';
  }

  @override
  String get genderMale => 'पुरुष';

  @override
  String get genderFemale => 'महिला';

  @override
  String get genderOther => 'अन्य';

  @override
  String get errorNetwork =>
      'केयरकम्पैनियन से जुड़ नहीं पा रहे। कनेक्शन जाँचें।';

  @override
  String get errorGeneric => 'कुछ गलत हो गया। फिर से कोशिश करें।';

  @override
  String get errorServer => 'सेवा में समस्या है। थोड़ी देर बाद कोशिश करें।';

  @override
  String get errorSessionExpired =>
      'आपका सत्र समाप्त हो गया। फिर से लॉग इन करें।';

  @override
  String get errorForbidden => 'आपको इसकी अनुमति नहीं है।';

  @override
  String get errorNotFound => 'यह अब उपलब्ध नहीं है।';

  @override
  String get errorRateLimited => 'बहुत सारे प्रयास। कुछ देर रुककर कोशिश करें।';

  @override
  String get errorMfaRequired => 'जारी रखने के लिए दो-चरणीय सत्यापन ज़रूरी है।';

  @override
  String get loginTitle => 'डॉक्टर साइन इन';

  @override
  String get loginSubtitle => 'आपकी कतार, मरीज़ और केयर टीम एक जगह।';

  @override
  String get loginPhoneLabel => 'मोबाइल नंबर';

  @override
  String get loginPhoneHint => '10 अंकों का नंबर';

  @override
  String get loginPhoneInvalid => 'सही 10 अंकों का मोबाइल नंबर डालें';

  @override
  String get loginSendOtp => 'OTP भेजें';

  @override
  String loginOtpSentTo(String phone) {
    return '$phone पर भेजा गया कोड डालें';
  }

  @override
  String get loginOtpLabel => '6 अंकों का OTP';

  @override
  String get loginOtpInvalid => '6 अंकों का कोड डालें';

  @override
  String loginDevOtpHint(String code) {
    return 'डेवलपमेंट OTP: $code';
  }

  @override
  String get loginVerify => 'सत्यापित करें';

  @override
  String get loginChangeNumber => 'नंबर बदलें';

  @override
  String get mfaTitle => 'दो-चरणीय सत्यापन';

  @override
  String get mfaEnrolIntro =>
      'डॉक्टर खाते SMS OTP के साथ ऑथेंटिकेटर ऐप कोड से सुरक्षित होते हैं।';

  @override
  String get mfaStep1 => '1. अपने ऑथेंटिकेटर में केयरकम्पैनियन जोड़ें';

  @override
  String get mfaStep2 => '2. वहाँ दिखा 6 अंकों का कोड डालें';

  @override
  String get mfaOpenAppHint =>
      'खाता अपने-आप जोड़ने के लिए बटन दबाएँ, या सेटअप कुंजी ऐप में टाइप करें।';

  @override
  String get mfaOpenAuthenticator => 'ऑथेंटिकेटर ऐप खोलें';

  @override
  String get mfaSecretLabel => 'सेटअप कुंजी';

  @override
  String get mfaCopySecret => 'सेटअप कुंजी कॉपी करें';

  @override
  String get mfaCodeLabel => 'ऑथेंटिकेटर कोड';

  @override
  String get mfaTurnOn => 'सत्यापित करें और चालू करें';

  @override
  String get mfaRecoveryIntro =>
      'ये रिकवरी कोड सुरक्षित रखें। फ़ोन खोने पर हर कोड एक बार काम करेगा। ये दोबारा नहीं दिखेंगे।';

  @override
  String get mfaCopyCodes => 'सभी कोड कॉपी करें';

  @override
  String get mfaSavedCodes => 'मैंने रिकवरी कोड सहेज लिए हैं';

  @override
  String get mfaVerifyPrompt => 'अपने ऑथेंटिकेटर ऐप से 6 अंकों का कोड डालें।';

  @override
  String get mfaRecoveryPrompt =>
      'अपना एक रिकवरी कोड डालें। हर कोड एक ही बार काम करता है।';

  @override
  String get mfaRecoveryLabel => 'रिकवरी कोड';

  @override
  String get mfaVerify => 'सत्यापित करें';

  @override
  String get mfaUseRecovery => 'इसके बजाय रिकवरी कोड इस्तेमाल करें';

  @override
  String get mfaUseAuthenticator => 'ऑथेंटिकेटर ऐप इस्तेमाल करें';

  @override
  String get mfaWrongCode => 'यह कोड गलत है।';

  @override
  String mfaWrongCodeAttempts(int count) {
    return 'यह कोड गलत है। $count प्रयास बाकी।';
  }

  @override
  String get mfaCodeInvalid => '6 अंकों का कोड डालें';

  @override
  String get mfaRecoveryInvalid => 'सही रिकवरी कोड डालें';

  @override
  String get mfaLocked => 'बहुत सारे गलत कोड। 15 मिनट बाद कोशिश करें।';

  @override
  String get mfaStatusOn => 'चालू (ऑथेंटिकेटर ऐप)';

  @override
  String get mfaStatusOff => 'अभी सेट नहीं है। संस्था के कहने पर पूछा जाएगा।';

  @override
  String get restrictedTitle => 'यह ऐप डॉक्टरों के लिए है';

  @override
  String get restrictedBody =>
      'आपके खाते में सत्यापित डॉक्टर प्रोफ़ाइल नहीं है।';

  @override
  String get restrictedPatient =>
      'कृपया मरीज़ों और परिवारों के लिए केयरकम्पैनियन ऐप इस्तेमाल करें।';

  @override
  String get restrictedProvider =>
      'होम-केयर विज़िट के लिए कृपया केयरकम्पैनियन प्रो ऐप इस्तेमाल करें।';

  @override
  String get restrictedStaff =>
      'अपनी भूमिका के लिए कृपया केयरकम्पैनियन वेब पोर्टल इस्तेमाल करें।';

  @override
  String get updateTitle => 'कृपया ऐप अपडेट करें';

  @override
  String get updateBody =>
      'यह संस्करण अब समर्थित नहीं है। सुरक्षित रूप से काम जारी रखने के लिए अपडेट करें।';

  @override
  String get updateNow => 'अभी अपडेट करें';

  @override
  String updateVersions(String current, String minimum) {
    return 'इंस्टॉल $current · आवश्यक $minimum';
  }

  @override
  String get supportTitle => 'सहायता';

  @override
  String get supportCall => 'सहायता को कॉल करें';

  @override
  String get supportEmail => 'सहायता को ईमेल करें';

  @override
  String get supportWhatsapp => 'व्हाट्सऐप सहायता';

  @override
  String get navToday => 'आज';

  @override
  String get navPatients => 'मरीज़';

  @override
  String get navMessages => 'संदेश';

  @override
  String get navMore => 'और';

  @override
  String helloDoctor(String name) {
    return 'नमस्ते, $name';
  }

  @override
  String get queueEmpty => 'इस दिन कोई परामर्श नहीं।';

  @override
  String get queueWaiting => 'प्रतीक्षा में';

  @override
  String get queueInProgress => 'जारी';

  @override
  String get queueDone => 'पूरा';

  @override
  String get apptPendingPayment => 'भुगतान बाकी';

  @override
  String get apptConfirmed => 'पुष्ट';

  @override
  String get apptInProgress => 'जारी';

  @override
  String get apptCompleted => 'पूरा';

  @override
  String get apptCancelled => 'रद्द';

  @override
  String get apptNoShow => 'नहीं आए';

  @override
  String get priorityRoutine => 'सामान्य';

  @override
  String get priorityUrgent => 'तत्काल';

  @override
  String get priorityEmergency => 'आपातकाल';

  @override
  String get epNew => 'नया';

  @override
  String get epIntake => 'इनटेक';

  @override
  String get epAwaitingCare => 'देखभाल की प्रतीक्षा';

  @override
  String get epCareScheduled => 'देखभाल तय';

  @override
  String get epUnderCare => 'देखभाल में';

  @override
  String get epFollowUp => 'फ़ॉलो-अप';

  @override
  String get epResolved => 'हल';

  @override
  String get epEscalated => 'एस्केलेट किया गया';

  @override
  String get epEmergency => 'आपातकाल';

  @override
  String get epTransferred => 'स्थानांतरित';

  @override
  String get epCancelled => 'रद्द';

  @override
  String get modeVideo => 'वीडियो';

  @override
  String get modeAudio => 'ऑडियो';

  @override
  String get modeChat => 'चैट';

  @override
  String get modeInClinic => 'क्लिनिक में';

  @override
  String get modeHomeVisit => 'होम विज़िट';

  @override
  String get consultTitle => 'परामर्श';

  @override
  String get openPatient => 'मरीज़ का रिकॉर्ड खोलें';

  @override
  String get startConsult => 'परामर्श शुरू करें';

  @override
  String get completeConsult => 'परामर्श पूरा करें';

  @override
  String get consultStarted => 'परामर्श शुरू हुआ';

  @override
  String get consultCompleted => 'परामर्श पूरा हुआ';

  @override
  String get savedNotes => 'सहेजे गए नोट्स';

  @override
  String get outcomeLabel => 'परिणाम';

  @override
  String get outcomeCarePlan => 'केयर प्लान';

  @override
  String get outcomeResolved => 'हल';

  @override
  String get outcomeRefer => 'रेफ़र';

  @override
  String get outcomeHomeVisit => 'होम विज़िट';

  @override
  String get notesTitle => 'क्लिनिकल नोट्स';

  @override
  String get notesHint => 'नोट्स लिखें या AI स्क्राइब इस्तेमाल करें';

  @override
  String get notesSaveHint => 'परामर्श पूरा करने पर नोट्स सहेजे जाते हैं।';

  @override
  String get saveEpisodeNote => 'अभी केयर एपिसोड में जोड़ें';

  @override
  String get noteSaved => 'नोट केयर एपिसोड में जुड़ गया';

  @override
  String get toolsTitle => 'कार्य';

  @override
  String get careTeamThread => 'केयर टीम संदेश';

  @override
  String get joinVideo => 'वीडियो से जुड़ें';

  @override
  String get videoTitle => 'वीडियो परामर्श';

  @override
  String get videoWindow => 'रूम खुला';

  @override
  String get videoAudioHint => 'ऑडियो परामर्श: कैमरा बंद रखें।';

  @override
  String videoOpensAt(String time) {
    return 'रूम $time पर खुलेगा (शुरू होने से 10 मिनट पहले)।';
  }

  @override
  String get intakeTitle => 'मुख्य शिकायत (AI इनटेक)';

  @override
  String get intakeComplaint => 'मुख्य शिकायत';

  @override
  String get intakeDuration => 'अवधि';

  @override
  String get intakeSeverity => 'गंभीरता';

  @override
  String get intakeSymptoms => 'संबंधित लक्षण';

  @override
  String get allergiesTitle => 'एलर्जी';

  @override
  String get allergiesNone => 'कोई ज्ञात एलर्जी दर्ज नहीं';

  @override
  String get conditionsTitle => 'स्थितियाँ';

  @override
  String get activeMedsTitle => 'चालू दवाइयाँ';

  @override
  String get recentVitalsTitle => 'हाल के वाइटल्स';

  @override
  String get homeVisitFindingsTitle => 'होम विज़िट निष्कर्ष';

  @override
  String get escalatedLabel => 'एस्केलेट किया गया';

  @override
  String get aiSummaryTitle => 'AI सारांश';

  @override
  String get aiAdvisoryLabel => 'AI द्वारा बनाया गया · केवल सलाह, निदान नहीं';

  @override
  String get aiSource => 'स्रोत';

  @override
  String get aiFeedbackPrompt => 'क्या यह सारांश सही था?';

  @override
  String get aiAccept => 'सही';

  @override
  String get aiReject => 'सही नहीं';

  @override
  String get aiFeedbackThanks => 'धन्यवाद, आपकी प्रतिक्रिया दर्ज हुई।';

  @override
  String get aiRecordSummary => 'AI रिकॉर्ड सारांश';

  @override
  String get srcRecord => 'रिकॉर्ड';

  @override
  String get srcVital => 'वाइटल';

  @override
  String get srcIntake => 'इनटेक';

  @override
  String get srcHomeVisit => 'होम विज़िट';

  @override
  String get srcPatientEntered => 'मरीज़ द्वारा दर्ज';

  @override
  String get scribeTitle => 'AI स्क्राइब';

  @override
  String get scribeConsent =>
      'मरीज़ ने इस परामर्श की रिकॉर्डिंग और लिप्यंतरण के लिए सहमति दी है';

  @override
  String get scribeConsentHint =>
      'रिकॉर्डिंग या ट्रांसक्रिप्ट भेजने से पहले ज़रूरी। इसका ऑडिट होता है।';

  @override
  String get scribeConsentRequired => 'पहले मरीज़ की सहमति की पुष्टि करें।';

  @override
  String get scribeRecordTitle => 'परामर्श रिकॉर्ड करें';

  @override
  String get scribeRecord => 'रिकॉर्ड करें';

  @override
  String get scribeRecording => 'रिकॉर्डिंग…';

  @override
  String get scribeStopUpload => 'रोकें और ड्राफ़्ट बनाएँ';

  @override
  String get scribeAudioNote =>
      'ऑडियो एक बार अपलोड होता है, लिप्यंतरण के बाद सर्वर उसे हटा देता है।';

  @override
  String get scribeTranscriptTitle => 'या ट्रांसक्रिप्ट लिखें / चिपकाएँ';

  @override
  String get scribeTranscriptHint => 'डॉक्टर: … मरीज़: …';

  @override
  String get scribeGenerate => 'SOAP ड्राफ़्ट बनाएँ';

  @override
  String get scribeDraftTitle => 'SOAP ड्राफ़्ट';

  @override
  String get scribeInsert => 'नोट्स में जोड़ें';

  @override
  String get scribeInserted =>
      'ड्राफ़्ट जोड़ा गया। पूरा करने से पहले जाँचें और बदलें।';

  @override
  String get scribeMicDenied => 'रिकॉर्ड करने के लिए माइक्रोफ़ोन अनुमति चाहिए।';

  @override
  String get scribeTranscriptShort => 'ट्रांसक्रिप्ट बहुत छोटा है।';

  @override
  String get scribeTooLarge =>
      'रिकॉर्डिंग 25 MB से बड़ी है। छोटा हिस्सा रिकॉर्ड करें।';

  @override
  String get soapS => 'सब्जेक्टिव';

  @override
  String get soapO => 'ऑब्जेक्टिव';

  @override
  String get soapA => 'आकलन';

  @override
  String get soapP => 'योजना';

  @override
  String get rxTitle => 'प्रिस्क्रिप्शन';

  @override
  String rxFor(String name) {
    return '$name के लिए';
  }

  @override
  String get rxItems => 'दवाइयाँ';

  @override
  String get rxNoItems => 'कम से कम एक दवा जोड़ें।';

  @override
  String get rxNeedsStart => 'पहले परामर्श शुरू करें';

  @override
  String get rxItemTitle => 'दवा';

  @override
  String get rxDrugName => 'दवा का नाम';

  @override
  String get rxStrength => 'शक्ति';

  @override
  String get rxForm => 'रूप';

  @override
  String get rxDose => 'खुराक';

  @override
  String get rxFrequency => 'आवृत्ति';

  @override
  String get rxTiming => 'समय';

  @override
  String get rxTimingHint => 'खाने के बाद';

  @override
  String get rxDuration => 'दिन';

  @override
  String get rxDurationInvalid => '1–365 दिन';

  @override
  String get rxTimes => 'रिमाइंडर समय (HH:MM)';

  @override
  String get rxTimesInvalid => '08:00, 20:00 जैसे 24-घंटे का समय लिखें';

  @override
  String get rxInstructions => 'निर्देश';

  @override
  String get rxChecksTitle => 'इंटरैक्शन और एलर्जी जाँच';

  @override
  String get rxCheckIdle => 'दवाएँ जोड़ते ही जाँच अपने-आप होती है।';

  @override
  String get rxChecking => 'जाँच हो रही है…';

  @override
  String get rxNoWarnings => 'कोई इंटरैक्शन या एलर्जी टकराव नहीं मिला।';

  @override
  String rxPack(String pack) {
    return 'नॉलेज पैक $pack';
  }

  @override
  String get sevMajor => 'गंभीर';

  @override
  String get sevModerate => 'मध्यम';

  @override
  String get sevInfo => 'जानकारी';

  @override
  String get warnAllergy => 'एलर्जी';

  @override
  String get warnDuplicate => 'दोहरा उपचार';

  @override
  String get warnInteraction => 'इंटरैक्शन';

  @override
  String get warnDoseForm => 'खुराक / रूप';

  @override
  String get rxAcknowledge =>
      'मैंने गंभीर चेतावनियाँ देख ली हैं और फिर भी लिखना चाहता/चाहती हूँ';

  @override
  String get rxOverrideReason => 'ओवरराइड का क्लिनिकल कारण';

  @override
  String rxOverrideReasonHint(int min) {
    return 'कम से कम $min अक्षर। ऑडिट होता है।';
  }

  @override
  String get rxMajorBlocked =>
      'गंभीर चेतावनियों के लिए स्वीकृति और कारण ज़रूरी है।';

  @override
  String get rxClinicalNote => 'क्लिनिकल नोट (प्रिस्क्रिप्शन पर)';

  @override
  String get rxAdvice => 'सलाह';

  @override
  String get rxFollowUpDays => 'फ़ॉलो-अप (दिन में)';

  @override
  String get rxSign => 'प्रिस्क्रिप्शन बनाएँ';

  @override
  String get rxCreated => 'प्रिस्क्रिप्शन बना और मरीज़ से साझा हुआ';

  @override
  String rxPdfTitle(String name) {
    return 'प्रिस्क्रिप्शन · $name';
  }

  @override
  String get formTablet => 'टैबलेट';

  @override
  String get formCapsule => 'कैप्सूल';

  @override
  String get formSyrup => 'सिरप';

  @override
  String get formInjection => 'इंजेक्शन';

  @override
  String get formOintment => 'मरहम';

  @override
  String get formDrops => 'ड्रॉप्स';

  @override
  String get formInhaler => 'इनहेलर';

  @override
  String get formOther => 'अन्य';

  @override
  String pdfDocument(String title) {
    return 'PDF दस्तावेज़: $title';
  }

  @override
  String pageOf(int page, int total) {
    return 'पेज $page / $total';
  }

  @override
  String get fileReady => 'फ़ाइल तैयार है। देखने के लिए ब्राउज़र में खोलें।';

  @override
  String get openInBrowser => 'ब्राउज़र में खोलें';

  @override
  String get carePlanTitle => 'केयर प्लान';

  @override
  String get carePlanSummary => 'सारांश';

  @override
  String get carePlanInstructions => 'मरीज़ के लिए निर्देश';

  @override
  String get carePlanTasks => 'कार्य';

  @override
  String get carePlanMeds => 'दवाइयाँ';

  @override
  String get carePlanSaved => 'केयर प्लान सहेजा गया';

  @override
  String get taskTitle => 'कार्य';

  @override
  String get taskType => 'प्रकार';

  @override
  String get taskOwner => 'कौन';

  @override
  String get taskDueInDays => 'कितने दिन में (वैकल्पिक)';

  @override
  String get taskMedication => 'दवा';

  @override
  String get taskTest => 'जाँच';

  @override
  String get taskFollowUp => 'फ़ॉलो-अप';

  @override
  String get taskLifestyle => 'जीवनशैली';

  @override
  String get taskMonitoring => 'निगरानी';

  @override
  String get taskGeneral => 'सामान्य';

  @override
  String get ownerPatient => 'मरीज़';

  @override
  String get ownerCaregiver => 'देखभालकर्ता';

  @override
  String get ownerProvider => 'केयर प्रोवाइडर';

  @override
  String get followUpTitle => 'फ़ॉलो-अप';

  @override
  String get followUpAfterDays => 'कितने दिन बाद';

  @override
  String get followUpMode => 'तरीका';

  @override
  String get followUpNone => 'कोई फ़ॉलो-अप नहीं';

  @override
  String get referTitle => 'अस्पताल रेफ़र करें';

  @override
  String get referSearchHospital => 'अस्पताल खोजें';

  @override
  String get referNoHospitals => 'कोई अस्पताल नहीं मिला।';

  @override
  String get referSpecialty => 'विशेषज्ञता (वैकल्पिक)';

  @override
  String get referReason => 'रेफ़रल का कारण';

  @override
  String get referSummary => 'क्लिनिकल सारांश (वैकल्पिक)';

  @override
  String get referSend => 'रेफ़रल पत्र बनाएँ';

  @override
  String get referSaved => 'रेफ़रल बना। मरीज़ को सूचित किया गया।';

  @override
  String get emergency24x7 => '24×7 आपातकालीन';

  @override
  String get enrolTitle => 'केयर प्रोग्राम में नामांकन';

  @override
  String get enrolThresholds => 'अलर्ट सीमाएँ';

  @override
  String get enrolSave => 'मरीज़ का नामांकन करें';

  @override
  String get enrolSaved => 'मरीज़ का नामांकन हुआ';

  @override
  String get fixtureWarning =>
      'टेम्पलेट अभी क्लिनिकल रूप से स्वीकृत नहीं (फ़िक्स्चर)।';

  @override
  String get exerciseTitle => 'व्यायाम योजना';

  @override
  String get exerciseWeeks => 'सप्ताह';

  @override
  String get exerciseSets => 'सेट';

  @override
  String get exerciseReps => 'रेप्स';

  @override
  String get exercisePerDay => 'प्रतिदिन';

  @override
  String get planSaved => 'योजना मरीज़ से साझा की गई';

  @override
  String get dietTitle => 'आहार योजना';

  @override
  String get dietTemplate => 'टेम्पलेट';

  @override
  String get dietNoTemplate => 'कोई टेम्पलेट नहीं';

  @override
  String get dietConditions => 'स्थितियाँ (कॉमा से अलग)';

  @override
  String get dietCalories => 'कैलोरी लक्ष्य (वैकल्पिक)';

  @override
  String get dietMeals => 'भोजन';

  @override
  String get dietMealsHint => 'आइटम कॉमा से अलग करें।';

  @override
  String dietMealsCount(int count) {
    return '$count भोजन भरे गए';
  }

  @override
  String get dietNeedMeals => 'टेम्पलेट चुनें या कम से कम एक भोजन भरें।';

  @override
  String get dietAvoid => 'परहेज़ (कॉमा से अलग)';

  @override
  String get dietNotes => 'नोट्स';

  @override
  String dietValidWeeks(int weeks) {
    return '$weeks सप्ताह तक मान्य';
  }

  @override
  String get slotEarlyMorning => 'सुबह जल्दी';

  @override
  String get slotBreakfast => 'नाश्ता';

  @override
  String get slotMidMorning => 'दोपहर से पहले';

  @override
  String get slotLunch => 'दोपहर का भोजन';

  @override
  String get slotEvening => 'शाम';

  @override
  String get slotDinner => 'रात का भोजन';

  @override
  String get slotBedtime => 'सोने से पहले';

  @override
  String get patientTitle => 'मरीज़';

  @override
  String get patientSearchHint => 'नाम से अपने मरीज़ खोजें';

  @override
  String get patientsEmpty =>
      'जिन मरीज़ों से आप परामर्श करते हैं या जो रिकॉर्ड साझा करते हैं, वे यहाँ दिखेंगे।';

  @override
  String get patientsNoMatch => 'खोज से कोई मरीज़ नहीं मिला।';

  @override
  String get bloodGroup => 'रक्त समूह';

  @override
  String get tabOverview => 'सारांश';

  @override
  String get tabRecords => 'रिकॉर्ड';

  @override
  String get tabVitals => 'वाइटल्स';

  @override
  String get tabPrograms => 'प्रोग्राम';

  @override
  String get tabPrescriptions => 'प्रिस्क्रिप्शन';

  @override
  String get tabEpisodes => 'एपिसोड';

  @override
  String get recordsEmpty => 'कोई रिकॉर्ड साझा नहीं।';

  @override
  String get openOriginal => 'मूल फ़ाइल खोलें';

  @override
  String get recLab => 'लैब रिपोर्ट';

  @override
  String get recPrescription => 'प्रिस्क्रिप्शन';

  @override
  String get recImaging => 'इमेजिंग';

  @override
  String get recDischarge => 'डिस्चार्ज सारांश';

  @override
  String get recVisitSummary => 'विज़िट सारांश';

  @override
  String get recOther => 'अन्य';

  @override
  String get vitalsEmpty => 'कोई वाइटल्स दर्ज नहीं।';

  @override
  String vitalRange(String min, String max) {
    return 'सीमा $min–$max';
  }

  @override
  String readingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रीडिंग',
      one: '1 रीडिंग',
    );
    return '$_temp0';
  }

  @override
  String vitalTrendSemantics(String vital, String min, String max, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रीडिंग',
      one: '1 रीडिंग',
    );
    return '$vital रुझान: $min से $max के बीच $_temp0';
  }

  @override
  String get vitalBpSystolic => 'BP सिस्टोलिक';

  @override
  String get vitalBpDiastolic => 'BP डायस्टोलिक';

  @override
  String get vitalPulse => 'नाड़ी';

  @override
  String get vitalSpo2 => 'SpO2';

  @override
  String get vitalTemperature => 'तापमान';

  @override
  String get vitalGlucose => 'ब्लड ग्लूकोज़';

  @override
  String get vitalWeight => 'वज़न';

  @override
  String get vitalRespiratoryRate => 'श्वसन दर';

  @override
  String get programsEmpty => 'किसी केयर प्रोग्राम में नामांकन नहीं।';

  @override
  String get programAdherence => 'पालन (7 दिन)';

  @override
  String get programLastReading => 'अंतिम रीडिंग';

  @override
  String get programOpenBreaches => 'खुले अलर्ट';

  @override
  String get progActive => 'सक्रिय';

  @override
  String get progPaused => 'रुका हुआ';

  @override
  String get progCompleted => 'पूरा';

  @override
  String get prescriptionsEmpty => 'अभी कोई प्रिस्क्रिप्शन नहीं।';

  @override
  String get episodesEmpty => 'कोई केयर एपिसोड नहीं।';

  @override
  String get inboxEmpty => 'अभी कोई केयर टीम बातचीत नहीं।';

  @override
  String get noMessagesYet => 'अभी कोई संदेश नहीं';

  @override
  String unreadCount(int count) {
    return '$count अपठित';
  }

  @override
  String get messageHint => 'केयर टीम को संदेश भेजें';

  @override
  String get emergencyNotice => 'आपातकालीन सुरक्षा सूचना';

  @override
  String get secondOpinionsTitle => 'सेकंड ओपिनियन';

  @override
  String get soTabOpen => 'खुले';

  @override
  String get soTabMine => 'मेरे';

  @override
  String get soEmpty => 'यहाँ कोई अनुरोध नहीं।';

  @override
  String get soOpen => 'खुला';

  @override
  String get soClaimed => 'लिया गया';

  @override
  String get soAnswered => 'उत्तर दिया';

  @override
  String get soClaim => 'लें';

  @override
  String get soClaimedMsg => 'अनुरोध लिया गया। रिकॉर्ड अब आपसे साझा हैं।';

  @override
  String get soRespond => 'राय लिखें';

  @override
  String get soOpinion => 'राय';

  @override
  String get soRecommendations => 'सिफ़ारिशें';

  @override
  String get soSuggestTele => 'टेलीकंसल्टेशन सुझाएँ';

  @override
  String get soSent => 'राय मरीज़ को भेजी गई';

  @override
  String soDue(String date) {
    return 'नियत $date';
  }

  @override
  String get escalationsTitle => 'एस्केलेशन';

  @override
  String get escalationsEmpty => 'आपके मरीज़ों के लिए कोई एस्केलेशन नहीं।';

  @override
  String get scheduleTitle => 'शेड्यूल और छुट्टियाँ';

  @override
  String get weeklyTab => 'साप्ताहिक समय';

  @override
  String get leavesTab => 'छुट्टियाँ';

  @override
  String scheduleHint(int days) {
    return 'सहेजने पर अगले $days दिनों के खाली स्लॉट फिर से बनते हैं। बुक स्लॉट नहीं बदलते।';
  }

  @override
  String get scheduleEmpty => 'अभी कोई साप्ताहिक समय नहीं।';

  @override
  String get addBlock => 'समय जोड़ें';

  @override
  String get blockTitle => 'परामर्श का समय';

  @override
  String get weekday => 'दिन';

  @override
  String get startTime => 'शुरू';

  @override
  String get endTime => 'समाप्त';

  @override
  String get slotLength => 'स्लॉट अवधि';

  @override
  String slotMinutes(int minutes) {
    return '$minutes मिनट';
  }

  @override
  String get blockInvalidTime => 'अमान्य समय';

  @override
  String get blockEndBeforeStart => 'समाप्ति शुरुआत के बाद होनी चाहिए';

  @override
  String get blockTooShort => 'एक स्लॉट से छोटा';

  @override
  String get blockNoModes => 'कम से कम एक तरीका चुनें';

  @override
  String get blockOverlap => 'इस दिन के दूसरे समय से टकराता है';

  @override
  String get saveSchedule => 'साप्ताहिक समय सहेजें';

  @override
  String get fixProblems => 'हाइलाइट किए गए समय ठीक करें';

  @override
  String get scheduleSaved => 'शेड्यूल सहेजा गया';

  @override
  String get leavesEmpty => 'कोई छुट्टी तय नहीं।';

  @override
  String get addLeave => 'छुट्टी जोड़ें';

  @override
  String get leaveReason => 'कारण (वैकल्पिक)';

  @override
  String get leaveAdded => 'छुट्टी जोड़ी गई';

  @override
  String leaveConflictsTitle(int count) {
    return 'इस दिन $count बुक परामर्श';
  }

  @override
  String get leaveConflictsBody =>
      'ये अपने-आप रद्द नहीं होते। कृपया केयर टीम से इन्हें फिर से तय करवाएँ।';

  @override
  String get earningsTitle => 'कमाई';

  @override
  String get previousMonth => 'पिछला महीना';

  @override
  String get nextMonth => 'अगला महीना';

  @override
  String get earnPayable => 'आपको देय';

  @override
  String earnServices(int count) {
    return '$count पूरे परामर्श';
  }

  @override
  String get earnGross => 'कुल';

  @override
  String get earnPlatformFee => 'प्लेटफ़ॉर्म शुल्क';

  @override
  String get earnRefunds => 'रिफ़ंड';

  @override
  String get earnLines => 'विवरण';

  @override
  String get earnEmpty => 'इस महीने कोई भुगतान वाला परामर्श नहीं।';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get photoGallery => 'फ़ोटो चुनें';

  @override
  String get photoCamera => 'फ़ोटो लें';

  @override
  String get photoUpdated => 'फ़ोटो अपडेट हुई';

  @override
  String get photoTooLarge => 'फ़ोटो 5 MB से कम होनी चाहिए।';

  @override
  String regNo(String number) {
    return 'पंजीकरण $number';
  }

  @override
  String ratingLine(String rating, int count) {
    return '★ $rating ($count समीक्षाएँ)';
  }

  @override
  String get acceptingBookings => 'नई बुकिंग ले रहे हैं';

  @override
  String get acceptingBookingsHint =>
      'बंद होने पर आप डॉक्टर खोज में नहीं दिखेंगे।';

  @override
  String get bookingsOn => 'आप बुकिंग ले रहे हैं';

  @override
  String get bookingsOff => 'बुकिंग रुकी हुई';

  @override
  String get feesTitle => 'परामर्श शुल्क';

  @override
  String get qualifications => 'योग्यताएँ';

  @override
  String get languagesSpoken => 'बोली जाने वाली भाषाएँ';

  @override
  String get bio => 'आपके बारे में';

  @override
  String get profileSaved => 'प्रोफ़ाइल सहेजी गई';

  @override
  String get languageTitle => 'भाषा';

  @override
  String get logoutConfirmTitle => 'लॉग आउट करें?';

  @override
  String get logoutConfirmBody =>
      'दोबारा साइन इन करने के लिए फ़ोन OTP और ऑथेंटिकेटर कोड चाहिए होगा।';

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

  @override
  String get otpIncorrect => 'कोड गलत है। कृपया जाँचें और फिर से कोशिश करें।';

  @override
  String otpIncorrectAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कोड गलत है। $count प्रयास बाकी।',
      one: 'कोड गलत है। 1 प्रयास बाकी।',
    );
    return '$_temp0';
  }

  @override
  String get otpNoAttemptsLeft =>
      'कोड गलत है। कोई प्रयास बाकी नहीं, कृपया नया कोड मँगाएँ।';

  @override
  String get otpExpired =>
      'इस कोड की समय-सीमा खत्म हो गई है। कृपया नया कोड मँगाएँ।';

  @override
  String get otpTooManyAttempts =>
      'बहुत सारे गलत प्रयास। कृपया नया कोड मँगाएँ।';

  @override
  String get vitalHigh => 'अधिक';

  @override
  String get vitalLow => 'कम';

  @override
  String vitalFlagSemantics(String vital, String value, String flag) {
    return '$vital $value, $flag';
  }

  @override
  String get logoutConfirmBodyOtp =>
      'फिर से साइन इन करने के लिए आपको फ़ोन OTP की ज़रूरत होगी।';

  @override
  String get leaveRemoveTitle => 'यह छुट्टी हटाएँ?';

  @override
  String leaveRemoveBody(String date) {
    return '$date फिर से बुकिंग के लिए खुल जाएगा।';
  }

  @override
  String get attachedRecord => 'संलग्न रिकॉर्ड';

  @override
  String get attachmentUnavailable => 'संलग्न रिकॉर्ड उपलब्ध नहीं है';

  @override
  String get attachmentNoFile =>
      'इस रिकॉर्ड में खोलने के लिए कोई फ़ाइल नहीं है।';

  @override
  String get specGeneralPhysician => 'जनरल फ़िज़िशियन';

  @override
  String get specDermatologist => 'त्वचा रोग विशेषज्ञ';

  @override
  String get specPediatrician => 'बाल रोग विशेषज्ञ';

  @override
  String get specGynecologist => 'स्त्री रोग विशेषज्ञ';

  @override
  String get specCardiologist => 'हृदय रोग विशेषज्ञ';

  @override
  String get specOrthopedist => 'हड्डी रोग विशेषज्ञ';

  @override
  String get specPsychiatrist => 'मनोचिकित्सक';

  @override
  String get specEnt => 'ईएनटी विशेषज्ञ';

  @override
  String get specDiabetologist => 'मधुमेह विशेषज्ञ';

  @override
  String get specNeurologist => 'तंत्रिका रोग विशेषज्ञ';
}
