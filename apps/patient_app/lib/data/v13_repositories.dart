import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/care.dart';
import '../models/doctor.dart';
import '../models/engagement_v13.dart';
import '../models/json.dart';
import '../models/monitoring.dart';
import '../models/patient.dart';
import '../models/services.dart';
import 'repositories.dart' show offerFields;

// Repositories for API_CONTRACT v1.3 (§41–§61). One class per domain, same
// style as data/repositories.dart.

const _limit = 50;

List<T> _items<T>(Object? body, T Function(Json) f) => Page.fromJson(body, f).items;

/// A body that is either the object itself or `{ <key>: object, payment? }`.
Json _unwrap(Json j, String key) => j[key] is Map ? asJson(j[key]) : j;

Payment? _payment(Json j) => j['payment'] is Map ? Payment.fromJson(asJson(j['payment'])) : null;

// ---------------------------------------------------------------- §41 Daily check-in

class CheckinRepository {
  CheckinRepository(this.api);
  final ApiClient api;

  /// Settings, or null when none exist yet (404).
  Future<CheckinSettings?> settings(String patientId) async {
    try {
      return CheckinSettings.fromJson(asJson(await api.get('/patients/$patientId/checkin-settings')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<CheckinSettings> saveSettings(String patientId, CheckinSettings s) async =>
      CheckinSettings.fromJson(asJson(await api.put('/patients/$patientId/checkin-settings', body: s.toJson())));

  Future<CheckIn> checkIn(String patientId, {int? mood, String? note}) async =>
      CheckIn.fromJson(asJson(await api.post('/patients/$patientId/checkins', body: {
        'mood': ?mood,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      })));

  Future<List<CheckIn>> history(String patientId, {int days = 30}) async =>
      _items(await api.get('/patients/$patientId/checkins', query: {'days': days}), CheckIn.fromJson);
}

// ---------------------------------------------------------------- §42 Care programs

class ProgramRepository {
  ProgramRepository(this.api);
  final ApiClient api;

  Future<List<ProgramTemplate>> templates() async =>
      _items(await api.get('/care-programs/templates'), ProgramTemplate.fromJson);

  Future<List<Enrollment>> enrollments(String patientId) async => _items(
      await api.get('/care-programs/enrollments', query: {'patientId': patientId, 'limit': _limit}),
      Enrollment.fromJson);

  Future<ProgramSummary> summary(String enrollmentId, {required DateTime from, required DateTime to}) async =>
      ProgramSummary.fromJson(asJson(await api.get('/care-programs/enrollments/$enrollmentId/summary',
          query: {'from': ymd(from), 'to': ymd(to)})));
}

// ---------------------------------------------------------------- §43 WhatsApp

class WhatsappRepository {
  WhatsappRepository(this.api);
  final ApiClient api;

  Future<WhatsappStatus> status() async => WhatsappStatus.fromJson(asJson(await api.get('/me/whatsapp')));

  Future<WhatsappStatus> setOptIn(bool optedIn) async =>
      WhatsappStatus.fromJson(asJson(await api.put('/me/whatsapp', body: {'optedIn': optedIn})));
}

// ---------------------------------------------------------------- §44 Lab tests

class LabRepository {
  LabRepository(this.api);
  final ApiClient api;

  Future<List<LabTest>> tests({String? q, String? category}) async => _items(
      await api.get('/lab/tests', query: {'q': q, 'category': category, 'limit': 100}), LabTest.fromJson);

  Future<List<LabPackage>> packages() async => _items(await api.get('/lab/packages'), LabPackage.fromJson);

  Future<BookingResult<LabOrder>> order({
    required String patientId,
    required List<String> testIds,
    required List<String> packageIds,
    required Address address,
    required DateTime preferredStart,
    required DateTime preferredEnd,
    String? prescriptionId,
    String? careEpisodeId,
    String? couponCode,
    bool useWallet = false,
    required String idempotencyKey,
  }) async {
    final j = asJson(await api.post('/lab/orders', idempotencyKey: idempotencyKey, body: {
      'patientId': patientId,
      'testIds': testIds,
      if (packageIds.isNotEmpty) 'packageIds': packageIds,
      'address': address.toJson(),
      'preferredStart': preferredStart.toUtc().toIso8601String(),
      'preferredEnd': preferredEnd.toUtc().toIso8601String(),
      'prescriptionId': ?prescriptionId,
      'careEpisodeId': ?careEpisodeId,
      ...offerFields(couponCode, useWallet),
    }));
    return BookingResult(LabOrder.fromJson(asJson(j['order'])), Payment.fromJson(asJson(j['payment'])));
  }

  Future<List<LabOrder>> orders(String patientId) async =>
      _items(await api.get('/lab/orders', query: {'patientId': patientId, 'limit': _limit}), LabOrder.fromJson);

  Future<LabOrder> get(String id) async => LabOrder.fromJson(asJson(await api.get('/lab/orders/$id')));

  Future<LabOrder> cancel(String id, String reason) async =>
      LabOrder.fromJson(asJson(await api.post('/lab/orders/$id/cancel', body: {'reason': reason})));
}

// ---------------------------------------------------------------- §49 Second opinion

class SecondOpinionRepository {
  SecondOpinionRepository(this.api);
  final ApiClient api;

  Future<List<SecondOpinionPrice>> pricing() async =>
      _items(await api.get('/second-opinions/pricing'), SecondOpinionPrice.fromJson);

  Future<BookingResult<SecondOpinion>> create({
    required String patientId,
    required String specialty,
    required String question,
    required List<String> recordIds,
    String? couponCode,
    bool useWallet = false,
    required String idempotencyKey,
  }) async {
    final j = asJson(await api.post('/second-opinions', idempotencyKey: idempotencyKey, body: {
      'patientId': patientId,
      'specialty': specialty,
      'question': question,
      'recordIds': recordIds,
      ...offerFields(couponCode, useWallet),
    }));
    return BookingResult(SecondOpinion.fromJson(asJson(j['request'])), Payment.fromJson(asJson(j['payment'])));
  }

  Future<List<SecondOpinion>> list(String patientId) async => _items(
      await api.get('/second-opinions', query: {'patientId': patientId, 'limit': _limit}), SecondOpinion.fromJson);

  Future<SecondOpinion> get(String id) async =>
      SecondOpinion.fromJson(asJson(await api.get('/second-opinions/$id')));
}

// ---------------------------------------------------------------- §50 ABDM

class AbdmRepository {
  AbdmRepository(this.api);
  final ApiClient api;

  /// Starts ABHA creation with a mobile OTP; returns the transaction id.
  Future<String> createStart(String patientId, String mobile) async => str(
      asJson(await api.post('/abdm/abha/create/start',
          body: {'patientId': patientId, 'method': 'mobile', 'mobile': mobile})),
      'txnId');

  Future<AbhaInfo> createVerify(String txnId, String otp) async =>
      AbhaInfo.fromJson(_unwrap(asJson(await api.post('/abdm/abha/create/verify', body: {'txnId': txnId, 'otp': otp})), 'abha'));

  Future<String> linkStart(String patientId, String abhaNumber) async => str(
      asJson(await api.post('/abdm/abha/link-existing/start', body: {'patientId': patientId, 'abhaNumber': abhaNumber})),
      'txnId');

  Future<AbhaInfo> linkVerify(String txnId, String otp) async => AbhaInfo.fromJson(
      _unwrap(asJson(await api.post('/abdm/abha/link-existing/verify', body: {'txnId': txnId, 'otp': otp})), 'abha'));

  Future<AbdmConsentRequest> requestConsent({
    required String patientId,
    required List<String> hiTypes,
    required DateTime from,
    required DateTime to,
  }) async =>
      AbdmConsentRequest.fromJson(asJson(await api.post('/abdm/consent-requests', body: {
        'patientId': patientId,
        'hiTypes': hiTypes,
        'from': ymd(from),
        'to': ymd(to),
        'purpose': 'CAREMGT',
      })));

  Future<List<AbdmConsentRequest>> consentRequests(String patientId) async => _items(
      await api.get('/abdm/consent-requests', query: {'patientId': patientId, 'limit': _limit}),
      AbdmConsentRequest.fromJson);
}

// ---------------------------------------------------------------- §51 Insurance

class InsuranceRepository {
  InsuranceRepository(this.api);
  final ApiClient api;

  Future<List<Insurer>> insurers() async => _items(await api.get('/insurance/insurers'), Insurer.fromJson);

  Future<List<InsurancePolicy>> policies(String patientId) async =>
      _items(await api.get('/patients/$patientId/insurance-policies'), InsurancePolicy.fromJson);

  Future<InsurancePolicy> add(String patientId, Json body) async =>
      InsurancePolicy.fromJson(asJson(await api.post('/patients/$patientId/insurance-policies', body: body)));

  Future<InsurancePolicy?> update(String patientId, String policyId, Json body) async {
    final r = await api.patch('/patients/$patientId/insurance-policies/$policyId', body: body);
    return r is Map ? InsurancePolicy.fromJson(asJson(r)) : null;
  }

  Future<void> delete(String patientId, String policyId) =>
      api.delete('/patients/$patientId/insurance-policies/$policyId');

  Future<ClaimChecklist> checklist(String type) async =>
      ClaimChecklist.fromJson(asJson(await api.get('/insurance/claim-checklist', query: {'type': type})));

  Future<List<Facility>> cashlessFacilities(String insurerCode) async => _items(
      await api.get('/facilities', query: {'cashlessInsurer': insurerCode, 'limit': _limit}), Facility.fromJson);
}

// ---------------------------------------------------------------- §52 Preventive care

class PreventiveRepository {
  PreventiveRepository(this.api);
  final ApiClient api;

  Future<PreventiveSchedule> schedule(String patientId) async =>
      PreventiveSchedule.fromJson(asJson(await api.get('/patients/$patientId/preventive-schedule')));

  Future<PreventiveItem> markDone(String patientId, String code, DateTime doneAt, {String? notes}) async =>
      PreventiveItem.fromJson(asJson(await api.post('/patients/$patientId/preventive-records', body: {
        'code': code,
        'doneAt': ymd(doneAt),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      })));
}

// ---------------------------------------------------------------- §53 Exercise

class ExerciseRepository {
  ExerciseRepository(this.api);
  final ApiClient api;

  Future<List<Exercise>> library({String? bodyArea}) async =>
      _items(await api.get('/exercise-library', query: {'bodyArea': bodyArea, 'limit': 100}), Exercise.fromJson);

  Future<List<ExercisePlan>> plans(String patientId) async =>
      _items(await api.get('/exercise-plans', query: {'patientId': patientId, 'limit': _limit}), ExercisePlan.fromJson);

  Future<void> logSession(String planId, {required List<String> completedExerciseIds, required int painScore, String? note}) =>
      api.post('/exercise-plans/$planId/sessions', body: {
        'completedExerciseIds': completedExerciseIds,
        'painScore': painScore,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<ExerciseProgress> progress(String planId) async =>
      ExerciseProgress.fromJson(asJson(await api.get('/exercise-plans/$planId/progress')));
}

// ---------------------------------------------------------------- §54 Diet

class DietRepository {
  DietRepository(this.api);
  final ApiClient api;

  Future<List<DietPlan>> plans(String patientId) async =>
      _items(await api.get('/diet-plans', query: {'patientId': patientId, 'limit': _limit}), DietPlan.fromJson);

  Future<void> log(String planId, {required DateTime date, required String slot, required bool followed}) =>
      api.post('/diet-plans/$planId/logs', body: {'date': ymd(date), 'slot': slot, 'followed': followed});

  Future<DietAdherence> adherence(String planId, {int days = 14}) async =>
      DietAdherence.fromJson(asJson(await api.get('/diet-plans/$planId/adherence', query: {'days': days})));
}

// ---------------------------------------------------------------- §55 Ambulance

class AmbulanceRepository {
  AmbulanceRepository(this.api);
  final ApiClient api;

  Future<({AmbulanceRequest request, Payment? payment})> request({
    required String patientId,
    required double lat,
    required double lng,
    required String address,
    String? destinationFacilityId,
    required String type,
    required String reason,
    String? sosId,
    required String idempotencyKey,
  }) async {
    final j = asJson(await api.post('/ambulance/requests', idempotencyKey: idempotencyKey, body: {
      'patientId': patientId,
      'pickup': {'lat': lat, 'lng': lng, 'address': address},
      'destinationFacilityId': ?destinationFacilityId,
      'type': type,
      'reason': reason,
      'sosId': ?sosId,
    }));
    return (request: AmbulanceRequest.fromJson(_unwrap(j, 'request')), payment: _payment(j));
  }

  Future<AmbulanceRequest> get(String id) async =>
      AmbulanceRequest.fromJson(asJson(await api.get('/ambulance/requests/$id')));

  Future<AmbulanceRequest> cancel(String id, String reason) async =>
      AmbulanceRequest.fromJson(asJson(await api.post('/ambulance/requests/$id/cancel', body: {'reason': reason})));
}

// ---------------------------------------------------------------- §56 Safe zone & SOS button

class SafeZoneRepository {
  SafeZoneRepository(this.api);
  final ApiClient api;

  /// The zone, or null when none was set up yet (404).
  Future<SafeZone?> get(String patientId) async {
    try {
      return SafeZone.fromJson(asJson(await api.get('/patients/$patientId/safe-zone')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<SafeZone> save(String patientId, SafeZone zone) async =>
      SafeZone.fromJson(asJson(await api.put('/patients/$patientId/safe-zone', body: zone.toJson())));

  /// Companion mode / tracker ping. Returns whether the point is inside.
  Future<bool> postLocation(String patientId,
          {required double lat, required double lng, required double accuracyM, String source = 'phone'}) async =>
      boolOf(
          asJson(await api.post('/patients/$patientId/location',
              body: {'lat': lat, 'lng': lng, 'accuracyM': accuracyM, 'source': source})),
          'inside',
          true);

  /// The latest location, or null (404: none yet).
  Future<LatestLocation?> latest(String patientId) async {
    try {
      return LatestLocation.fromJson(asJson(await api.get('/patients/$patientId/location/latest')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<SosDevice> pair(String patientId, {required String deviceId, required String model}) async =>
      SosDevice.fromJson(
          asJson(await api.post('/patients/$patientId/sos-devices', body: {'deviceId': deviceId, 'model': model})));

  Future<void> unpair(String patientId, String deviceRowId) => api.delete('/patients/$patientId/sos-devices/$deviceRowId');
}

// ---------------------------------------------------------------- §57 / §60 Offers, wallet & invites

class OffersRepository {
  OffersRepository(this.api);
  final ApiClient api;

  Future<CouponValidation> validateCoupon(String code, {required String purpose, required int amount}) async =>
      CouponValidation.fromJson(asJson(await api.post('/coupons/validate',
          body: {'code': code.trim().toUpperCase(), 'purpose': purpose, 'amount': amount})));

  Future<Wallet> wallet() async => Wallet.fromJson(asJson(await api.get('/wallet')));

  Future<InviteInfo> invite() async => InviteInfo.fromJson(asJson(await api.get('/me/invite')));

  Future<void> redeemInvite(String code) => api.post('/me/invite/redeem', body: {'code': code.trim().toUpperCase()});
}

// ---------------------------------------------------------------- §61 Support desk

class SupportRepository {
  SupportRepository(this.api);
  final ApiClient api;

  Future<Ticket> create({
    required String subject,
    required String category,
    required String message,
    String? refType,
    String? refId,
    String? attachmentRecordId,
  }) async =>
      Ticket.fromJson(asJson(await api.post('/support/tickets', body: {
        'subject': subject,
        'category': category,
        'message': message,
        'refType': ?refType,
        'refId': ?refId,
        'attachmentRecordId': ?attachmentRecordId,
      })));

  Future<List<Ticket>> list() async => _items(await api.get('/support/tickets', query: {'limit': _limit}), Ticket.fromJson);

  Future<Ticket> get(String id) async => Ticket.fromJson(asJson(await api.get('/support/tickets/$id')));

  Future<TicketMessage> send(String id, String text) async =>
      TicketMessage.fromJson(asJson(await api.post('/support/tickets/$id/messages', body: {'text': text})));

  Future<Ticket> rate(String id, int score, {String? comment}) async =>
      Ticket.fromJson(asJson(await api.post('/support/tickets/$id/rating', body: {
        'score': score,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      })));
}
