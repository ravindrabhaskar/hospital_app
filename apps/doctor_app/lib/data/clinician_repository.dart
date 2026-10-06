import '../core/api/api_client.dart';
import '../models/care.dart';
import '../models/clinical.dart';
import '../models/doctor.dart';
import '../models/json.dart';
import '../models/messaging.dart';
import '../models/prescription.dart';

/// Every doctor-facing endpoint the app uses (contract §16, §26, §29, §31,
/// §32, §34, §36, §42, §46, §47, §49, §53, §54). No invented endpoints.
class ClinicianRepository {
  ClinicianRepository(this._api);
  final ApiClient _api;

  ApiClient get api => _api;

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- §16
  Future<List<Appointment>> queue(DateTime date) async =>
      itemsOf(await _api.get('/clinician/queue', query: {'date': isoDate(date)})).map(Appointment.fromJson).toList();

  Future<Appointment> appointment(String id) async => Appointment.fromJson(asJson(await _api.get('/appointments/$id')));

  Future<List<Patient>> patients(String q) async =>
      itemsOf(await _api.get('/clinician/patients', query: {'q': q.trim(), 'limit': 50}))
          .map(Patient.fromJson)
          .toList();

  Future<ClinicalSnapshot> snapshot(String patientId) async =>
      ClinicalSnapshot.fromJson(asJson(await _api.get('/clinician/patients/$patientId/snapshot')));

  Future<Appointment> start(String appointmentId) async =>
      Appointment.fromJson(asJson(await _api.post('/clinician/appointments/$appointmentId/start')));

  Future<Appointment> complete(String appointmentId, {required String notes, required String outcome}) async =>
      Appointment.fromJson(
        asJson(
          await _api.post(
            '/clinician/appointments/$appointmentId/complete',
            body: {'notes': notes, 'outcome': outcome},
          ),
        ),
      );

  Future<List<SafetyEvent>> escalations() async =>
      itemsOf(await _api.get('/clinician/escalations')).map(SafetyEvent.fromJson).toList();

  Future<void> aiFeedback({required String interactionId, required String decision, String note = ''}) async {
    await _api.post(
      '/clinician/ai-feedback',
      body: {'aiInteractionId': interactionId, 'decision': decision, 'note': note},
    );
  }

  Future<void> addEpisodeNote(String episodeId, String text) async {
    await _api.post('/care-episodes/$episodeId/notes', body: {'text': text});
  }

  Future<List<CareEpisode>> episodes(String patientId) async =>
      itemsOf(await _api.get('/care-episodes', query: {'patientId': patientId})).map(CareEpisode.fromJson).toList();

  // ------------------------------------------------------------- §9 records
  Future<List<MedicalRecord>> records(String patientId) async =>
      itemsOf(await _api.get('/records', query: {'patientId': patientId})).map(MedicalRecord.fromJson).toList();

  /// One record (e.g. a message attachment); 403/404 when not visible.
  Future<MedicalRecord> record(String recordId) async =>
      MedicalRecord.fromJson(asJson(await _api.get('/records/$recordId')));

  Future<List<int>> recordFile(String recordId) => _api.getBytes('/records/$recordId/file');

  Future<List<Vital>> vitals(String patientId, {String? type}) async =>
      itemsOf(await _api.get('/vitals', query: {'patientId': patientId, 'type': type, 'limit': 100}))
          .map(Vital.fromJson)
          .toList();

  // ---------------------------------------------------------------- §26
  Future<VideoSession> videoSession(String appointmentId) async =>
      VideoSession.fromJson(asJson(await _api.get('/appointments/$appointmentId/video-session')));

  // ---------------------------------------------------------------- §31/§47
  Future<RxCheckResult> checkPrescription(String patientId, List<RxItem> items) async => RxCheckResult.fromJson(
    asJson(
      await _api.post(
        '/clinician/prescriptions/check',
        body: {'patientId': patientId, 'items': items.map((i) => i.toCheckJson()).toList()},
      ),
    ),
  );

  Future<Prescription> createPrescription(Json body, {String? idempotencyKey}) async => Prescription.fromJson(
    asJson(await _api.post('/clinician/prescriptions', body: body, idempotencyKey: idempotencyKey)),
  );

  Future<List<Prescription>> prescriptions(String patientId) async =>
      itemsOf(await _api.get('/prescriptions', query: {'patientId': patientId})).map(Prescription.fromJson).toList();

  Future<List<int>> prescriptionPdf(String id) => _api.getBytes('/prescriptions/$id/pdf');

  // ---------------------------------------------------------------- §11
  Future<void> createCarePlan(Json body, {String? idempotencyKey}) async {
    await _api.post('/care-plans', body: body, idempotencyKey: idempotencyKey);
  }

  // ---------------------------------------------------------------- §36
  Future<List<Facility>> hospitals(String q) async =>
      itemsOf(await _api.get('/facilities', query: {'type': 'hospital', 'q': q.trim()}))
          .map(Facility.fromJson)
          .toList();

  Future<void> createReferral(Json body, {String? idempotencyKey}) async {
    await _api.post('/clinician/referrals', body: body, idempotencyKey: idempotencyKey);
  }

  // ---------------------------------------------------------------- §42
  Future<List<ProgramTemplate>> programTemplates() async =>
      itemsOf(await _api.get('/care-programs/templates')).map(ProgramTemplate.fromJson).toList();

  Future<List<Enrollment>> enrollments(String patientId) async =>
      itemsOf(await _api.get('/care-programs/enrollments', query: {'patientId': patientId}))
          .map(Enrollment.fromJson)
          .toList();

  Future<void> enroll(Json body, {String? idempotencyKey}) async {
    await _api.post('/care-programs/enrollments', body: body, idempotencyKey: idempotencyKey);
  }

  // ---------------------------------------------------------------- §46
  Future<ScribeDraft> scribeFromTranscript(String appointmentId, String transcript) async => ScribeDraft.fromJson(
    asJson(
      await _api.post(
        '/clinician/appointments/$appointmentId/scribe',
        body: {'transcript': transcript, 'consentConfirmed': true},
      ),
    ),
  );

  Future<ScribeDraft> scribeFromAudio(
    String appointmentId,
    List<int> bytes, {
    required String filename,
    required String contentType,
  }) async => ScribeDraft.fromJson(
    asJson(
      await _api.postMultipart(
        '/clinician/appointments/$appointmentId/scribe',
        fields: {'consentConfirmed': 'true'},
        files: [MultipartFilePart(field: 'audio', bytes: bytes, filename: filename, contentType: contentType)],
      ),
    ),
  );

  // ---------------------------------------------------------------- §53/§54
  Future<List<Exercise>> exerciseLibrary() async =>
      itemsOf(await _api.get('/exercise-library', query: {'limit': 100})).map(Exercise.fromJson).toList();

  Future<void> createExercisePlan(Json body, {String? idempotencyKey}) async {
    await _api.post('/exercise-plans', body: body, idempotencyKey: idempotencyKey);
  }

  Future<List<DietTemplate>> dietTemplates() async =>
      itemsOf(await _api.get('/diet-templates')).map(DietTemplate.fromJson).toList();

  Future<void> createDietPlan(Json body, {String? idempotencyKey}) async {
    await _api.post('/diet-plans', body: body, idempotencyKey: idempotencyKey);
  }

  // ---------------------------------------------------------------- §34
  Future<List<InboxThread>> inbox() async => itemsOf(await _api.get('/inbox')).map(InboxThread.fromJson).toList();

  Future<List<ChatMessage>> messages(String episodeId, {String? after}) async =>
      itemsOf(await _api.get('/care-episodes/$episodeId/messages', query: {'after': after}))
          .map(ChatMessage.fromJson)
          .toList();

  Future<ChatMessage> sendMessage(String episodeId, String text) async =>
      ChatMessage.fromJson(asJson(await _api.post('/care-episodes/$episodeId/messages', body: {'text': text})));

  Future<void> markRead(String episodeId) async {
    await _api.post('/care-episodes/$episodeId/messages/read');
  }

  // ---------------------------------------------------------------- §49
  Future<List<SecondOpinion>> secondOpinions(String scope) async =>
      itemsOf(await _api.get('/clinician/second-opinions', query: {'scope': scope}))
          .map(SecondOpinion.fromJson)
          .toList();

  Future<SecondOpinion> claimSecondOpinion(String id) async =>
      SecondOpinion.fromJson(asJson(await _api.post('/clinician/second-opinions/$id/claim')));

  Future<SecondOpinion> respondSecondOpinion(
    String id, {
    required String opinion,
    required List<String> recommendations,
    required bool suggestTeleconsult,
  }) async => SecondOpinion.fromJson(
    asJson(
      await _api.post(
        '/clinician/second-opinions/$id/respond',
        body: {'opinion': opinion, 'recommendations': recommendations, 'suggestTeleconsult': suggestTeleconsult},
      ),
    ),
  );

  // ---------------------------------------------------------------- §29
  Future<DoctorProfile> profile() async => DoctorProfile.fromJson(asJson(await _api.get('/doctor/me/profile')));

  Future<DoctorProfile> updateProfile(Json patch) async =>
      DoctorProfile.fromJson(asJson(await _api.patch('/doctor/me/profile', body: patch)));

  Future<String?> uploadPhoto(List<int> bytes, {required String filename, required String contentType}) async {
    final res = asJson(
      await _api.postMultipart(
        '/me/photo',
        files: [MultipartFilePart(field: 'image', bytes: bytes, filename: filename, contentType: contentType)],
      ),
    );
    return str(res['photoUrl']);
  }

  Future<Schedule> schedule() async => Schedule.fromJson(asJson(await _api.get('/doctor/me/schedule')));

  Future<Schedule> saveSchedule(List<WeeklyBlock> weekly) async => Schedule.fromJson(
    asJson(await _api.put('/doctor/me/schedule', body: {'weekly': weekly.map((b) => b.toJson()).toList()})),
  );

  Future<LeaveResult> addLeave(String date, String? reason) async => LeaveResult.fromJson(
    asJson(
      await _api.post(
        '/doctor/me/leaves',
        body: {'date': date, if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
      ),
    ),
  );

  Future<void> deleteLeave(String id) async {
    await _api.delete('/doctor/me/leaves/$id');
  }

  // ---------------------------------------------------------------- §32
  Future<Earnings> earnings(DateTime month) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    return Earnings.fromJson(
      asJson(await _api.get('/provider/earnings', query: {'from': isoDate(from), 'to': isoDate(to)})),
    );
  }
}
