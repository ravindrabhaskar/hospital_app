import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/care.dart';
import '../../models/clinical.dart';
import '../../models/prescription.dart';

final snapshotProvider = FutureProvider.autoDispose.family<ClinicalSnapshot, String>(
  (ref, patientId) => ref.watch(clinicianRepositoryProvider).snapshot(patientId),
);

final recordsProvider = FutureProvider.autoDispose.family<List<MedicalRecord>, String>(
  (ref, patientId) => ref.watch(clinicianRepositoryProvider).records(patientId),
);

final vitalsProvider = FutureProvider.autoDispose.family<List<Vital>, String>(
  (ref, patientId) => ref.watch(clinicianRepositoryProvider).vitals(patientId),
);

final enrollmentsProvider = FutureProvider.autoDispose.family<List<Enrollment>, String>(
  (ref, patientId) => ref.watch(clinicianRepositoryProvider).enrollments(patientId),
);

final prescriptionsProvider = FutureProvider.autoDispose.family<List<Prescription>, String>(
  (ref, patientId) => ref.watch(clinicianRepositoryProvider).prescriptions(patientId),
);

final episodesProvider = FutureProvider.autoDispose.family<List<CareEpisode>, String>(
  (ref, patientId) => ref.watch(clinicianRepositoryProvider).episodes(patientId),
);

final appointmentProvider = FutureProvider.autoDispose.family<Appointment, String>(
  (ref, id) => ref.watch(clinicianRepositoryProvider).appointment(id),
);
