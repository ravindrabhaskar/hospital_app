import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/v13_repositories.dart';
import '../models/doctor.dart';
import '../models/engagement_v13.dart';
import '../models/monitoring.dart';
import '../models/services.dart';
import 'core_providers.dart';

// Repositories and data providers for API_CONTRACT v1.3 (§41–§61).

final checkinRepositoryProvider = Provider((ref) => CheckinRepository(ref.watch(apiClientProvider)));
final programRepositoryProvider = Provider((ref) => ProgramRepository(ref.watch(apiClientProvider)));
final whatsappRepositoryProvider = Provider((ref) => WhatsappRepository(ref.watch(apiClientProvider)));
final labRepositoryProvider = Provider((ref) => LabRepository(ref.watch(apiClientProvider)));
final secondOpinionRepositoryProvider = Provider((ref) => SecondOpinionRepository(ref.watch(apiClientProvider)));
final abdmRepositoryProvider = Provider((ref) => AbdmRepository(ref.watch(apiClientProvider)));
final insuranceRepositoryProvider = Provider((ref) => InsuranceRepository(ref.watch(apiClientProvider)));
final preventiveRepositoryProvider = Provider((ref) => PreventiveRepository(ref.watch(apiClientProvider)));
final exerciseRepositoryProvider = Provider((ref) => ExerciseRepository(ref.watch(apiClientProvider)));
final dietRepositoryProvider = Provider((ref) => DietRepository(ref.watch(apiClientProvider)));
final ambulanceRepositoryProvider = Provider((ref) => AmbulanceRepository(ref.watch(apiClientProvider)));
final safeZoneRepositoryProvider = Provider((ref) => SafeZoneRepository(ref.watch(apiClientProvider)));
final offersRepositoryProvider = Provider((ref) => OffersRepository(ref.watch(apiClientProvider)));
final supportRepositoryProvider = Provider((ref) => SupportRepository(ref.watch(apiClientProvider)));

Future<String> _pid(Ref ref) async => (await ref.watch(activePatientProvider.future)).id;

// ---------------------------------------------------------------- §41 Check-in

final checkinSettingsProvider = FutureProvider<CheckinSettings?>(
    (ref) async => ref.watch(checkinRepositoryProvider).settings(await _pid(ref)));

final checkinHistoryProvider = FutureProvider<List<CheckIn>>(
    (ref) async => ref.watch(checkinRepositoryProvider).history(await _pid(ref), days: 30));

// ---------------------------------------------------------------- §42 Programs

final enrollmentsProvider = FutureProvider<List<Enrollment>>(
    (ref) async => ref.watch(programRepositoryProvider).enrollments(await _pid(ref)));

final programTemplatesProvider =
    FutureProvider<List<ProgramTemplate>>((ref) => ref.watch(programRepositoryProvider).templates());

final programSummaryProvider = FutureProvider.autoDispose.family<ProgramSummary, String>((ref, id) {
  final now = DateTime.now();
  return ref
      .watch(programRepositoryProvider)
      .summary(id, from: now.subtract(const Duration(days: 29)), to: now);
});

// ---------------------------------------------------------------- §43 WhatsApp

final whatsappStatusProvider =
    FutureProvider.autoDispose<WhatsappStatus>((ref) => ref.watch(whatsappRepositoryProvider).status());

// ---------------------------------------------------------------- §44 Lab

typedef LabQuery = ({String? q, String? category});

final labTestsProvider = FutureProvider.autoDispose.family<List<LabTest>, LabQuery>(
    (ref, q) => ref.watch(labRepositoryProvider).tests(q: q.q, category: q.category));

/// The full catalogue (resolves package test ids for fasting rules).
final labCatalogProvider = FutureProvider<Map<String, LabTest>>((ref) async {
  final list = await ref.watch(labRepositoryProvider).tests();
  return {for (final t in list) t.id: t};
});

final labPackagesProvider = FutureProvider<List<LabPackage>>((ref) => ref.watch(labRepositoryProvider).packages());

final labOrdersProvider =
    FutureProvider.autoDispose<List<LabOrder>>((ref) async => ref.watch(labRepositoryProvider).orders(await _pid(ref)));

final labOrderProvider =
    FutureProvider.autoDispose.family<LabOrder, String>((ref, id) => ref.watch(labRepositoryProvider).get(id));

class LabCartNotifier extends Notifier<LabCart> {
  @override
  LabCart build() => const LabCart();

  void toggleTest(LabTest t) => state = state.toggleTest(t);
  void togglePackage(LabPackage p) => state = state.togglePackage(p);
  void clear() => state = const LabCart();
}

final labCartProvider = NotifierProvider<LabCartNotifier, LabCart>(LabCartNotifier.new);

// ---------------------------------------------------------------- §49 Second opinion

final secondOpinionPricingProvider = FutureProvider.autoDispose<List<SecondOpinionPrice>>(
    (ref) => ref.watch(secondOpinionRepositoryProvider).pricing());

final secondOpinionsProvider = FutureProvider.autoDispose<List<SecondOpinion>>(
    (ref) async => ref.watch(secondOpinionRepositoryProvider).list(await _pid(ref)));

final secondOpinionProvider = FutureProvider.autoDispose.family<SecondOpinion, String>(
    (ref, id) => ref.watch(secondOpinionRepositoryProvider).get(id));

// ---------------------------------------------------------------- §50 ABDM

final abdmConsentRequestsProvider = FutureProvider.autoDispose<List<AbdmConsentRequest>>(
    (ref) async => ref.watch(abdmRepositoryProvider).consentRequests(await _pid(ref)));

// ---------------------------------------------------------------- §51 Insurance

final insurersProvider = FutureProvider<List<Insurer>>((ref) => ref.watch(insuranceRepositoryProvider).insurers());

final insurancePoliciesProvider = FutureProvider<List<InsurancePolicy>>(
    (ref) async => ref.watch(insuranceRepositoryProvider).policies(await _pid(ref)));

final claimChecklistProvider = FutureProvider.autoDispose.family<ClaimChecklist, String>(
    (ref, type) => ref.watch(insuranceRepositoryProvider).checklist(type));

final cashlessFacilitiesProvider = FutureProvider.autoDispose.family<List<Facility>, String>(
    (ref, insurer) => ref.watch(insuranceRepositoryProvider).cashlessFacilities(insurer));

// ---------------------------------------------------------------- §52 Preventive (per family member)

final preventiveScheduleProvider = FutureProvider.autoDispose.family<PreventiveSchedule, String>(
    (ref, patientId) => ref.watch(preventiveRepositoryProvider).schedule(patientId));

// ---------------------------------------------------------------- §53 Exercise

final exercisePlansProvider = FutureProvider.autoDispose<List<ExercisePlan>>((ref) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final plans = await repo.plans(await _pid(ref));
  // Join exercise details from the library when the plan only has ids.
  if (plans.every((p) => p.items.every((i) => i.exercise != null))) return plans;
  Map<String, Exercise> lib = const {};
  try {
    lib = {for (final e in await repo.library()) e.id: e};
  } catch (_) {}
  return [
    for (final p in plans)
      ExercisePlan(
        id: p.id,
        patientId: p.patientId,
        authorName: p.authorName,
        authorRole: p.authorRole,
        items: [for (final i in p.items) i.withExercise(lib[i.exerciseId])],
        startDate: p.startDate,
        endDate: p.endDate,
        status: p.status,
      ),
  ];
});

final exerciseProgressProvider = FutureProvider.autoDispose.family<ExerciseProgress, String>(
    (ref, planId) => ref.watch(exerciseRepositoryProvider).progress(planId));

// ---------------------------------------------------------------- §54 Diet

final dietPlansProvider =
    FutureProvider.autoDispose<List<DietPlan>>((ref) async => ref.watch(dietRepositoryProvider).plans(await _pid(ref)));

final dietAdherenceProvider = FutureProvider.autoDispose.family<DietAdherence, String>(
    (ref, planId) => ref.watch(dietRepositoryProvider).adherence(planId, days: 14));

// ---------------------------------------------------------------- §55 Ambulance

/// How often the tracking screen polls (§55: every 5 s). Overridable in tests.
final ambulancePollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 5));

// ---------------------------------------------------------------- §56 Safe zone

final safeZoneProvider =
    FutureProvider.autoDispose<SafeZone?>((ref) async => ref.watch(safeZoneRepositoryProvider).get(await _pid(ref)));

final latestLocationProvider = FutureProvider.autoDispose<LatestLocation?>(
    (ref) async => ref.watch(safeZoneRepositoryProvider).latest(await _pid(ref)));

// ---------------------------------------------------------------- §60 Wallet & invites

final walletProvider = FutureProvider.autoDispose<Wallet>((ref) {
  ref.watch(sessionProvider.select((s) => s.me?.id));
  return ref.watch(offersRepositoryProvider).wallet();
});

final inviteProvider = FutureProvider.autoDispose<InviteInfo>((ref) {
  ref.watch(sessionProvider.select((s) => s.me?.id));
  return ref.watch(offersRepositoryProvider).invite();
});

// ---------------------------------------------------------------- §61 Support

/// How often an open ticket conversation polls (§61: every 15 s).
final ticketPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 15));

final ticketsProvider = FutureProvider.autoDispose<List<Ticket>>((ref) {
  ref.watch(sessionProvider.select((s) => s.me?.id));
  return ref.watch(supportRepositoryProvider).list();
});
