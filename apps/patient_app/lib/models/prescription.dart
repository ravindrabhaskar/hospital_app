import 'json.dart';
import 'misc.dart';

/// One medicine line of an e-prescription (API_CONTRACT §31 `RxItem`).
class RxItem {
  RxItem({
    required this.drugName,
    required this.strength,
    required this.form,
    required this.dose,
    required this.frequency,
    required this.timing,
    required this.durationDays,
    required this.times,
    required this.instructions,
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

  /// "Paracetamol 500 mg" style display name.
  String get displayName =>
      [drugName, if (strength != null && strength!.trim().isNotEmpty) strength!.trim()].join(' ');

  factory RxItem.fromJson(Json j) => RxItem(
        drugName: str(j, 'drugName'),
        strength: strOrNull(j, 'strength'),
        form: str(j, 'form', 'other'),
        dose: str(j, 'dose'),
        frequency: str(j, 'frequency'),
        timing: strOrNull(j, 'timing'),
        durationDays: intOf(j, 'durationDays'),
        times: strList(j, 'times'),
        instructions: strOrNull(j, 'instructions'),
      );
}

/// A doctor-issued e-prescription (§31 `Prescription`).
class Prescription {
  Prescription({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.doctorId,
    required this.doctorName,
    required this.doctorQualifications,
    required this.doctorRegistration,
    required this.appointmentId,
    required this.careEpisodeId,
    required this.clinicalNote,
    required this.items,
    required this.advice,
    required this.followUpInDays,
    required this.recordId,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final String patientName;
  final int? patientAge;
  final String patientGender;
  final String doctorId;
  final String doctorName;
  final String doctorQualifications;
  final String doctorRegistration;
  final String? appointmentId;
  final String? careEpisodeId;
  final String? clinicalNote;
  final List<RxItem> items;
  final String? advice;
  final int? followUpInDays;
  final String? recordId;
  final DateTime createdAt;

  factory Prescription.fromJson(Json j) => Prescription(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        patientAge: intOrNull(j, 'patientAge'),
        patientGender: str(j, 'patientGender'),
        doctorId: str(j, 'doctorId'),
        doctorName: str(j, 'doctorName'),
        doctorQualifications: str(j, 'doctorQualifications'),
        doctorRegistration: str(j, 'doctorRegistration'),
        appointmentId: strOrNull(j, 'appointmentId'),
        careEpisodeId: strOrNull(j, 'careEpisodeId'),
        clinicalNote: strOrNull(j, 'clinicalNote'),
        items: listOf(j['items'], RxItem.fromJson),
        advice: strOrNull(j, 'advice'),
        followUpInDays: intOrNull(j, 'followUpInDays'),
        recordId: strOrNull(j, 'recordId'),
        createdAt: dateOf(j, 'createdAt'),
      );
}

/// One row of `GET /prescriptions/:id/pharmacy-match`.
class RxMatch {
  RxMatch({required this.itemIndex, required this.drugName, required this.product});
  final int itemIndex;
  final String drugName;
  final Product? product;

  bool get orderable => product != null && product!.inStock;

  factory RxMatch.fromJson(Json j) => RxMatch(
        itemIndex: intOf(j, 'itemIndex'),
        drugName: str(j, 'drugName'),
        product: j['product'] is Map ? Product.fromJson(asJson(j['product'])) : null,
      );
}
