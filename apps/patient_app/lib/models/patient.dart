import 'json.dart';

class FamilyPermission {
  FamilyPermission._();
  static const viewRecords = 'view_records';
  static const manageCare = 'manage_care';
  static const book = 'book';
  static const receiveAlerts = 'receive_alerts';
  static const all = [viewRecords, manageCare, book, receiveAlerts];
}

class PatientSummary {
  PatientSummary({
    required this.id,
    required this.name,
    required this.dob,
    required this.age,
    required this.gender,
    required this.relation,
    required this.isSelf,
    required this.permissions,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String? dob;
  final int? age;
  final String gender;
  final String relation;
  final bool isSelf;
  final List<String> permissions;
  final String? avatarUrl;

  bool can(String permission) => isSelf || permissions.contains(permission);

  factory PatientSummary.fromJson(Json j) => PatientSummary(
        id: str(j, 'id'),
        name: str(j, 'name'),
        dob: strOrNull(j, 'dob'),
        age: intOrNull(j, 'age'),
        gender: str(j, 'gender'),
        relation: str(j, 'relation', 'self'),
        isSelf: boolOf(j, 'isSelf'),
        permissions: strList(j, 'permissions'),
        avatarUrl: strOrNull(j, 'avatarUrl'),
      );
}

class Allergy {
  Allergy({
    required this.id,
    required this.substance,
    this.reaction,
    this.severity,
    required this.source,
    this.createdAt,
  });
  final String id;
  final String substance;
  final String? reaction;
  final String? severity;
  final String source;
  final DateTime? createdAt;

  factory Allergy.fromJson(Json j) => Allergy(
        id: str(j, 'id'),
        substance: str(j, 'substance'),
        reaction: strOrNull(j, 'reaction'),
        severity: strOrNull(j, 'severity'),
        source: str(j, 'source'),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

class Condition {
  Condition({
    required this.id,
    required this.name,
    this.since,
    required this.source,
    this.createdAt,
  });
  final String id;
  final String name;
  final String? since;
  final String source;
  final DateTime? createdAt;

  factory Condition.fromJson(Json j) => Condition(
        id: str(j, 'id'),
        name: str(j, 'name'),
        since: strOrNull(j, 'since'),
        source: str(j, 'source'),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

class EmergencyContact {
  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
  });
  final String id;
  final String name;
  final String phone;
  final String relation;

  factory EmergencyContact.fromJson(Json j) => EmergencyContact(
        id: str(j, 'id'),
        name: str(j, 'name'),
        phone: str(j, 'phone'),
        relation: str(j, 'relation'),
      );
}

class PatientProfile extends PatientSummary {
  PatientProfile({
    required super.id,
    required super.name,
    required super.dob,
    required super.age,
    required super.gender,
    required super.relation,
    required super.isSelf,
    required super.permissions,
    required super.avatarUrl,
    required this.phone,
    required this.bloodGroup,
    required this.heightCm,
    required this.weightKg,
    required this.allergies,
    required this.conditions,
    required this.emergencyContacts,
    this.abha,
  });

  /// ABHA (ABDM Health ID) link, null when never entered (§39).
  final AbhaInfo? abha;
  final String? phone;
  final String? bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final List<Allergy> allergies;
  final List<Condition> conditions;
  final List<EmergencyContact> emergencyContacts;

  factory PatientProfile.fromJson(Json j) {
    final s = PatientSummary.fromJson(j);
    return PatientProfile(
      id: s.id,
      name: s.name,
      dob: s.dob,
      age: s.age,
      gender: s.gender,
      relation: s.relation,
      isSelf: s.isSelf,
      permissions: s.permissions,
      avatarUrl: s.avatarUrl,
      phone: strOrNull(j, 'phone'),
      bloodGroup: strOrNull(j, 'bloodGroup'),
      heightCm: dblOrNull(j, 'heightCm'),
      weightKg: dblOrNull(j, 'weightKg'),
      allergies: listOf(j['allergies'], Allergy.fromJson),
      conditions: listOf(j['conditions'], Condition.fromJson),
      emergencyContacts: listOf(j['emergencyContacts'], EmergencyContact.fromJson),
      abha: j['abha'] is Map ? AbhaInfo.fromJson(asJson(j['abha'])) : null,
    );
  }
}

class FamilyAccessGrant {
  FamilyAccessGrant({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.granteeUserId,
    required this.granteeName,
    required this.granteePhone,
    required this.relation,
    required this.permissions,
    required this.status,
    required this.createdAt,
    required this.revokedAt,
  });
  final String id;
  final String patientId;
  final String patientName;
  final String granteeUserId;
  final String? granteeName;
  final String granteePhone;
  final String relation;
  final List<String> permissions;
  final String status;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  bool get isActive => status == 'active';

  factory FamilyAccessGrant.fromJson(Json j) => FamilyAccessGrant(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        granteeUserId: str(j, 'granteeUserId'),
        granteeName: strOrNull(j, 'granteeName'),
        granteePhone: str(j, 'granteePhone'),
        relation: str(j, 'relation'),
        permissions: strList(j, 'permissions'),
        status: str(j, 'status'),
        createdAt: dateOrNull(j, 'createdAt'),
        revokedAt: dateOrNull(j, 'revokedAt'),
      );
}

/// `PatientProfile.abha` (API_CONTRACT §39).
class AbhaInfo {
  const AbhaInfo({required this.number, required this.address, required this.status});
  final String? number;
  final String? address;
  final String status;

  bool get verified => status == 'verified';

  factory AbhaInfo.fromJson(Json j) => AbhaInfo(
        number: strOrNull(j, 'number'),
        address: strOrNull(j, 'address'),
        status: str(j, 'status', 'unverified'),
      );
}
