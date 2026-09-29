import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/care.dart';
import '../../models/clinical.dart';
import '../../models/prescription.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import '../common/file_viewer.dart';
import 'patient_providers.dart';
import 'snapshot_view.dart';

/// Full patient snapshot with tabs (contract §16 + §9, §31, §42, §5).
class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final snap = ref.watch(snapshotProvider(patientId));
    final name = snap.value?.patient.name ?? l.patientTitle;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name, overflow: TextOverflow.ellipsis),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.tabOverview),
              Tab(text: l.tabRecords),
              Tab(text: l.tabVitals),
              Tab(text: l.tabPrograms),
              Tab(text: l.tabPrescriptions),
              Tab(text: l.tabEpisodes),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _refreshable(
              ref,
              () => ref.refresh(snapshotProvider(patientId).future),
              AsyncBody<ClinicalSnapshot>(
                value: snap,
                onRetry: () => ref.invalidate(snapshotProvider(patientId)),
                data: (s) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    Text(
                      ageGender(l, s.patient.age, s.patient.gender),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (s.patient.bloodGroup != null) LabeledValue(label: l.bloodGroup, value: s.patient.bloodGroup!),
                    gap8,
                    SnapshotSummary(snapshot: s),
                  ],
                ),
              ),
            ),
            _RecordsTab(patientId: patientId),
            _VitalsTab(patientId: patientId),
            _ProgramsTab(patientId: patientId),
            _PrescriptionsTab(patientId: patientId),
            _EpisodesTab(patientId: patientId, fallback: snap.value?.activeEpisodes ?? const []),
          ],
        ),
      ),
    );
  }
}

Widget _refreshable(WidgetRef ref, Future<Object?> Function() onRefresh, Widget child) =>
    RefreshIndicator(onRefresh: onRefresh, child: child);

class _RecordsTab extends ConsumerWidget {
  const _RecordsTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(clinicianRepositoryProvider);
    return _refreshable(
      ref,
      () => ref.refresh(recordsProvider(patientId).future),
      AsyncBody<List<MedicalRecord>>(
        value: ref.watch(recordsProvider(patientId)),
        onRetry: () => ref.invalidate(recordsProvider(patientId)),
        data: (items) => items.isEmpty
            ? EmptyView(message: l.recordsEmpty, icon: Icons.folder_open_outlined)
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screen),
                itemCount: items.length,
                separatorBuilder: (_, _) => gap8,
                itemBuilder: (context, i) {
                  final r = items[i];
                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          minVerticalPadding: 12,
                          leading: Icon(
                            r.isImage ? Icons.image_outlined : Icons.description_outlined,
                            color: AppColors.primaryLight,
                          ),
                          title: Text(r.title),
                          subtitle: Text(
                            [recordTypeLabel(l, r.type), formatIsoDate(context, r.recordDate)].join(' · '),
                          ),
                          trailing: r.hasFile
                              ? IconButton(
                                  tooltip: l.openOriginal,
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () => openFile(
                                    context,
                                    title: r.title,
                                    mimeType: r.mimeType ?? 'application/pdf',
                                    load: () => repo.recordFile(r.id),
                                  ),
                                )
                              : null,
                        ),
                        if (r.aiSummary != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: AiAdvisoryCard(title: l.aiRecordSummary, child: Text(r.aiSummary!)),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _VitalsTab extends ConsumerWidget {
  const _VitalsTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return _refreshable(
      ref,
      () => ref.refresh(vitalsProvider(patientId).future),
      AsyncBody<List<Vital>>(
        value: ref.watch(vitalsProvider(patientId)),
        onRetry: () => ref.invalidate(vitalsProvider(patientId)),
        data: (items) {
          final byType = <String, List<Vital>>{};
          for (final v in items) {
            byType.putIfAbsent(v.type, () => []).add(v);
          }
          if (byType.isEmpty) return EmptyView(message: l.vitalsEmpty, icon: Icons.favorite_border);
          final types = [
            for (final t in vitalTypes)
              if (byType.containsKey(t)) t,
            for (final t in byType.keys)
              if (!vitalTypes.contains(t)) t,
          ];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              for (final t in types) ...[VitalTrendCard(type: t, readings: byType[t]!), gap12],
            ],
          );
        },
      ),
    );
  }
}

/// One vital type: latest value, min/max and a sparkline (oldest -> newest).
class VitalTrendCard extends StatelessWidget {
  const VitalTrendCard({super.key, required this.type, required this.readings});
  final String type;
  final List<Vital> readings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sorted = [...readings]..sort((a, b) => (a.measuredAt ?? DateTime(0)).compareTo(b.measuredAt ?? DateTime(0)));
    final values = sorted.map((v) => v.value.toDouble()).toList();
    final latest = sorted.last;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    return SectionCard(
      title: vitalLabel(l, type),
      trailing: Text(
        '${formatNumber(latest.value)} ${latest.unit}',
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l.vitalTrendSemantics(vitalLabel(l, type), formatNumber(min), formatNumber(max), values.length),
            excludeSemantics: true,
            child: SizedBox(height: 64, child: CustomPaint(painter: SparklinePainter(values))),
          ),
          gap8,
          Text(
            '${l.vitalRange(formatNumber(min), formatNumber(max))} · ${l.readingsCount(values.length)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            formatDateTime(context, latest.measuredAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 1e-9 ? 1.0 : max - min;
    final dx = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    Offset pt(int i) => Offset(
      values.length == 1 ? size.width / 2 : i * dx,
      size.height - 4 - (values[i] - min) / span * (size.height - 8),
    );
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryLight
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final dot = Paint()..color = AppColors.primary;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(pt(i), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(SparklinePainter old) => old.values != values;
}

class _ProgramsTab extends ConsumerWidget {
  const _ProgramsTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return _refreshable(
      ref,
      () => ref.refresh(enrollmentsProvider(patientId).future),
      AsyncBody<List<Enrollment>>(
        value: ref.watch(enrollmentsProvider(patientId)),
        onRetry: () => ref.invalidate(enrollmentsProvider(patientId)),
        data: (items) => items.isEmpty
            ? EmptyView(message: l.programsEmpty, icon: Icons.monitor_heart_outlined)
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  for (final e in items) ...[
                    SectionCard(
                      title: e.templateName,
                      trailing: TonePill(
                        label: programStatusLabel(l, e.status),
                        bg: AppColors.mint100,
                        fg: AppColors.primary,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LabeledValue(
                            label: l.programAdherence,
                            value: e.adherencePct7d == null ? '–' : '${formatNumber(e.adherencePct7d!)}%',
                          ),
                          LabeledValue(label: l.programLastReading, value: formatDateTime(context, e.lastReadingAt)),
                          LabeledValue(label: l.programOpenBreaches, value: '${e.openBreaches}'),
                          if (e.thresholds.isNotEmpty)
                            Text(
                              e.thresholds
                                  .map(
                                    (t) =>
                                        '${vitalLabel(l, t.type)} ${t.op == 'gt' ? '>' : '<'} ${formatNumber(t.value)} (${levelLabel(l, t.level)})',
                                  )
                                  .join('\n'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    gap12,
                  ],
                ],
              ),
      ),
    );
  }
}

class _PrescriptionsTab extends ConsumerWidget {
  const _PrescriptionsTab({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(clinicianRepositoryProvider);
    return _refreshable(
      ref,
      () => ref.refresh(prescriptionsProvider(patientId).future),
      AsyncBody<List<Prescription>>(
        value: ref.watch(prescriptionsProvider(patientId)),
        onRetry: () => ref.invalidate(prescriptionsProvider(patientId)),
        data: (items) => items.isEmpty
            ? EmptyView(message: l.prescriptionsEmpty, icon: Icons.receipt_long_outlined)
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screen),
                itemCount: items.length,
                separatorBuilder: (_, _) => gap8,
                itemBuilder: (context, i) {
                  final p = items[i];
                  return Card(
                    child: ListTile(
                      minVerticalPadding: 12,
                      leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primaryLight),
                      title: Text(p.items.map((x) => x.drugName).join(', ')),
                      subtitle: Text('${p.doctorName} · ${formatDate(context, p.createdAt)}'),
                      trailing: const Icon(Icons.picture_as_pdf_outlined),
                      onTap: () =>
                          openFile(context, title: l.rxPdfTitle(p.patientName), load: () => repo.prescriptionPdf(p.id)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EpisodesTab extends ConsumerWidget {
  const _EpisodesTab({required this.patientId, required this.fallback});
  final String patientId;
  final List<CareEpisode> fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final value = ref.watch(episodesProvider(patientId));
    // Doctors may not be allowed to list every episode; fall back to the
    // snapshot's active episodes.
    final items = value.value ?? (value.hasError ? fallback : null);
    if (items == null) return const LoadingView();
    if (items.isEmpty) return EmptyView(message: l.episodesEmpty, icon: Icons.timeline);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screen),
      itemCount: items.length,
      separatorBuilder: (_, _) => gap8,
      itemBuilder: (context, i) {
        final e = items[i];
        return Card(
          child: ListTile(
            minVerticalPadding: 12,
            title: Text(e.title),
            subtitle: Text(
              [
                episodeStatusLabel(l, e.status),
                if (e.nextAction != null) e.nextAction!,
                formatDate(context, e.updatedAt ?? e.createdAt),
              ].join(' · '),
            ),
            leading: PriorityChip(priority: e.priority),
            trailing: IconButton(
              tooltip: l.careTeamThread,
              icon: const Icon(Icons.forum_outlined),
              onPressed: () => context.push('/messages/${e.id}', extra: e.title),
            ),
          ),
        );
      },
    );
  }
}
