import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../models/home_visit.dart';
import '../../../ui/l10n_helpers.dart';
import '../../../ui/widgets.dart';
import '../../../models/care_plans.dart';
import '../../../models/field_ops.dart';
import '../../care_plans/diet_plan_screen.dart';
import '../../care_plans/exercise_plan_screen.dart';
import '../../field/supplies_screen.dart';
import '../../offline/offline_queue.dart';
import '../data/visit_providers.dart';
import '../domain/visit_lifecycle.dart';
import '../domain/vitals_validation.dart';
import 'escalate_dialog.dart';
import 'lifecycle_panel.dart';
import 'observations_form.dart';
import 'photo_capture.dart';
import 'sample_collection.dart';
import 'vitals_form.dart';

class VisitDetailScreen extends ConsumerStatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});
  final String visitId;

  @override
  ConsumerState<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends ConsumerState<VisitDetailScreen> {
  bool _busy = false;

  /// Latest copy returned by an action, shown until the provider refetches.
  HomeVisit? _latest;

  /// Consent tick of the verify step; kept here so a wrong visit code
  /// (rejected → panel rebuilt) does not clear it.
  bool _consent = false;

  void _refreshAll() {
    ref.invalidate(visitDetailProvider(widget.visitId));
    ref.invalidate(visitListProvider);
  }

  /// Runs an action through the offline-capable service and reports the result.
  Future<bool> _perform(HomeVisit visit, VisitActionType type, Map<String, dynamic> body,
      {String? successMessage}) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(visitActionServiceProvider).perform(visit, type, body);
      if (!mounted) return false;
      switch (outcome.kind) {
        case ActionOutcomeKind.synced:
          messenger.showSnackBar(SnackBar(content: Text(successMessage ?? l.actionDone)));
          setState(() => _latest = outcome.visit);
          if (type == VisitActionType.reject) {
            ref.invalidate(visitListProvider);
            router.go('/');
            return true;
          }
          _refreshAll();
          return true;
        case ActionOutcomeKind.pending:
          messenger.showSnackBar(SnackBar(content: Text(l.actionQueued)));
          setState(() => _latest = outcome.visit);
          if (type == VisitActionType.reject) {
            ref.invalidate(visitListProvider);
            router.go('/');
          }
          return true;
        case ActionOutcomeKind.rejected:
          messenger.showSnackBar(SnackBar(
            content: Text(errorMessage(l, outcome.error ?? const ApiException.network())),
            backgroundColor: AppColors.dangerDeep,
          ));
          setState(() => _latest = null);
          _refreshAll();
          return false;
        case ActionOutcomeKind.accessRevoked:
          messenger.showSnackBar(SnackBar(content: Text(l.syncAccessRevoked)));
          ref.invalidate(visitListProvider);
          router.go('/');
          return false;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _navigate(HomeVisit visit) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final a = visit.address;
    final destination = a.hasCoordinates ? '${a.lat},${a.lng}' : a.fullText;
    final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination});
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.visitNavigateFailed)));
    if (visit.status == VisitStatus.enRoute) {
      ref.read(locationReporterProvider).reportNow();
    }
  }

  /// Optional, consented visit photo -> `POST /records` (queued offline).
  Future<void> _addPhoto(HomeVisit visit) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final consented = await showPhotoConsentDialog(context);
    if (consented != true || !mounted) return;
    String? path;
    try {
      path = await ref.read(photoCaptureProvider)();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.photoCameraFailed)));
      return;
    }
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(visitActionServiceProvider).addPhoto(visit, path);
      if (!mounted) return;
      final (String text, bool error) = switch (outcome.kind) {
        ActionOutcomeKind.synced => (l.photoUploaded, false),
        ActionOutcomeKind.pending => (l.photoQueued, false),
        ActionOutcomeKind.rejected when outcome.error?.statusCode == 403 => (l.photoNoPermission, true),
        _ => (errorMessage(l, outcome.error ?? const ApiException.network()), true),
      };
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.dangerDeep : null,
        duration: Duration(seconds: error ? 8 : 4),
      ));
    } catch (_) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Supplies used during the visit -> `POST /provider/supplies/usage`
  /// through the offline queue (same Idempotency-Key on every replay).
  Future<void> _recordSupplies(HomeVisit visit) async {
    final quantities = await showSuppliesUsageSheet(context);
    if (quantities == null || quantities.isEmpty || !mounted) return;
    final ok = await _perform(visit, VisitActionType.suppliesUsage, suppliesUsageBody(visit.id, quantities),
        successMessage: context.l10n.supUsageSaved);
    if (ok) ref.invalidate(suppliesProvider);
  }

  void _openPlan(HomeVisit visit, String kind) {
    context.push(Uri(path: '/visits/${visit.id}/$kind', queryParameters: {
      'patientId': visit.patientId,
      'patientName': visit.patientName,
      'careEpisodeId': ?visit.careEpisodeId,
    }).toString());
  }

  Future<void> _escalate(HomeVisit visit) async {
    final request = await showEscalationFlow(context);
    if (request == null || !mounted) return;
    await _perform(visit, VisitActionType.escalate, request.toBody());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(visitDetailProvider(widget.visitId));
    final online = ref.watch(onlineStatusProvider).value ?? true;

    return async.when(
      loading: () => Scaffold(appBar: AppBar(title: Text(l.visitTitle)), body: const LoadingView()),
      error: (e, _) {
        final lost = e is ApiException && e.isAccessLost;
        return Scaffold(
          appBar: AppBar(title: Text(l.visitTitle)),
          body: ErrorView(
            icon: lost ? Icons.lock_outline : Icons.error_outline,
            message: lost ? l.visitNotFound : errorMessage(l, e),
            onRetry: lost ? null : () => ref.invalidate(visitDetailProvider(widget.visitId)),
          ),
        );
      },
      data: (result) {
        // Prefer the fresher copy returned by the last action while refetching.
        final visit = (_latest != null && async.isLoading) ? _latest! : result.visit;
        final providerType = ref.watch(authControllerProvider).profile?.type;
        final planStage = VisitLifecycle.canRecordCare(visit.status) || visit.status == VisitStatus.completed;
        final showEscalate = VisitLifecycle.canEscalate(visit.status);
        return Scaffold(
          appBar: AppBar(title: Text(visit.serviceName)),
          bottomNavigationBar: showEscalate
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 12),
                    child: EscalateButton(onPressed: _busy ? null : () => _escalate(visit)),
                  ),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async => _refreshAll(),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SyncBanners(),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.fromCache)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(l.visitsShowingCached,
                              style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                        ),
                      _HeaderCard(visit: visit),
                      const SizedBox(height: 12),
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            VisitStepper(status: visit.status),
                            const SizedBox(height: 16),
                            NextActionPanel(
                              key: ValueKey('panel-${visit.status}'),
                              visit: visit,
                              busy: _busy,
                              online: online,
                              consent: _consent,
                              onConsentChanged: (v) => setState(() => _consent = v),
                              onNavigate: () => _navigate(visit),
                              onAction: (type, body) async {
                                await _perform(visit, type, body);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AddressCard(visit: visit),
                      const SizedBox(height: 12),
                      PatientContextCard(visit: visit),
                      if (visit.isSampleCollection) ...[
                        const SizedBox(height: 12),
                        LabTestsCard(visit: visit),
                      ],
                      if (planStage && canCreateExercisePlan(providerType)) ...[
                        const SizedBox(height: 12),
                        ExercisePlanCard(patientId: visit.patientId, onCreate: () => _openPlan(visit, 'exercise-plan')),
                      ],
                      if (planStage && canCreateDietPlan(providerType)) ...[
                        const SizedBox(height: 12),
                        DietPlanCard(onCreate: () => _openPlan(visit, 'diet-plan')),
                      ],
                      if (VisitLifecycle.canRecordCare(visit.status)) ...[
                        const SizedBox(height: 12),
                        SectionCard(
                          title: l.vitalsTitle,
                          child: VitalsForm(
                            busy: _busy,
                            onSubmit: (body) =>
                                _perform(visit, VisitActionType.vitals, body, successMessage: l.vitalsSaved),
                          ),
                        ),
                        if (visit.status == VisitStatus.inProgress && !kIsWeb) ...[
                          const SizedBox(height: 12),
                          VisitPhotoCard(busy: _busy, onAddPhoto: () => _addPhoto(visit)),
                        ],
                        const SizedBox(height: 12),
                        SectionCard(
                          key: const Key('suppliesUsageCard'),
                          title: l.supUsageTitle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l.supUsageCardBody, style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const Key('recordSupplies'),
                                onPressed: _busy ? null : () => _recordSupplies(visit),
                                icon: const Icon(Icons.inventory_2_outlined),
                                label: Text(l.supUsageButton),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SectionCard(
                          title: l.obsTitle,
                          child: ObservationsForm(
                            initial: visit.observations,
                            busy: _busy,
                            dictation: ref.read(voiceDictationProvider),
                            onSubmit: (body) =>
                                _perform(visit, VisitActionType.observations, body, successMessage: l.obsSaved),
                          ),
                        ),
                      ],
                      if (visit.vitals.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _RecordedVitals(visit: visit),
                      ],
                      if (visit.escalation != null) ...[
                        const SizedBox(height: 12),
                        SectionCard(
                          title: l.visitEscalation,
                          color: AppColors.dangerBg,
                          child: Text(
                            '${visit.escalation!.severity == 'emergency' ? l.escalateEmergency : l.escalateUrgent}: '
                            '${visit.escalation!.reason}',
                          ),
                        ),
                      ],
                      if (visit.summary != null && visit.summary!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SectionCard(title: l.visitSummary, child: Text(visit.summary!)),
                      ],
                      const SizedBox(height: 12),
                      _TimelineCard(visit: visit),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Large, always-visible red escalation button (in_progress).
class EscalateButton extends StatelessWidget {
  const EscalateButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        key: const Key('action.escalate'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          minimumSize: const Size.fromHeight(56),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.emergency_outlined),
        label: Text(context.l10n.escalateButton),
      );
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      color: AppColors.mint50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(visit.patientName, style: Theme.of(context).textTheme.titleLarge)),
              StatusChip(status: visit.status),
            ],
          ),
          if (visit.pendingSync) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.sync, size: 16, color: AppColors.sky),
                const SizedBox(width: 4),
                Text(l.visitPendingSyncChip, style: const TextStyle(color: AppColors.sky, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          LabeledValue(
            icon: Icons.schedule,
            label: l.visitTimeWindow,
            value: formatWindow(context, visit.preferredStart, visit.preferredEnd),
          ),
          if (visit.reason.isNotEmpty)
            LabeledValue(icon: Icons.notes, label: l.visitReason, value: visit.reason),
          if (visit.status == VisitStatus.enRoute && visit.etaMinutes != null)
            LabeledValue(icon: Icons.directions_car_outlined, label: l.stepTravel, value: l.visitEta(visit.etaMinutes!)),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = visit.address;
    final full = VisitLifecycle.showFullAddress(visit.status);
    return SectionCard(
      title: l.visitAddress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (full) ...[
            Text(a.fullText, key: const Key('fullAddress')),
            if (a.landmark != null && a.landmark!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l.visitLandmark(a.landmark!), style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ] else ...[
            Text(l.visitAreaOnly(a.city, a.pincode), key: const Key('areaOnly')),
            const SizedBox(height: 4),
            Text(l.visitAddressHidden, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Minimum-necessary patient context, exactly as returned by the API.
class PatientContextCard extends StatelessWidget {
  const PatientContextCard({super.key, required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ctx = visit.patientContext;
    if (ctx == null) {
      return SectionCard(
        title: l.visitPatientContext,
        child: Text(l.visitContextUnavailable, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    Widget chips(List<String> items, {bool danger = false}) {
      if (items.isEmpty) {
        return Text(danger ? l.visitNoAllergiesRecorded : l.visitNoneRecorded,
            style: const TextStyle(color: AppColors.textSecondary));
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: danger ? AppColors.dangerBg : AppColors.mint50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: danger ? AppColors.danger : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (danger) ...[
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.dangerDeep),
                    const SizedBox(width: 4),
                  ],
                  Text(item,
                      style: TextStyle(
                        color: danger ? AppColors.dangerDeep : AppColors.textPrimary,
                        fontWeight: danger ? FontWeight.w700 : FontWeight.w500,
                      )),
                ],
              ),
            ),
        ],
      );
    }

    Widget label(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        );

    final ageGender = l.visitAgeGender(ctx.age?.toString() ?? '–', genderLabel(l, ctx.gender));
    return SectionCard(
      title: l.visitPatientContext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ageGender),
          Semantics(
            label: '${l.visitAllergies}: ${ctx.allergies.isEmpty ? l.visitNoAllergiesRecorded : ctx.allergies.join(', ')}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label(l.visitAllergies, color: AppColors.dangerDeep),
                chips(ctx.allergies, danger: true),
              ],
            ),
          ),
          label(l.visitConditions),
          chips(ctx.conditions),
          label(l.visitMedications),
          chips(ctx.activeMedications),
        ],
      ),
    );
  }
}

class _RecordedVitals extends StatelessWidget {
  const _RecordedVitals({required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      title: l.visitRecordedVitals,
      child: Column(
        children: [
          for (final v in visit.vitals)
            ConstrainedBox(
              key: Key('recordedVital.${v.type}.${v.id ?? v.measuredAt?.toIso8601String()}'),
              constraints: const BoxConstraints(minHeight: 40),
              child: MergeSemantics(
                child: Row(
                  children: [
                    Expanded(child: Text(vitalLabel(l, v.type))),
                    if (VitalRanges.flag(v.type, v.value) case final flag?) ...[
                      VitalFlagBadge(flag: flag),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '${v.value} ${v.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: VitalRanges.flag(v.type, v.value) == null ? null : AppColors.dangerDeep,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatTime(context, v.measuredAt),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = visit.timeline;
    return SectionCard(
      title: l.visitTimeline,
      child: entries.isEmpty
          ? Text(l.visitNoneRecorded, style: const TextStyle(color: AppColors.textSecondary))
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  MergeSemantics(
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: i == entries.length - 1 ? AppColors.primary : AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (i < entries.length - 1)
                                Expanded(child: Container(width: 2, color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(visitStatusLabel(l, entries[i].status),
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${formatDate(context, entries[i].at)} · ${formatTime(context, entries[i].at)}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  if (entries[i].note != null && entries[i].note!.isNotEmpty)
                                    Text(entries[i].note!, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
