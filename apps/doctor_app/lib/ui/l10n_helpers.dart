import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/api/api_exception.dart';
import '../l10n/gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String apptStatusLabel(AppLocalizations l, String status) => switch (status) {
  'pending_payment' => l.apptPendingPayment,
  'confirmed' => l.apptConfirmed,
  'in_progress' => l.apptInProgress,
  'completed' => l.apptCompleted,
  'cancelled' => l.apptCancelled,
  'no_show' => l.apptNoShow,
  _ => status,
};

String priorityLabel(AppLocalizations l, String p) => switch (p) {
  'emergency' => l.priorityEmergency,
  'urgent' => l.priorityUrgent,
  _ => l.priorityRoutine,
};

String episodeStatusLabel(AppLocalizations l, String s) => switch (s) {
  'NEW' => l.epNew,
  'INTAKE' => l.epIntake,
  'AWAITING_CARE' => l.epAwaitingCare,
  'CARE_SCHEDULED' => l.epCareScheduled,
  'UNDER_CARE' => l.epUnderCare,
  'FOLLOW_UP' => l.epFollowUp,
  'RESOLVED' => l.epResolved,
  'ESCALATED' => l.epEscalated,
  'EMERGENCY' => l.epEmergency,
  'TRANSFERRED' => l.epTransferred,
  'CANCELLED' => l.epCancelled,
  _ => s,
};

String modeLabel(AppLocalizations l, String mode) => switch (mode) {
  'video' => l.modeVideo,
  'audio' => l.modeAudio,
  'chat' => l.modeChat,
  'in_clinic' => l.modeInClinic,
  'home_visit' => l.modeHomeVisit,
  _ => mode,
};

String genderLabel(AppLocalizations l, String? gender) => switch (gender) {
  'male' => l.genderMale,
  'female' => l.genderFemale,
  'other' => l.genderOther,
  _ => '–',
};

/// "68 y · Male"
String ageGender(AppLocalizations l, int? age, String? gender) {
  final parts = [if (age != null) l.ageYears(age), if (gender != null) genderLabel(l, gender)];
  return parts.isEmpty ? '–' : parts.join(' · ');
}

String vitalLabel(AppLocalizations l, String type) => switch (type) {
  'bp_systolic' => l.vitalBpSystolic,
  'bp_diastolic' => l.vitalBpDiastolic,
  'pulse' => l.vitalPulse,
  'spo2' => l.vitalSpo2,
  'temperature' => l.vitalTemperature,
  'blood_glucose' => l.vitalGlucose,
  'weight' => l.vitalWeight,
  'respiratory_rate' => l.vitalRespiratoryRate,
  _ => type,
};

const vitalTypes = [
  'bp_systolic',
  'bp_diastolic',
  'pulse',
  'spo2',
  'temperature',
  'blood_glucose',
  'weight',
  'respiratory_rate',
];

String severityLabel(AppLocalizations l, String s) => switch (s) {
  'major' => l.sevMajor,
  'moderate' => l.sevModerate,
  _ => l.sevInfo,
};

String warningTypeLabel(AppLocalizations l, String t) => switch (t) {
  'allergy' => l.warnAllergy,
  'duplicate_therapy' => l.warnDuplicate,
  'interaction' => l.warnInteraction,
  'dose_form' => l.warnDoseForm,
  _ => t,
};

String levelLabel(AppLocalizations l, String level) => switch (level) {
  'emergency' => l.priorityEmergency,
  'urgent' => l.priorityUrgent,
  _ => l.priorityRoutine,
};

String outcomeLabel(AppLocalizations l, String o) => switch (o) {
  'care_plan' => l.outcomeCarePlan,
  'resolved' => l.outcomeResolved,
  'refer' => l.outcomeRefer,
  'home_visit' => l.outcomeHomeVisit,
  _ => o,
};

String recordTypeLabel(AppLocalizations l, String t) => switch (t) {
  'lab_report' => l.recLab,
  'prescription' => l.recPrescription,
  'imaging' => l.recImaging,
  'discharge_summary' => l.recDischarge,
  'visit_summary' => l.recVisitSummary,
  _ => l.recOther,
};

String sourceKindLabel(AppLocalizations l, String kind) => switch (kind) {
  'record' => l.srcRecord,
  'vital' => l.srcVital,
  'intake' => l.srcIntake,
  'home_visit' => l.srcHomeVisit,
  'patient_entered' => l.srcPatientEntered,
  _ => kind,
};

String rxFormLabel(AppLocalizations l, String f) => switch (f) {
  'tablet' => l.formTablet,
  'capsule' => l.formCapsule,
  'syrup' => l.formSyrup,
  'injection' => l.formInjection,
  'ointment' => l.formOintment,
  'drops' => l.formDrops,
  'inhaler' => l.formInhaler,
  _ => l.formOther,
};

String taskTypeLabel(AppLocalizations l, String t) => switch (t) {
  'medication' => l.taskMedication,
  'test' => l.taskTest,
  'follow_up' => l.taskFollowUp,
  'lifestyle' => l.taskLifestyle,
  'monitoring' => l.taskMonitoring,
  _ => l.taskGeneral,
};

String ownerLabel(AppLocalizations l, String o) => switch (o) {
  'caregiver' => l.ownerCaregiver,
  'provider' => l.ownerProvider,
  _ => l.ownerPatient,
};

String dietSlotLabel(AppLocalizations l, String s) => switch (s) {
  'early_morning' => l.slotEarlyMorning,
  'breakfast' => l.slotBreakfast,
  'mid_morning' => l.slotMidMorning,
  'lunch' => l.slotLunch,
  'evening' => l.slotEvening,
  'dinner' => l.slotDinner,
  _ => l.slotBedtime,
};

String secondOpinionStatusLabel(AppLocalizations l, String s) => switch (s) {
  'open' => l.soOpen,
  'claimed' => l.soClaimed,
  'answered' => l.soAnswered,
  'cancelled' => l.apptCancelled,
  _ => s,
};

String programStatusLabel(AppLocalizations l, String s) => switch (s) {
  'active' => l.progActive,
  'paused' => l.progPaused,
  'completed' => l.progCompleted,
  _ => s,
};

/// Weekday name for the schedule (0 = Sunday), localized by intl.
String weekdayName(BuildContext context, int weekday) {
  final locale = Localizations.localeOf(context).toString();
  // 1 Jan 2023 was a Sunday.
  return DateFormat.EEEE(locale).format(DateTime(2023, 1, 1 + weekday));
}

String errorMessage(AppLocalizations l, Object error) {
  if (error is ApiException) {
    if (error.isNetwork) return l.errorNetwork;
    if (error.isMfaRequired) return l.errorMfaRequired;
    if (error.isUnauthenticated) return l.errorSessionExpired;
    if (error.isForbidden) return l.errorForbidden;
    if (error.isRateLimited) return l.errorRateLimited;
    if (error.isNotFound) return l.errorNotFound;
    if (error.message.isNotEmpty && !error.isServerError) return error.message;
    if (error.isServerError) return l.errorServer;
  }
  return l.errorGeneric;
}

/// Errors from `POST /auth/otp/verify`. There is no session yet, so a 401
/// means a wrong or expired code, never "session expired" (that wording is
/// for authenticated calls only, see [errorMessage]).
String otpErrorMessage(AppLocalizations l, Object error) {
  if (error is ApiException) {
    if (error.isUnauthenticated) {
      final left = error.details['attemptsRemaining'];
      if (left is num) return left <= 0 ? l.otpNoAttemptsLeft : l.otpIncorrectAttempts(left.toInt());
      if (error.message.toLowerCase().contains('expired')) return l.otpExpired;
      return l.otpIncorrect;
    }
    if (error.isRateLimited) return l.otpTooManyAttempts;
  }
  return errorMessage(l, error);
}

String specialtyLabel(AppLocalizations l, String code) => switch (code) {
  'general_physician' => l.specGeneralPhysician,
  'dermatologist' => l.specDermatologist,
  'pediatrician' => l.specPediatrician,
  'gynecologist' => l.specGynecologist,
  'cardiologist' => l.specCardiologist,
  'orthopedist' => l.specOrthopedist,
  'psychiatrist' => l.specPsychiatrist,
  'ent' => l.specEnt,
  'diabetologist' => l.specDiabetologist,
  'neurologist' => l.specNeurologist,
  _ => _humanize(code),
};

/// `sports_medicine` -> `Sports medicine` for codes without a translation.
String _humanize(String code) {
  final s = code.replaceAll('_', ' ').trim();
  return s.isEmpty ? '–' : s[0].toUpperCase() + s.substring(1);
}

/// Integer rupees (contract: money is integer rupees), Indian grouping.
String formatRupees(num amount) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: amount % 1 == 0 ? 0 : 2).format(amount);

String formatTime(BuildContext context, DateTime? dt) {
  if (dt == null) return '–';
  return DateFormat.jm(Localizations.localeOf(context).toString()).format(dt.toLocal());
}

String formatDate(BuildContext context, DateTime? dt) {
  if (dt == null) return '–';
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(dt.toLocal());
}

String formatDateTime(BuildContext context, DateTime? dt) {
  if (dt == null) return '–';
  final locale = Localizations.localeOf(context).toString();
  return '${DateFormat.MMMd(locale).format(dt.toLocal())}, ${DateFormat.jm(locale).format(dt.toLocal())}';
}

/// Formats a `YYYY-MM-DD` string.
String formatIsoDate(BuildContext context, String? iso) {
  if (iso == null || iso.isEmpty) return '–';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);
}

String formatNumber(num v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
