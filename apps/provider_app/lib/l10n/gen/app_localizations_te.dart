// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'కేర్‌కంపానియన్ ప్రో';

  @override
  String get commonRetry => 'మళ్ళీ ప్రయత్నించండి';

  @override
  String get commonCancel => 'రద్దు చేయి';

  @override
  String get commonConfirm => 'నిర్ధారించు';

  @override
  String get commonSubmit => 'సమర్పించు';

  @override
  String get commonLogout => 'లాగ్ అవుట్';

  @override
  String get commonRefresh => 'రిఫ్రెష్';

  @override
  String get commonLoading => 'లోడ్ అవుతోంది…';

  @override
  String get commonBack => 'వెనక్కి';

  @override
  String get commonNotAvailable => 'అందుబాటులో లేదు';

  @override
  String get errorGeneric => 'ఏదో తప్పు జరిగింది. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorNetwork =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నట్లు ఉంది. కనెక్షన్ చూసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get errorSessionExpired =>
      'మీ సెషన్ ముగిసింది. దయచేసి మళ్ళీ లాగిన్ అవ్వండి.';

  @override
  String get loginTitle => 'ప్రొవైడర్ సైన్ ఇన్';

  @override
  String get loginSubtitle =>
      'ధృవీకరించబడిన నర్సులు, టెక్నీషియన్లు మరియు ఫీల్డ్ మెడికల్ వర్కర్ల కోసం.';

  @override
  String get loginPhoneLabel => 'మొబైల్ నంబర్';

  @override
  String get loginPhoneHint => '10 అంకెల మొబైల్ నంబర్';

  @override
  String get loginPhoneInvalid => 'సరైన 10 అంకెల మొబైల్ నంబర్ ఇవ్వండి';

  @override
  String get loginSendOtp => 'OTP పంపండి';

  @override
  String get loginOtpLabel => '6 అంకెల OTP';

  @override
  String get loginOtpInvalid => '6 అంకెల OTP ఇవ్వండి';

  @override
  String loginOtpSentTo(String phone) {
    return 'OTP $phoneకి పంపబడింది';
  }

  @override
  String get loginVerify => 'ధృవీకరించి కొనసాగండి';

  @override
  String get loginChangeNumber => 'నంబర్ మార్చండి';

  @override
  String loginDevOtpHint(String otp) {
    return 'డెవలప్‌మెంట్ OTP: $otp';
  }

  @override
  String get restrictedTitle =>
      'ధృవీకరించబడిన కేర్ ప్రొవైడర్లకు మాత్రమే ప్రవేశం';

  @override
  String get restrictedBody =>
      'ఈ యాప్ కేర్‌కంపానియన్‌లో నమోదైన హోమ్-కేర్ ప్రొవైడర్ల కోసం మాత్రమే. మీరు రోగి లేదా కుటుంబ సభ్యులు అయితే, కేర్‌కంపానియన్ పేషెంట్ యాప్ ఉపయోగించండి.';

  @override
  String get blockedTitle => 'ప్రస్తుతం మీకు విజిట్లు రావు';

  @override
  String get blockedNoVisits =>
      'మీ ధృవీకరణ యాక్టివ్ అయ్యే వరకు మీకు హోమ్ విజిట్లు కేటాయించబడవు.';

  @override
  String get blockedPending =>
      'మీ వృత్తిపరమైన ధృవీకరణ కేర్‌కంపానియన్ ఆపరేషన్స్ టీమ్ సమీక్షలో ఉంది.';

  @override
  String get blockedExpired =>
      'మీ వృత్తిపరమైన సర్టిఫికేట్ గడువు ముగిసింది. దయచేసి దాన్ని రెన్యూ చేసి, కొత్త పత్రాన్ని మీ కోఆర్డినేటర్‌కు ఇవ్వండి.';

  @override
  String blockedExpiredOn(String date) {
    return 'సర్టిఫికేట్ గడువు $dateన ముగిసింది.';
  }

  @override
  String get blockedSuspended =>
      'మీ ప్రొవైడర్ ఖాతా సస్పెండ్ చేయబడింది. వివరాల కోసం మీ కేర్ కోఆర్డినేటర్‌ను సంప్రదించండి.';

  @override
  String get blockedRejected =>
      'మీ ధృవీకరణ ఆమోదించబడలేదు. దయచేసి మీ కేర్ కోఆర్డినేటర్‌ను సంప్రదించండి.';

  @override
  String get blockedCheckAgain => 'స్థితిని మళ్ళీ చూడండి';

  @override
  String homeGreeting(String name) {
    return 'నమస్తే, $name';
  }

  @override
  String get homeDutyOn => 'డ్యూటీలో';

  @override
  String get homeDutyOff => 'డ్యూటీలో లేరు';

  @override
  String get homeDutyOnHint => 'మీకు కొత్త హోమ్ విజిట్లు కేటాయించవచ్చు.';

  @override
  String get homeDutyOffHint => 'కొత్త హోమ్ విజిట్ల కోసం డ్యూటీలోకి రండి.';

  @override
  String get homeDutyToggleLabel => 'డ్యూటీ స్థితి';

  @override
  String get homeDutyFailed =>
      'డ్యూటీ స్థితి మార్చలేకపోయాం. మీరు ఆన్‌లైన్‌లో ఉండాలి.';

  @override
  String get homeTodaySummary => 'ఈరోజు';

  @override
  String get homeSummaryTotal => 'విజిట్లు';

  @override
  String get homeSummaryActive => 'యాక్టివ్';

  @override
  String get homeSummaryDone => 'పూర్తి';

  @override
  String homeNextVisit(String time) {
    return 'తదుపరి: $time';
  }

  @override
  String get tabToday => 'ఈరోజు';

  @override
  String get tabUpcoming => 'రాబోయే';

  @override
  String get tabCompleted => 'పూర్తయినవి';

  @override
  String get visitsEmptyToday => 'ఈరోజు విజిట్లు లేవు.';

  @override
  String get visitsEmptyUpcoming => 'రాబోయే విజిట్లు లేవు.';

  @override
  String get visitsEmptyCompleted => 'ఇంకా పూర్తయిన విజిట్లు లేవు.';

  @override
  String get visitsShowingCached => 'ఆఫ్‌లైన్ – సేవ్ చేసిన డేటా చూపుతున్నాం';

  @override
  String get profileTooltip => 'ప్రొఫైల్';

  @override
  String get offlineBanner =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. చర్యలు సేవ్ అయి తర్వాత సింక్ అవుతాయి.';

  @override
  String pendingSync(int count) {
    return 'సింక్ పెండింగ్ ($count)';
  }

  @override
  String get syncNow => 'ఇప్పుడే సింక్ చేయి';

  @override
  String get syncAccessRevoked =>
      'ఒక విజిట్ ఇప్పుడు మీకు కేటాయించబడలేదు. దాని సింక్ కాని మార్పులు తొలగించబడ్డాయి మరియు సేవ్ చేసిన రోగి డేటా తీసివేయబడింది.';

  @override
  String syncRejected(String message) {
    return 'సేవ్ చేసిన ఒక చర్యను సర్వర్ అంగీకరించలేదు: $message';
  }

  @override
  String get actionQueued =>
      'ఆఫ్‌లైన్‌లో సేవ్ అయింది. ఆన్‌లైన్‌కి వచ్చాక సింక్ అవుతుంది.';

  @override
  String get actionDone => 'అప్‌డేట్ అయింది';

  @override
  String get statusRequested => 'అభ్యర్థించబడింది';

  @override
  String get statusUnassigned => 'కేటాయించలేదు';

  @override
  String get statusAssigned => 'కొత్త కేటాయింపు';

  @override
  String get statusAccepted => 'అంగీకరించారు';

  @override
  String get statusEnRoute => 'దారిలో';

  @override
  String get statusArrived => 'చేరుకున్నారు';

  @override
  String get statusInProgress => 'జరుగుతోంది';

  @override
  String get statusCompleted => 'పూర్తయింది';

  @override
  String get statusCancelled => 'రద్దయింది';

  @override
  String get statusEscalated => 'ఎస్కలేట్ చేయబడింది';

  @override
  String get visitTitle => 'హోమ్ విజిట్';

  @override
  String get visitTimeWindow => 'సమయం';

  @override
  String get visitReason => 'విజిట్ కారణం';

  @override
  String get visitAddress => 'చిరునామా';

  @override
  String visitAreaOnly(String city, String pincode) {
    return '$city – $pincode';
  }

  @override
  String get visitAddressHidden =>
      'విజిట్ అంగీకరించిన తర్వాత పూర్తి చిరునామా కనిపిస్తుంది.';

  @override
  String visitLandmark(String landmark) {
    return 'ల్యాండ్‌మార్క్: $landmark';
  }

  @override
  String get visitNavigate => 'నావిగేట్ చేయి';

  @override
  String get visitNavigateFailed => 'మ్యాప్స్ తెరవలేకపోయాం.';

  @override
  String get visitPatient => 'రోగి';

  @override
  String get visitPatientContext => 'రోగి సమాచారం';

  @override
  String visitAgeGender(String age, String gender) {
    return '$age సం. · $gender';
  }

  @override
  String get visitAllergies => 'అలర్జీలు';

  @override
  String get visitNoAllergiesRecorded => 'అలర్జీలు నమోదు కాలేదు';

  @override
  String get visitConditions => 'ఆరోగ్య పరిస్థితులు';

  @override
  String get visitMedications => 'వాడుతున్న మందులు';

  @override
  String get visitNoneRecorded => 'ఏమీ నమోదు కాలేదు';

  @override
  String get visitContextUnavailable =>
      'ఈ విజిట్‌కు రోగి సమాచారం అందుబాటులో లేదు.';

  @override
  String get visitTimeline => 'స్థితి టైమ్‌లైన్';

  @override
  String get visitPendingSyncChip => 'సింక్ పెండింగ్';

  @override
  String visitEta(int minutes) {
    return 'ETA $minutes నిమి';
  }

  @override
  String get visitNotFound => 'ఈ విజిట్ ఇప్పుడు మీకు అందుబాటులో లేదు.';

  @override
  String get visitRecordedVitals => 'నమోదైన వైటల్స్';

  @override
  String get visitSummary => 'విజిట్ సారాంశం';

  @override
  String get visitEscalation => 'ఎస్కలేషన్';

  @override
  String get stepAccept => 'అంగీకారం';

  @override
  String get stepTravel => 'ప్రయాణం';

  @override
  String get stepArrive => 'చేరిక';

  @override
  String get stepVerify => 'ధృవీకరణ';

  @override
  String get stepCare => 'పరీక్ష';

  @override
  String get stepComplete => 'పూర్తి';

  @override
  String stepperLabel(int current, int total) {
    return 'విజిట్ పురోగతి: దశ $current / $total';
  }

  @override
  String get actionAccept => 'విజిట్ అంగీకరించండి';

  @override
  String get actionReject => 'తిరస్కరించండి';

  @override
  String get actionRejectTitle => 'ఈ విజిట్‌ను తిరస్కరించాలా?';

  @override
  String get actionRejectReason => 'కారణం';

  @override
  String get actionRejectReasonRequired => 'దయచేసి కారణం ఇవ్వండి';

  @override
  String get actionStartTravel => 'ప్రయాణం ప్రారంభించండి';

  @override
  String get actionEtaLabel => 'చేరే అంచనా సమయం (నిమిషాలు)';

  @override
  String get actionEtaInvalid => '1 నుండి 240 మధ్య నిమిషాలు ఇవ్వండి';

  @override
  String get actionArrived => 'నేను చేరుకున్నాను';

  @override
  String get actionVerifyTitle => 'రోగి ధృవీకరణ';

  @override
  String get actionVerifyBody =>
      'రోగి లేదా సంరక్షకుడిని వారి యాప్‌లో కనిపించే 4 అంకెల విజిట్ కోడ్ చదవమని అడగండి.';

  @override
  String get actionVisitCode => 'విజిట్ కోడ్';

  @override
  String get actionVisitCodeInvalid => '4 అంకెల కోడ్ ఇవ్వండి';

  @override
  String get actionConsent => 'రోగి/సంరక్షకుడు పరీక్షకు అంగీకరిస్తున్నారు';

  @override
  String get actionConsentRequired =>
      'ప్రారంభించే ముందు అంగీకారం నిర్ధారించాలి';

  @override
  String get actionVerify => 'ధృవీకరించి పరీక్ష ప్రారంభించండి';

  @override
  String get actionVerifyOfflineNote =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. మళ్ళీ కనెక్ట్ అయ్యాక కోడ్ తనిఖీ అవుతుంది.';

  @override
  String get actionComplete => 'విజిట్ పూర్తి చేయండి';

  @override
  String get actionCompleteTitle => 'విజిట్ పూర్తి చేయండి';

  @override
  String get actionSummaryLabel => 'విజిట్ సారాంశం';

  @override
  String get actionSummaryHint =>
      'ఏమి చేశారు, రోగికి చెప్పిన విషయాలు, ఏదైనా ఫాలో-అప్';

  @override
  String get actionSummaryRequired => 'దయచేసి చిన్న సారాంశం రాయండి';

  @override
  String get nextAwaitingAssignment => 'కేటాయింపు కోసం వేచి ఉంది.';

  @override
  String get nextNoAction => 'ఇంకే చర్యా అవసరం లేదు.';

  @override
  String get nextCancelled => 'ఈ విజిట్ రద్దు చేయబడింది.';

  @override
  String get nextReassigned => 'ఈ విజిట్ ఇప్పుడు మీకు కేటాయించబడలేదు.';

  @override
  String get nextVerifyIntro =>
      'ప్రారంభించే ముందు రోగి గుర్తింపు మరియు అంగీకారం ధృవీకరించండి.';

  @override
  String get nextCareIntro =>
      'వైటల్స్ మరియు పరిశీలనలు నమోదు చేసి, విజిట్ పూర్తి చేయండి.';

  @override
  String get nextEscalatedIntro =>
      'ఈ విజిట్ ఎస్కలేట్ చేయబడింది. మీరు ఇప్పటికీ దాన్ని పూర్తి చేయవచ్చు.';

  @override
  String get escalateButton => 'ఎస్కలేట్ చేయండి';

  @override
  String get escalateTitle => 'సూపర్వైజింగ్ డాక్టర్‌కు ఎస్కలేట్ చేయండి';

  @override
  String get escalateReason => 'ఆందోళన ఏమిటి?';

  @override
  String get escalateReasonRequired => 'దయచేసి ఆందోళనను వివరించండి';

  @override
  String get escalateSeverity => 'తీవ్రత';

  @override
  String get escalateUrgent => 'అత్యవసరం';

  @override
  String get escalateEmergency => 'ఎమర్జెన్సీ';

  @override
  String get escalateEmergencyHint =>
      'ప్రాణాపాయ పరిస్థితిలో వెంటనే 108కి కాల్ చేయండి.';

  @override
  String get escalateCall108 => '108కి కాల్ చేయండి';

  @override
  String get escalateConfirmTitle => 'ఎస్కలేషన్ నిర్ధారించండి';

  @override
  String escalateConfirmBody(String severity) {
    return 'ఇది క్లినికల్ టీమ్‌కు తీవ్రత $severityతో వెంటనే హెచ్చరిక పంపుతుంది. కొనసాగించాలా?';
  }

  @override
  String get escalateSend => 'ఎస్కలేషన్ పంపండి';

  @override
  String get vitalsTitle => 'వైటల్స్';

  @override
  String get vitalsSave => 'వైటల్స్ సేవ్ చేయండి';

  @override
  String get vitalsSaved => 'వైటల్స్ సేవ్ అయ్యాయి';

  @override
  String get vitalsBpSystolic => 'BP సిస్టోలిక్';

  @override
  String get vitalsBpDiastolic => 'BP డయాస్టోలిక్';

  @override
  String get vitalsPulse => 'నాడి';

  @override
  String get vitalsSpo2 => 'SpO2';

  @override
  String get vitalsTemperature => 'ఉష్ణోగ్రత';

  @override
  String get vitalsBloodGlucose => 'బ్లడ్ గ్లూకోజ్';

  @override
  String get vitalsWeight => 'బరువు';

  @override
  String get vitalsRespiratoryRate => 'శ్వాస రేటు';

  @override
  String get vitalsErrorNumber => 'ఒక సంఖ్య ఇవ్వండి';

  @override
  String vitalsErrorRange(String min, String max) {
    return '$min మరియు $max మధ్య ఉండాలి';
  }

  @override
  String get vitalsErrorBpPair => 'సిస్టోలిక్ మరియు డయాస్టోలిక్ రెండూ ఇవ్వండి';

  @override
  String get vitalsErrorBpOrder =>
      'డయాస్టోలిక్ సిస్టోలిక్ కంటే తక్కువగా ఉండాలి';

  @override
  String get vitalsErrorEmpty => 'కనీసం ఒక వైటల్ ఇవ్వండి';

  @override
  String get vitalsNoInterpretation =>
      'పెద్దల సాధారణ పరిధికి బయట ఉన్న విలువలు ఎక్కువ లేదా తక్కువ అని హైలైట్ అవుతాయి. క్లినికల్ సమీక్ష కేర్ టీమ్ చేస్తుంది.';

  @override
  String get obsTitle => 'పరిశీలనలు';

  @override
  String get obsAlertOriented => 'రోగి అప్రమత్తంగా, స్పృహతో ఉన్నారు';

  @override
  String get obsMedicationsReviewed => 'మందులు సమీక్షించబడ్డాయి';

  @override
  String get obsMobilityObserved => 'కదలికలు పరిశీలించబడ్డాయి';

  @override
  String get obsCaregiverPresent => 'సంరక్షకుడు ఉన్నారు';

  @override
  String get obsHomeSafe => 'ఇంటి వాతావరణం సురక్షితం';

  @override
  String get obsConcernsNoted => 'రోగి ఆందోళనలు నమోదు చేయబడ్డాయి';

  @override
  String get obsNotes => 'నోట్స్';

  @override
  String get obsNotesHint => 'వాస్తవ పరిశీలనలు మాత్రమే';

  @override
  String get obsSave => 'పరిశీలనలు సేవ్ చేయండి';

  @override
  String get obsSaved => 'పరిశీలనలు సేవ్ అయ్యాయి';

  @override
  String get profileTitle => 'ప్రొఫైల్';

  @override
  String get profileType => 'పాత్ర';

  @override
  String get profileQualification => 'అర్హత';

  @override
  String get profileVerification => 'ధృవీకరణ';

  @override
  String get profileCredentialExpiry => 'సర్టిఫికేట్ చెల్లుబాటు';

  @override
  String profileCredentialExpiring(int days) {
    return 'మీ సర్టిఫికేట్ $days రోజుల్లో ముగుస్తుంది. విజిట్లు అందుకుంటూ ఉండటానికి రెన్యూ చేయండి.';
  }

  @override
  String get profileZones => 'సేవా ప్రాంతాలు';

  @override
  String get profileCapabilities => 'సామర్థ్యాలు';

  @override
  String get profileLanguage => 'భాష';

  @override
  String get profilePhone => 'ఫోన్';

  @override
  String get profileLogoutConfirm => 'లాగ్ అవుట్ చేయాలా?';

  @override
  String profileLogoutPending(int count) {
    return 'ఇప్పుడు లాగ్ అవుట్ చేస్తే $count సింక్ కాని చర్యలు తొలగిపోతాయి.';
  }

  @override
  String get profileLogoutBody =>
      'ఈ పరికరంలో సేవ్ చేసిన విజిట్ డేటా తీసివేయబడుతుంది.';

  @override
  String get typeNurse => 'నర్స్';

  @override
  String get typeTechnician => 'టెక్నీషియన్';

  @override
  String get typeIntern => 'ఇంటర్న్';

  @override
  String get typePhysiotherapist => 'ఫిజియోథెరపిస్ట్';

  @override
  String get verificationVerified => 'ధృవీకరించబడింది';

  @override
  String get verificationPending => 'పెండింగ్';

  @override
  String get verificationRejected => 'తిరస్కరించబడింది';

  @override
  String get verificationSuspended => 'సస్పెండ్ చేయబడింది';

  @override
  String get verificationExpired => 'గడువు ముగిసింది';

  @override
  String get genderMale => 'పురుషుడు';

  @override
  String get genderFemale => 'స్త్రీ';

  @override
  String get genderOther => 'ఇతర';

  @override
  String get errorMfaRequired =>
      'ఈ ఖాతాకు రెండు-దశల ధృవీకరణ అవసరం, ఇది ప్రొవైడర్ యాప్‌లో లేదు. దయచేసి సహాయాన్ని సంప్రదించండి.';

  @override
  String get mfaTitle => 'అదనపు ధృవీకరణ అవసరం';

  @override
  String get mfaBody =>
      'మీ ఖాతాకు రెండు-దశల ధృవీకరణ (MFA) అవసరంగా సెట్ చేయబడింది. కేర్‌కంపానియన్ ప్రో ప్రొవైడర్ ఖాతాలకు దీనిని సపోర్ట్ చేయదు. మీ ఖాతాను సరిచేయడానికి మీ కోఆర్డినేటర్ లేదా సహాయ బృందాన్ని సంప్రదించండి. క్యూలో ఉన్న మీ విజిట్ అప్‌డేట్‌లు ఈ పరికరంలో భద్రంగా ఉన్నాయి.';

  @override
  String get updateTitle => 'అప్‌డేట్ అవసరం';

  @override
  String get updateBody =>
      'కేర్‌కంపానియన్ ప్రో యొక్క ఈ వెర్షన్‌కు ఇకపై సపోర్ట్ లేదు. విజిట్‌లు అందుకుంటూ ఉండటానికి దయచేసి తాజా వెర్షన్‌ను ఇన్‌స్టాల్ చేయండి.';

  @override
  String updateVersions(String current, String minimum) {
    return 'ఇన్‌స్టాల్ చేసినది $current · అవసరమైనది $minimum';
  }

  @override
  String get updateNow => 'ఇప్పుడే అప్‌డేట్ చేయండి';

  @override
  String get photoAdd => 'ఫోటో జోడించండి';

  @override
  String get photoSectionTitle => 'విజిట్ ఫోటో (ఐచ్ఛికం)';

  @override
  String get photoSectionHint =>
      'సంరక్షణకు సహాయపడితేనే (ఉదా. గాయం లేదా పరికరం). రోగి అంగీకారం అవసరం.';

  @override
  String get photoConsentTitle => 'రోగి అంగీకారం';

  @override
  String get photoConsentBody =>
      'ఫోటో రోగి ఆరోగ్య రికార్డులో సేవ్ చేయబడుతుంది. ముఖాలు మరియు సంరక్షణకు అవసరం లేనివి తీయవద్దు.';

  @override
  String get photoConsent =>
      'ఈ ఫోటో తీసి వారి రికార్డులో సేవ్ చేయడానికి రోగి (లేదా వారి సంరక్షకులు) అంగీకరించారు.';

  @override
  String get photoConsentRequired => 'ఫోటో తీసే ముందు రోగి అంగీకారం అవసరం.';

  @override
  String get photoOpenCamera => 'కెమెరా తెరవండి';

  @override
  String get photoUploaded => 'ఫోటో రోగి రికార్డులో అప్‌లోడ్ అయింది.';

  @override
  String get photoQueued =>
      'ఫోటో సేవ్ అయింది. మీరు ఆన్‌లైన్‌లోకి వచ్చినప్పుడు అప్‌లోడ్ అవుతుంది.';

  @override
  String get photoNoPermission =>
      'ఈ రోగి రికార్డులో ఫోటోలు జోడించడానికి మీకు అనుమతి లేదు. దయచేసి మీ కోఆర్డినేటర్‌ను సంప్రదించండి.';

  @override
  String get photoFileMissing =>
      'క్యూలో ఉన్న ఒక ఫోటో ఈ పరికరంలో లేనందున అప్‌లోడ్ కాలేదు. దయచేసి మళ్లీ తీయండి.';

  @override
  String get photoCameraFailed => 'కెమెరా తెరవలేకపోయాం.';

  @override
  String get profileSupport => 'సహాయం';

  @override
  String get profileSupportCall => 'సహాయానికి కాల్ చేయండి';

  @override
  String get profileSupportEmail => 'సహాయానికి ఇమెయిల్ చేయండి';

  @override
  String get profileSupportWhatsapp => 'వాట్సాప్ సహాయం';

  @override
  String get profileSupportUnavailable =>
      'సహాయ సంప్రదింపులు ప్రస్తుతం అందుబాటులో లేవు. దయచేసి మీ కోఆర్డినేటర్‌ను సంప్రదించండి.';

  @override
  String get profilePrivacy => 'గోప్యతా విధానం';

  @override
  String get profileTerms => 'సేవా నిబంధనలు';

  @override
  String get profileAccount => 'ఖాతా';

  @override
  String get profileCloseAccount => 'ఖాతా మూసివేత అభ్యర్థన';

  @override
  String get profileCloseAccountBody =>
      'ప్రొవైడర్ ఖాతాలు సిబ్బంది ఖాతాలు, యాప్ నుండి తొలగించలేరు. మూసివేత కోసం సహాయాన్ని సంప్రదించండి: ఒక నిర్వాహకుడు మీ ఖాతాను నిలిపివేసి, మీ డేటాను రిటెన్షన్ విధానం ప్రకారం నిర్వహిస్తారు.';

  @override
  String get profileCloseAccountSubject => 'ప్రొవైడర్ ఖాతా మూసివేత అభ్యర్థన';

  @override
  String get profileLinkFailed => 'లింక్ తెరవలేకపోయాం.';

  @override
  String profileAppVersion(String version) {
    return 'వెర్షన్ $version';
  }

  @override
  String get commonDelete => 'తొలగించు';

  @override
  String get typeDoctor => 'డాక్టర్';

  @override
  String get onbTitle => 'కేర్ ప్రొవైడర్‌గా చేరడానికి దరఖాస్తు చేయండి';

  @override
  String get onbIntro =>
      'ఈ ఖాతా ఇంకా కేర్ ప్రొవైడర్‌గా నమోదు కాలేదు. కింద దరఖాస్తు చేయండి: ఏ విజిట్ కేటాయించే ముందు అయినా మా బృందం ప్రతి ప్రొవైడర్‌ను ధృవీకరిస్తుంది.';

  @override
  String get onbEditTitle => 'మీ దరఖాస్తును సవరించండి';

  @override
  String get onbStepRole => 'పాత్ర';

  @override
  String get onbStepDetails => 'అర్హత';

  @override
  String get onbStepAreas => 'భాషలు మరియు ప్రాంతాలు';

  @override
  String get onbStepReview => 'సమీక్ష';

  @override
  String get onbTypeLabel => 'నేను ఈ పాత్రకు దరఖాస్తు చేస్తున్నాను';

  @override
  String get onbDoctorNote =>
      'ఆమోదం తర్వాత డాక్టర్లు ఈ యాప్ కాకుండా CareCompanion వెబ్ పోర్టల్‌ను ఉపయోగిస్తారు. మీరు ఇక్కడే దరఖాస్తు చేయవచ్చు.';

  @override
  String get onbFullName => 'పూర్తి పేరు (నమోదులో ఉన్నట్లు)';

  @override
  String get onbQualification => 'అర్హత (ఉదా. GNM, B.Sc నర్సింగ్, DMLT)';

  @override
  String get onbRegNumber => 'నమోదు సంఖ్య';

  @override
  String get onbRegCouncil => 'నమోదు కౌన్సిల్ (ఐచ్ఛికం)';

  @override
  String get onbSpecialty => 'ప్రత్యేకత';

  @override
  String get onbExperience => 'అనుభవం (సంవత్సరాలు)';

  @override
  String get onbRequired => 'తప్పనిసరి';

  @override
  String get onbExperienceInvalid => '0 నుండి 60 మధ్య సంవత్సరాలు నమోదు చేయండి';

  @override
  String get onbLanguages => 'మీరు మాట్లాడే భాషలు';

  @override
  String get onbLanguagesRequired => 'కనీసం ఒక భాషను ఎంచుకోండి';

  @override
  String get onbAreas => 'ఇష్టమైన పని ప్రాంతాలు';

  @override
  String get onbAreasHint =>
      'మీరు పని చేయాలనుకునే పిన్‌కోడ్‌లను జోడించండి. ప్రతి పిన్‌కోడ్ మా సేవా జోన్‌లలో ఒకదానికి సరిపోల్చబడుతుంది. ఐచ్ఛికం.';

  @override
  String get onbPincode => 'పిన్‌కోడ్';

  @override
  String get onbPincodeInvalid => '6 అంకెల పిన్‌కోడ్ నమోదు చేయండి';

  @override
  String get onbAddArea => 'జోడించు';

  @override
  String get onbZoneSaved => 'సేవ్ చేసిన ప్రాంతం';

  @override
  String onbAreaNotServiceable(String pincode) {
    return 'మేము ఇంకా పిన్‌కోడ్ $pincodeలో సేవలు అందించడం లేదు. మీరు అయినా దరఖాస్తు చేయవచ్చు.';
  }

  @override
  String get onbReviewDocsNote =>
      'సమర్పించిన తర్వాత మీ పత్రాలను అప్‌లోడ్ చేయండి. ఆమోదానికి నమోదు ధృవపత్రం మరియు గుర్తింపు రుజువు తప్పనిసరి.';

  @override
  String get onbNext => 'తదుపరి';

  @override
  String get onbSubmit => 'దరఖాస్తు సమర్పించండి';

  @override
  String get onbResubmit => 'దరఖాస్తును మళ్లీ సమర్పించండి';

  @override
  String get onbSubmitted => 'దరఖాస్తు సమర్పించబడింది';

  @override
  String get onbCancelEdit => 'సవరణ రద్దు చేయండి';

  @override
  String get onbStatusSubmittedTitle => 'దరఖాస్తు సమీక్షలో ఉంది';

  @override
  String get onbStatusSubmittedBody =>
      'మా బృందం మీ దరఖాస్తును సమీక్షిస్తోంది. నిర్ణయం వచ్చినప్పుడు మీకు తెలియజేస్తాము.';

  @override
  String get onbStatusChangesTitle => 'మార్పులు కోరబడ్డాయి';

  @override
  String get onbStatusChangesBody =>
      'సమీక్షకులు మార్పులు కోరారు. మీ వివరాలు లేదా పత్రాలను నవీకరించి, మళ్లీ సమర్పించండి.';

  @override
  String get onbStatusRejectedTitle => 'దరఖాస్తు ఆమోదించబడలేదు';

  @override
  String get onbStatusRejectedBody =>
      'మీ దరఖాస్తు ఆమోదించబడలేదు. ప్రశ్నలు ఉంటే సహాయాన్ని సంప్రదించండి.';

  @override
  String get onbReviewerNote => 'సమీక్షకుల గమనిక';

  @override
  String onbReviewerNoteBy(String name) {
    return '$name నుండి గమనిక';
  }

  @override
  String get onbEditResubmit => 'సవరించి మళ్లీ సమర్పించండి';

  @override
  String get onbEditDetails => 'వివరాలు సవరించండి';

  @override
  String get onbApprovedTitle => 'మీరు ఆమోదించబడ్డారు';

  @override
  String get onbApprovedBody =>
      'మీ దరఖాస్తు ఆమోదించబడింది. ప్రారంభించడానికి లాగ్ అవుట్ చేసి మళ్లీ సైన్ ఇన్ చేయండి.';

  @override
  String get onbApprovedDoctorBody =>
      'మీ డాక్టర్ ఖాతా ఆమోదించబడింది. మీ షెడ్యూల్ సెట్ చేయడానికి CareCompanion వెబ్ పోర్టల్‌లో సైన్ ఇన్ చేయండి.';

  @override
  String get onbSignOutAndIn => 'లాగ్ అవుట్ చేసి మళ్లీ సైన్ ఇన్ చేయండి';

  @override
  String get onbCheckStatus => 'స్థితి తనిఖీ చేయండి';

  @override
  String onbUpdatedOn(String date) {
    return 'చివరి నవీకరణ $date';
  }

  @override
  String get onbDocuments => 'పత్రాలు';

  @override
  String onbDocsMissing(String docs) {
    return 'ఇంకా అవసరం: $docs';
  }

  @override
  String get onbDocsComplete => 'అవసరమైన అన్ని పత్రాలు అప్‌లోడ్ అయ్యాయి.';

  @override
  String get onbDocsHint => 'PDF, JPG లేదా PNG, ఒక్కొక్కటి 10 MB వరకు.';

  @override
  String get onbNoDocuments => 'ఇంకా పత్రాలు ఏవీ అప్‌లోడ్ కాలేదు.';

  @override
  String get onbAddDocument => 'పత్రం జోడించండి';

  @override
  String get onbDocType => 'పత్రం రకం';

  @override
  String get docRegistrationCertificate => 'నమోదు ధృవపత్రం';

  @override
  String get docDegree => 'డిగ్రీ లేదా డిప్లొమా';

  @override
  String get docIdProof => 'గుర్తింపు రుజువు';

  @override
  String get docExperienceLetter => 'అనుభవ లేఖ';

  @override
  String get docOther => 'ఇతర';

  @override
  String get sourceCamera => 'ఫోటో తీయండి';

  @override
  String get sourceGallery => 'గ్యాలరీ నుండి ఎంచుకోండి';

  @override
  String get sourceFiles => 'ఫైల్ ఎంచుకోండి (PDF, JPG, PNG)';

  @override
  String onbUploading(int percent) {
    return 'అప్‌లోడ్ అవుతోంది… $percent%';
  }

  @override
  String onbUploadFailed(String error) {
    return 'అప్‌లోడ్ విఫలమైంది: $error';
  }

  @override
  String get onbFileTooLarge => 'ఈ ఫైల్ 10 MB కంటే పెద్దది.';

  @override
  String get onbDeleteDocConfirm => 'ఈ పత్రాన్ని తొలగించాలా?';

  @override
  String get earnTitle => 'ఆదాయం';

  @override
  String get earnEntrySubtitle => 'పూర్తైన సేవలు మరియు చెల్లింపులు';

  @override
  String get earnCompleted => 'పూర్తైన సేవలు';

  @override
  String get earnGross => 'స్థూల మొత్తం';

  @override
  String get earnPlatformFee => 'ప్లాట్‌ఫారమ్ రుసుము';

  @override
  String get earnRefunds => 'రీఫండ్‌లు';

  @override
  String get earnPayable => 'మీకు చెల్లించవలసినది';

  @override
  String get earnLines => 'సేవలు';

  @override
  String get earnEmpty => 'ఈ నెలలో పూర్తై చెల్లించిన సేవలు లేవు.';

  @override
  String get earnPrevMonth => 'మునుపటి నెల';

  @override
  String get earnNextMonth => 'తదుపరి నెల';

  @override
  String get earnNote =>
      'పూర్తై చెల్లించిన సేవలు మాత్రమే లెక్కించబడతాయి. చెల్లింపులను ఆపరేషన్స్ బృందం పరిష్కరిస్తుంది.';

  @override
  String get earnRefHomeVisit => 'హోమ్ విజిట్';

  @override
  String get earnRefAppointment => 'అపాయింట్‌మెంట్';

  @override
  String earnLineDetail(String fee, String payable) {
    return 'రుసుము $fee · చెల్లించవలసినది $payable';
  }

  @override
  String get avatarChange => 'ప్రొఫైల్ ఫోటో మార్చండి';

  @override
  String get avatarPreviewTitle => 'ఈ ఫోటోను ఉపయోగించాలా?';

  @override
  String get avatarPreviewBody =>
      'మీకు వారి విజిట్ కేటాయించినప్పుడు రోగులు ఈ ఫోటోను చూస్తారు.';

  @override
  String get avatarUse => 'ఫోటో ఉపయోగించండి';

  @override
  String get avatarUploaded => 'ప్రొఫైల్ ఫోటో నవీకరించబడింది';

  @override
  String get avatarTooLarge => 'ఫోటో 5 MB కంటే చిన్నదిగా ఉండాలి.';

  @override
  String profileRating(String rating, int count) {
    return '$rating ★ ($count రేటింగ్‌లు)';
  }

  @override
  String get voiceDictate => 'నోట్స్ మాట్లాడి రాయండి';

  @override
  String get voiceStop => 'డిక్టేషన్ ఆపండి';

  @override
  String get voiceListening => 'వింటోంది… ఇప్పుడు మాట్లాడండి';

  @override
  String get voiceReview =>
      'మాట్లాడిన వచనం నోట్స్‌కు జోడించబడింది. సేవ్ చేసే ముందు దాన్ని సమీక్షించి సరిదిద్దండి.';

  @override
  String get voiceUnavailable =>
      'ఈ పరికరంలో వాయిస్ ఇన్‌పుట్ అందుబాటులో లేదు, లేదా మైక్రోఫోన్ అనుమతి నిరాకరించబడింది.';

  @override
  String get typeDietitian => 'డైటీషియన్';

  @override
  String get tabRoute => 'రూట్';

  @override
  String get optionalHint => 'ఐచ్ఛికం';

  @override
  String planFor(String name) {
    return '$name కోసం';
  }

  @override
  String get routeEmpty => 'ఈరోజు మీ రూట్‌లో స్టాప్‌లు లేవు.';

  @override
  String routeSummary(int count, String km) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count స్టాప్‌లు',
      one: '1 స్టాప్',
    );
    return '$_temp0 · మొత్తం $km కి.మీ.';
  }

  @override
  String get routeFromLastLocation =>
      'దూరాలు మీరు చివరగా పంపిన లొకేషన్ నుండి లెక్కించబడ్డాయి.';

  @override
  String get routeFromCurrentLocation =>
      'దూరాలు మీ సేవా ప్రాంత కేంద్రం నుండి లెక్కించబడ్డాయి.';

  @override
  String get routeStartNavigation => 'నావిగేషన్ ప్రారంభించండి';

  @override
  String routeTooManyStops(int count) {
    return 'Google Maps మొదటి $count స్టాప్‌లను చూపిస్తుంది. వాటి తర్వాత నావిగేషన్‌ను మళ్లీ తెరవండి.';
  }

  @override
  String routeFromStart(String km) {
    return 'ప్రారంభం నుండి $km కి.మీ.';
  }

  @override
  String routeFromPrev(String km) {
    return 'మునుపటి స్టాప్ నుండి $km కి.మీ.';
  }

  @override
  String routeEta(String time) {
    return 'చేరే సమయం $time';
  }

  @override
  String routeStopLabel(
    int index,
    String service,
    String window,
    String details,
  ) {
    return 'స్టాప్ $index: $service, $window. $details';
  }

  @override
  String get attTitle => 'హాజరు';

  @override
  String get attUnknown => 'హాజరు స్థితి అందుబాటులో లేదు';

  @override
  String get attNotCheckedIn => 'ఈరోజు చెక్-ఇన్ చేయలేదు';

  @override
  String get attNotCheckedInHint =>
      'మీ షిఫ్ట్ ప్రారంభించినప్పుడు చెక్-ఇన్ చేయండి.';

  @override
  String attCheckedInAt(String time) {
    return '$timeకి చెక్-ఇన్ అయ్యారు';
  }

  @override
  String attCheckedOutAt(String time) {
    return '$timeకి చెక్-అవుట్ అయ్యారు';
  }

  @override
  String get attCheckIn => 'చెక్-ఇన్';

  @override
  String get attCheckOut => 'చెక్-అవుట్';

  @override
  String get attCheckedInToast => 'చెక్-ఇన్ అయింది.';

  @override
  String get attCheckedOutToast => 'చెక్-అవుట్ అయింది.';

  @override
  String get attNoLocation => '(లొకేషన్ అందుబాటులో లేదు.)';

  @override
  String get attDaysPresent => 'హాజరైన రోజులు';

  @override
  String get attHours => 'గంటలు';

  @override
  String get attVisits => 'విజిట్‌లు';

  @override
  String get attDaily => 'రోజువారీగా';

  @override
  String get attEmpty => 'ఈ నెలలో హాజరు నమోదు కాలేదు.';

  @override
  String get attAbsent => 'చెక్-ఇన్ లేదు';

  @override
  String get attOpen => 'చెక్-అవుట్ చేయలేదు';

  @override
  String attHoursShort(String hours) {
    return '$hours గం.';
  }

  @override
  String attVisitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count విజిట్‌లు',
      one: '1 విజిట్',
      zero: 'విజిట్‌లు లేవు',
    );
    return '$_temp0';
  }

  @override
  String get supTitle => 'సామాగ్రి';

  @override
  String get supEmpty => 'మీకు సామాగ్రి కేటాయించబడలేదు.';

  @override
  String supLowBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count వస్తువులు తక్కువగా ఉన్నాయి. తిరిగి నింపమని కోఆర్డినేటర్‌ను అడగండి.',
      one: '1 వస్తువు తక్కువగా ఉంది. తిరిగి నింపమని కోఆర్డినేటర్‌ను అడగండి.',
    );
    return '$_temp0';
  }

  @override
  String get supLow => 'స్టాక్ తక్కువ';

  @override
  String get supOut => 'స్టాక్ అయిపోయింది';

  @override
  String supReorderAt(String qty) {
    return '$qty వద్ద మళ్లీ ఆర్డర్ చేయండి';
  }

  @override
  String supOnHand(String qty) {
    return 'చేతిలో: $qty';
  }

  @override
  String get supUsageTitle => 'వాడిన సామాగ్రి';

  @override
  String get supUsageHint =>
      'ఈ విజిట్‌లో వాడిన వాటిని నమోదు చేయండి. ఆఫ్‌లైన్‌లో ఉన్నా సేవ్ అవుతుంది.';

  @override
  String get supUsageCardBody =>
      'ఈ విజిట్‌లో వాడిన గ్లౌజులు, స్ట్రిప్‌లు, స్వాబ్‌లు మొదలైనవి నమోదు చేయండి.';

  @override
  String get supUsageButton => 'వాడిన సామాగ్రిని నమోదు చేయండి';

  @override
  String get supUsageSave => 'సేవ్ చేయండి';

  @override
  String get supUsageSaved => 'సామాగ్రి వినియోగం సేవ్ అయింది';

  @override
  String supIncrease(String name) {
    return 'ఒక $name జోడించండి';
  }

  @override
  String supDecrease(String name) {
    return 'ఒక $name తీసివేయండి';
  }

  @override
  String get sampleTestsTitle => 'సేకరించాల్సిన ల్యాబ్ పరీక్షలు';

  @override
  String get sampleGeneric => 'ల్యాబ్ ఆర్డర్ ప్రకారం శాంపిల్స్ సేకరించండి.';

  @override
  String get sampleFastingShort => 'ఉపవాసం';

  @override
  String get sampleFastingRequired =>
      'ఉపవాసం అవసరం. శాంపిల్ తీసుకునే ముందు రోగితో నిర్ధారించండి.';

  @override
  String sampleFastingHours(int hours) {
    return 'ఉపవాసం అవసరం ($hours గం.). శాంపిల్ తీసుకునే ముందు రోగితో నిర్ధారించండి.';
  }

  @override
  String get sampleNoFasting => 'ఈ పరీక్షలకు ఉపవాసం అవసరం లేదు.';

  @override
  String get sampleChecklistTitle => 'పూర్తి చేసే ముందు: శాంపిల్ చెక్‌లిస్ట్';

  @override
  String get samplePatientId => 'రోగి గుర్తింపు ధృవీకరించబడింది';

  @override
  String get sampleFastingConfirmed => 'రోగితో ఉపవాస స్థితి నిర్ధారించబడింది';

  @override
  String get sampleFastingNotNeeded =>
      'ఉపవాసం అవసరం లేదు (రోగితో తనిఖీ చేశాను)';

  @override
  String get sampleTubesLabelled => 'అన్ని ట్యూబ్‌లకు లేబుల్ వేశాను';

  @override
  String get sampleCount => 'శాంపిల్స్ సంఖ్య';

  @override
  String get sampleCollectedConfirm => 'శాంపిల్స్ సేకరించబడ్డాయి';

  @override
  String get sampleCompleteHint =>
      'విజిట్ పూర్తి చేయడానికి ప్రతి అంశాన్ని నిర్ధారించండి.';

  @override
  String sampleSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count శాంపిల్స్ సేకరించబడ్డాయి.',
      one: '1 శాంపిల్ సేకరించబడింది.',
    );
    return '$_temp0 ట్యూబ్‌లకు లేబుల్ వేశాను, రోగి గుర్తింపు ధృవీకరించాను, ఉపవాస స్థితి నిర్ధారించాను.';
  }

  @override
  String get exCardTitle => 'వ్యాయామ ప్రణాళిక';

  @override
  String get exCreateTitle => 'వ్యాయామ ప్రణాళిక సృష్టించండి';

  @override
  String get exChooseTitle => '1. వ్యాయామాలు ఎంచుకోండి';

  @override
  String get exAllAreas => 'అన్నీ';

  @override
  String get exLibraryEmpty => 'ఈ శరీర భాగానికి వ్యాయామాలు లేవు.';

  @override
  String get exDosageTitle => '2. సెట్‌లు మరియు పునరావృతాలు';

  @override
  String get exNoneSelected => 'పైన కనీసం ఒక వ్యాయామం ఎంచుకోండి.';

  @override
  String get exSets => 'సెట్‌లు';

  @override
  String get exReps => 'పునరావృతాలు';

  @override
  String get exHold => 'ఆపండి (సె.)';

  @override
  String get exPerDay => 'రోజుకు';

  @override
  String get exNotes => 'గమనికలు (ఐచ్ఛికం)';

  @override
  String get exScheduleTitle => '3. షెడ్యూల్';

  @override
  String get exStartDate => 'ప్రారంభ తేదీ';

  @override
  String get exWeeks => 'వారాలు';

  @override
  String get exSave => 'వ్యాయామ ప్రణాళికను సేవ్ చేయండి';

  @override
  String get exCreated => 'వ్యాయామ ప్రణాళిక సృష్టించబడింది';

  @override
  String get exErrNoExercises => 'కనీసం ఒక వ్యాయామం ఎంచుకోండి.';

  @override
  String exErrRange(String field, int min, int max) {
    return '$field $min మరియు $max మధ్య ఉండాలి.';
  }

  @override
  String get exErrStartDate => 'ప్రారంభ తేదీ గతంలో ఉండకూడదు.';

  @override
  String get exNoPlans => 'ఈ రోగికి ఇంకా వ్యాయామ ప్రణాళికలు లేవు.';

  @override
  String get exProgressUnavailable => 'ప్రణాళిక పురోగతి మీకు అందుబాటులో లేదు.';

  @override
  String exPlanLine(int count, String author) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count వ్యాయామాలు',
      one: '1 వ్యాయామం',
    );
    return '$_temp0 · $author';
  }

  @override
  String exProgressLine(int done, int planned, int pct) {
    return '$done/$planned సెషన్‌లు · $pct% పాటింపు';
  }

  @override
  String exLatestPain(int score) {
    return 'తాజా నొప్పి $score/10';
  }

  @override
  String get dietCardTitle => 'డైట్ ప్లాన్';

  @override
  String get dietCardBody => 'ఈ రోగికి భోజన ప్రణాళిక సృష్టించండి.';

  @override
  String get dietCreateTitle => 'డైట్ ప్లాన్ సృష్టించండి';

  @override
  String get dietTemplate => 'టెంప్లేట్';

  @override
  String get dietNoTemplate => 'టెంప్లేట్ లేదు';

  @override
  String get dietGovernance =>
      '[క్లినికల్ సమీక్ష అవసరం] ఈ టెంప్లేట్ ఇంకా క్లినికల్‌గా ఆమోదించబడలేదు. ప్రతి అంశాన్ని సమీక్షించండి.';

  @override
  String get dietConditions => 'పరిస్థితులు మరియు లక్ష్యం';

  @override
  String get dietAddCondition => 'పరిస్థితిని జోడించండి';

  @override
  String get dietCalories => 'కేలరీ లక్ష్యం (kcal/రోజు)';

  @override
  String get dietMeals => 'భోజనాలు';

  @override
  String get dietMealsHint => 'అంశాలను కామాలతో వేరు చేయండి.';

  @override
  String get dietAvoid => 'నివారించాల్సినవి మరియు గమనికలు';

  @override
  String get dietAvoidHint => 'నివారించాల్సిన ఆహారాలు (కామాలతో వేరు చేయండి)';

  @override
  String get dietNotes => 'గమనికలు (ఐచ్ఛికం)';

  @override
  String get dietValidUntil => 'ఎప్పటి వరకు చెల్లుతుంది';

  @override
  String get dietSave => 'డైట్ ప్లాన్ సేవ్ చేయండి';

  @override
  String get dietCreated => 'డైట్ ప్లాన్ సృష్టించబడింది';

  @override
  String get dietErrNoMeals => 'కనీసం ఒక భోజనానికి ఆహార అంశాలు జోడించండి.';

  @override
  String get dietErrNoConditions => 'కనీసం ఒక పరిస్థితిని జోడించండి.';

  @override
  String dietErrCalories(int min, int max) {
    return 'కేలరీ లక్ష్యం $min మరియు $max మధ్య ఉండాలి.';
  }

  @override
  String get dietErrValidUntil =>
      '\"ఎప్పటి వరకు\" ఈరోజు తర్వాతి తేదీ అయి ఉండాలి.';

  @override
  String get slotEarlyMorning => 'తెల్లవారుజాము';

  @override
  String get slotBreakfast => 'అల్పాహారం';

  @override
  String get slotMidMorning => 'మధ్యాహ్నానికి ముందు';

  @override
  String get slotLunch => 'మధ్యాహ్న భోజనం';

  @override
  String get slotEvening => 'సాయంత్రం అల్పాహారం';

  @override
  String get slotDinner => 'రాత్రి భోజనం';

  @override
  String get slotBedtime => 'పడుకునే ముందు';

  @override
  String serverChip(String host) {
    return 'సర్వర్: $host';
  }

  @override
  String get serverAddressTitle => 'సర్వర్ చిరునామా';

  @override
  String get serverAddressHelp =>
      'కేర్‌కంపానియన్ సర్వర్ చిరునామా నమోదు చేయండి, ఉదా. 10.10.17.134, http://10.10.17.134:4000 లేదా టన్నెల్ లింక్ https://xyz.trycloudflare.com.';

  @override
  String get serverAddressLabel => 'సర్వర్ URL లేదా IP చిరునామా';

  @override
  String get serverAddressInvalid =>
      '10.10.17.134 లేదా https://example.com లాంటి చిరునామా నమోదు చేయండి';

  @override
  String get serverTestConnection => 'కనెక్షన్ పరీక్షించండి';

  @override
  String get serverTesting => 'కనెక్షన్ పరీక్షిస్తోంది…';

  @override
  String serverConnectedVersion(String version) {
    return 'కనెక్ట్ అయింది. సర్వర్ వెర్షన్ $version';
  }

  @override
  String get serverCantReach =>
      'సర్వర్‌ను చేరుకోలేకపోతున్నాం: PCలో START-CARECOMPANION.bat నడుస్తోందని, ఫోన్ అదే నెట్‌వర్క్‌లో ఉందని తనిఖీ చేయండి, లేదా టన్నెల్ లింక్ ఉపయోగించండి.';

  @override
  String serverNotCareCompanion(String status) {
    return 'సర్వర్ స్పందించింది (HTTP $status), కానీ ఇది కేర్‌కంపానియన్ API కాదు. చిరునామా తనిఖీ చేయండి.';
  }

  @override
  String get serverSave => 'సేవ్ చేయండి';

  @override
  String get serverReset => 'డిఫాల్ట్‌కు రీసెట్ చేయండి';

  @override
  String serverDefaultIs(String url) {
    return 'డిఫాల్ట్: $url';
  }

  @override
  String get serverSignOutWarning => 'సర్వర్ మార్చితే మీరు లాగ్ అవుట్ అవుతారు.';

  @override
  String serverCantReachAt(String host) {
    return '$host వద్ద సర్వర్‌ను చేరుకోలేకపోతున్నాం';
  }

  @override
  String get serverChange => 'సర్వర్ మార్చండి';

  @override
  String errorOtpIncorrectAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'తప్పు OTP. $count ప్రయత్నాలు మిగిలి ఉన్నాయి.',
      one: 'తప్పు OTP. 1 ప్రయత్నం మిగిలి ఉంది.',
    );
    return '$_temp0';
  }

  @override
  String get errorOtpExpired =>
      'ఈ OTP గడువు ముగిసింది. దయచేసి కొత్త OTP కోరండి.';

  @override
  String get errorOtpTooManyAttempts =>
      'చాలా తప్పు ప్రయత్నాలు. దయచేసి కొత్త OTP కోరండి.';

  @override
  String get vitalsFlagHigh => 'ఎక్కువ';

  @override
  String get vitalsFlagLow => 'తక్కువ';

  @override
  String vitalsFlagWithRange(String flag, String range) {
    return '$flag · పెద్దలకు సాధారణ పరిధి $range';
  }

  @override
  String get capVitalsCheck => 'వైటల్స్ తనిఖీ';

  @override
  String get capSampleCollection => 'శాంపిల్ సేకరణ';

  @override
  String get capElderlyCare => 'వృద్ధుల సంరక్షణ';

  @override
  String get capPostReportConsult => 'రిపోర్ట్ తర్వాత సంప్రదింపు';

  @override
  String get capPhysiotherapy => 'ఫిజియోథెరపీ';

  @override
  String get credentialBannerAction => 'ప్రొఫైల్ చూడండి';

  @override
  String get locRationaleTitle => 'మీ లొకేషన్ ఉపయోగించాలా?';

  @override
  String get locRationaleBody =>
      'డ్యూటీలో ఉన్నప్పుడు మీ రూట్ ప్లాన్ చేయడానికి మరియు పేషెంట్లకు మీరు వచ్చే సమయం చూపడానికి కేర్‌కంపానియన్ ప్రో మీ లొకేషన్‌ను కేర్ టీమ్‌తో పంచుకుంటుంది. డ్యూటీలో లేనప్పుడు పంచుకోదు.';

  @override
  String get locRationaleAllow => 'కొనసాగించు';

  @override
  String get locRationaleNotNow => 'ఇప్పుడు కాదు';

  @override
  String get locDeniedMessage =>
      'లొకేషన్ ఆఫ్‌లో ఉంది, కాబట్టి రూట్ సమయాలు మరియు లైవ్ ట్రాకింగ్ పనిచేయవు. రూట్ ట్యాబ్ లేదా ప్రొఫైల్ నుండి దీన్ని ఆన్ చేయవచ్చు.';

  @override
  String get locOffBanner =>
      'లొకేషన్ ఆఫ్‌లో ఉంది. సరైన రూట్ సమయాలు మరియు పేషెంట్ ట్రాకింగ్ కోసం దీన్ని ఆన్ చేయండి.';

  @override
  String get locTurnOn => 'లొకేషన్ ఆన్ చేయండి';

  @override
  String get locBlocked =>
      'ఈ యాప్‌కు లొకేషన్ బ్లాక్ చేయబడింది. సెట్టింగ్స్‌లో అనుమతించండి.';

  @override
  String get locOpenSettings => 'సెట్టింగ్స్ తెరవండి';

  @override
  String get locSettingTitle => 'లొకేషన్ యాక్సెస్';

  @override
  String get locSettingOn => 'అనుమతి ఉంది';

  @override
  String get locSettingOff => 'ఆఫ్. ఆన్ చేయడానికి నొక్కండి';

  @override
  String get locServiceOff => 'ఈ ఫోన్‌లో లొకేషన్ (GPS) ఆఫ్‌లో ఉంది.';
}
