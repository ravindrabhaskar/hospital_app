import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth.dart';
import '../models/billing.dart';
import '../models/care.dart';
import '../models/doctor.dart';
import '../models/engagement.dart';
import '../models/json.dart';
import '../models/misc.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../models/records.dart';
import 'core_providers.dart';

Future<String> _pid(Ref ref) async => (await ref.watch(activePatientProvider.future)).id;

// ---------------------------------------------------------------- Home

final remindersTodayProvider = FutureProvider<List<Reminder>>((ref) async =>
    ref.watch(carePlanRepositoryProvider).remindersToday(await _pid(ref)));

final activeEpisodesProvider = FutureProvider<List<CareEpisode>>((ref) async =>
    ref.watch(episodeRepositoryProvider).list(await _pid(ref), active: true));

final insightsTodayProvider = FutureProvider<List<Insight>>((ref) async =>
    ref.watch(safetyRepositoryProvider).insightsToday(await _pid(ref)));

final notificationsProvider = FutureProvider<NotificationPage>((ref) async {
  ref.watch(sessionProvider.select((s) => s.me?.id));
  return ref.watch(notificationRepositoryProvider).list();
});

final notificationPrefsProvider = FutureProvider.autoDispose<NotificationPreferences>(
    (ref) => ref.watch(notificationRepositoryProvider).preferences());

// ---------------------------------------------------------------- Care

final allEpisodesProvider = FutureProvider<List<CareEpisode>>(
    (ref) async => ref.watch(episodeRepositoryProvider).list(await _pid(ref)));

final episodeDetailProvider = FutureProvider.autoDispose.family<CareEpisodeDetail, String>(
    (ref, id) => ref.watch(episodeRepositoryProvider).get(id));

/// First page of appointments; the screen loads more with `nextCursor`.
final appointmentsProvider = FutureProvider.family<Page<Appointment>, String>((ref, scope) async =>
    ref.watch(appointmentRepositoryProvider).page(await _pid(ref), scope));

final appointmentProvider = FutureProvider.autoDispose.family<Appointment, String>(
    (ref, id) => ref.watch(appointmentRepositoryProvider).get(id));

final homeVisitsProvider = FutureProvider.family<List<HomeVisit>, String>((ref, scope) async =>
    ref.watch(homeVisitRepositoryProvider).list(await _pid(ref), scope));

final homeVisitProvider = FutureProvider.autoDispose.family<HomeVisit, String>(
    (ref, id) => ref.watch(homeVisitRepositoryProvider).get(id));

final homeVisitServicesProvider = FutureProvider<List<HomeVisitService>>(
    (ref) => ref.watch(homeVisitRepositoryProvider).services());

final carePlansProvider = FutureProvider<List<CarePlan>>(
    (ref) async => ref.watch(carePlanRepositoryProvider).plans(await _pid(ref)));

final carePlanProvider = FutureProvider.autoDispose.family<CarePlan, String>(
    (ref, id) => ref.watch(carePlanRepositoryProvider).plan(id));

final careTasksProvider = FutureProvider<List<CareTask>>(
    (ref) async => ref.watch(carePlanRepositoryProvider).tasks(await _pid(ref)));

final medicationsProvider = FutureProvider<List<Medication>>(
    (ref) async => ref.watch(carePlanRepositoryProvider).medications(await _pid(ref)));

// ---------------------------------------------------------------- Doctors & facilities

final specialtiesProvider =
    FutureProvider<List<Specialty>>((ref) => ref.watch(doctorRepositoryProvider).specialties());

typedef DoctorQuery = ({String? specialty, String? q, String? mode});

final doctorsProvider = FutureProvider.autoDispose.family<List<Doctor>, DoctorQuery>(
    (ref, q) => ref.watch(doctorRepositoryProvider).search(
          specialty: q.specialty,
          q: q.q,
          mode: q.mode,
        ));

final doctorDetailProvider = FutureProvider.autoDispose.family<DoctorDetail, String>(
    (ref, id) => ref.watch(doctorRepositoryProvider).get(id));

typedef SlotQuery = ({String doctorId, DateTime date});

final slotsProvider = FutureProvider.autoDispose.family<List<Slot>, SlotQuery>(
    (ref, q) => ref.watch(doctorRepositoryProvider).slots(q.doctorId, q.date));

typedef FacilityQuery = ({String? type, String? q, double? lat, double? lng});

final facilitiesProvider = FutureProvider.autoDispose.family<List<Facility>, FacilityQuery>(
    (ref, q) => ref
        .watch(doctorRepositoryProvider)
        .facilities(type: q.type, q: q.q, lat: q.lat, lng: q.lng));

// ---------------------------------------------------------------- Records

/// First page of records; the screen loads more with `nextCursor`.
final recordsProvider = FutureProvider.family<Page<MedicalRecord>, String?>((ref, type) async =>
    ref.watch(recordsRepositoryProvider).page(await _pid(ref), type: type));

final recordProvider = FutureProvider.autoDispose.family<MedicalRecord, String>(
    (ref, id) => ref.watch(recordsRepositoryProvider).get(id));

/// First page of the timeline; the screen loads more with `nextCursor`.
final timelineProvider = FutureProvider<Page<TimelineItem>>(
    (ref) async => ref.watch(recordsRepositoryProvider).timelinePage(await _pid(ref)));

final vitalsProvider = FutureProvider<List<VitalMeasurement>>(
    (ref) async => ref.watch(recordsRepositoryProvider).vitals(await _pid(ref)));

// ---------------------------------------------------------------- Profile

final patientProfileProvider = FutureProvider<PatientProfile>(
    (ref) async => ref.watch(patientRepositoryProvider).get(await _pid(ref)));

final familyAccessProvider = FutureProvider.autoDispose<List<FamilyAccessGrant>>(
    (ref) async => ref.watch(patientRepositoryProvider).familyAccess(await _pid(ref)));

final consentCatalogProvider = FutureProvider<List<ConsentCatalogItem>>(
    (ref) => ref.watch(consentRepositoryProvider).catalog());

final consentsProvider = FutureProvider.autoDispose<List<Consent>>((ref) {
  ref.watch(sessionProvider.select((s) => s.me?.id));
  return ref.watch(consentRepositoryProvider).list();
});

final paymentsProvider = FutureProvider.autoDispose<List<Payment>>(
    (ref) async => ref.watch(paymentRepositoryProvider).list(await _pid(ref)));

// ---------------------------------------------------------------- Pharmacy

final pharmacyCategoriesProvider = FutureProvider<List<PharmacyCategory>>(
    (ref) => ref.watch(pharmacyRepositoryProvider).categories());

typedef ProductQuery = ({String? q, String? category});

final productsProvider = FutureProvider.autoDispose.family<List<Product>, ProductQuery>(
    (ref, q) => ref.watch(pharmacyRepositoryProvider).products(q: q.q, category: q.category));

final pharmacyOrdersProvider = FutureProvider.autoDispose<List<PharmacyOrder>>(
    (ref) async => ref.watch(pharmacyRepositoryProvider).orders(await _pid(ref)));

// ---------------------------------------------------------------- Wellness / wound / wearables

final wellnessActivitiesProvider = FutureProvider<List<WellnessActivity>>(
    (ref) => ref.watch(wellnessRepositoryProvider).activities());

final moodsProvider = FutureProvider.autoDispose<List<MoodEntry>>(
    (ref) async => ref.watch(wellnessRepositoryProvider).moods(await _pid(ref)));

final woundCasesProvider = FutureProvider.autoDispose<List<WoundCase>>(
    (ref) async => ref.watch(woundRepositoryProvider).list(await _pid(ref)));

final wearableProvidersProvider = FutureProvider<List<WearableProvider>>(
    (ref) => ref.watch(wearablesRepositoryProvider).providers());

final wearableConnectionsProvider = FutureProvider.autoDispose<List<WearableConnection>>(
    (ref) async => ref.watch(wearablesRepositoryProvider).connections(await _pid(ref)));

// ---------------------------------------------------------------- v1.2

final prescriptionsProvider = FutureProvider<List<Prescription>>(
    (ref) async => ref.watch(prescriptionRepositoryProvider).list(await _pid(ref)));

final prescriptionProvider = FutureProvider.autoDispose.family<Prescription, String>(
    (ref, id) => ref.watch(prescriptionRepositoryProvider).get(id));

final pharmacyMatchProvider = FutureProvider.autoDispose.family<List<RxMatch>, String>(
    (ref, id) => ref.watch(prescriptionRepositoryProvider).pharmacyMatch(id));

final invoiceProvider = FutureProvider.autoDispose.family<Invoice, String>(
    (ref, paymentId) => ref.watch(paymentRepositoryProvider).invoice(paymentId));

final pendingReviewsProvider = FutureProvider<List<PendingReview>>(
    (ref) async => ref.watch(reviewRepositoryProvider).pending(await _pid(ref)));

/// Threads the caller participates in (all managed patients).
final inboxProvider = FutureProvider<List<InboxThread>>((ref) async {
  ref.watch(sessionProvider.select((s) => s.me?.id));
  return ref.watch(messagingRepositoryProvider).inbox();
});

final inboxUnreadProvider = Provider<int>(
    (ref) => (ref.watch(inboxProvider).value ?? const <InboxThread>[]).fold(0, (a, t) => a + t.unread));

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<Plan>>((ref) => ref.watch(subscriptionRepositoryProvider).plans());

final mySubscriptionProvider = FutureProvider<Subscription?>((ref) {
  ref.watch(sessionProvider.select((s) => s.me?.id));
  return ref.watch(subscriptionRepositoryProvider).mine();
});

final schemesProvider = FutureProvider.autoDispose.family<List<Scheme>, String?>(
    (ref, state) => ref.watch(schemeRepositoryProvider).list(state: state));

final schemeProvider = FutureProvider.autoDispose.family<Scheme, String>(
    (ref, id) => ref.watch(schemeRepositoryProvider).get(id));
