import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/ai.dart';
import '../models/auth.dart';
import '../models/billing.dart';
import '../models/care.dart';
import '../models/config.dart';
import '../models/doctor.dart';
import '../models/engagement.dart';
import '../models/json.dart';
import '../models/misc.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../models/records.dart';

const _defaultLimit = 50;

/// Page size for screens with "Load more" (cursor pagination).
const pageLimit = 20;

List<T> _items<T>(Object? body, T Function(Json) f) => Page.fromJson(body, f).items;

/// `couponCode?` / `useWallet?` accepted by every booking endpoint (§60).
Json offerFields(String? couponCode, bool useWallet) => {
      if (couponCode != null && couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim().toUpperCase(),
      if (useWallet) 'useWallet': true,
    };

// ---------------------------------------------------------------- Auth

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;

  Future<OtpRequestResult> requestOtp(String phone) async => OtpRequestResult.fromJson(
      asJson(await api.post('/auth/otp/request', body: {'phone': phone}, auth: false)));

  Future<AuthSession> verifyOtp(String phone, String otp, {String? deviceName}) async =>
      AuthSession.fromJson(asJson(await api.post('/auth/otp/verify',
          body: {'phone': phone, 'otp': otp, 'deviceName': ?deviceName}, auth: false)));

  Future<void> logout(String refreshToken) async {
    await api.post('/auth/logout', body: {'refreshToken': refreshToken}, auth: false);
  }

  Future<Me> me() async => Me.fromJson(asJson(await api.get('/me')));

  Future<Me> updateMe({String? name, String? language, String? email}) async =>
      Me.fromJson(asJson(await api.patch('/me', body: {
        'name': ?name,
        'language': ?language,
        'email': ?email,
      })));
}

// ---------------------------------------------------------------- Public config

class ConfigRepository {
  ConfigRepository(this.api);
  final ApiClient api;

  /// `GET /config/public` (no auth). Returns the raw JSON so it can be cached.
  Future<Json> publicConfigJson() async => asJson(await api.get('/config/public', auth: false));

  /// `GET /config/public?tenant=<code>`: adds the hospital's white-label
  /// `branding` (§58).
  Future<Json> publicConfigJsonForTenant(String tenant) async =>
      asJson(await api.get('/config/public', query: {'tenant': tenant}, auth: false));

  Future<PublicConfig> publicConfig() async => PublicConfig.fromJson(await publicConfigJson());
}

// ---------------------------------------------------------------- Account (deletion / export)

class AccountRepository {
  AccountRepository(this.api);
  final ApiClient api;

  /// The current deletion request, or null when there is none (404).
  Future<DeletionRequest?> deletionRequest() async {
    try {
      return DeletionRequest.fromJson(asJson(await api.get('/me/deletion-request')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<DeletionRequest> requestDeletion({String? reason}) async => DeletionRequest.fromJson(
      asJson(await api.post('/me/deletion-request', body: {'reason': ?reason})));

  Future<DeletionRequest> cancelDeletion() async =>
      DeletionRequest.fromJson(asJson(await api.post('/me/deletion-request/cancel')));

  Future<DataExport> createExport() async =>
      DataExport.fromJson(asJson(await api.post('/me/data-export')));

  Future<List<int>> exportFile(String id) => api.getBytes('/me/data-export/$id/file');

  /// `POST /me/photo` (§29): sets the caller's avatar; returns the new URL.
  Future<String?> uploadPhoto(List<int> bytes,
          {String fileName = 'avatar.png', String mimeType = 'image/png'}) async =>
      strOrNull(
          asJson(await api.multipart('/me/photo', fields: const {}, files: [
            UploadFile(field: 'image', bytes: bytes, filename: fileName, contentType: mimeType),
          ])),
          'photoUrl');
}

// ---------------------------------------------------------------- Consent

class ConsentRepository {
  ConsentRepository(this.api);
  final ApiClient api;

  Future<List<ConsentCatalogItem>> catalog() async =>
      _items(await api.get('/consents/catalog'), ConsentCatalogItem.fromJson);

  Future<List<Consent>> list() async => _items(await api.get('/consents'), Consent.fromJson);

  Future<Consent> grant(String purpose, String version) async => Consent.fromJson(
      asJson(await api.post('/consents', body: {'purpose': purpose, 'version': version})));

  Future<Consent> revoke(String id) async =>
      Consent.fromJson(asJson(await api.post('/consents/$id/revoke')));

  /// Grants a purpose using the current catalog version.
  Future<Consent> grantPurpose(String purpose) async {
    final cat = await catalog();
    final item = cat.firstWhere((c) => c.purpose == purpose,
        orElse: () => ConsentCatalogItem(
            purpose: purpose, version: '1', title: purpose, description: '', required: false));
    return grant(item.purpose, item.version);
  }
}

// ---------------------------------------------------------------- Patients

class PatientRepository {
  PatientRepository(this.api);
  final ApiClient api;

  Future<List<PatientSummary>> list() async =>
      _items(await api.get('/patients'), PatientSummary.fromJson);

  Future<PatientProfile> get(String id) async =>
      PatientProfile.fromJson(asJson(await api.get('/patients/$id')));

  Future<PatientProfile> addDependent({
    required String name,
    required String dob,
    required String gender,
    required String relation,
    String? bloodGroup,
  }) async =>
      PatientProfile.fromJson(asJson(await api.post('/patients', body: {
        'name': name,
        'dob': dob,
        'gender': gender,
        'relation': relation,
        'bloodGroup': ?bloodGroup,
      })));

  Future<PatientProfile> update(String id, Json patch) async =>
      PatientProfile.fromJson(asJson(await api.patch('/patients/$id', body: patch)));

  Future<Allergy> addAllergy(String id,
          {required String substance, String? reaction, String? severity}) async =>
      Allergy.fromJson(asJson(await api.post('/patients/$id/allergies', body: {
        'substance': substance,
        'reaction': ?reaction,
        'severity': ?severity,
      })));

  Future<void> deleteAllergy(String id, String allergyId) =>
      api.delete('/patients/$id/allergies/$allergyId');

  Future<Condition> addCondition(String id, {required String name, String? since}) async =>
      Condition.fromJson(asJson(await api
          .post('/patients/$id/conditions', body: {'name': name, 'since': ?since})));

  Future<void> deleteCondition(String id, String conditionId) =>
      api.delete('/patients/$id/conditions/$conditionId');

  Future<EmergencyContact> addEmergencyContact(String id,
          {required String name, required String phone, required String relation}) async =>
      EmergencyContact.fromJson(asJson(await api.post('/patients/$id/emergency-contacts',
          body: {'name': name, 'phone': phone, 'relation': relation})));

  Future<void> deleteEmergencyContact(String id, String contactId) =>
      api.delete('/patients/$id/emergency-contacts/$contactId');

  /// `POST /patients/:id/abha/verify` (§39). 503 DEPENDENCY_UNAVAILABLE while
  /// the ABDM gateway is not connected.
  Future<void> verifyAbha(String id) => api.post('/patients/$id/abha/verify');

  Future<List<FamilyAccessGrant>> familyAccess(String id) async =>
      _items(await api.get('/patients/$id/family-access'), FamilyAccessGrant.fromJson);

  Future<FamilyAccessGrant> inviteCaregiver(String id,
          {required String phone, required String relation, required List<String> permissions}) async =>
      FamilyAccessGrant.fromJson(asJson(await api.post('/patients/$id/family-access', body: {
        'granteePhone': phone,
        'relation': relation,
        'permissions': permissions,
      })));

  Future<FamilyAccessGrant> revokeGrant(String grantId) async =>
      FamilyAccessGrant.fromJson(asJson(await api.post('/family-access/$grantId/revoke')));
}

// ---------------------------------------------------------------- Care episodes

class EpisodeRepository {
  EpisodeRepository(this.api);
  final ApiClient api;

  Future<List<CareEpisode>> list(String patientId, {bool? active, String? status}) async =>
      _items(
          await api.get('/care-episodes', query: {
            'patientId': patientId,
            'active': active,
            'status': status,
            'limit': _defaultLimit,
          }),
          CareEpisode.fromJson);

  Future<CareEpisodeDetail> get(String id) async =>
      CareEpisodeDetail.fromJson(asJson(await api.get('/care-episodes/$id')));
}

// ---------------------------------------------------------------- Doctors & facilities

class DoctorRepository {
  DoctorRepository(this.api);
  final ApiClient api;

  Future<List<Specialty>> specialties() async =>
      _items(await api.get('/specialties'), Specialty.fromJson);

  Future<List<Doctor>> search({
    String? specialty,
    String? q,
    String? language,
    String? mode,
    bool? availableToday,
  }) async =>
      _items(
          await api.get('/doctors', query: {
            'specialty': specialty,
            'q': q,
            'language': language,
            'mode': mode,
            'availableToday': availableToday == true ? true : null,
            'limit': _defaultLimit,
          }),
          Doctor.fromJson);

  Future<DoctorDetail> get(String id) async =>
      DoctorDetail.fromJson(asJson(await api.get('/doctors/$id')));

  Future<List<Slot>> slots(String doctorId, DateTime date) async =>
      _items(await api.get('/doctors/$doctorId/slots', query: {'date': ymd(date)}), Slot.fromJson);

  Future<List<Facility>> facilities(
          {String? type, String? q, double? lat, double? lng, String? cashlessInsurer}) async =>
      _items(
          await api.get('/facilities', query: {
            'type': type,
            'q': q,
            'lat': lat,
            'lng': lng,
            'cashlessInsurer': cashlessInsurer,
            'limit': _defaultLimit,
          }),
          Facility.fromJson);
}

// ---------------------------------------------------------------- Appointments

class AppointmentRepository {
  AppointmentRepository(this.api);
  final ApiClient api;

  Future<BookingResult<Appointment>> book({
    required String patientId,
    required String doctorId,
    required String slotId,
    required String mode,
    required String reason,
    String? careEpisodeId,
    required String idempotencyKey,
    String? couponCode,
    bool useWallet = false,
  }) async {
    final j = asJson(await api.post('/appointments',
        idempotencyKey: idempotencyKey,
        body: {
          'patientId': patientId,
          'doctorId': doctorId,
          'slotId': slotId,
          'mode': mode,
          'reason': reason,
          'careEpisodeId': ?careEpisodeId,
          ...offerFields(couponCode, useWallet),
        }));
    return BookingResult(
        Appointment.fromJson(asJson(j['appointment'])), Payment.fromJson(asJson(j['payment'])));
  }

  Future<List<Appointment>> list(String patientId, String scope) async => _items(
      await api.get('/appointments',
          query: {'patientId': patientId, 'scope': scope, 'limit': _defaultLimit}),
      Appointment.fromJson);

  Future<Page<Appointment>> page(String patientId, String scope, {String? cursor}) async =>
      Page.fromJson(
          await api.get('/appointments', query: {
            'patientId': patientId,
            'scope': scope,
            'limit': pageLimit,
            'cursor': cursor,
          }),
          Appointment.fromJson);

  /// `GET /appointments/:id/video-session` (§26). 409 CONFLICT with
  /// `details.opensAt` outside the join window.
  Future<VideoSession> videoSession(String id) async =>
      VideoSession.fromJson(asJson(await api.get('/appointments/$id/video-session')));

  Future<Appointment> get(String id) async =>
      Appointment.fromJson(asJson(await api.get('/appointments/$id')));

  Future<Appointment> cancel(String id, String reason) async => Appointment.fromJson(
      asJson(await api.post('/appointments/$id/cancel', body: {'reason': reason})));

  Future<Appointment> reschedule(String id, String slotId) async => Appointment.fromJson(
      asJson(await api.post('/appointments/$id/reschedule', body: {'slotId': slotId})));
}

// ---------------------------------------------------------------- Home visits

class HomeVisitRepository {
  HomeVisitRepository(this.api);
  final ApiClient api;

  Future<List<HomeVisitService>> services() async =>
      _items(await api.get('/home-visit/services'), HomeVisitService.fromJson);

  Future<Serviceability> serviceability(String pincode, {double? lat, double? lng}) async =>
      Serviceability.fromJson(asJson(await api.post('/home-visit/serviceability',
          body: {'pincode': pincode, 'lat': ?lat, 'lng': ?lng})));

  Future<BookingResult<HomeVisit>> book({
    required String patientId,
    required String serviceCode,
    required Address address,
    required DateTime preferredStart,
    required DateTime preferredEnd,
    required String reason,
    String? careEpisodeId,
    required String idempotencyKey,
    String? couponCode,
    bool useWallet = false,
  }) async {
    final j = asJson(await api.post('/home-visits',
        idempotencyKey: idempotencyKey,
        body: {
          'patientId': patientId,
          'serviceCode': serviceCode,
          'address': address.toJson(),
          'preferredStart': preferredStart.toUtc().toIso8601String(),
          'preferredEnd': preferredEnd.toUtc().toIso8601String(),
          'reason': reason,
          'careEpisodeId': ?careEpisodeId,
          ...offerFields(couponCode, useWallet),
        }));
    return BookingResult(
        HomeVisit.fromJson(asJson(j['homeVisit'])), Payment.fromJson(asJson(j['payment'])));
  }

  Future<List<HomeVisit>> list(String patientId, String scope) async => _items(
      await api.get('/home-visits',
          query: {'patientId': patientId, 'scope': scope, 'limit': _defaultLimit}),
      HomeVisit.fromJson);

  Future<HomeVisit> get(String id) async =>
      HomeVisit.fromJson(asJson(await api.get('/home-visits/$id')));

  Future<HomeVisit> cancel(String id, String reason) async => HomeVisit.fromJson(
      asJson(await api.post('/home-visits/$id/cancel', body: {'reason': reason})));
}

// ---------------------------------------------------------------- Records

class RecordsRepository {
  RecordsRepository(this.api);
  final ApiClient api;

  Future<List<MedicalRecord>> list(String patientId, {String? type}) async => _items(
      await api.get('/records',
          query: {'patientId': patientId, 'type': type, 'limit': _defaultLimit}),
      MedicalRecord.fromJson);

  Future<Page<MedicalRecord>> page(String patientId, {String? type, String? cursor}) async =>
      Page.fromJson(
          await api.get('/records', query: {
            'patientId': patientId,
            'type': type,
            'limit': pageLimit,
            'cursor': cursor,
          }),
          MedicalRecord.fromJson);

  Future<MedicalRecord> get(String id) async =>
      MedicalRecord.fromJson(asJson(await api.get('/records/$id')));

  Future<MedicalRecord> upload({
    required String patientId,
    required String type,
    required String title,
    required String recordDate,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async =>
      MedicalRecord.fromJson(asJson(await api.multipart('/records', fields: {
        'patientId': patientId,
        'type': type,
        'title': title,
        'recordDate': recordDate,
      }, files: [
        UploadFile(field: 'file', bytes: bytes, filename: fileName, contentType: mimeType),
      ])));

  Future<List<int>> file(String id) => api.getBytes('/records/$id/file');

  Future<MedicalRecord> summarize(String id) async =>
      MedicalRecord.fromJson(asJson(await api.post('/records/$id/summarize')));

  Future<List<TimelineItem>> timeline(String patientId) async =>
      (await timelinePage(patientId)).items;

  Future<Page<TimelineItem>> timelinePage(String patientId, {String? cursor}) async =>
      Page.fromJson(
          await api.get('/timeline',
              query: {'patientId': patientId, 'limit': pageLimit, 'cursor': cursor}),
          TimelineItem.fromJson);

  Future<List<VitalMeasurement>> vitals(String patientId, {String? type}) async => _items(
      await api.get('/vitals',
          query: {'patientId': patientId, 'type': type, 'limit': _defaultLimit}),
      VitalMeasurement.fromJson);

  Future<VitalMeasurement> addVital({
    required String patientId,
    required String type,
    required double value,
    required String unit,
    required DateTime measuredAt,
  }) async =>
      VitalMeasurement.fromJson(asJson(await api.post('/vitals', body: {
        'patientId': patientId,
        'type': type,
        'value': value,
        'unit': unit,
        'measuredAt': measuredAt.toUtc().toIso8601String(),
      })));
}

// ---------------------------------------------------------------- AI

class AiRepository {
  AiRepository(this.api);
  final ApiClient api;

  Future<List<Conversation>> list(String patientId) async => _items(
      await api.get('/ai/conversations', query: {'patientId': patientId, 'limit': 20}),
      Conversation.fromJson);

  Future<Conversation> create(String patientId) async => Conversation.fromJson(
      asJson(await api.post('/ai/conversations', body: {'patientId': patientId})));

  Future<Conversation> get(String id) async =>
      Conversation.fromJson(asJson(await api.get('/ai/conversations/$id')));

  Future<AssistantTurn> send(String conversationId, String text, {String inputMode = 'text'}) async =>
      AssistantTurn.fromJson(asJson(await api.post('/ai/conversations/$conversationId/messages',
          body: {'text': text, 'inputMode': inputMode})));
}

// ---------------------------------------------------------------- Care plans / meds

class CarePlanRepository {
  CarePlanRepository(this.api);
  final ApiClient api;

  Future<List<CarePlan>> plans(String patientId, {String? careEpisodeId}) async => _items(
      await api.get('/care-plans', query: {
        'patientId': patientId,
        'careEpisodeId': careEpisodeId,
        'limit': _defaultLimit,
      }),
      CarePlan.fromJson);

  Future<CarePlan> plan(String id) async =>
      CarePlan.fromJson(asJson(await api.get('/care-plans/$id')));

  Future<List<CareTask>> tasks(String patientId, {String? status}) async => _items(
      await api.get('/care-tasks',
          query: {'patientId': patientId, 'status': status, 'limit': _defaultLimit}),
      CareTask.fromJson);

  Future<CareTask> completeTask(String id, {String? note}) async => CareTask.fromJson(
      asJson(await api.post('/care-tasks/$id/complete', body: {'note': ?note})));

  Future<List<Medication>> medications(String patientId, {bool active = true}) async => _items(
      await api.get('/medications',
          query: {'patientId': patientId, 'active': active, 'limit': _defaultLimit}),
      Medication.fromJson);

  Future<Medication> addMedication({
    required String patientId,
    required String name,
    required String dose,
    required String frequency,
    required List<String> times,
    required String startDate,
    String? endDate,
    String? instructions,
  }) async =>
      Medication.fromJson(asJson(await api.post('/medications', body: {
        'patientId': patientId,
        'name': name,
        'dose': dose,
        'frequency': frequency,
        'times': times,
        'startDate': startDate,
        'endDate': ?endDate,
        'instructions': ?instructions,
      })));

  Future<DoseLog> logDose(String medicationId, String scheduledAt, String status) async =>
      DoseLog.fromJson(asJson(await api.post('/medications/$medicationId/doses',
          body: {'scheduledAt': scheduledAt, 'status': status})));

  Future<List<Reminder>> remindersToday(String patientId) async => _items(
      await api.get('/reminders/today', query: {'patientId': patientId}), Reminder.fromJson);
}

// ---------------------------------------------------------------- Notifications

class NotificationRepository {
  NotificationRepository(this.api);
  final ApiClient api;

  Future<NotificationPage> list({String? cursor}) async {
    final res = await api.send('GET', '/notifications', query: {'limit': pageLimit, 'cursor': cursor});
    final unread = int.tryParse(res.headers['x-unread-count'] ?? '');
    final page = Page.fromJson(res.body, AppNotification.fromJson);
    return NotificationPage(page.items, unread ?? page.items.where((n) => !n.read).length,
        nextCursor: page.nextCursor);
  }

  Future<void> markRead(String id) => api.post('/notifications/$id/read');

  Future<void> markAllRead() => api.post('/notifications/read-all');

  Future<void> registerDevice(String pushToken, String platform) =>
      api.post('/devices', body: {'pushToken': pushToken, 'platform': platform});

  /// `DELETE /devices` (§24), called on logout.
  Future<void> unregisterDevice(String pushToken) =>
      api.delete('/devices', body: {'pushToken': pushToken});

  Future<NotificationPreferences> preferences() async =>
      NotificationPreferences.fromJson(asJson(await api.get('/notification-preferences')));

  Future<NotificationPreferences> savePreferences(NotificationPreferences p) async =>
      NotificationPreferences.fromJson(
          asJson(await api.put('/notification-preferences', body: p.toJson())));
}

// ---------------------------------------------------------------- Payments

class PaymentRepository {
  PaymentRepository(this.api);
  final ApiClient api;

  Future<List<Payment>> list(String patientId) async => _items(
      await api.get('/payments', query: {'patientId': patientId, 'limit': _defaultLimit}),
      Payment.fromJson);

  Future<Payment> get(String id) async =>
      Payment.fromJson(asJson(await api.get('/payments/$id')));

  Future<Payment> confirmMock(String id,
          {required bool success, required String idempotencyKey}) async =>
      Payment.fromJson(asJson(await api.post('/payments/$id/confirm-mock',
          idempotencyKey: idempotencyKey,
          body: {'outcome': success ? 'success' : 'failure'})));

  /// Verifies a Razorpay checkout result server-side (§25).
  Future<Payment> verify(String id,
          {required String razorpayPaymentId,
          required String razorpayOrderId,
          required String razorpaySignature}) async =>
      Payment.fromJson(asJson(await api.post('/payments/$id/verify', body: {
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpaySignature': razorpaySignature,
      })));

  /// `GET /payments/:id/invoice` (§32).
  Future<Invoice> invoice(String id) async =>
      Invoice.fromJson(asJson(await api.get('/payments/$id/invoice')));

  /// `GET /payments/:id/invoice.pdf` (§32).
  Future<List<int>> invoicePdf(String id) => api.getBytes('/payments/$id/invoice.pdf');

  /// A fresh checkout for a `failed`/`pending` payment (§25).
  Future<Payment> retry(String id) async =>
      Payment.fromJson(asJson(await api.post('/payments/$id/retry')));
}

// ---------------------------------------------------------------- Pharmacy

class PharmacyRepository {
  PharmacyRepository(this.api);
  final ApiClient api;

  Future<List<PharmacyCategory>> categories() async =>
      _items(await api.get('/pharmacy/categories'), PharmacyCategory.fromJson);

  Future<List<Product>> products({String? q, String? category}) async => _items(
      await api.get('/pharmacy/products',
          query: {'q': q, 'category': category, 'limit': _defaultLimit}),
      Product.fromJson);

  Future<BookingResult<PharmacyOrder>> order({
    required String patientId,
    required Map<String, int> items,
    String? prescriptionRecordId,
    String? prescriptionId,
    required Address address,
    required String idempotencyKey,
    String? couponCode,
    bool useWallet = false,
  }) async {
    final j = asJson(await api.post('/pharmacy/orders',
        idempotencyKey: idempotencyKey,
        body: {
          'patientId': patientId,
          'items': [
            for (final e in items.entries) {'productId': e.key, 'qty': e.value},
          ],
          'prescriptionRecordId': ?prescriptionRecordId,
          'prescriptionId': ?prescriptionId,
          'address': address.toJson(),
          ...offerFields(couponCode, useWallet),
        }));
    return BookingResult(
        PharmacyOrder.fromJson(asJson(j['order'])), Payment.fromJson(asJson(j['payment'])));
  }

  Future<List<PharmacyOrder>> orders(String patientId) async => _items(
      await api.get('/pharmacy/orders', query: {'patientId': patientId, 'limit': _defaultLimit}),
      PharmacyOrder.fromJson);
}

// ---------------------------------------------------------------- Wellness / wound / wearables / fall / SOS / insights

class WellnessRepository {
  WellnessRepository(this.api);
  final ApiClient api;

  Future<List<WellnessActivity>> activities() async =>
      _items(await api.get('/wellness/activities'), WellnessActivity.fromJson);

  Future<MoodCheckInResult> checkIn(String patientId, int score,
          {String? note, required bool shareWithClinician}) async =>
      MoodCheckInResult.fromJson(asJson(await api.post('/wellness/mood', body: {
        'patientId': patientId,
        'score': score,
        'note': ?note,
        'shareWithClinician': shareWithClinician,
      })));

  Future<List<MoodEntry>> moods(String patientId) async => _items(
      await api.get('/wellness/mood', query: {'patientId': patientId, 'limit': 30}),
      MoodEntry.fromJson);
}

class WoundRepository {
  WoundRepository(this.api);
  final ApiClient api;

  Future<WoundCase> submit({
    required String patientId,
    required String bodySite,
    String? note,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async =>
      WoundCase.fromJson(asJson(await api.multipart('/wound-cases', fields: {
        'patientId': patientId,
        'bodySite': bodySite,
        if (note != null && note.isNotEmpty) 'note': note,
      }, files: [
        UploadFile(field: 'image', bytes: bytes, filename: fileName, contentType: mimeType),
      ])));

  Future<List<WoundCase>> list(String patientId) async => _items(
      await api.get('/wound-cases', query: {'patientId': patientId, 'limit': _defaultLimit}),
      WoundCase.fromJson);
}

class WearablesRepository {
  WearablesRepository(this.api);
  final ApiClient api;

  Future<List<WearableProvider>> providers() async =>
      _items(await api.get('/wearables/providers'), WearableProvider.fromJson);

  Future<List<WearableConnection>> connections(String patientId) async => _items(
      await api.get('/wearables/connections', query: {'patientId': patientId}),
      WearableConnection.fromJson);

  Future<WearableConnection> connect(String patientId, String provider) async =>
      WearableConnection.fromJson(asJson(await api
          .post('/wearables/connections', body: {'patientId': patientId, 'provider': provider})));

  Future<WearableConnection> revoke(String id) async =>
      WearableConnection.fromJson(asJson(await api.post('/wearables/connections/$id/revoke')));

  /// `POST /wearables/sync`; returns the number of accepted measurements.
  Future<int> sync(String patientId, String provider, List<Json> measurements) async => intOf(
      asJson(await api.post('/wearables/sync',
          body: {'patientId': patientId, 'provider': provider, 'measurements': measurements})),
      'accepted');
}

class SafetyRepository {
  SafetyRepository(this.api);
  final ApiClient api;

  Future<FallEvent> reportFall(String patientId,
          {String source = 'manual', double? lat, double? lng}) async =>
      FallEvent.fromJson(asJson(await api.post('/fall-events', body: {
        'patientId': patientId,
        'source': source,
        'lat': ?lat,
        'lng': ?lng,
      })));

  Future<FallEvent> respondFall(String id, bool safe) async =>
      FallEvent.fromJson(asJson(await api.post('/fall-events/$id/respond', body: {'safe': safe})));

  Future<SosResult> sos(String patientId,
          {double? lat, double? lng, String? note, required String idempotencyKey}) async =>
      SosResult.fromJson(asJson(await api.post('/emergency/sos',
          idempotencyKey: idempotencyKey,
          body: {'patientId': patientId, 'lat': ?lat, 'lng': ?lng, 'note': ?note})));

  Future<List<Insight>> insightsToday(String patientId) async => _items(
      await api.get('/insights/today', query: {'patientId': patientId}), Insight.fromJson);
}

// ---------------------------------------------------------------- v1.2: e-Prescriptions (§31)

class PrescriptionRepository {
  PrescriptionRepository(this.api);
  final ApiClient api;

  Future<List<Prescription>> list(String patientId) async => _items(
      await api.get('/prescriptions', query: {'patientId': patientId, 'limit': _defaultLimit}),
      Prescription.fromJson);

  Future<Prescription> get(String id) async =>
      Prescription.fromJson(asJson(await api.get('/prescriptions/$id')));

  Future<List<int>> pdf(String id) => api.getBytes('/prescriptions/$id/pdf');

  Future<List<RxMatch>> pharmacyMatch(String id) async =>
      _items(await api.get('/prescriptions/$id/pharmacy-match'), RxMatch.fromJson);
}

// ---------------------------------------------------------------- v1.2: Reviews (§33)

class ReviewRepository {
  ReviewRepository(this.api);
  final ApiClient api;

  Future<List<PendingReview>> pending(String patientId) async => _items(
      await api.get('/reviews/pending', query: {'patientId': patientId}), PendingReview.fromJson);

  Future<SubmittedReview> submit({
    required String targetType,
    required String targetId,
    required int rating,
    String? text,
  }) async =>
      SubmittedReview.fromJson(asJson(await api.post('/reviews', body: {
        'targetType': targetType,
        'targetId': targetId,
        'rating': rating,
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      })));
}

// ---------------------------------------------------------------- v1.2: Care-team messaging (§34)

class MessagingRepository {
  MessagingRepository(this.api);
  final ApiClient api;

  Future<List<InboxThread>> inbox() async =>
      _items(await api.get('/inbox', query: {'limit': _defaultLimit}), InboxThread.fromJson);

  Future<List<CareMessage>> messages(String episodeId, {String? after}) async => _items(
      await api.get('/care-episodes/$episodeId/messages', query: {'after': after}),
      CareMessage.fromJson);

  Future<CareMessage> send(String episodeId, String text, {String? attachmentRecordId}) async =>
      CareMessage.fromJson(asJson(await api.post('/care-episodes/$episodeId/messages',
          body: {'text': text, 'attachmentRecordId': ?attachmentRecordId})));

  Future<void> markRead(String episodeId) => api.post('/care-episodes/$episodeId/messages/read');
}

// ---------------------------------------------------------------- v1.2: Family Care Plan (§37)

class SubscriptionRepository {
  SubscriptionRepository(this.api);
  final ApiClient api;

  Future<List<Plan>> plans() async => _items(await api.get('/subscription-plans'), Plan.fromJson);

  /// The caller's subscription, or null (404).
  Future<Subscription?> mine() async {
    try {
      return Subscription.fromJson(asJson(await api.get('/subscriptions/me')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  Future<({Subscription subscription, Payment payment})> subscribe(String planCode, Billing billing,
      {required String idempotencyKey, String? couponCode, bool useWallet = false}) async {
    final j = asJson(await api.post('/subscriptions',
        idempotencyKey: idempotencyKey,
        body: {'planCode': planCode, 'billing': billing.name, ...offerFields(couponCode, useWallet)}));
    return (
      subscription: Subscription.fromJson(asJson(j['subscription'])),
      payment: Payment.fromJson(asJson(j['payment'])),
    );
  }

  Future<Subscription> cancel() async =>
      Subscription.fromJson(asJson(await api.post('/subscriptions/me/cancel')));

  /// `POST /subscriptions/redeem` (§57): a single-use company code.
  Future<Subscription> redeem(String code) async =>
      Subscription.fromJson(asJson(await api.post('/subscriptions/redeem', body: {'code': code.trim()})));
}

// ---------------------------------------------------------------- v1.2: Government schemes (§38)

class SchemeRepository {
  SchemeRepository(this.api);
  final ApiClient api;

  Future<List<Scheme>> list({String? state}) async => _items(
      await api.get('/schemes', query: {'state': state, 'limit': _defaultLimit}), Scheme.fromJson);

  Future<Scheme> get(String id) async => Scheme.fromJson(asJson(await api.get('/schemes/$id')));
}
