import type { Lang } from './context.js';

type Strings = Record<string, string>;

/**
 * Server-generated text registry (en / hi / te). Missing keys fall back to English.
 * Clinical wording in these strings is NON-CLINICAL placeholder copy pending clinical/legal review.
 */
const STRINGS: Record<Lang, Strings> = {
  en: {
    'ai.greeting':
      "Hello! I'm your CareCompanion assistant. I can help you describe what's going on and find the right care. I can't diagnose conditions. What's bothering you today?",
    'ai.ask.chiefComplaint': 'Please tell me the main problem you are facing.',
    'ai.ask.durationText': 'Thanks. How long has this been going on?',
    'ai.ask.severity': 'On a scale of 0 to 10, how severe is it right now (10 = worst)?',
    'ai.ask.associatedSymptoms': 'Are you noticing any other symptoms along with this?',
    'ai.intakeComplete': 'Thank you. I have noted your concern: {complaint}.',
    'ai.emergency':
      'This could be a medical emergency. Call 108 now or press the SOS button in the app. If possible, ask someone nearby to stay with you. Do not wait for an online reply.',
    'ai.fallback':
      'Sorry, our assistant is temporarily limited. Your information is saved. For advice about your symptoms, please consult a doctor. If this is an emergency, call 108.',
    'ai.urgent': 'Based on what you shared, please speak to a doctor soon. We have flagged this for a clinician to review.',
    'ai.routing.continue_intake': 'A few more questions will help us guide you to the right care.',
    'ai.routing.book_doctor': 'A doctor consultation is the recommended next step. You can book one now.',
    'ai.routing.home_visit': 'A home visit by a nurse can check on you at home. You can request one now.',
    'ai.routing.emergency': 'Please seek emergency care immediately: call 108 or use the SOS button.',
    'ai.routing.information': 'Here is some general wellness information.',
    'ai.routing.fallback_doctor': 'Our assistant is limited right now, so we recommend a doctor consultation.',
    'ai.info.prefix': 'General wellness information (not medical advice):',
    'ai.disclaimer': 'AI-generated for information only. Not a diagnosis. The original document remains the source of truth.',
    'mood.support.low':
      "Thank you for sharing how you feel. You don't have to go through this alone. Talking to someone you trust or a counsellor can help.",
    'mood.support.mid': 'Thanks for checking in. A short breathing exercise may help you feel a little calmer.',
    'mood.support.high': "Great to hear you're doing well. Keep up the routines that help you.",
    'mood.support.emergency':
      'Your safety matters. If you are thinking about harming yourself, call 108 or Tele-MANAS 14416 now, or press SOS. Please reach out to someone you trust.',
    'notify.lockscreen': 'You have a care update',
    'notify.lockscreen.critical': 'Urgent: please open CareCompanion',
    'notify.appointment_confirmed.title': 'Appointment confirmed',
    'notify.appointment_confirmed.body': 'Your appointment with {doctor} is confirmed for {when}.',
    'notify.appointment_cancelled.title': 'Appointment cancelled',
    'notify.appointment_cancelled.body': 'Your appointment with {doctor} on {when} was cancelled.',
    'notify.appointment_reminder.title': 'Upcoming appointment',
    'notify.appointment_reminder.body': 'Your appointment with {doctor} starts at {when}.',
    'notify.home_visit_update.title': 'Home visit update',
    'notify.home_visit_update.body': 'Your home visit is now: {status}.',
    'notify.home_visit_completed.title': 'Home visit completed',
    'notify.home_visit_completed.body': 'The visit summary has been added to your records.',
    'notify.safety_alert.title': 'Safety alert',
    'notify.safety_alert.body': 'A safety alert was raised for {patient}. Please check the app.',
    'notify.care_plan.title': 'New care plan',
    'notify.care_plan.body': '{doctor} shared a care plan.',
    'notify.medication_missed.title': 'Missed dose',
    'notify.medication_missed.body': 'A scheduled medicine dose was not marked as taken.',
    'notify.task_overdue.title': 'Care task overdue',
    'notify.task_overdue.body': 'A care task is overdue: {task}.',
    'notify.payment_succeeded.title': 'Payment successful',
    'notify.payment_succeeded.body': 'We received your payment of ₹{amount}.',
    'notify.payment_failed.title': 'Payment failed',
    'notify.payment_failed.body': 'Your payment of ₹{amount} did not go through.',
    'notify.refund.title': 'Refund processed',
    'notify.refund.body': 'A refund of ₹{amount} has been initiated.',
    'notify.fall.title': 'Possible fall detected',
    'notify.fall.body': 'A possible fall was detected for {patient} and they did not respond.',
    'notify.sos.title': 'SOS raised',
    'notify.sos.body': '{patient} pressed SOS. Please call them or 108.',
    'notify.visit_sla.title': 'Visit assignment SLA breached',
    'notify.visit_sla.body': 'A home visit has not been assigned within the SLA.',
    'notify.family_access.title': 'Family access granted',
    'notify.family_access.body': 'You now have access to {patient} on CareCompanion.',
    'notify.record_summary.title': 'Record summary ready',
    'notify.record_summary.body': 'An AI summary of your record is ready.',
    'notify.lockscreen.message': 'New message from your care team',
    'notify.care_message.title': 'New message',
    'notify.care_message.body': 'New message from your care team',
    'notify.prescription_issued.title': 'New prescription',
    'notify.prescription_issued.body': '{doctor} issued an e-prescription. It has been added to your records.',
    'notify.referral_created.title': 'Referral created',
    'notify.referral_created.body': '{doctor} created a referral. Please check the app for next steps.',
    'notify.application_decision.title': 'Application update',
    'notify.application_decision.body': 'Your application status is now: {status}.',
    'notify.subscription_active.title': 'Family Care Plan active',
    'notify.subscription_active.body': 'Your {plan} plan is active until {until}.',
    'notify.subscription_renewal.title': 'Family Care Plan renewal',
    'notify.subscription_renewal.body': 'Your {plan} plan ends on {until}. Renew to keep your benefits.',
    'notify.subscription_ended.title': 'Family Care Plan ended',
    'notify.subscription_ended.body': 'Your {plan} plan has ended.',
    'notify.coordinator_assigned.title': 'Care coordinator assigned',
    'notify.coordinator_assigned.body': '{coordinator} is now your care coordinator.',
  },
  hi: {
    'ai.greeting':
      'नमस्ते! मैं आपका CareCompanion सहायक हूँ। मैं आपकी समस्या समझने और सही देखभाल तक पहुँचने में मदद कर सकता हूँ। मैं निदान नहीं कर सकता। आज आपको क्या परेशानी है?',
    'ai.ask.chiefComplaint': 'कृपया अपनी मुख्य समस्या बताइए।',
    'ai.ask.durationText': 'धन्यवाद। यह कब से हो रहा है?',
    'ai.ask.severity': '0 से 10 के पैमाने पर, अभी यह कितना गंभीर है (10 = सबसे ज़्यादा)?',
    'ai.ask.associatedSymptoms': 'क्या इसके साथ कोई और लक्षण भी हैं?',
    'ai.intakeComplete': 'धन्यवाद। मैंने आपकी समस्या नोट कर ली है: {complaint}।',
    'ai.emergency':
      'यह एक मेडिकल इमरजेंसी हो सकती है। तुरंत 108 पर कॉल करें या ऐप में SOS बटन दबाएँ। हो सके तो पास के किसी व्यक्ति को अपने साथ रहने को कहें।',
    'ai.fallback':
      'क्षमा करें, हमारा सहायक अभी सीमित है। आपकी जानकारी सुरक्षित है। कृपया डॉक्टर से परामर्श करें। इमरजेंसी में 108 पर कॉल करें।',
    'ai.urgent': 'आपकी जानकारी के आधार पर, कृपया जल्द डॉक्टर से बात करें। हमने इसे डॉक्टर की समीक्षा के लिए चिह्नित किया है।',
    'ai.routing.book_doctor': 'डॉक्टर से परामर्श अगला उचित कदम है। आप अभी बुक कर सकते हैं।',
    'ai.routing.home_visit': 'नर्स घर आकर आपकी जाँच कर सकती है। आप अभी होम विज़िट बुक कर सकते हैं।',
    'ai.routing.emergency': 'कृपया तुरंत आपातकालीन सहायता लें: 108 पर कॉल करें या SOS दबाएँ।',
    'mood.support.emergency': 'आपकी सुरक्षा ज़रूरी है। अगर आप खुद को नुकसान पहुँचाने के बारे में सोच रहे हैं, तो अभी 108 या टेली-मानस 14416 पर कॉल करें।',
    'notify.lockscreen': 'आपके लिए एक देखभाल अपडेट है',
    'notify.lockscreen.critical': 'ज़रूरी: कृपया CareCompanion खोलें',
    'notify.lockscreen.message': 'आपकी केयर टीम का नया संदेश',
    'notify.care_message.title': 'नया संदेश',
    'notify.care_message.body': 'आपकी केयर टीम का नया संदेश',
    'notify.appointment_confirmed.title': 'अपॉइंटमेंट की पुष्टि हुई',
    'notify.appointment_confirmed.body': '{doctor} के साथ आपका अपॉइंटमेंट {when} के लिए पक्का है।',
    'notify.safety_alert.title': 'सुरक्षा अलर्ट',
    'notify.safety_alert.body': '{patient} के लिए सुरक्षा अलर्ट जारी हुआ है। कृपया ऐप देखें।',
  },
  te: {
    'ai.greeting':
      'నమస్కారం! నేను మీ CareCompanion సహాయకుడిని. మీ సమస్యను వివరించడంలో, సరైన వైద్య సేవను పొందడంలో సహాయం చేస్తాను. నేను రోగనిర్ధారణ చేయలేను. ఈరోజు మీకు ఏమి ఇబ్బందిగా ఉంది?',
    'ai.ask.chiefComplaint': 'దయచేసి మీ ప్రధాన సమస్యను చెప్పండి.',
    'ai.ask.durationText': 'ధన్యవాదాలు. ఇది ఎప్పటి నుంచి ఉంది?',
    'ai.ask.severity': '0 నుండి 10 స్కేల్‌లో, ఇప్పుడు ఇది ఎంత తీవ్రంగా ఉంది (10 = అత్యంత తీవ్రం)?',
    'ai.ask.associatedSymptoms': 'దీనితో పాటు ఇంకేమైనా లక్షణాలు ఉన్నాయా?',
    'ai.intakeComplete': 'ధన్యవాదాలు. మీ సమస్యను నమోదు చేశాను: {complaint}.',
    'ai.emergency':
      'ఇది వైద్య అత్యవసర పరిస్థితి కావచ్చు. వెంటనే 108కి కాల్ చేయండి లేదా యాప్‌లో SOS బటన్ నొక్కండి. వీలైతే దగ్గరలో ఉన్నవారిని మీతో ఉండమని అడగండి.',
    'ai.fallback':
      'క్షమించండి, మా సహాయకుడు ప్రస్తుతం పరిమితంగా పనిచేస్తోంది. మీ సమాచారం భద్రంగా ఉంది. దయచేసి డాక్టర్‌ను సంప్రదించండి. అత్యవసరమైతే 108కి కాల్ చేయండి.',
    'ai.urgent': 'మీరు చెప్పిన దాని ఆధారంగా, దయచేసి త్వరగా డాక్టర్‌తో మాట్లాడండి. దీన్ని డాక్టర్ సమీక్ష కోసం గుర్తించాము.',
    'ai.routing.book_doctor': 'డాక్టర్ సంప్రదింపు తదుపరి సరైన దశ. మీరు ఇప్పుడే బుక్ చేసుకోవచ్చు.',
    'ai.routing.home_visit': 'నర్సు ఇంటికి వచ్చి మిమ్మల్ని పరీక్షించవచ్చు. మీరు ఇప్పుడే హోమ్ విజిట్ బుక్ చేసుకోవచ్చు.',
    'ai.routing.emergency': 'దయచేసి వెంటనే అత్యవసర సహాయం పొందండి: 108కి కాల్ చేయండి లేదా SOS నొక్కండి.',
    'mood.support.emergency': 'మీ భద్రత ముఖ్యం. మీకు హాని చేసుకోవాలనే ఆలోచనలు ఉంటే, ఇప్పుడే 108 లేదా టెలి-మానస్ 14416కి కాల్ చేయండి.',
    'notify.lockscreen': 'మీకు ఒక కేర్ అప్‌డేట్ ఉంది',
    'notify.lockscreen.critical': 'అత్యవసరం: దయచేసి CareCompanion తెరవండి',
    'notify.lockscreen.message': 'మీ కేర్ టీమ్ నుండి కొత్త సందేశం',
    'notify.care_message.title': 'కొత్త సందేశం',
    'notify.care_message.body': 'మీ కేర్ టీమ్ నుండి కొత్త సందేశం',
    'notify.appointment_confirmed.title': 'అపాయింట్‌మెంట్ నిర్ధారించబడింది',
    'notify.appointment_confirmed.body': '{doctor}తో మీ అపాయింట్‌మెంట్ {when}కి నిర్ధారించబడింది.',
    'notify.safety_alert.title': 'భద్రతా హెచ్చరిక',
    'notify.safety_alert.body': '{patient} కోసం భద్రతా హెచ్చరిక వచ్చింది. దయచేసి యాప్ చూడండి.',
  },
};

export function t(lang: Lang, key: string, params: Record<string, string | number> = {}): string {
  const template = STRINGS[lang]?.[key] ?? STRINGS.en[key] ?? key;
  return template.replace(/\{(\w+)\}/g, (_, k: string) => (params[k] !== undefined ? String(params[k]) : `{${k}}`));
}

export function hasKey(key: string): boolean {
  return key in STRINGS.en;
}

export function formatIst(d: Date): string {
  return d.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
}
