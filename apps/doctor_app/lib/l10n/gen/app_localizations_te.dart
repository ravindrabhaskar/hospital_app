// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'కేర్‌కంపానియన్ డాక్టర్';

  @override
  String get commonLoading => 'లోడ్ అవుతోంది';

  @override
  String get commonRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get commonRefresh => 'రిఫ్రెష్ చేయండి';

  @override
  String get commonSave => 'సేవ్ చేయండి';

  @override
  String get commonCancel => 'రద్దు చేయండి';

  @override
  String get commonConfirm => 'నిర్ధారించండి';

  @override
  String get commonContinue => 'కొనసాగించండి';

  @override
  String get commonDiscard => 'విస్మరించండి';

  @override
  String get commonAdd => 'జోడించండి';

  @override
  String get commonRemove => 'తొలగించండి';

  @override
  String get commonOk => 'సరే';

  @override
  String get commonLogout => 'లాగ్ అవుట్';

  @override
  String get copied => 'కాపీ అయింది';

  @override
  String get send => 'పంపండి';

  @override
  String get fieldRequired => 'అవసరం';

  @override
  String get linkFailed => 'లింక్ తెరవలేకపోయాం';

  @override
  String get offlineBanner =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. చివరిగా లోడ్ చేసిన డేటా చూపిస్తున్నాం.';

  @override
  String get statusLabel => 'స్థితి';

  @override
  String get priorityLabel => 'ప్రాధాన్యత';

  @override
  String get severityLabel => 'తీవ్రత';

  @override
  String get episodeLabel => 'కేర్ ఎపిసోడ్';

  @override
  String get reasonLabel => 'కారణం';

  @override
  String get noneRecorded => 'ఏదీ నమోదు కాలేదు';

  @override
  String get noneAdded => 'ఇంకా ఏదీ జోడించలేదు';

  @override
  String get onePerLine => 'ఒక్కో లైన్‌కు ఒకటి';

  @override
  String get commaSeparated => 'కామాలతో వేరు చేయండి';

  @override
  String ageYears(int age) {
    return '$age సం';
  }

  @override
  String daysCount(int count) {
    return '$count రోజులు';
  }

  @override
  String get genderMale => 'పురుషుడు';

  @override
  String get genderFemale => 'స్త్రీ';

  @override
  String get genderOther => 'ఇతర';

  @override
  String get errorNetwork =>
      'కేర్‌కంపానియన్‌ను చేరలేకపోతున్నాం. కనెక్షన్ తనిఖీ చేయండి.';

  @override
  String get errorGeneric => 'ఏదో తప్పు జరిగింది. మళ్లీ ప్రయత్నించండి.';

  @override
  String get errorServer =>
      'సేవలో సమస్య ఉంది. కొద్దిసేపటి తర్వాత ప్రయత్నించండి.';

  @override
  String get errorSessionExpired => 'మీ సెషన్ ముగిసింది. మళ్లీ లాగిన్ అవ్వండి.';

  @override
  String get errorForbidden => 'దీనికి మీకు అనుమతి లేదు.';

  @override
  String get errorNotFound => 'ఇది ఇక అందుబాటులో లేదు.';

  @override
  String get errorRateLimited => 'చాలా ప్రయత్నాలు. కొంతసేపు ఆగి ప్రయత్నించండి.';

  @override
  String get errorMfaRequired => 'కొనసాగడానికి రెండు-దశల ధృవీకరణ అవసరం.';

  @override
  String get loginTitle => 'డాక్టర్ సైన్ ఇన్';

  @override
  String get loginSubtitle => 'మీ క్యూ, రోగులు, కేర్ టీమ్ ఒకే చోట.';

  @override
  String get loginPhoneLabel => 'మొబైల్ నంబర్';

  @override
  String get loginPhoneHint => '10 అంకెల నంబర్';

  @override
  String get loginPhoneInvalid => 'సరైన 10 అంకెల మొబైల్ నంబర్ నమోదు చేయండి';

  @override
  String get loginSendOtp => 'OTP పంపండి';

  @override
  String loginOtpSentTo(String phone) {
    return '$phoneకి పంపిన కోడ్ నమోదు చేయండి';
  }

  @override
  String get loginOtpLabel => '6 అంకెల OTP';

  @override
  String get loginOtpInvalid => '6 అంకెల కోడ్ నమోదు చేయండి';

  @override
  String loginDevOtpHint(String code) {
    return 'డెవలప్‌మెంట్ OTP: $code';
  }

  @override
  String get loginVerify => 'ధృవీకరించండి';

  @override
  String get loginChangeNumber => 'నంబర్ మార్చండి';

  @override
  String get mfaTitle => 'రెండు-దశల ధృవీకరణ';

  @override
  String get mfaEnrolIntro =>
      'డాక్టర్ ఖాతాలు SMS OTPతో పాటు ఆథెంటికేటర్ యాప్ కోడ్‌తో రక్షించబడతాయి.';

  @override
  String get mfaStep1 => '1. మీ ఆథెంటికేటర్‌లో కేర్‌కంపానియన్ జోడించండి';

  @override
  String get mfaStep2 => '2. అక్కడ చూపిన 6 అంకెల కోడ్ నమోదు చేయండి';

  @override
  String get mfaOpenAppHint =>
      'ఖాతాను ఆటోమేటిక్‌గా జోడించడానికి బటన్ నొక్కండి, లేదా సెటప్ కీని యాప్‌లో టైప్ చేయండి.';

  @override
  String get mfaOpenAuthenticator => 'ఆథెంటికేటర్ యాప్ తెరవండి';

  @override
  String get mfaSecretLabel => 'సెటప్ కీ';

  @override
  String get mfaCopySecret => 'సెటప్ కీ కాపీ చేయండి';

  @override
  String get mfaCodeLabel => 'ఆథెంటికేటర్ కోడ్';

  @override
  String get mfaTurnOn => 'ధృవీకరించి ఆన్ చేయండి';

  @override
  String get mfaRecoveryIntro =>
      'ఈ రికవరీ కోడ్‌లను సురక్షితంగా ఉంచండి. ఫోన్ పోతే ఒక్కో కోడ్ ఒకసారి పనిచేస్తుంది. ఇవి మళ్లీ చూపబడవు.';

  @override
  String get mfaCopyCodes => 'అన్ని కోడ్‌లు కాపీ చేయండి';

  @override
  String get mfaSavedCodes => 'నేను రికవరీ కోడ్‌లను సేవ్ చేశాను';

  @override
  String get mfaVerifyPrompt =>
      'మీ ఆథెంటికేటర్ యాప్ నుండి 6 అంకెల కోడ్ నమోదు చేయండి.';

  @override
  String get mfaRecoveryPrompt =>
      'మీ రికవరీ కోడ్‌లలో ఒకటి నమోదు చేయండి. ఒక్కో కోడ్ ఒకసారే పనిచేస్తుంది.';

  @override
  String get mfaRecoveryLabel => 'రికవరీ కోడ్';

  @override
  String get mfaVerify => 'ధృవీకరించండి';

  @override
  String get mfaUseRecovery => 'బదులుగా రికవరీ కోడ్ ఉపయోగించండి';

  @override
  String get mfaUseAuthenticator => 'ఆథెంటికేటర్ యాప్ ఉపయోగించండి';

  @override
  String get mfaWrongCode => 'ఆ కోడ్ తప్పు.';

  @override
  String mfaWrongCodeAttempts(int count) {
    return 'ఆ కోడ్ తప్పు. ఇంకా $count ప్రయత్నాలు.';
  }

  @override
  String get mfaCodeInvalid => '6 అంకెల కోడ్ నమోదు చేయండి';

  @override
  String get mfaRecoveryInvalid => 'సరైన రికవరీ కోడ్ నమోదు చేయండి';

  @override
  String get mfaLocked =>
      'చాలా తప్పు కోడ్‌లు. 15 నిమిషాల తర్వాత ప్రయత్నించండి.';

  @override
  String get mfaStatusOn => 'ఆన్ (ఆథెంటికేటర్ యాప్)';

  @override
  String get mfaStatusOff =>
      'ఇంకా సెట్ చేయలేదు. మీ సంస్థ అడిగినప్పుడు అడుగుతాం.';

  @override
  String get restrictedTitle => 'ఈ యాప్ డాక్టర్ల కోసం';

  @override
  String get restrictedBody => 'మీ ఖాతాకు ధృవీకరించిన డాక్టర్ ప్రొఫైల్ లేదు.';

  @override
  String get restrictedPatient =>
      'దయచేసి రోగులు, కుటుంబాల కోసం కేర్‌కంపానియన్ యాప్ ఉపయోగించండి.';

  @override
  String get restrictedProvider =>
      'హోమ్-కేర్ విజిట్‌ల కోసం దయచేసి కేర్‌కంపానియన్ ప్రో యాప్ ఉపయోగించండి.';

  @override
  String get restrictedStaff =>
      'మీ పాత్ర కోసం దయచేసి కేర్‌కంపానియన్ వెబ్ పోర్టల్ ఉపయోగించండి.';

  @override
  String get updateTitle => 'దయచేసి యాప్‌ను అప్‌డేట్ చేయండి';

  @override
  String get updateBody =>
      'ఈ వెర్షన్‌కు ఇక మద్దతు లేదు. సురక్షితంగా కొనసాగడానికి అప్‌డేట్ చేయండి.';

  @override
  String get updateNow => 'ఇప్పుడే అప్‌డేట్ చేయండి';

  @override
  String updateVersions(String current, String minimum) {
    return 'ఇన్‌స్టాల్ $current · అవసరం $minimum';
  }

  @override
  String get supportTitle => 'సహాయం';

  @override
  String get supportCall => 'సహాయానికి కాల్ చేయండి';

  @override
  String get supportEmail => 'సహాయానికి ఈమెయిల్ చేయండి';

  @override
  String get supportWhatsapp => 'వాట్సాప్ సహాయం';

  @override
  String get navToday => 'ఈరోజు';

  @override
  String get navPatients => 'రోగులు';

  @override
  String get navMessages => 'సందేశాలు';

  @override
  String get navMore => 'మరిన్ని';

  @override
  String helloDoctor(String name) {
    return 'నమస్తే, $name';
  }

  @override
  String get queueEmpty => 'ఈ రోజు సంప్రదింపులు లేవు.';

  @override
  String get queueWaiting => 'వేచి ఉన్నవి';

  @override
  String get queueInProgress => 'జరుగుతున్నవి';

  @override
  String get queueDone => 'పూర్తయినవి';

  @override
  String get apptPendingPayment => 'చెల్లింపు పెండింగ్';

  @override
  String get apptConfirmed => 'నిర్ధారించబడింది';

  @override
  String get apptInProgress => 'జరుగుతోంది';

  @override
  String get apptCompleted => 'పూర్తయింది';

  @override
  String get apptCancelled => 'రద్దు';

  @override
  String get apptNoShow => 'హాజరు కాలేదు';

  @override
  String get priorityRoutine => 'సాధారణం';

  @override
  String get priorityUrgent => 'అత్యవసరం';

  @override
  String get priorityEmergency => 'అత్యవసర పరిస్థితి';

  @override
  String get epNew => 'కొత్తది';

  @override
  String get epIntake => 'ఇన్‌టేక్';

  @override
  String get epAwaitingCare => 'సంరక్షణ కోసం వేచి';

  @override
  String get epCareScheduled => 'సంరక్షణ షెడ్యూల్';

  @override
  String get epUnderCare => 'సంరక్షణలో';

  @override
  String get epFollowUp => 'ఫాలో-అప్';

  @override
  String get epResolved => 'పరిష్కరించబడింది';

  @override
  String get epEscalated => 'ఎస్కలేట్ చేయబడింది';

  @override
  String get epEmergency => 'అత్యవసర పరిస్థితి';

  @override
  String get epTransferred => 'బదిలీ చేయబడింది';

  @override
  String get epCancelled => 'రద్దు';

  @override
  String get modeVideo => 'వీడియో';

  @override
  String get modeAudio => 'ఆడియో';

  @override
  String get modeChat => 'చాట్';

  @override
  String get modeInClinic => 'క్లినిక్‌లో';

  @override
  String get modeHomeVisit => 'హోమ్ విజిట్';

  @override
  String get consultTitle => 'సంప్రదింపు';

  @override
  String get openPatient => 'రోగి రికార్డు తెరవండి';

  @override
  String get startConsult => 'సంప్రదింపు ప్రారంభించండి';

  @override
  String get completeConsult => 'సంప్రదింపు పూర్తి చేయండి';

  @override
  String get consultStarted => 'సంప్రదింపు ప్రారంభమైంది';

  @override
  String get consultCompleted => 'సంప్రదింపు పూర్తయింది';

  @override
  String get savedNotes => 'సేవ్ చేసిన నోట్స్';

  @override
  String get outcomeLabel => 'ఫలితం';

  @override
  String get outcomeCarePlan => 'కేర్ ప్లాన్';

  @override
  String get outcomeResolved => 'పరిష్కరించబడింది';

  @override
  String get outcomeRefer => 'రిఫర్';

  @override
  String get outcomeHomeVisit => 'హోమ్ విజిట్';

  @override
  String get notesTitle => 'క్లినికల్ నోట్స్';

  @override
  String get notesHint => 'నోట్స్ టైప్ చేయండి లేదా AI స్క్రైబ్ ఉపయోగించండి';

  @override
  String get notesSaveHint =>
      'సంప్రదింపు పూర్తి చేసినప్పుడు నోట్స్ సేవ్ అవుతాయి.';

  @override
  String get saveEpisodeNote => 'ఇప్పుడే కేర్ ఎపిసోడ్‌కు జోడించండి';

  @override
  String get noteSaved => 'నోట్ కేర్ ఎపిసోడ్‌కు జోడించబడింది';

  @override
  String get toolsTitle => 'చర్యలు';

  @override
  String get careTeamThread => 'కేర్ టీమ్ సందేశాలు';

  @override
  String get joinVideo => 'వీడియోలో చేరండి';

  @override
  String get videoTitle => 'వీడియో సంప్రదింపు';

  @override
  String get videoWindow => 'రూమ్ తెరిచి ఉంటుంది';

  @override
  String get videoAudioHint => 'ఆడియో సంప్రదింపు: కెమెరా ఆఫ్‌లో ఉంచండి.';

  @override
  String videoOpensAt(String time) {
    return 'రూమ్ $timeకి తెరుచుకుంటుంది (ప్రారంభానికి 10 నిమిషాల ముందు).';
  }

  @override
  String get intakeTitle => 'ప్రధాన ఫిర్యాదు (AI ఇన్‌టేక్)';

  @override
  String get intakeComplaint => 'ప్రధాన ఫిర్యాదు';

  @override
  String get intakeDuration => 'వ్యవధి';

  @override
  String get intakeSeverity => 'తీవ్రత';

  @override
  String get intakeSymptoms => 'సంబంధిత లక్షణాలు';

  @override
  String get allergiesTitle => 'అలెర్జీలు';

  @override
  String get allergiesNone => 'తెలిసిన అలెర్జీలు నమోదు కాలేదు';

  @override
  String get conditionsTitle => 'పరిస్థితులు';

  @override
  String get activeMedsTitle => 'ప్రస్తుత మందులు';

  @override
  String get recentVitalsTitle => 'ఇటీవలి వైటల్స్';

  @override
  String get homeVisitFindingsTitle => 'హోమ్ విజిట్ ఫలితాలు';

  @override
  String get escalatedLabel => 'ఎస్కలేట్ చేయబడింది';

  @override
  String get aiSummaryTitle => 'AI సారాంశం';

  @override
  String get aiAdvisoryLabel =>
      'AI రూపొందించినది · సలహా మాత్రమే, నిర్ధారణ కాదు';

  @override
  String get aiSource => 'మూలం';

  @override
  String get aiFeedbackPrompt => 'ఈ సారాంశం ఖచ్చితంగా ఉందా?';

  @override
  String get aiAccept => 'ఖచ్చితం';

  @override
  String get aiReject => 'ఖచ్చితం కాదు';

  @override
  String get aiFeedbackThanks => 'ధన్యవాదాలు, మీ అభిప్రాయం నమోదైంది.';

  @override
  String get aiRecordSummary => 'AI రికార్డు సారాంశం';

  @override
  String get srcRecord => 'రికార్డు';

  @override
  String get srcVital => 'వైటల్';

  @override
  String get srcIntake => 'ఇన్‌టేక్';

  @override
  String get srcHomeVisit => 'హోమ్ విజిట్';

  @override
  String get srcPatientEntered => 'రోగి నమోదు చేసినది';

  @override
  String get scribeTitle => 'AI స్క్రైబ్';

  @override
  String get scribeConsent =>
      'ఈ సంప్రదింపును రికార్డ్ చేసి లిప్యంతరీకరించడానికి రోగి అంగీకరించారు';

  @override
  String get scribeConsentHint =>
      'రికార్డింగ్ లేదా ట్రాన్స్‌క్రిప్ట్ పంపే ముందు అవసరం. ఇది ఆడిట్ అవుతుంది.';

  @override
  String get scribeConsentRequired =>
      'ముందుగా రోగి అంగీకారాన్ని నిర్ధారించండి.';

  @override
  String get scribeRecordTitle => 'సంప్రదింపును రికార్డ్ చేయండి';

  @override
  String get scribeRecord => 'రికార్డ్ చేయండి';

  @override
  String get scribeRecording => 'రికార్డ్ అవుతోంది…';

  @override
  String get scribeStopUpload => 'ఆపి డ్రాఫ్ట్ సృష్టించండి';

  @override
  String get scribeAudioNote =>
      'ఆడియో ఒకసారి అప్‌లోడ్ అవుతుంది, లిప్యంతరీకరణ తర్వాత సర్వర్ తొలగిస్తుంది.';

  @override
  String get scribeTranscriptTitle =>
      'లేదా ట్రాన్స్‌క్రిప్ట్ టైప్ / పేస్ట్ చేయండి';

  @override
  String get scribeTranscriptHint => 'డాక్టర్: … రోగి: …';

  @override
  String get scribeGenerate => 'SOAP డ్రాఫ్ట్ సృష్టించండి';

  @override
  String get scribeDraftTitle => 'SOAP డ్రాఫ్ట్';

  @override
  String get scribeInsert => 'నోట్స్‌లో చేర్చండి';

  @override
  String get scribeInserted =>
      'డ్రాఫ్ట్ చేర్చబడింది. పూర్తి చేసే ముందు సమీక్షించి సవరించండి.';

  @override
  String get scribeMicDenied => 'రికార్డ్ చేయడానికి మైక్రోఫోన్ అనుమతి అవసరం.';

  @override
  String get scribeTranscriptShort => 'ట్రాన్స్‌క్రిప్ట్ చాలా చిన్నది.';

  @override
  String get scribeTooLarge =>
      'రికార్డింగ్ 25 MB కంటే పెద్దది. చిన్న భాగాన్ని రికార్డ్ చేయండి.';

  @override
  String get soapS => 'సబ్జెక్టివ్';

  @override
  String get soapO => 'ఆబ్జెక్టివ్';

  @override
  String get soapA => 'అంచనా';

  @override
  String get soapP => 'ప్రణాళిక';

  @override
  String get rxTitle => 'ప్రిస్క్రిప్షన్';

  @override
  String rxFor(String name) {
    return '$name కోసం';
  }

  @override
  String get rxItems => 'మందులు';

  @override
  String get rxNoItems => 'కనీసం ఒక మందు జోడించండి.';

  @override
  String get rxNeedsStart => 'ముందుగా సంప్రదింపు ప్రారంభించండి';

  @override
  String get rxItemTitle => 'మందు';

  @override
  String get rxDrugName => 'మందు పేరు';

  @override
  String get rxStrength => 'బలం';

  @override
  String get rxForm => 'రూపం';

  @override
  String get rxDose => 'మోతాదు';

  @override
  String get rxFrequency => 'ఫ్రీక్వెన్సీ';

  @override
  String get rxTiming => 'సమయం';

  @override
  String get rxTimingHint => 'భోజనం తర్వాత';

  @override
  String get rxDuration => 'రోజులు';

  @override
  String get rxDurationInvalid => '1–365 రోజులు';

  @override
  String get rxTimes => 'రిమైండర్ సమయాలు (HH:MM)';

  @override
  String get rxTimesInvalid => '08:00, 20:00 వంటి 24 గంటల సమయాలు వాడండి';

  @override
  String get rxInstructions => 'సూచనలు';

  @override
  String get rxChecksTitle => 'ఇంటరాక్షన్ & అలెర్జీ తనిఖీ';

  @override
  String get rxCheckIdle => 'మందులు జోడించగానే తనిఖీలు ఆటోమేటిక్‌గా జరుగుతాయి.';

  @override
  String get rxChecking => 'తనిఖీ చేస్తోంది…';

  @override
  String get rxNoWarnings => 'ఇంటరాక్షన్‌లు లేదా అలెర్జీ విభేదాలు కనబడలేదు.';

  @override
  String rxPack(String pack) {
    return 'నాలెడ్జ్ ప్యాక్ $pack';
  }

  @override
  String get sevMajor => 'తీవ్రమైనది';

  @override
  String get sevModerate => 'మధ్యస్థం';

  @override
  String get sevInfo => 'సమాచారం';

  @override
  String get warnAllergy => 'అలెర్జీ';

  @override
  String get warnDuplicate => 'నకిలీ చికిత్స';

  @override
  String get warnInteraction => 'ఇంటరాక్షన్';

  @override
  String get warnDoseForm => 'మోతాదు / రూపం';

  @override
  String get rxAcknowledge =>
      'నేను తీవ్ర హెచ్చరికలను సమీక్షించాను, అయినా రాయాలనుకుంటున్నాను';

  @override
  String get rxOverrideReason => 'ఓవర్‌రైడ్ చేయడానికి క్లినికల్ కారణం';

  @override
  String rxOverrideReasonHint(int min) {
    return 'కనీసం $min అక్షరాలు. ఆడిట్ అవుతుంది.';
  }

  @override
  String get rxMajorBlocked => 'తీవ్ర హెచ్చరికలకు మీ అంగీకారం, కారణం అవసరం.';

  @override
  String get rxClinicalNote => 'క్లినికల్ నోట్ (ప్రిస్క్రిప్షన్‌పై)';

  @override
  String get rxAdvice => 'సలహా';

  @override
  String get rxFollowUpDays => 'ఫాలో-అప్ (రోజుల్లో)';

  @override
  String get rxSign => 'ప్రిస్క్రిప్షన్ సృష్టించండి';

  @override
  String get rxCreated => 'ప్రిస్క్రిప్షన్ సృష్టించి రోగితో పంచుకున్నాం';

  @override
  String rxPdfTitle(String name) {
    return 'ప్రిస్క్రిప్షన్ · $name';
  }

  @override
  String get formTablet => 'టాబ్లెట్';

  @override
  String get formCapsule => 'క్యాప్సూల్';

  @override
  String get formSyrup => 'సిరప్';

  @override
  String get formInjection => 'ఇంజెక్షన్';

  @override
  String get formOintment => 'లేపనం';

  @override
  String get formDrops => 'డ్రాప్స్';

  @override
  String get formInhaler => 'ఇన్‌హేలర్';

  @override
  String get formOther => 'ఇతర';

  @override
  String pdfDocument(String title) {
    return 'PDF పత్రం: $title';
  }

  @override
  String pageOf(int page, int total) {
    return 'పేజీ $page / $total';
  }

  @override
  String get fileReady => 'ఫైల్ సిద్ధంగా ఉంది. చూడటానికి బ్రౌజర్‌లో తెరవండి.';

  @override
  String get openInBrowser => 'బ్రౌజర్‌లో తెరవండి';

  @override
  String get carePlanTitle => 'కేర్ ప్లాన్';

  @override
  String get carePlanSummary => 'సారాంశం';

  @override
  String get carePlanInstructions => 'రోగికి సూచనలు';

  @override
  String get carePlanTasks => 'పనులు';

  @override
  String get carePlanMeds => 'మందులు';

  @override
  String get carePlanSaved => 'కేర్ ప్లాన్ సేవ్ అయింది';

  @override
  String get taskTitle => 'పని';

  @override
  String get taskType => 'రకం';

  @override
  String get taskOwner => 'ఎవరు';

  @override
  String get taskDueInDays => 'ఎన్ని రోజుల్లో (ఐచ్ఛికం)';

  @override
  String get taskMedication => 'మందు';

  @override
  String get taskTest => 'పరీక్ష';

  @override
  String get taskFollowUp => 'ఫాలో-అప్';

  @override
  String get taskLifestyle => 'జీవనశైలి';

  @override
  String get taskMonitoring => 'పర్యవేక్షణ';

  @override
  String get taskGeneral => 'సాధారణం';

  @override
  String get ownerPatient => 'రోగి';

  @override
  String get ownerCaregiver => 'సంరక్షకులు';

  @override
  String get ownerProvider => 'కేర్ ప్రొవైడర్';

  @override
  String get followUpTitle => 'ఫాలో-అప్';

  @override
  String get followUpAfterDays => 'ఎన్ని రోజుల తర్వాత';

  @override
  String get followUpMode => 'విధానం';

  @override
  String get followUpNone => 'ఫాలో-అప్ లేదు';

  @override
  String get referTitle => 'ఆసుపత్రికి రిఫర్ చేయండి';

  @override
  String get referSearchHospital => 'ఆసుపత్రులను వెతకండి';

  @override
  String get referNoHospitals => 'ఆసుపత్రులు కనబడలేదు.';

  @override
  String get referSpecialty => 'స్పెషాలిటీ (ఐచ్ఛికం)';

  @override
  String get referReason => 'రిఫరల్ కారణం';

  @override
  String get referSummary => 'క్లినికల్ సారాంశం (ఐచ్ఛికం)';

  @override
  String get referSend => 'రిఫరల్ లేఖ సృష్టించండి';

  @override
  String get referSaved => 'రిఫరల్ సృష్టించబడింది. రోగికి తెలియజేశాం.';

  @override
  String get emergency24x7 => '24×7 అత్యవసర';

  @override
  String get enrolTitle => 'కేర్ ప్రోగ్రామ్‌లో నమోదు';

  @override
  String get enrolThresholds => 'అలర్ట్ పరిమితులు';

  @override
  String get enrolSave => 'రోగిని నమోదు చేయండి';

  @override
  String get enrolSaved => 'రోగి నమోదయ్యారు';

  @override
  String get fixtureWarning =>
      'టెంప్లేట్ ఇంకా క్లినికల్‌గా ఆమోదించబడలేదు (ఫిక్స్చర్).';

  @override
  String get exerciseTitle => 'వ్యాయామ ప్రణాళిక';

  @override
  String get exerciseWeeks => 'వారాలు';

  @override
  String get exerciseSets => 'సెట్లు';

  @override
  String get exerciseReps => 'రెప్స్';

  @override
  String get exercisePerDay => 'రోజుకు';

  @override
  String get planSaved => 'ప్రణాళిక రోగితో పంచుకున్నాం';

  @override
  String get dietTitle => 'ఆహార ప్రణాళిక';

  @override
  String get dietTemplate => 'టెంప్లేట్';

  @override
  String get dietNoTemplate => 'టెంప్లేట్ లేదు';

  @override
  String get dietConditions => 'పరిస్థితులు (కామాలతో)';

  @override
  String get dietCalories => 'కేలరీ లక్ష్యం (ఐచ్ఛికం)';

  @override
  String get dietMeals => 'భోజనాలు';

  @override
  String get dietMealsHint => 'అంశాలను కామాలతో వేరు చేయండి.';

  @override
  String dietMealsCount(int count) {
    return '$count భోజనాలు నింపారు';
  }

  @override
  String get dietNeedMeals =>
      'టెంప్లేట్ ఎంచుకోండి లేదా కనీసం ఒక భోజనం నింపండి.';

  @override
  String get dietAvoid => 'నివారించాల్సినవి (కామాలతో)';

  @override
  String get dietNotes => 'నోట్స్';

  @override
  String dietValidWeeks(int weeks) {
    return '$weeks వారాలు చెల్లుబాటు';
  }

  @override
  String get slotEarlyMorning => 'తెల్లవారుజామున';

  @override
  String get slotBreakfast => 'అల్పాహారం';

  @override
  String get slotMidMorning => 'మధ్యాహ్నం ముందు';

  @override
  String get slotLunch => 'మధ్యాహ్న భోజనం';

  @override
  String get slotEvening => 'సాయంత్రం';

  @override
  String get slotDinner => 'రాత్రి భోజనం';

  @override
  String get slotBedtime => 'నిద్రకు ముందు';

  @override
  String get patientTitle => 'రోగి';

  @override
  String get patientSearchHint => 'పేరుతో మీ రోగులను వెతకండి';

  @override
  String get patientsEmpty =>
      'మీరు సంప్రదించిన లేదా రికార్డులు పంచుకున్న రోగులు ఇక్కడ కనిపిస్తారు.';

  @override
  String get patientsNoMatch => 'మీ శోధనకు రోగులు సరిపోలలేదు.';

  @override
  String get bloodGroup => 'రక్త గ్రూప్';

  @override
  String get tabOverview => 'అవలోకనం';

  @override
  String get tabRecords => 'రికార్డులు';

  @override
  String get tabVitals => 'వైటల్స్';

  @override
  String get tabPrograms => 'ప్రోగ్రామ్‌లు';

  @override
  String get tabPrescriptions => 'ప్రిస్క్రిప్షన్లు';

  @override
  String get tabEpisodes => 'ఎపిసోడ్‌లు';

  @override
  String get recordsEmpty => 'రికార్డులు పంచుకోలేదు.';

  @override
  String get openOriginal => 'అసలు ఫైల్ తెరవండి';

  @override
  String get recLab => 'ల్యాబ్ రిపోర్ట్';

  @override
  String get recPrescription => 'ప్రిస్క్రిప్షన్';

  @override
  String get recImaging => 'ఇమేజింగ్';

  @override
  String get recDischarge => 'డిశ్చార్జ్ సారాంశం';

  @override
  String get recVisitSummary => 'విజిట్ సారాంశం';

  @override
  String get recOther => 'ఇతర';

  @override
  String get vitalsEmpty => 'వైటల్స్ నమోదు కాలేదు.';

  @override
  String vitalRange(String min, String max) {
    return 'పరిధి $min–$max';
  }

  @override
  String readingsCount(int count) {
    return '$count రీడింగ్‌లు';
  }

  @override
  String vitalTrendSemantics(String vital, String min, String max, int count) {
    return '$vital ధోరణి: $min నుండి $max మధ్య $count రీడింగ్‌లు';
  }

  @override
  String get vitalBpSystolic => 'BP సిస్టోలిక్';

  @override
  String get vitalBpDiastolic => 'BP డయాస్టోలిక్';

  @override
  String get vitalPulse => 'నాడి';

  @override
  String get vitalSpo2 => 'SpO2';

  @override
  String get vitalTemperature => 'ఉష్ణోగ్రత';

  @override
  String get vitalGlucose => 'రక్తంలో గ్లూకోజ్';

  @override
  String get vitalWeight => 'బరువు';

  @override
  String get vitalRespiratoryRate => 'శ్వాస రేటు';

  @override
  String get programsEmpty => 'ఏ కేర్ ప్రోగ్రామ్‌లోనూ నమోదు కాలేదు.';

  @override
  String get programAdherence => 'పాటించడం (7 రోజులు)';

  @override
  String get programLastReading => 'చివరి రీడింగ్';

  @override
  String get programOpenBreaches => 'తెరిచిన అలర్ట్‌లు';

  @override
  String get progActive => 'సక్రియం';

  @override
  String get progPaused => 'నిలిపివేయబడింది';

  @override
  String get progCompleted => 'పూర్తయింది';

  @override
  String get prescriptionsEmpty => 'ఇంకా ప్రిస్క్రిప్షన్లు లేవు.';

  @override
  String get episodesEmpty => 'కేర్ ఎపిసోడ్‌లు లేవు.';

  @override
  String get inboxEmpty => 'ఇంకా కేర్ టీమ్ సంభాషణలు లేవు.';

  @override
  String get noMessagesYet => 'ఇంకా సందేశాలు లేవు';

  @override
  String unreadCount(int count) {
    return '$count చదవనివి';
  }

  @override
  String get messageHint => 'కేర్ టీమ్‌కు సందేశం పంపండి';

  @override
  String get emergencyNotice => 'అత్యవసర భద్రతా సూచన';

  @override
  String get secondOpinionsTitle => 'సెకండ్ ఒపీనియన్';

  @override
  String get soTabOpen => 'తెరిచినవి';

  @override
  String get soTabMine => 'నావి';

  @override
  String get soEmpty => 'ఇక్కడ అభ్యర్థనలు లేవు.';

  @override
  String get soOpen => 'తెరిచి ఉంది';

  @override
  String get soClaimed => 'తీసుకోబడింది';

  @override
  String get soAnswered => 'సమాధానం ఇచ్చారు';

  @override
  String get soClaim => 'తీసుకోండి';

  @override
  String get soClaimedMsg =>
      'అభ్యర్థన తీసుకున్నారు. రికార్డులు ఇప్పుడు మీతో పంచుకోబడ్డాయి.';

  @override
  String get soRespond => 'అభిప్రాయం రాయండి';

  @override
  String get soOpinion => 'అభిప్రాయం';

  @override
  String get soRecommendations => 'సిఫార్సులు';

  @override
  String get soSuggestTele => 'టెలికన్సల్టేషన్ సూచించండి';

  @override
  String get soSent => 'అభిప్రాయం రోగికి పంపబడింది';

  @override
  String soDue(String date) {
    return 'గడువు $date';
  }

  @override
  String get escalationsTitle => 'ఎస్కలేషన్‌లు';

  @override
  String get escalationsEmpty => 'మీ రోగులకు ఎస్కలేషన్‌లు లేవు.';

  @override
  String get scheduleTitle => 'షెడ్యూల్ & సెలవులు';

  @override
  String get weeklyTab => 'వారపు గంటలు';

  @override
  String get leavesTab => 'సెలవులు';

  @override
  String scheduleHint(int days) {
    return 'సేవ్ చేస్తే తదుపరి $days రోజుల ఖాళీ స్లాట్‌లు మళ్లీ సృష్టించబడతాయి. బుక్ అయిన స్లాట్‌లు మారవు.';
  }

  @override
  String get scheduleEmpty => 'ఇంకా వారపు గంటలు లేవు.';

  @override
  String get addBlock => 'గంటలు జోడించండి';

  @override
  String get blockTitle => 'సంప్రదింపు గంటలు';

  @override
  String get weekday => 'రోజు';

  @override
  String get startTime => 'ప్రారంభం';

  @override
  String get endTime => 'ముగింపు';

  @override
  String get slotLength => 'స్లాట్ వ్యవధి';

  @override
  String slotMinutes(int minutes) {
    return '$minutes నిమి';
  }

  @override
  String get blockInvalidTime => 'చెల్లని సమయం';

  @override
  String get blockEndBeforeStart => 'ముగింపు ప్రారంభం తర్వాత ఉండాలి';

  @override
  String get blockTooShort => 'ఒక స్లాట్ కంటే చిన్నది';

  @override
  String get blockNoModes => 'కనీసం ఒక విధానం ఎంచుకోండి';

  @override
  String get blockOverlap => 'ఈ రోజు ఇతర గంటలతో అతివ్యాప్తి చెందుతుంది';

  @override
  String get saveSchedule => 'వారపు గంటలు సేవ్ చేయండి';

  @override
  String get fixProblems => 'హైలైట్ చేసిన గంటలను సరిచేయండి';

  @override
  String get scheduleSaved => 'షెడ్యూల్ సేవ్ అయింది';

  @override
  String get leavesEmpty => 'సెలవులు ప్లాన్ చేయలేదు.';

  @override
  String get addLeave => 'సెలవు జోడించండి';

  @override
  String get leaveReason => 'కారణం (ఐచ్ఛికం)';

  @override
  String get leaveAdded => 'సెలవు జోడించబడింది';

  @override
  String leaveConflictsTitle(int count) {
    return 'ఈ రోజు $count బుక్ అయిన సంప్రదింపులు';
  }

  @override
  String get leaveConflictsBody =>
      'ఇవి ఆటోమేటిక్‌గా రద్దు కావు. దయచేసి వీటిని మళ్లీ షెడ్యూల్ చేయమని కేర్ టీమ్‌ను అడగండి.';

  @override
  String get earningsTitle => 'ఆదాయం';

  @override
  String get previousMonth => 'మునుపటి నెల';

  @override
  String get nextMonth => 'తదుపరి నెల';

  @override
  String get earnPayable => 'మీకు చెల్లించవలసినది';

  @override
  String earnServices(int count) {
    return '$count పూర్తయిన సంప్రదింపులు';
  }

  @override
  String get earnGross => 'స్థూలం';

  @override
  String get earnPlatformFee => 'ప్లాట్‌ఫామ్ ఫీజు';

  @override
  String get earnRefunds => 'రీఫండ్‌లు';

  @override
  String get earnLines => 'వివరాలు';

  @override
  String get earnEmpty => 'ఈ నెల చెల్లించిన సంప్రదింపులు లేవు.';

  @override
  String get profileTitle => 'ప్రొఫైల్';

  @override
  String get photoGallery => 'ఫోటో ఎంచుకోండి';

  @override
  String get photoCamera => 'ఫోటో తీయండి';

  @override
  String get photoUpdated => 'ఫోటో అప్‌డేట్ అయింది';

  @override
  String get photoTooLarge => 'ఫోటో 5 MB కంటే తక్కువ ఉండాలి.';

  @override
  String regNo(String number) {
    return 'రిజి. $number';
  }

  @override
  String ratingLine(String rating, int count) {
    return '★ $rating ($count సమీక్షలు)';
  }

  @override
  String get acceptingBookings => 'కొత్త బుకింగ్‌లు స్వీకరిస్తున్నారు';

  @override
  String get acceptingBookingsHint =>
      'ఆఫ్‌లో ఉంటే డాక్టర్ శోధనలో మీరు కనిపించరు.';

  @override
  String get bookingsOn => 'మీరు బుకింగ్‌లు స్వీకరిస్తున్నారు';

  @override
  String get bookingsOff => 'బుకింగ్‌లు నిలిపివేయబడ్డాయి';

  @override
  String get feesTitle => 'సంప్రదింపు ఫీజులు';

  @override
  String get qualifications => 'అర్హతలు';

  @override
  String get languagesSpoken => 'మాట్లాడే భాషలు';

  @override
  String get bio => 'మీ గురించి';

  @override
  String get profileSaved => 'ప్రొఫైల్ సేవ్ అయింది';

  @override
  String get languageTitle => 'భాష';

  @override
  String get logoutConfirmTitle => 'లాగ్ అవుట్ చేయాలా?';

  @override
  String get logoutConfirmBody =>
      'మళ్లీ సైన్ ఇన్ చేయడానికి ఫోన్ OTP, ఆథెంటికేటర్ కోడ్ అవసరం.';
}
