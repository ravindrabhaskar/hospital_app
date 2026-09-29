import 'json.dart';

/// Appointment statuses (contract §7).
class ApptStatus {
  ApptStatus._();
  static const pendingPayment = 'pending_payment';
  static const confirmed = 'confirmed';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const noShow = 'no_show';
}

/// `Appointment` (§7), plus the queue fields of `/clinician/queue` (§16).
class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    this.doctorName,
    this.startAt,
    this.endAt,
    required this.mode,
    required this.status,
    required this.reason,
    this.fee,
    this.careEpisodeId,
    this.videoRoomUrl,
    this.clinicianNotes,
    this.patientAge,
    this.patientGender,
    this.episodeStatus,
    this.priority = 'routine',
  });

  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String? doctorName;
  final DateTime? startAt;
  final DateTime? endAt;
  final String mode;
  final String status;
  final String reason;
  final num? fee;
  final String? careEpisodeId;
  final String? videoRoomUrl;
  final String? clinicianNotes;
  final int? patientAge;
  final String? patientGender;
  final String? episodeStatus;
  final String priority;

  bool get isVideoOrAudio => mode == 'video' || mode == 'audio';
  bool get canStart => status == ApptStatus.confirmed;
  bool get isInProgress => status == ApptStatus.inProgress;
  bool get isCompleted => status == ApptStatus.completed;

  /// e-Prescriptions need `in_progress` or `completed` (contract §31).
  bool get canPrescribe => isInProgress || isCompleted;

  factory Appointment.fromJson(Json j) => Appointment(
    id: strOr(j['id']),
    patientId: strOr(j['patientId']),
    patientName: strOr(j['patientName'], '–'),
    doctorId: strOr(j['doctorId']),
    doctorName: str(j['doctorName']),
    startAt: dateOrNull(j['startAt']),
    endAt: dateOrNull(j['endAt']),
    mode: strOr(j['mode'], 'video'),
    status: strOr(j['status'], ApptStatus.confirmed),
    reason: strOr(j['reason']),
    fee: numOrNull(j['fee']),
    careEpisodeId: str(j['careEpisodeId']),
    videoRoomUrl: str(j['videoRoomUrl']),
    clinicianNotes: str(j['clinicianNotes']),
    patientAge: intOrNull(j['patientAge']),
    patientGender: str(j['patientGender']),
    episodeStatus: str(j['episodeStatus']),
    priority: strOr(j['priority'], 'routine'),
  );

  Appointment copyWith({String? status}) => Appointment(
    id: id,
    patientId: patientId,
    patientName: patientName,
    doctorId: doctorId,
    doctorName: doctorName,
    startAt: startAt,
    endAt: endAt,
    mode: mode,
    status: status ?? this.status,
    reason: reason,
    fee: fee,
    careEpisodeId: careEpisodeId,
    videoRoomUrl: videoRoomUrl,
    clinicianNotes: clinicianNotes,
    patientAge: patientAge,
    patientGender: patientGender,
    episodeStatus: episodeStatus,
    priority: priority,
  );
}

class Allergy {
  const Allergy({required this.id, required this.substance, this.reaction, this.severity});
  final String id;
  final String substance;
  final String? reaction;
  final String? severity;

  factory Allergy.fromJson(Json j) => Allergy(
    id: strOr(j['id']),
    substance: strOr(j['substance'], '–'),
    reaction: str(j['reaction']),
    severity: str(j['severity']),
  );
}

class Condition {
  const Condition({required this.id, required this.name, this.since});
  final String id;
  final String name;
  final String? since;

  factory Condition.fromJson(Json j) =>
      Condition(id: strOr(j['id']), name: strOr(j['name'], '–'), since: str(j['since']));
}

/// `PatientSummary` / `PatientProfile` (§4).
class Patient {
  const Patient({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.dob,
    this.avatarUrl,
    this.phone,
    this.bloodGroup,
    this.heightCm,
    this.weightKg,
    this.allergies = const [],
    this.conditions = const [],
  });

  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? dob;
  final String? avatarUrl;
  final String? phone;
  final String? bloodGroup;
  final num? heightCm;
  final num? weightKg;
  final List<Allergy> allergies;
  final List<Condition> conditions;

  factory Patient.fromJson(Json j) => Patient(
    id: strOr(j['id']),
    name: strOr(j['name'], '–'),
    age: intOrNull(j['age']),
    gender: str(j['gender']),
    dob: str(j['dob']),
    avatarUrl: str(j['avatarUrl']),
    phone: str(j['phone']),
    bloodGroup: str(j['bloodGroup']),
    heightCm: numOrNull(j['heightCm']),
    weightKg: numOrNull(j['weightKg']),
    allergies: jsonList(j['allergies']).map(Allergy.fromJson).toList(),
    conditions: jsonList(j['conditions']).map(Condition.fromJson).toList(),
  );
}

/// `Medication` (§11).
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    this.times = const [],
    this.instructions,
    this.source,
    this.prescribedByName,
    this.active = true,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String name;
  final String dose;
  final String frequency;
  final List<String> times;
  final String? instructions;
  final String? source;
  final String? prescribedByName;
  final bool active;
  final String? startDate;
  final String? endDate;

  factory Medication.fromJson(Json j) => Medication(
    id: strOr(j['id']),
    name: strOr(j['name'], '–'),
    dose: strOr(j['dose']),
    frequency: strOr(j['frequency']),
    times: stringList(j['times']),
    instructions: str(j['instructions']),
    source: str(j['source']),
    prescribedByName: str(j['prescribedByName']),
    active: boolOr(j['active'], true),
    startDate: str(j['startDate']),
    endDate: str(j['endDate']),
  );
}

/// `VitalMeasurement` (§9).
class Vital {
  const Vital({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    this.measuredAt,
    this.source,
    this.recordedByName,
  });

  final String id;
  final String type;
  final num value;
  final String unit;
  final DateTime? measuredAt;
  final String? source;
  final String? recordedByName;

  factory Vital.fromJson(Json j) => Vital(
    id: strOr(j['id']),
    type: strOr(j['type']),
    value: numOrNull(j['value']) ?? 0,
    unit: strOr(j['unit']),
    measuredAt: dateOrNull(j['measuredAt']),
    source: str(j['source']),
    recordedByName: str(j['recordedByName']),
  );
}

/// `MedicalRecord` (§9).
class MedicalRecord {
  const MedicalRecord({
    required this.id,
    required this.type,
    required this.title,
    this.recordDate,
    this.source,
    this.fileName,
    this.mimeType,
    this.hasFile = false,
    this.aiSummary,
    this.uploadedByName,
  });

  final String id;
  final String type;
  final String title;
  final String? recordDate;
  final String? source;
  final String? fileName;
  final String? mimeType;
  final bool hasFile;
  final String? aiSummary;
  final String? uploadedByName;

  bool get isPdf => (mimeType ?? '').contains('pdf') || (fileName ?? '').toLowerCase().endsWith('.pdf');
  bool get isImage => (mimeType ?? '').startsWith('image/');

  factory MedicalRecord.fromJson(Json j) => MedicalRecord(
    id: strOr(j['id']),
    type: strOr(j['type'], 'other'),
    title: strOr(j['title'], '–'),
    recordDate: str(j['recordDate']),
    source: str(j['source']),
    fileName: str(j['fileName']),
    mimeType: str(j['mimeType']),
    hasFile: boolOr(j['hasFile'], true),
    aiSummary: str(asJson(j['aiSummary'])['text']),
    uploadedByName: str(j['uploadedByName']),
  );
}

/// Home-visit findings in the snapshot (a subset of `HomeVisit`, §8).
class VisitFinding {
  const VisitFinding({
    required this.id,
    required this.serviceName,
    required this.status,
    this.summary,
    this.notes,
    this.providerName,
    this.at,
    this.vitals = const [],
    this.escalationReason,
  });

  final String id;
  final String serviceName;
  final String status;
  final String? summary;
  final String? notes;
  final String? providerName;
  final DateTime? at;
  final List<Vital> vitals;
  final String? escalationReason;

  factory VisitFinding.fromJson(Json j) => VisitFinding(
    id: strOr(j['id']),
    serviceName: strOr(j['serviceName'], strOr(j['serviceCode'])),
    status: strOr(j['status']),
    summary: str(j['summary']),
    notes: str(asJson(j['observations'])['notes']),
    providerName: str(asJson(j['provider'])['name']),
    at: dateOrNull(j['preferredStart']) ?? dateOrNull(j['createdAt']),
    vitals: jsonList(j['vitals']).map(Vital.fromJson).toList(),
    escalationReason: str(asJson(j['escalation'])['reason']),
  );
}

class AiSource {
  const AiSource({required this.kind, required this.label, this.refId});
  final String kind;
  final String label;
  final String? refId;

  factory AiSource.fromJson(Json j) =>
      AiSource(kind: strOr(j['kind']), label: strOr(j['label'], strOr(j['kind'])), refId: str(j['refId']));
}

class AiClaim {
  const AiClaim({required this.text, this.sources = const []});
  final String text;
  final List<AiSource> sources;

  factory AiClaim.fromJson(Json j) =>
      AiClaim(text: strOr(j['text']), sources: jsonList(j['sources']).map(AiSource.fromJson).toList());
}

/// The advisory AI summary of `ClinicalSnapshot` (§16).
class AiSummary {
  const AiSummary({
    required this.interactionId,
    required this.text,
    this.model,
    this.generatedAt,
    this.claims = const [],
  });
  final String interactionId;
  final String text;
  final String? model;
  final DateTime? generatedAt;
  final List<AiClaim> claims;

  static AiSummary? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final j = asJson(raw);
    return AiSummary(
      interactionId: strOr(j['interactionId']),
      text: strOr(j['text']),
      model: str(j['model']),
      generatedAt: dateOrNull(j['generatedAt']),
      claims: jsonList(j['claims']).map(AiClaim.fromJson).toList(),
    );
  }
}

/// `CareEpisode` (§5).
class CareEpisode {
  const CareEpisode({
    required this.id,
    required this.patientId,
    required this.title,
    required this.status,
    this.patientName,
    this.concern,
    this.priority = 'routine',
    this.nextAction,
    this.ownerName,
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String? patientName;
  final String title;
  final String? concern;
  final String status;
  final String priority;
  final String? nextAction;
  final String? ownerName;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  factory CareEpisode.fromJson(Json j) => CareEpisode(
    id: strOr(j['id']),
    patientId: strOr(j['patientId']),
    patientName: str(j['patientName']),
    title: strOr(j['title'], '–'),
    concern: str(j['concern']),
    status: strOr(j['status']),
    priority: strOr(j['priority'], 'routine'),
    nextAction: str(j['nextAction']),
    ownerName: str(j['ownerName']),
    updatedAt: dateOrNull(j['updatedAt']),
    createdAt: dateOrNull(j['createdAt']),
  );
}

/// A few intake fields from the AI intake (§10), for the consultation header.
class IntakeBrief {
  const IntakeBrief({this.chiefComplaint, this.duration, this.severity, this.symptoms = const []});
  final String? chiefComplaint;
  final String? duration;
  final num? severity;
  final List<String> symptoms;

  bool get isEmpty => chiefComplaint == null && duration == null && severity == null && symptoms.isEmpty;

  static IntakeBrief? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final j = asJson(raw);
    Object? v(String k) => asJson(j[k])['value'];
    final b = IntakeBrief(
      chiefComplaint: str(v('chiefComplaint')),
      duration: str(v('durationText')),
      severity: numOrNull(v('severity')),
      symptoms: stringList(v('associatedSymptoms')),
    );
    return b.isEmpty ? null : b;
  }
}

/// `ClinicalSnapshot` (§16).
class ClinicalSnapshot {
  const ClinicalSnapshot({
    required this.patient,
    this.activeEpisodes = const [],
    this.activeMedications = const [],
    this.recentVitals = const [],
    this.recentRecords = const [],
    this.homeVisitFindings = const [],
    this.aiSummary,
    this.intake,
  });

  final Patient patient;
  final List<CareEpisode> activeEpisodes;
  final List<Medication> activeMedications;
  final List<Vital> recentVitals;
  final List<MedicalRecord> recentRecords;
  final List<VisitFinding> homeVisitFindings;
  final AiSummary? aiSummary;
  final IntakeBrief? intake;

  factory ClinicalSnapshot.fromJson(Json j) => ClinicalSnapshot(
    patient: Patient.fromJson(asJson(j['patient'])),
    activeEpisodes: jsonList(j['activeEpisodes']).map(CareEpisode.fromJson).toList(),
    activeMedications: jsonList(j['activeMedications']).map(Medication.fromJson).toList(),
    recentVitals: jsonList(j['recentVitals']).map(Vital.fromJson).toList(),
    recentRecords: jsonList(j['recentRecords']).map(MedicalRecord.fromJson).toList(),
    homeVisitFindings: jsonList(j['homeVisitFindings']).map(VisitFinding.fromJson).toList(),
    aiSummary: AiSummary.fromJsonOrNull(j['aiSummary']),
    intake: IntakeBrief.fromJsonOrNull(j['intake']),
  );

  /// Latest reading per vital type, newest first.
  List<Vital> get latestVitals {
    final sorted = [...recentVitals]
      ..sort((a, b) => (b.measuredAt ?? DateTime(0)).compareTo(a.measuredAt ?? DateTime(0)));
    final seen = <String>{};
    return [
      for (final v in sorted)
        if (seen.add(v.type)) v,
    ];
  }
}

/// `SafetyEvent` (§16).
class SafetyEvent {
  const SafetyEvent({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.level,
    required this.source,
    required this.status,
    this.careEpisodeId,
    this.rules = const [],
    this.assignedToName,
    this.createdAt,
    this.note,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String level;
  final String source;
  final String status;
  final String? careEpisodeId;
  final List<String> rules;
  final String? assignedToName;
  final DateTime? createdAt;
  final String? note;

  bool get isEmergency => level == 'emergency';

  factory SafetyEvent.fromJson(Json j) => SafetyEvent(
    id: strOr(j['id']),
    patientId: strOr(j['patientId']),
    patientName: strOr(j['patientName'], '–'),
    level: strOr(j['level'], 'urgent'),
    source: strOr(j['source']),
    status: strOr(j['status'], 'open'),
    careEpisodeId: str(j['careEpisodeId']),
    rules: jsonList(j['rules']).map((r) => strOr(r['title'], strOr(r['ruleId']))).toList(),
    assignedToName: str(j['assignedToName']),
    createdAt: dateOrNull(j['createdAt']),
    note: str(j['note']),
  );
}

/// `GET /appointments/:id/video-session` (§26).
class VideoSession {
  const VideoSession({
    required this.provider,
    required this.joinUrl,
    required this.roomName,
    this.opensAt,
    this.expiresAt,
  });

  final String provider;
  final String joinUrl;
  final String roomName;
  final DateTime? opensAt;
  final DateTime? expiresAt;

  factory VideoSession.fromJson(Json j) => VideoSession(
    provider: strOr(j['provider'], 'jitsi'),
    joinUrl: strOr(j['joinUrl']),
    roomName: strOr(j['roomName']),
    opensAt: dateOrNull(j['opensAt']),
    expiresAt: dateOrNull(j['expiresAt']),
  );
}

/// Standard list envelope `{ items, nextCursor }`.
List<Json> itemsOf(Object? res) {
  if (res is List) return res.map(asJson).toList();
  return jsonList(asJson(res)['items']);
}
