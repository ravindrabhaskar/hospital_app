import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/load_more.dart';
import '../../core/widgets/state_views.dart';
import '../../models/json.dart';
import '../../models/patient.dart';
import '../../models/prescription.dart';
import '../../models/records.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../prescriptions/prescription_widgets.dart';

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  static const _filters = <String?>[null, RecordType.labReport, RecordType.prescription, RecordType.imaging];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final patient = ref.watch(activePatientProvider).value;
    final canView = patient?.can(FamilyPermission.viewRecords) ?? true;
    return DefaultTabController(
      length: _filters.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.healthRecords),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                tooltip: l.healthTimeline,
                onPressed: () => context.push('/timeline'),
                icon: const Icon(Icons.timeline)),
            IconButton(
                tooltip: l.vitals, onPressed: () => context.push('/vitals'), icon: const Icon(Icons.monitor_heart_outlined)),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.sm),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
                  labelColor: Colors.white,
                  splashBorderRadius: BorderRadius.circular(22),
                  unselectedLabelColor: context.textMuted,
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    Tab(text: l.all),
                    Tab(text: l.reports),
                    Tab(text: l.prescriptions),
                    Tab(text: l.images),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: !canView
            ? EmptyStateView(icon: Icons.lock_outline, title: l.forbiddenTitle, message: l.noRecordsPermission)
            : TabBarView(children: [
                for (final f in _filters)
                  f == RecordType.prescription ? const PrescriptionsTab() : RecordList(type: f),
              ]),
      ),
    );
  }
}

class RecordList extends ConsumerWidget {
  const RecordList({super.key, required this.type});
  final String? type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(recordsProvider(type));
    final upload = ListRowTile(
      icon: Icons.add,
      accent: Accent.teal,
      title: l.uploadNewReport,
      subtitle: l.uploadNewReportSub,
      onTap: () => context.push(type == null ? '/records/upload' : '/records/upload?type=$type'),
    );
    return RefreshIndicator(
      onRefresh: () => ref.refresh(recordsProvider(type).future),
      child: AsyncView<Page<MedicalRecord>>(
        value: v,
        onRetry: () => ref.invalidate(recordsProvider(type)),
        isEmpty: (p) => p.items.isEmpty,
        empty: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            EmptyStateView(icon: Icons.folder_open, title: l.noRecordsTitle, message: l.noRecordsMessage),
            upload,
          ],
        ),
        data: (page) => PagedItems<MedicalRecord>(
          first: page.items,
          nextCursor: page.nextCursor,
          fetch: (cursor) async => ref.read(recordsRepositoryProvider).page(
              (await ref.read(activePatientProvider.future)).id,
              type: type,
              cursor: cursor),
          builder: (context, list, footer) => ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              for (final r in list) RecordTile(record: r),
              ?footer,
              const SizedBox(height: Space.sm),
              upload,
            ],
          ),
        ),
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record});
  final MedicalRecord record;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = record;
    final sub = [
      fmtYmd(context, r.recordDate),
      if (r.mimeType.isNotEmpty) r.isImage ? l.image : (r.mimeType.contains('pdf') ? 'PDF' : Labels.recordType(l, r.type)),
      ?r.uploadedByName,
    ].join(' • ');
    return ListRowTile(
      icon: Labels.recordIcon(r.type),
      accent: Labels.recordAccent(r.type),
      title: r.title,
      subtitle: sub,
      onTap: () => context.push('/records/${r.id}'),
    );
  }
}

/// Records → Prescriptions: doctor-issued e-prescriptions (§31) first, then
/// other prescription documents (family uploads and scanned paper prescriptions).
class PrescriptionsTab extends ConsumerWidget {
  const PrescriptionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final uploaded = ref.watch(recordsProvider(RecordType.prescription));
    // PDFs of structured e-prescriptions are already listed above; don't show them twice.
    final structuredRecordIds = {
      for (final rx in ref.watch(prescriptionsProvider).value ?? const <Prescription>[])
        if (rx.recordId != null) rx.recordId!,
    };
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recordsProvider(RecordType.prescription));
        ref.invalidate(prescriptionsProvider);
        await ref.read(prescriptionsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
        children: [
          PrescriptionsSection(title: l.ePrescriptions),
          SectionHeader(title: l.uploadedPrescriptions),
          AsyncView<Page<MedicalRecord>>(
            value: uploaded,
            compact: true,
            onRetry: () => ref.invalidate(recordsProvider(RecordType.prescription)),
            isEmpty: (p) => p.items.every((r) => structuredRecordIds.contains(r.id)),
            empty: Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(l.noUploadedPrescriptions, style: TextStyle(color: context.textMuted)),
            ),
            data: (p) => Column(children: [
              for (final r in p.items)
                if (!structuredRecordIds.contains(r.id)) RecordTile(record: r),
            ]),
          ),
          ListRowTile(
            icon: Icons.add,
            accent: Accent.teal,
            title: l.uploadPrescription,
            onTap: () => context.push('/records/upload?type=${RecordType.prescription}'),
          ),
        ],
      ),
    );
  }
}
