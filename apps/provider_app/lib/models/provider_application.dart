import 'json.dart';

/// Applicant types accepted by `POST /provider-applications` (contract §30).
/// `doctor` applications are approved into the `doctor` role, which uses the
/// web portal, not this app.
const applicationTypes = ['nurse', 'technician', 'intern', 'physiotherapist', 'dietitian', 'doctor'];

/// Document types for `POST /provider-applications/me/documents`.
const applicationDocTypes = ['registration_certificate', 'degree', 'id_proof', 'experience_letter', 'other'];

/// Approval requires at least one of each (contract §30).
const requiredDocTypes = ['registration_certificate', 'id_proof'];

class ApplicationStatus {
  ApplicationStatus._();
  static const submitted = 'submitted';
  static const changesRequested = 'changes_requested';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

/// `ProviderApplication` (contract §30).
class ProviderApplication {
  const ProviderApplication({
    required this.id,
    required this.fullName,
    required this.type,
    required this.qualification,
    required this.registrationNumber,
    required this.registrationCouncil,
    required this.specialty,
    required this.experienceYears,
    required this.languages,
    required this.preferredZoneIds,
    required this.status,
    required this.documents,
    required this.decisionNote,
    required this.decidedByName,
    required this.updatedAt,
    required this.decidedAt,
  });

  final String id;
  final String fullName;
  final String type;
  final String qualification;
  final String registrationNumber;
  final String? registrationCouncil;
  final String? specialty;
  final int experienceYears;
  final List<String> languages;
  final List<String> preferredZoneIds;
  final String status;
  final List<ApplicationDocument> documents;
  final String? decisionNote;
  final String? decidedByName;
  final DateTime? updatedAt;
  final DateTime? decidedAt;

  /// Fields and documents can change only while under review (PATCH rules).
  bool get isEditable => status == ApplicationStatus.submitted || status == ApplicationStatus.changesRequested;

  List<String> get missingRequiredDocs =>
      [for (final t in requiredDocTypes) if (!documents.any((d) => d.docType == t)) t];

  factory ProviderApplication.fromJson(Json json) => ProviderApplication(
        id: strOr(json['id']),
        fullName: strOr(json['fullName']),
        type: strOr(json['type'], 'nurse'),
        qualification: strOr(json['qualification']),
        registrationNumber: strOr(json['registrationNumber']),
        registrationCouncil: str(json['registrationCouncil']),
        specialty: str(json['specialty']),
        experienceYears: intOrNull(json['experienceYears']) ?? 0,
        languages: stringList(json['languages']),
        preferredZoneIds: stringList(json['preferredZoneIds']),
        status: strOr(json['status'], ApplicationStatus.submitted),
        documents: jsonList(json['documents']).map(ApplicationDocument.fromJson).toList(),
        decisionNote: str(json['decisionNote']),
        decidedByName: str(json['decidedByName']),
        updatedAt: dateOrNull(json['updatedAt']),
        decidedAt: dateOrNull(json['decidedAt']),
      );
}

class ApplicationDocument {
  const ApplicationDocument({
    required this.id,
    required this.docType,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final String id;
  final String docType;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime? uploadedAt;

  factory ApplicationDocument.fromJson(Json json) => ApplicationDocument(
        id: strOr(json['id']),
        docType: strOr(json['docType'], 'other'),
        fileName: strOr(json['fileName']),
        mimeType: strOr(json['mimeType']),
        sizeBytes: intOrNull(json['sizeBytes']) ?? 0,
        uploadedAt: dateOrNull(json['uploadedAt']),
      );
}

/// A preferred service zone resolved from a pincode via
/// `POST /home-visit/serviceability` (the zone list itself is admin-only).
class ZoneChoice {
  const ZoneChoice({required this.id, this.name});
  final String id;

  /// Null for zones loaded from an existing application (only ids are stored).
  final String? name;
}

/// Form state for `POST`/`PATCH /provider-applications(/me)`.
class ApplicationDraft {
  ApplicationDraft({
    this.type = 'nurse',
    this.fullName = '',
    this.qualification = '',
    this.registrationNumber = '',
    this.registrationCouncil = '',
    this.specialty,
    this.experienceYears = 0,
    List<String>? languages,
    List<ZoneChoice>? zones,
  })  : languages = languages ?? [],
        zones = zones ?? [];

  String type;
  String fullName;
  String qualification;
  String registrationNumber;
  String registrationCouncil;
  String? specialty;
  int experienceYears;
  final List<String> languages;
  final List<ZoneChoice> zones;

  bool get isDoctor => type == 'doctor';

  factory ApplicationDraft.fromApplication(ProviderApplication a) => ApplicationDraft(
        type: a.type,
        fullName: a.fullName,
        qualification: a.qualification,
        registrationNumber: a.registrationNumber,
        registrationCouncil: a.registrationCouncil ?? '',
        specialty: a.specialty,
        experienceYears: a.experienceYears,
        languages: [...a.languages],
        zones: [for (final id in a.preferredZoneIds) ZoneChoice(id: id)],
      );

  Json toJson() => {
        'type': type,
        'fullName': fullName.trim(),
        'qualification': qualification.trim(),
        'registrationNumber': registrationNumber.trim(),
        if (registrationCouncil.trim().isNotEmpty) 'registrationCouncil': registrationCouncil.trim(),
        if (isDoctor && specialty != null) 'specialty': specialty,
        'experienceYears': experienceYears,
        'languages': languages,
        'preferredZoneIds': [for (final z in zones) z.id],
      };
}
