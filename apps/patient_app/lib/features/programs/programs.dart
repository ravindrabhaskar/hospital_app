import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pdf_viewer.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/trend_chart.dart';
import '../../l10n/app_localizations.dart';
import '../../models/care.dart';
import '../../models/json.dart';
import '../../models/monitoring.dart';
import '../../models/records.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../../state/v13_providers.dart';

// Chronic care programs / remote monitoring (API_CONTRACT §42).

/// Readings still due today for a program's metrics.
class DueReading {
  const DueReading({required this.type, required this.due, required this.done});
  final String type;
  final int due;
  final int done;
  int get remaining => (due - done).clamp(0, due);
}

List<DueReading> readingsDueToday(List<ProgramMetric> metrics, List<VitalMeasurement> vitals, DateTime now) {
  final types = metrics.map((m) => m.type).toSet();
  final out = <DueReading>[];
  bool sameDay(DateTime a) => a.year == now.year && a.month == now.month && a.day == now.day;
  for (final m in metrics) {
    // Systolic and diastolic are one BP reading.
    if (m.type == 'bp_diastolic' && types.contains('bp_systolic')) continue;
    final todays = vitals.where((v) => v.type == m.type && sameDay(v.measuredAt)).length;
    switch (m.frequency) {
      case 'twice_daily':
        out.add(DueReading(type: m.type, due: 2, done: todays));
      case 'weekly':
        final week = vitals.where((v) => v.type == m.type && now.difference(v.measuredAt).inDays < 7).length;
        out.add(DueReading(type: m.type, due: week > 0 ? 0 : 1, done: 0));
      default:
        out.add(DueReading(type: m.type, due: 1, done: todays));
    }
  }
  return out;
}

String metricLabel(AppLocalizations l, String type) => type == 'bp_systolic' ? l.bloodPressure : Labels.vitalType(l, type);

String readingErrorText(AppLocalizations l, ReadingError e) => switch (e) {
      ReadingError.missing => l.fieldRequired,
      ReadingError.notNumber => l.enterValidNumber,
      ReadingError.outOfRange => l.readingOutOfRange,
      ReadingError.systolicNotAboveDiastolic => l.readingSystolicBelowDiastolic,
    };

/// Compact Home section; hidden when there are no enrollments or on error.
class MyProgramsSection extends ConsumerWidget {
  const MyProgramsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureFlagsProvider).carePrograms) return const SizedBox.shrink();
    final list = ref.watch(enrollmentsProvider).value?.where((e) => e.isActive).toList();
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      key: const Key('home-programs'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.myPrograms, onSeeAll: () => context.push('/programs')),
        for (final e in list.take(2)) EnrollmentCard(enrollment: e),
      ],
    );
  }
}

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myPrograms)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('log-reading-fab'),
        onPressed: () => showLogReadingSheet(context),
        icon: const Icon(Icons.add_chart),
        label: Text(l.logReading),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(enrollmentsProvider);
          ref.invalidate(vitalsProvider);
          await ref.read(enrollmentsProvider.future);
        },
        child: AsyncView<List<Enrollment>>(
          value: ref.watch(enrollmentsProvider),
          onRetry: () => ref.invalidate(enrollmentsProvider),
          isEmpty: (list) => list.isEmpty,
          empty: ListView(children: [
            EmptyStateView(
              icon: Icons.monitor_heart_outlined,
              title: l.noProgramsTitle,
              message: l.noProgramsBody,
            ),
          ]),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 96),
            children: [
              Text(l.programsIntro, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.md),
              for (final e in list) EnrollmentCard(enrollment: e),
            ],
          ),
        ),
      ),
    );
  }
}

class EnrollmentCard extends ConsumerWidget {
  const EnrollmentCard({super.key, required this.enrollment});
  final Enrollment enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = enrollment;
    final template =
        ref.watch(programTemplatesProvider).value?.where((t) => t.code == e.templateCode).firstOrNull;
    final vitals = ref.watch(vitalsProvider).value ?? const <VitalMeasurement>[];
    final due = template == null ? const <DueReading>[] : readingsDueToday(template.metrics, vitals, DateTime.now());
    final remaining = due.fold<int>(0, (a, d) => a + d.remaining);
    final adherence = e.adherencePct7d;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        key: Key('enrollment-${e.id}'),
        onTap: () => context.push('/programs/${e.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.monitor_heart_outlined, accent: Accent.rose, size: 44),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.templateName, style: Theme.of(context).textTheme.titleSmall),
                      if (e.lastReadingAt != null)
                        Text(l.lastReadingAt(fmtDateTime(context, e.lastReadingAt!)),
                            style: TextStyle(fontSize: 12, color: context.textMuted)),
                    ],
                  ),
                ),
                if (!e.isActive) StatusPill(label: programStatusLabel(l, e.status), color: AppColors.peachFg),
              ],
            ),
            const SizedBox(height: Space.md),
            if (adherence != null) ...[
              Row(
                children: [
                  Expanded(child: Text(l.adherence7d, style: TextStyle(color: context.textMuted, fontSize: 12.5))),
                  Text('${adherence.round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (adherence / 100).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: context.borderColor,
                  color: adherence >= 80 ? AppColors.primaryLight : AppColors.peachFg,
                  semanticsLabel: l.adherence7d,
                  semanticsValue: '${adherence.round()}%',
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (template != null)
                  StatusPill(
                    key: const Key('readings-due'),
                    label: remaining == 0 ? l.readingsDoneToday : l.readingsDueToday(remaining),
                    color: remaining == 0 ? AppColors.primaryLight : AppColors.skyFg,
                    icon: remaining == 0 ? Icons.check : Icons.schedule,
                  ),
                if (e.openBreaches > 0)
                  StatusPill(
                    label: l.openAlerts(e.openBreaches),
                    color: AppColors.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),
            if (e.isActive) ...[
              const SizedBox(height: Space.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showLogReadingSheet(context, template: template),
                  icon: const Icon(Icons.add_chart),
                  label: Text(l.logReading),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String programStatusLabel(AppLocalizations l, String s) => switch (s) {
      'paused' => l.programPaused,
      'completed' => l.programCompleted,
      _ => l.active,
    };

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final enrollments = ref.watch(enrollmentsProvider);
    final e = enrollments.value?.where((x) => x.id == id).firstOrNull;
    final summary = ref.watch(programSummaryProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(e?.templateName ?? l.carePrograms)),
      floatingActionButton: e != null && e.isActive
          ? FloatingActionButton.extended(
              onPressed: () => showLogReadingSheet(context,
                  template: ref.read(programTemplatesProvider).value?.where((t) => t.code == e.templateCode).firstOrNull),
              icon: const Icon(Icons.add_chart),
              label: Text(l.logReading),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(programSummaryProvider(id));
          ref.invalidate(enrollmentsProvider);
          await ref.read(programSummaryProvider(id).future);
        },
        child: AsyncView<ProgramSummary>(
          value: summary,
          onRetry: () => ref.invalidate(programSummaryProvider(id)),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 96),
            children: [
              if (e != null) EnrollmentCard(enrollment: e),
              CcCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.adherence30d, style: TextStyle(color: context.textMuted)),
                          Text('${s.adherencePct.round()}%',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Text(l.readingsReceived(s.receivedReadings, s.expectedReadings),
                        style: TextStyle(color: context.textMuted)),
                  ],
                ),
              ),
              SectionHeader(title: l.trend),
              if (s.trend.isEmpty)
                EmptyStateView(compact: true, icon: Icons.show_chart, title: l.noReadingsYet)
              else
                for (final type in s.trendTypes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: CcCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Labels.vitalType(l, type), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: Space.sm),
                          ProgramTrendChart(
                            type: type,
                            points: s.trendFor(type),
                            thresholds: e?.thresholds.where((t) => t.type == type).toList() ?? const [],
                          ),
                        ],
                      ),
                    ),
                  ),
              SectionHeader(title: l.openAlertsTitle),
              if (s.breaches.isEmpty)
                Text(l.noAlerts, style: TextStyle(color: context.textMuted))
              else
                for (final b in s.breaches.reversed.take(10))
                  ListRowTile(
                    icon: Icons.warning_amber_rounded,
                    accent: b.threshold.level == 'routine' ? Accent.peach : Accent.rose,
                    title: '${Labels.vitalType(l, b.type)}: ${_fmtNum(b.value)}',
                    subtitle: [
                      fmtDateTime(context, b.at),
                      if (b.threshold.message.isNotEmpty) b.threshold.message,
                    ].join(' · '),
                  ),
              SectionHeader(title: l.weeklyReports),
              const WeeklyReportsList(),
              const SizedBox(height: Space.md),
              Text(l.programDisclaimer, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtNum(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Trend chart of one vital with the program thresholds as dashed lines.
class ProgramTrendChart extends StatelessWidget {
  const ProgramTrendChart({super.key, required this.type, required this.points, this.thresholds = const []});
  final String type;
  final List<TrendPoint> points;
  final List<ProgramThreshold> thresholds;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final latest = points.isEmpty ? null : points.last;
    return TrendChart(
      key: Key('trend-$type'),
      points: [for (final p in points) ChartPoint(p.date, p.avg, min: p.min, max: p.max)],
      references: [for (final t in thresholds) t.value],
      semanticLabel: latest == null
          ? l.noReadingsYet
          : l.trendSemantic(Labels.vitalType(l, type), points.length, _fmtNum(latest.avg), fmtDate(context, latest.date)),
    );
  }
}

/// "Weekly health report" PDFs generated every Monday (§42), opened in the
/// in-app PDF viewer.
class WeeklyReportsList extends ConsumerWidget {
  const WeeklyReportsList({super.key});

  static bool isWeeklyReport(MedicalRecord r) => r.title.toLowerCase().contains('weekly');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView<Page<MedicalRecord>>(
      value: ref.watch(recordsProvider(null)),
      compact: true,
      onRetry: () => ref.invalidate(recordsProvider(null)),
      isEmpty: (p) => !p.items.any(isWeeklyReport),
      empty: Text(l.noWeeklyReports, style: TextStyle(color: context.textMuted)),
      data: (p) => Column(
        children: [
          for (final r in p.items.where(isWeeklyReport).take(6))
            ListRowTile(
              icon: Icons.picture_as_pdf_outlined,
              accent: Accent.sky,
              title: r.title,
              subtitle: fmtYmd(context, r.recordDate),
              onTap: () => r.isPdf
                  ? openPdf(context,
                      title: r.title,
                      fileName: r.fileName.isEmpty ? '${r.title}.pdf' : r.fileName,
                      load: () => ref.read(recordsRepositoryProvider).file(r.id))
                  : context.push('/records/${r.id}'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Log reading

Future<bool?> showLogReadingSheet(BuildContext context, {ProgramTemplate? template}) {
  ReadingKind initial = ReadingKind.bp;
  final types = template?.metrics.map((m) => m.type).toSet() ?? const <String>{};
  if (!types.contains('bp_systolic') && types.contains('blood_glucose')) initial = ReadingKind.glucose;
  if (!types.contains('bp_systolic') && !types.contains('blood_glucose') && types.contains('weight')) {
    initial = ReadingKind.weight;
  }
  return showModalBottomSheet<bool>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (_) => LogReadingSheet(initial: initial),
  );
}

class LogReadingSheet extends ConsumerStatefulWidget {
  const LogReadingSheet({super.key, this.initial = ReadingKind.bp});
  final ReadingKind initial;

  @override
  ConsumerState<LogReadingSheet> createState() => _LogReadingSheetState();
}

class _LogReadingSheetState extends ConsumerState<LogReadingSheet> {
  late ReadingKind _kind = widget.initial;
  final _a = TextEditingController();
  final _b = TextEditingController();
  ReadingError? _error;
  bool _busy = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = validateReading(_kind, _a.text, _b.text);
    setState(() => _error = err);
    if (err != null) return;
    setState(() => _busy = true);
    try {
      final patient = await ref.read(activePatientProvider.future);
      final now = DateTime.now();
      for (final (type, value, unit) in readingToVitals(_kind, _a.text, _b.text)) {
        await ref
            .read(recordsRepositoryProvider)
            .addVital(patientId: patient.id, type: type, value: value, unit: unit, measuredAt: now);
      }
      ref.invalidate(vitalsProvider);
      ref.invalidate(enrollmentsProvider);
      ref.invalidate(insightsTodayProvider);
      if (!mounted) return;
      showSnack(context, context.l10n.readingSaved);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final (labelA, unit) = switch (_kind) {
      ReadingKind.bp => (l.vitalBpSystolic, 'mmHg'),
      ReadingKind.glucose => (l.vitalBloodGlucose, 'mg/dL'),
      ReadingKind.weight => (l.vitalWeight, 'kg'),
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.logReading, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.md),
            SegmentedButton<ReadingKind>(
              segments: [
                ButtonSegment(value: ReadingKind.bp, label: Text(l.bloodPressureShort)),
                ButtonSegment(value: ReadingKind.glucose, label: Text(l.glucoseShort)),
                ButtonSegment(value: ReadingKind.weight, label: Text(l.weightShort)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() {
                _kind = v.first;
                _a.clear();
                _b.clear();
                _error = null;
              }),
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('reading-a'),
                    controller: _a,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: numeric,
                    decoration: InputDecoration(labelText: labelA, suffixText: unit),
                  ),
                ),
                if (_kind == ReadingKind.bp) ...[
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: TextField(
                      key: const Key('reading-b'),
                      controller: _b,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: numeric,
                      decoration: InputDecoration(labelText: l.vitalBpDiastolic, suffixText: 'mmHg'),
                    ),
                  ),
                ],
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Semantics(
                liveRegion: true,
                child: Text(readingErrorText(l, _error!),
                    key: const Key('reading-error'), style: const TextStyle(color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: Space.sm),
            Text(l.readingSafetyNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(height: Space.lg),
            PrimaryButton(key: const Key('reading-save'), label: l.save, loading: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
