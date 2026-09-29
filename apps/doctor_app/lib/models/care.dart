import 'json.dart';

/// `ProgramThreshold` (contract §42).
class ProgramThreshold {
  const ProgramThreshold({
    required this.type,
    required this.op,
    required this.value,
    required this.level,
    this.message = '',
  });
  final String type;
  final String op;
  final num value;
  final String level;
  final String message;

  factory ProgramThreshold.fromJson(Json j) => ProgramThreshold(
    type: strOr(j['type']),
    op: strOr(j['op'], 'gt'),
    value: numOrNull(j['value']) ?? 0,
    level: strOr(j['level'], 'urgent'),
    message: strOr(j['message']),
  );

  Json toJson() => {'type': type, 'op': op, 'value': value, 'level': level, 'message': message};

  ProgramThreshold copyWith({num? value, String? level}) =>
      ProgramThreshold(type: type, op: op, value: value ?? this.value, level: level ?? this.level, message: message);
}

/// `ProgramTemplate` (§42).
class ProgramTemplate {
  const ProgramTemplate({
    required this.code,
    required this.name,
    this.description = '',
    this.defaultThresholds = const [],
    this.status = 'fixture_unapproved',
    this.version,
  });

  final String code;
  final String name;
  final String description;
  final List<ProgramThreshold> defaultThresholds;
  final String status;
  final String? version;

  bool get approved => status == 'approved';

  factory ProgramTemplate.fromJson(Json j) => ProgramTemplate(
    code: strOr(j['code']),
    name: strOr(j['name'], strOr(j['code'])),
    description: strOr(j['description']),
    defaultThresholds: jsonList(j['defaultThresholds']).map(ProgramThreshold.fromJson).toList(),
    status: strOr(j['status'], 'fixture_unapproved'),
    version: str(j['version']),
  );
}

/// `Enrollment` (§42).
class Enrollment {
  const Enrollment({
    required this.id,
    required this.templateName,
    required this.status,
    this.templateCode = '',
    this.thresholds = const [],
    this.startDate,
    this.endDate,
    this.adherencePct7d,
    this.lastReadingAt,
    this.openBreaches = 0,
  });

  final String id;
  final String templateCode;
  final String templateName;
  final String status;
  final List<ProgramThreshold> thresholds;
  final String? startDate;
  final String? endDate;
  final num? adherencePct7d;
  final DateTime? lastReadingAt;
  final int openBreaches;

  factory Enrollment.fromJson(Json j) => Enrollment(
    id: strOr(j['id']),
    templateCode: strOr(j['templateCode']),
    templateName: strOr(j['templateName'], strOr(j['templateCode'])),
    status: strOr(j['status'], 'active'),
    thresholds: jsonList(j['thresholds']).map(ProgramThreshold.fromJson).toList(),
    startDate: str(j['startDate']),
    endDate: str(j['endDate']),
    adherencePct7d: numOrNull(j['adherencePct7d']),
    lastReadingAt: dateOrNull(j['lastReadingAt']),
    openBreaches: intOrNull(j['openBreaches']) ?? 0,
  );
}

/// `SecondOpinion` (§49).
class SecondOpinion {
  const SecondOpinion({
    required this.id,
    required this.patientName,
    required this.specialty,
    required this.question,
    required this.status,
    this.patientId = '',
    this.records = const [],
    this.price,
    this.doctorName,
    this.opinion,
    this.recommendations = const [],
    this.dueAt,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String specialty;
  final String question;
  final String status;
  final List<({String id, String title})> records;
  final num? price;
  final String? doctorName;
  final String? opinion;
  final List<String> recommendations;
  final DateTime? dueAt;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';
  bool get isClaimed => status == 'claimed';
  bool get isAnswered => status == 'answered';

  factory SecondOpinion.fromJson(Json j) => SecondOpinion(
    id: strOr(j['id']),
    patientId: strOr(j['patientId']),
    patientName: strOr(j['patientName'], '–'),
    specialty: strOr(j['specialty']),
    question: strOr(j['question']),
    status: strOr(j['status'], 'open'),
    records: jsonList(j['records']).map((r) => (id: strOr(r['id']), title: strOr(r['title'], '–'))).toList(),
    price: numOrNull(j['price']),
    doctorName: str(j['doctorName']),
    opinion: str(j['opinion']),
    recommendations: stringList(j['recommendations']),
    dueAt: dateOrNull(j['dueAt']),
    createdAt: dateOrNull(j['createdAt']),
  );
}

/// `ScribeDraft` (§46). Advisory: never auto-saved into the record.
class ScribeDraft {
  const ScribeDraft({
    required this.id,
    required this.transcript,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    this.model,
  });

  final String id;
  final String transcript;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final String? model;

  factory ScribeDraft.fromJson(Json j) {
    final d = asJson(j['draft']);
    return ScribeDraft(
      id: strOr(j['id']),
      transcript: strOr(j['transcript']),
      subjective: strOr(d['subjective']),
      objective: strOr(d['objective']),
      assessment: strOr(d['assessment']),
      plan: strOr(d['plan']),
      model: str(j['model']),
    );
  }
}

/// A `Facility` (§6), for referrals.
class Facility {
  const Facility({
    required this.id,
    required this.name,
    this.type = 'hospital',
    this.area,
    this.city,
    this.emergency24x7 = false,
  });
  final String id;
  final String name;
  final String type;
  final String? area;
  final String? city;
  final bool emergency24x7;

  factory Facility.fromJson(Json j) => Facility(
    id: strOr(j['id']),
    name: strOr(j['name'], '–'),
    type: strOr(j['type'], 'hospital'),
    area: str(j['area']),
    city: str(j['city']),
    emergency24x7: boolOr(j['emergency24x7']),
  );
}

/// Exercise library item (§53).
class Exercise {
  const Exercise({required this.id, required this.title, this.bodyArea = '', this.level = ''});
  final String id;
  final String title;
  final String bodyArea;
  final String level;

  factory Exercise.fromJson(Json j) => Exercise(
    id: strOr(j['id']),
    title: strOr(j['title'], '–'),
    bodyArea: strOr(j['bodyArea']),
    level: strOr(j['level']),
  );
}

/// Diet template (§54).
class DietTemplate {
  const DietTemplate({required this.code, required this.name, this.conditions = const []});
  final String code;
  final String name;
  final List<String> conditions;

  factory DietTemplate.fromJson(Json j) => DietTemplate(
    code: strOr(j['code']),
    name: strOr(j['name'], strOr(j['code'])),
    conditions: stringList(j['conditions']),
  );
}

const dietSlots = ['early_morning', 'breakfast', 'mid_morning', 'lunch', 'evening', 'dinner', 'bedtime'];
