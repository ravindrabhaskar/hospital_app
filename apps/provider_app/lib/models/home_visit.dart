import 'json.dart';

/// Home-visit statuses from API contract §8.
class VisitStatus {
  VisitStatus._();
  static const requested = 'requested';
  static const unassigned = 'unassigned';
  static const assigned = 'assigned';
  static const accepted = 'accepted';
  static const enRoute = 'en_route';
  static const arrived = 'arrived';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const escalated = 'escalated';
}

class Address {
  const Address({
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.pincode,
    this.lat,
    this.lng,
  });

  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String pincode;
  final double? lat;
  final double? lng;

  bool get hasCoordinates => lat != null && lng != null;

  String get fullText => [line1, if (line2 != null && line2!.isNotEmpty) line2!, city, pincode]
      .where((s) => s.isNotEmpty)
      .join(', ');

  factory Address.fromJson(Json json) => Address(
        line1: strOr(json['line1']),
        line2: str(json['line2']),
        landmark: str(json['landmark']),
        city: strOr(json['city']),
        pincode: strOr(json['pincode']),
        lat: numOrNull(json['lat'])?.toDouble(),
        lng: numOrNull(json['lng'])?.toDouble(),
      );

  Json toJson() => {
        'line1': line1,
        if (line2 != null) 'line2': line2,
        if (landmark != null) 'landmark': landmark,
        'city': city,
        'pincode': pincode,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

class VisitProvider {
  const VisitProvider({required this.id, required this.name, this.qualification, this.phoneMasked});
  final String id;
  final String name;
  final String? qualification;
  final String? phoneMasked;

  factory VisitProvider.fromJson(Json json) => VisitProvider(
        id: strOr(json['id']),
        name: strOr(json['name']),
        qualification: str(json['qualification']),
        phoneMasked: str(json['phoneMasked']),
      );

  Json toJson() => {'id': id, 'name': name, 'qualification': qualification, 'phoneMasked': phoneMasked};
}

class TimelineEntry {
  const TimelineEntry({required this.status, required this.at, this.note});
  final String status;
  final DateTime? at;
  final String? note;

  factory TimelineEntry.fromJson(Json json) => TimelineEntry(
        status: strOr(json['status']),
        at: dateOrNull(json['at']),
        note: str(json['note']),
      );

  Json toJson() => {'status': status, 'at': at?.toUtc().toIso8601String(), 'note': note};
}

/// Minimum-necessary patient context; only present for provider/doctor views.
class PatientContext {
  const PatientContext({
    this.age,
    this.gender,
    this.allergies = const [],
    this.conditions = const [],
    this.activeMedications = const [],
  });

  final int? age;
  final String? gender;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> activeMedications;

  factory PatientContext.fromJson(Json json) => PatientContext(
        age: intOrNull(json['age']),
        gender: str(json['gender']),
        allergies: stringList(json['allergies']),
        conditions: stringList(json['conditions']),
        activeMedications: stringList(json['activeMedications']),
      );

  Json toJson() => {
        'age': age,
        'gender': gender,
        'allergies': allergies,
        'conditions': conditions,
        'activeMedications': activeMedications,
      };
}

class VitalMeasurement {
  const VitalMeasurement({
    this.id,
    required this.type,
    required this.value,
    required this.unit,
    required this.measuredAt,
    this.recordedByName,
  });

  final String? id;
  final String type;
  final num value;
  final String unit;
  final DateTime? measuredAt;
  final String? recordedByName;

  factory VitalMeasurement.fromJson(Json json) => VitalMeasurement(
        id: str(json['id']),
        type: strOr(json['type']),
        value: numOrNull(json['value']) ?? 0,
        unit: strOr(json['unit']),
        measuredAt: dateOrNull(json['measuredAt']),
        recordedByName: str(json['recordedByName']),
      );

  Json toJson() => {
        if (id != null) 'id': id,
        'type': type,
        'value': value,
        'unit': unit,
        'measuredAt': measuredAt?.toUtc().toIso8601String(),
        if (recordedByName != null) 'recordedByName': recordedByName,
      };
}

class VisitObservations {
  const VisitObservations({required this.notes, required this.checklist});
  final String notes;
  final Map<String, dynamic> checklist;

  factory VisitObservations.fromJson(Json json) =>
      VisitObservations(notes: strOr(json['notes']), checklist: asJson(json['checklist']));

  Json toJson() => {'notes': notes, 'checklist': checklist};
}

class VisitEscalation {
  const VisitEscalation({required this.reason, required this.severity, this.at});
  final String reason;
  final String severity;
  final DateTime? at;

  factory VisitEscalation.fromJson(Json json) => VisitEscalation(
        reason: strOr(json['reason']),
        severity: strOr(json['severity']),
        at: dateOrNull(json['at']),
      );

  Json toJson() => {'reason': reason, 'severity': severity, 'at': at?.toUtc().toIso8601String()};
}

/// A lab test ordered for a `sample_collection` visit (§44). The §8 HomeVisit
/// shape has no tests field, so this is read only if the server sends one
/// (`labTests`, `tests` or `labOrder.tests`); otherwise the UI falls back to a
/// generic collection checklist.
class VisitLabTest {
  const VisitLabTest({required this.name, this.sampleType, this.fastingRequired = false, this.fastingHours});
  final String name;
  final String? sampleType;
  final bool fastingRequired;
  final int? fastingHours;

  factory VisitLabTest.fromJson(Json json) => VisitLabTest(
        name: strOr(json['name'], strOr(json['code'])),
        sampleType: str(json['sampleType']),
        fastingRequired: boolOr(json['fastingRequired']),
        fastingHours: intOrNull(json['fastingHours']),
      );

  Json toJson() => {
        'name': name,
        'sampleType': sampleType,
        'fastingRequired': fastingRequired,
        'fastingHours': fastingHours,
      };

  static List<VisitLabTest> listFrom(Json visit) {
    final order = asJson(visit['labOrder']);
    final raw = visit['labTests'] ?? visit['tests'] ?? order['tests'];
    return jsonList(raw).map(VisitLabTest.fromJson).where((t) => t.name.isNotEmpty).toList();
  }
}

/// `HomeVisit` from API contract §8. `visitCode` is intentionally not modelled:
/// the API never returns it to providers.
class HomeVisit {
  const HomeVisit({
    required this.id,
    required this.status,
    required this.serviceCode,
    required this.serviceName,
    required this.patientId,
    required this.patientName,
    required this.reason,
    required this.address,
    required this.preferredStart,
    required this.preferredEnd,
    this.careEpisodeId,
    this.provider,
    this.etaMinutes,
    this.timeline = const [],
    this.patientContext,
    this.vitals = const [],
    this.observations,
    this.summary,
    this.escalation,
    this.createdAt,
    this.labTests = const [],
    this.pendingSync = false,
  });

  final String id;
  final String status;
  final String serviceCode;
  final String serviceName;
  final String patientId;
  final String patientName;
  final String reason;
  final Address address;
  final DateTime? preferredStart;
  final DateTime? preferredEnd;
  final String? careEpisodeId;
  final VisitProvider? provider;
  final int? etaMinutes;
  final List<TimelineEntry> timeline;
  final PatientContext? patientContext;
  final List<VitalMeasurement> vitals;
  final VisitObservations? observations;
  final String? summary;
  final VisitEscalation? escalation;
  final DateTime? createdAt;

  /// Ordered tests for sample-collection visits, when the server provides them.
  final List<VisitLabTest> labTests;

  bool get isSampleCollection => serviceCode == 'sample_collection';

  /// Any ordered test needs fasting (null when the tests are unknown).
  bool? get fastingRequired => labTests.isEmpty ? null : labTests.any((t) => t.fastingRequired);

  /// Longest fasting period among the ordered tests.
  int? get fastingHours {
    final hours = labTests.map((t) => t.fastingHours).whereType<int>();
    return hours.isEmpty ? null : hours.reduce((a, b) => a > b ? a : b);
  }

  /// Local-only flag: this copy includes actions that are still queued.
  final bool pendingSync;

  /// When the visit was completed (from the timeline), if it was.
  DateTime? get completedAt {
    for (final e in timeline.reversed) {
      if (e.status == VisitStatus.completed) return e.at;
    }
    return null;
  }

  factory HomeVisit.fromJson(Json json) => HomeVisit(
        id: strOr(json['id']),
        status: strOr(json['status'], VisitStatus.requested),
        serviceCode: strOr(json['serviceCode']),
        serviceName: strOr(json['serviceName'], strOr(json['serviceCode'])),
        patientId: strOr(json['patientId']),
        patientName: strOr(json['patientName']),
        reason: strOr(json['reason']),
        address: Address.fromJson(asJson(json['address'])),
        preferredStart: dateOrNull(json['preferredStart']),
        preferredEnd: dateOrNull(json['preferredEnd']),
        careEpisodeId: str(json['careEpisodeId']),
        provider: json['provider'] is Map ? VisitProvider.fromJson(asJson(json['provider'])) : null,
        etaMinutes: intOrNull(json['etaMinutes']),
        timeline: jsonList(json['timeline']).map(TimelineEntry.fromJson).toList(),
        patientContext:
            json['patientContext'] is Map ? PatientContext.fromJson(asJson(json['patientContext'])) : null,
        vitals: jsonList(json['vitals']).map(VitalMeasurement.fromJson).toList(),
        observations:
            json['observations'] is Map ? VisitObservations.fromJson(asJson(json['observations'])) : null,
        summary: str(json['summary']),
        escalation: json['escalation'] is Map ? VisitEscalation.fromJson(asJson(json['escalation'])) : null,
        createdAt: dateOrNull(json['createdAt']),
        labTests: VisitLabTest.listFrom(json),
        pendingSync: boolOr(json['_pendingSync']),
      );

  Json toJson() => {
        'id': id,
        'status': status,
        'serviceCode': serviceCode,
        'serviceName': serviceName,
        'patientId': patientId,
        'patientName': patientName,
        'reason': reason,
        'address': address.toJson(),
        'preferredStart': preferredStart?.toUtc().toIso8601String(),
        'preferredEnd': preferredEnd?.toUtc().toIso8601String(),
        'careEpisodeId': careEpisodeId,
        'provider': provider?.toJson(),
        'etaMinutes': etaMinutes,
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'patientContext': patientContext?.toJson(),
        'vitals': vitals.map((v) => v.toJson()).toList(),
        'observations': observations?.toJson(),
        'summary': summary,
        'escalation': escalation?.toJson(),
        'createdAt': createdAt?.toUtc().toIso8601String(),
        if (labTests.isNotEmpty) 'labTests': labTests.map((t) => t.toJson()).toList(),
        if (pendingSync) '_pendingSync': true,
      };

  HomeVisit copyWith({
    String? status,
    int? etaMinutes,
    List<TimelineEntry>? timeline,
    List<VitalMeasurement>? vitals,
    VisitObservations? observations,
    String? summary,
    VisitEscalation? escalation,
    bool? pendingSync,
    bool clearPatientContext = false,
    bool clearProvider = false,
  }) =>
      HomeVisit(
        id: id,
        status: status ?? this.status,
        serviceCode: serviceCode,
        serviceName: serviceName,
        patientId: patientId,
        patientName: patientName,
        reason: reason,
        address: address,
        preferredStart: preferredStart,
        preferredEnd: preferredEnd,
        careEpisodeId: careEpisodeId,
        provider: clearProvider ? null : provider,
        etaMinutes: etaMinutes ?? this.etaMinutes,
        timeline: timeline ?? this.timeline,
        patientContext: clearPatientContext ? null : patientContext,
        vitals: vitals ?? this.vitals,
        observations: observations ?? this.observations,
        summary: summary ?? this.summary,
        escalation: escalation ?? this.escalation,
        createdAt: createdAt,
        labTests: labTests,
        pendingSync: pendingSync ?? this.pendingSync,
      );
}
