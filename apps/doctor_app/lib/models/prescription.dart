import 'json.dart';

const rxForms = ['tablet', 'capsule', 'syrup', 'injection', 'ointment', 'drops', 'inhaler', 'other'];

/// `RxItem` (contract §31).
class RxItem {
  const RxItem({
    required this.drugName,
    this.strength,
    this.form = 'tablet',
    required this.dose,
    required this.frequency,
    this.timing,
    required this.durationDays,
    this.times = const [],
    this.instructions,
  });

  final String drugName;
  final String? strength;
  final String form;
  final String dose;
  final String frequency;
  final String? timing;
  final int durationDays;
  final List<String> times;
  final String? instructions;

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// Client-side validity before sending (the server validates again).
  bool get isValid =>
      drugName.trim().isNotEmpty &&
      dose.trim().isNotEmpty &&
      frequency.trim().isNotEmpty &&
      durationDays > 0 &&
      durationDays <= 365 &&
      rxForms.contains(form) &&
      times.every(_hhmm.hasMatch);

  factory RxItem.fromJson(Json j) => RxItem(
    drugName: strOr(j['drugName']),
    strength: str(j['strength']),
    form: strOr(j['form'], 'tablet'),
    dose: strOr(j['dose']),
    frequency: strOr(j['frequency']),
    timing: str(j['timing']),
    durationDays: intOrNull(j['durationDays']) ?? 0,
    times: stringList(j['times']),
    instructions: str(j['instructions']),
  );

  Json toJson() => {
    'drugName': drugName.trim(),
    if (strength != null && strength!.trim().isNotEmpty) 'strength': strength!.trim(),
    'form': form,
    'dose': dose.trim(),
    'frequency': frequency.trim(),
    if (timing != null && timing!.trim().isNotEmpty) 'timing': timing!.trim(),
    'durationDays': durationDays,
    'times': times,
    if (instructions != null && instructions!.trim().isNotEmpty) 'instructions': instructions!.trim(),
  };

  /// Body for `POST /clinician/prescriptions/check` (§47).
  Json toCheckJson() => {
    'drugName': drugName.trim(),
    if (strength != null && strength!.trim().isNotEmpty) 'strength': strength!.trim(),
  };
}

/// `RxWarning` (§47).
class RxWarning {
  const RxWarning({
    required this.severity,
    required this.type,
    required this.drugs,
    required this.message,
    this.source,
  });

  final String severity;
  final String type;
  final List<String> drugs;
  final String message;
  final String? source;

  bool get isMajor => severity == 'major';

  static int rank(String s) => switch (s) {
    'major' => 0,
    'moderate' => 1,
    _ => 2,
  };

  factory RxWarning.fromJson(Json j) => RxWarning(
    severity: strOr(j['severity'], 'info'),
    type: strOr(j['type'], 'interaction'),
    drugs: stringList(j['drugs']),
    message: strOr(j['message']),
    source: str(j['source']),
  );
}

/// Result of the interaction check.
class RxCheckResult {
  const RxCheckResult({required this.warnings, this.packVersion, this.packStatus});
  final List<RxWarning> warnings;
  final String? packVersion;
  final String? packStatus;

  factory RxCheckResult.fromJson(Json j) {
    final pack = asJson(j['knowledgePack']);
    final w = jsonList(j['warnings']).map(RxWarning.fromJson).toList()
      ..sort((a, b) => RxWarning.rank(a.severity).compareTo(RxWarning.rank(b.severity)));
    return RxCheckResult(warnings: w, packVersion: str(pack['version']), packStatus: str(pack['status']));
  }
}

/// `Prescription` (§31).
class Prescription {
  const Prescription({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorName,
    required this.items,
    this.appointmentId,
    this.clinicalNote,
    this.advice,
    this.followUpInDays,
    this.recordId,
    this.createdAt,
    this.warnings = const [],
  });

  final String id;
  final String patientId;
  final String patientName;
  final String doctorName;
  final List<RxItem> items;
  final String? appointmentId;
  final String? clinicalNote;
  final String? advice;
  final int? followUpInDays;
  final String? recordId;
  final DateTime? createdAt;
  final List<RxWarning> warnings;

  factory Prescription.fromJson(Json j) => Prescription(
    id: strOr(j['id']),
    patientId: strOr(j['patientId']),
    patientName: strOr(j['patientName'], '–'),
    doctorName: strOr(j['doctorName'], '–'),
    items: jsonList(j['items']).map(RxItem.fromJson).toList(),
    appointmentId: str(j['appointmentId']),
    clinicalNote: str(j['clinicalNote']),
    advice: str(j['advice']),
    followUpInDays: intOrNull(j['followUpInDays']),
    recordId: str(j['recordId']),
    createdAt: dateOrNull(j['createdAt']),
    warnings: jsonList(j['warnings']).map(RxWarning.fromJson).toList(),
  );
}

/// Pure gating rules for the prescription writer (§47): a prescription with
/// any `major` warning can only be sent with an explicit acknowledgement and
/// an override reason, which the server audits.
class RxGate {
  const RxGate({
    required this.items,
    required this.warnings,
    this.acknowledged = false,
    this.overrideReason = '',
    this.checking = false,
  });

  static const minReasonLength = 5;

  final List<RxItem> items;
  final List<RxWarning> warnings;
  final bool acknowledged;
  final String overrideReason;

  /// A check is in flight: wait for the latest warnings before sending.
  final bool checking;

  bool get hasItems => items.isNotEmpty && items.length <= 20;
  bool get itemsValid => hasItems && items.every((i) => i.isValid);
  bool get hasMajor => warnings.any((w) => w.isMajor);
  bool get reasonValid => overrideReason.trim().length >= minReasonLength;

  /// Major warnings need the checkbox + a reason.
  bool get overrideSatisfied => !hasMajor || (acknowledged && reasonValid);

  bool get canSubmit => itemsValid && !checking && overrideSatisfied;

  /// Extra fields for `POST /clinician/prescriptions` when overriding.
  Json get overrideFields =>
      hasMajor ? {'acknowledgedWarnings': true, 'overrideReason': overrideReason.trim()} : const {};
}
