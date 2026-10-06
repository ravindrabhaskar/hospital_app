import 'doctor.dart';
import 'json.dart';

// Models for API_CONTRACT v1.3 bookable services: lab tests (§44), second
// opinion (§49), ABDM (§50), insurance (§51) and ambulance (§55).

// ---------------------------------------------------------------- §44 Lab tests

class LabTest {
  const LabTest({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.sampleType,
    required this.fastingRequired,
    required this.fastingHours,
    required this.turnaroundHours,
    required this.price,
    required this.mrp,
    required this.partnerName,
  });
  final String id;
  final String code;
  final String name;
  final String description;
  final String category;
  final String sampleType;
  final bool fastingRequired;
  final int? fastingHours;
  final int turnaroundHours;
  final int price;
  final int mrp;
  final String partnerName;

  factory LabTest.fromJson(Json j) => LabTest(
        id: str(j, 'id'),
        code: str(j, 'code'),
        name: str(j, 'name'),
        description: str(j, 'description'),
        category: str(j, 'category'),
        sampleType: str(j, 'sampleType', 'blood'),
        fastingRequired: boolOf(j, 'fastingRequired'),
        fastingHours: intOrNull(j, 'fastingHours'),
        turnaroundHours: intOf(j, 'turnaroundHours'),
        price: intOf(j, 'price'),
        mrp: intOf(j, 'mrp'),
        partnerName: str(j, 'partnerName'),
      );
}

class LabPackage {
  const LabPackage({
    required this.id,
    required this.code,
    required this.name,
    required this.testIds,
    required this.price,
    required this.mrp,
    required this.description,
  });
  final String id;
  final String code;
  final String name;
  final List<String> testIds;
  final int price;
  final int mrp;
  final String description;

  factory LabPackage.fromJson(Json j) => LabPackage(
        id: str(j, 'id'),
        code: str(j, 'code'),
        name: str(j, 'name'),
        testIds: strList(j, 'testIds'),
        price: intOf(j, 'price'),
        mrp: intOf(j, 'mrp'),
        description: str(j, 'description'),
      );
}

/// The lab cart: individual tests plus packages. A test that is already part
/// of a selected package is not charged again (and not sent as a `testId`).
class LabCart {
  const LabCart({this.tests = const {}, this.packages = const {}});
  final Map<String, LabTest> tests;
  final Map<String, LabPackage> packages;

  bool get isEmpty => tests.isEmpty && packages.isEmpty;
  int get count => tests.length + packages.length;

  bool hasTest(String id) => tests.containsKey(id);
  bool hasPackage(String id) => packages.containsKey(id);

  /// True when [testId] is included in one of the selected packages.
  bool coveredByPackage(String testId) => packages.values.any((p) => p.testIds.contains(testId));

  LabCart toggleTest(LabTest t) {
    final next = Map<String, LabTest>.from(tests);
    if (next.containsKey(t.id)) {
      next.remove(t.id);
    } else {
      next[t.id] = t;
    }
    return LabCart(tests: next, packages: packages);
  }

  LabCart togglePackage(LabPackage p) {
    final next = Map<String, LabPackage>.from(packages);
    if (next.containsKey(p.id)) {
      next.remove(p.id);
    } else {
      next[p.id] = p;
    }
    return LabCart(tests: tests, packages: next);
  }

  /// Tests charged individually (not covered by a selected package).
  List<LabTest> get chargedTests => tests.values.where((t) => !coveredByPackage(t.id)).toList();

  int get total =>
      chargedTests.fold<int>(0, (a, t) => a + t.price) + packages.values.fold<int>(0, (a, p) => a + p.price);

  int get mrpTotal =>
      chargedTests.fold<int>(0, (a, t) => a + (t.mrp > 0 ? t.mrp : t.price)) +
      packages.values.fold<int>(0, (a, p) => a + (p.mrp > 0 ? p.mrp : p.price));

  List<String> get testIds => chargedTests.map((t) => t.id).toList();
  List<String> get packageIds => packages.keys.toList();

  /// The longest fasting requirement across all tests in the cart, including
  /// tests inside packages ([catalog] resolves package test ids). Null when
  /// no fasting is needed. A fasting test without hours counts as 8 h.
  int? fastingHours(Map<String, LabTest> catalog) {
    final all = <LabTest>[
      ...tests.values,
      for (final p in packages.values)
        for (final id in p.testIds)
          if (catalog[id] != null) catalog[id]!,
    ];
    int? max;
    for (final t in all) {
      if (!t.fastingRequired) continue;
      final h = t.fastingHours ?? 8;
      if (max == null || h > max) max = h;
    }
    return max;
  }
}

class StatusStep {
  const StatusStep({required this.status, required this.at});
  final String status;
  final DateTime at;

  factory StatusStep.fromJson(Json j) => StatusStep(status: str(j, 'status'), at: dateOf(j, 'at'));
}

class LabOrder {
  const LabOrder({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.tests,
    required this.total,
    required this.discount,
    required this.status,
    required this.collectionVisitId,
    required this.preferredStart,
    required this.preferredEnd,
    required this.reportRecordId,
    required this.partnerName,
    required this.timeline,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final String patientName;
  final List<({String id, String name})> tests;
  final int total;
  final int discount;
  final String status;
  final String? collectionVisitId;
  final DateTime? preferredStart;
  final DateTime? preferredEnd;
  final String? reportRecordId;
  final String partnerName;
  final List<StatusStep> timeline;
  final DateTime? createdAt;

  static const flow = ['pending_payment', 'scheduled', 'sample_collected', 'processing', 'report_ready'];

  /// The server's `total` is the gross price of the tests (before coupon).
  int get subtotal => total;

  /// What the patient pays (or paid): subtotal minus the coupon discount.
  int get amountDue => total - discount < 0 ? 0 : total - discount;

  bool get reportReady => status == 'report_ready' && reportRecordId != null;
  bool get canCancel => status == 'pending_payment' || status == 'scheduled';

  factory LabOrder.fromJson(Json j) => LabOrder(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        tests: [for (final t in listOf(j['tests'], (e) => e)) (id: str(t, 'id'), name: str(t, 'name'))],
        total: intOf(j, 'total'),
        discount: intOf(j, 'discount'),
        status: str(j, 'status'),
        collectionVisitId: strOrNull(j, 'collectionVisitId'),
        preferredStart: dateOrNull(j, 'preferredStart'),
        preferredEnd: dateOrNull(j, 'preferredEnd'),
        reportRecordId: strOrNull(j, 'reportRecordId'),
        partnerName: str(j, 'partnerName'),
        timeline: listOf(j['timeline'], StatusStep.fromJson),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

// ---------------------------------------------------------------- §49 Second opinion

class SecondOpinionPrice {
  const SecondOpinionPrice({required this.specialty, required this.price, required this.turnaroundHours});
  final String specialty;
  final int price;
  final int turnaroundHours;

  factory SecondOpinionPrice.fromJson(Json j) => SecondOpinionPrice(
        specialty: str(j, 'specialty'),
        price: intOf(j, 'price'),
        turnaroundHours: intOf(j, 'turnaroundHours', 48),
      );
}

class SecondOpinion {
  const SecondOpinion({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.specialty,
    required this.question,
    required this.records,
    required this.status,
    required this.price,
    required this.doctorName,
    required this.opinion,
    required this.recommendations,
    required this.opinionRecordId,
    required this.dueAt,
    required this.createdAt,
    required this.answeredAt,
  });
  final String id;
  final String patientId;
  final String patientName;
  final String specialty;
  final String question;
  final List<({String id, String title})> records;

  /// pending_payment | open | claimed | answered | cancelled
  final String status;
  final int price;
  final String? doctorName;
  final String? opinion;
  final List<String> recommendations;
  final String? opinionRecordId;
  final DateTime? dueAt;
  final DateTime? createdAt;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered';

  factory SecondOpinion.fromJson(Json j) => SecondOpinion(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        specialty: str(j, 'specialty'),
        question: str(j, 'question'),
        records: [for (final r in listOf(j['records'], (e) => e)) (id: str(r, 'id'), title: str(r, 'title'))],
        status: str(j, 'status'),
        price: intOf(j, 'price'),
        doctorName: strOrNull(j, 'doctorName'),
        opinion: strOrNull(j, 'opinion'),
        recommendations: strList(j, 'recommendations'),
        opinionRecordId: strOrNull(j, 'opinionRecordId'),
        dueAt: dateOrNull(j, 'dueAt'),
        createdAt: dateOrNull(j, 'createdAt'),
        answeredAt: dateOrNull(j, 'answeredAt'),
      );
}

// ---------------------------------------------------------------- §50 ABDM

const abdmHiTypes = ['Prescription', 'DiagnosticReport', 'DischargeSummary', 'OPConsultation'];

class AbdmConsentRequest {
  const AbdmConsentRequest({
    required this.id,
    required this.patientId,
    required this.hiTypes,
    required this.from,
    required this.to,
    required this.status,
    required this.recordsImported,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final List<String> hiTypes;
  final String from;
  final String to;

  /// requested | granted | denied | expired | data_received
  final String status;
  final int recordsImported;
  final DateTime? createdAt;

  factory AbdmConsentRequest.fromJson(Json j) => AbdmConsentRequest(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        hiTypes: strList(j, 'hiTypes'),
        from: str(j, 'from'),
        to: str(j, 'to'),
        status: str(j, 'status', 'requested'),
        recordsImported: intOf(j, 'recordsImported'),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

// ---------------------------------------------------------------- §51 Insurance

class Insurer {
  const Insurer({required this.code, required this.name, required this.type});
  final String code;
  final String name;
  final String type;

  factory Insurer.fromJson(Json j) => Insurer(code: str(j, 'code'), name: str(j, 'name'), type: str(j, 'type'));
}

const policyTypes = ['individual', 'family_floater', 'corporate', 'government'];

class InsurancePolicy {
  const InsurancePolicy({
    required this.id,
    required this.patientId,
    required this.insurerCode,
    required this.insurerName,
    required this.policyNumberMasked,
    required this.planName,
    required this.type,
    required this.sumInsured,
    required this.validFrom,
    required this.validTo,
    required this.tpaName,
    required this.cardRecordId,
    required this.status,
  });
  final String id;
  final String patientId;
  final String insurerCode;
  final String insurerName;
  final String policyNumberMasked;
  final String? planName;
  final String type;
  final int? sumInsured;
  final String validFrom;
  final String validTo;
  final String? tpaName;
  final String? cardRecordId;

  /// active | expiring_soon | expired
  final String status;

  factory InsurancePolicy.fromJson(Json j) => InsurancePolicy(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        insurerCode: str(j, 'insurerCode'),
        insurerName: str(j, 'insurerName'),
        policyNumberMasked: str(j, 'policyNumberMasked'),
        planName: strOrNull(j, 'planName'),
        type: str(j, 'type', 'individual'),
        sumInsured: intOrNull(j, 'sumInsured'),
        validFrom: str(j, 'validFrom'),
        validTo: str(j, 'validTo'),
        tpaName: strOrNull(j, 'tpaName'),
        cardRecordId: strOrNull(j, 'cardRecordId'),
        status: str(j, 'status', 'active'),
      );
}

class ClaimChecklist {
  const ClaimChecklist({required this.steps, required this.documents, required this.disclaimer});
  final List<String> steps;
  final List<String> documents;
  final String disclaimer;

  factory ClaimChecklist.fromJson(Json j) =>
      ClaimChecklist(steps: strList(j, 'steps'), documents: strList(j, 'documents'), disclaimer: str(j, 'disclaimer'));
}

// ---------------------------------------------------------------- §55 Ambulance

class AmbulanceRequest {
  const AmbulanceRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.type,
    required this.status,
    required this.vehicleNumber,
    required this.driverName,
    required this.driverPhoneMasked,
    required this.etaMinutes,
    required this.lat,
    required this.lng,
    required this.locationUpdatedAt,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destination,
    required this.partnerName,
    required this.timeline,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final String patientName;

  /// bls | als
  final String type;

  /// searching | assigned | en_route | arrived | transporting | completed | cancelled | no_vehicle
  final String status;
  final String? vehicleNumber;
  final String? driverName;
  final String? driverPhoneMasked;
  final int? etaMinutes;
  final double? lat;
  final double? lng;
  final DateTime? locationUpdatedAt;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final Facility? destination;
  final String partnerName;
  final List<StatusStep> timeline;
  final DateTime? createdAt;

  static const flow = ['searching', 'assigned', 'en_route', 'arrived', 'transporting', 'completed'];

  bool get hasVehicle => vehicleNumber != null;
  bool get isTerminal => status == 'completed' || status == 'cancelled' || status == 'no_vehicle';
  bool get canCancel => status == 'searching' || status == 'assigned' || status == 'en_route';

  factory AmbulanceRequest.fromJson(Json j) {
    final v = j['vehicle'] is Map ? asJson(j['vehicle']) : null;
    final loc = j['location'] is Map ? asJson(j['location']) : null;
    final pickup = asJson(j['pickup']);
    return AmbulanceRequest(
      id: str(j, 'id'),
      patientId: str(j, 'patientId'),
      patientName: str(j, 'patientName'),
      type: str(j, 'type', 'bls'),
      status: str(j, 'status', 'searching'),
      vehicleNumber: v == null ? null : str(v, 'number'),
      driverName: v == null ? null : strOrNull(v, 'driverName'),
      driverPhoneMasked: v == null ? null : strOrNull(v, 'phoneMasked'),
      etaMinutes: intOrNull(j, 'etaMinutes'),
      lat: loc == null ? null : dblOrNull(loc, 'lat'),
      lng: loc == null ? null : dblOrNull(loc, 'lng'),
      locationUpdatedAt: loc == null ? null : dateOrNull(loc, 'updatedAt'),
      pickupAddress: str(pickup, 'address'),
      pickupLat: dblOrNull(pickup, 'lat'),
      pickupLng: dblOrNull(pickup, 'lng'),
      destination: j['destination'] is Map ? Facility.fromJson(asJson(j['destination'])) : null,
      partnerName: str(j, 'partnerName'),
      timeline: listOf(j['timeline'], StatusStep.fromJson),
      createdAt: dateOrNull(j, 'createdAt'),
    );
  }
}
