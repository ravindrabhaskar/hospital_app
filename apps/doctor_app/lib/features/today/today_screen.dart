import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/clinician_repository.dart';
import '../../models/clinical.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// `GET /clinician/queue?date=` keyed by `YYYY-MM-DD`.
final queueProvider = FutureProvider.autoDispose.family<List<Appointment>, String>((ref, date) async {
  final items = await ref.watch(clinicianRepositoryProvider).queue(DateTime.parse(date));
  items.sort((a, b) => (a.startAt ?? DateTime(0)).compareTo(b.startAt ?? DateTime(0)));
  return items;
});

final selectedQueueDateProvider = NotifierProvider<_SelectedDate, DateTime>(_SelectedDate.new);

class _SelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime d) => state = DateTime(d.year, d.month, d.day);
}

IconData modeIcon(String mode) => switch (mode) {
  'video' => Icons.videocam_outlined,
  'audio' => Icons.call_outlined,
  'chat' => Icons.chat_bubble_outline,
  'in_clinic' => Icons.local_hospital_outlined,
  _ => Icons.event_outlined,
};

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final date = ref.watch(selectedQueueDateProvider);
    final key = ClinicianRepository.isoDate(date);
    final queue = ref.watch(queueProvider(key));
    final auth = ref.watch(authControllerProvider);
    final name = auth.displayName;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: Text(name.isEmpty ? l.navToday : l.helloDoctor(name))),
        actions: [
          IconButton(
            tooltip: l.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(queueProvider(key)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(queueProvider(key).future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _DateStrip(selected: date)),
            ...queue.when(
              skipLoadingOnRefresh: true,
              loading: () => [const SliverFillRemaining(hasScrollBody: false, child: LoadingView())],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(error: e, onRetry: () => ref.invalidate(queueProvider(key))),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyView(message: l.queueEmpty, icon: Icons.event_available_outlined),
                      ),
                    ]
                  : [
                      SliverToBoxAdapter(child: QueueSummary(items: items)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 24),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => gap12,
                          itemBuilder: (context, i) => QueueCard(
                            appointment: items[i],
                            onTap: () => context.push('/consultation/${items[i].id}', extra: items[i]),
                          ),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateStrip extends ConsumerWidget {
  const _DateStrip({required this.selected});
  final DateTime selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final locale = Localizations.localeOf(context).toString();
    final days = [for (var i = -1; i <= 6; i++) today.add(Duration(days: i))];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 8),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final isSel = d == selected;
          final label = '${DateFormat.E(locale).format(d)} ${d.day}';
          return Semantics(
            button: true,
            selected: isSel,
            label: DateFormat.yMMMMEEEEd(locale).format(d),
            excludeSemantics: true,
            child: InkWell(
              key: Key('day.${ClinicianRepository.isoDate(d)}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => ref.read(selectedQueueDateProvider.notifier).select(d),
              child: Container(
                width: 56,
                decoration: BoxDecoration(
                  color: isSel ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSel ? AppColors.primary : AppColors.border),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label.split(' ').first,
                      style: TextStyle(fontSize: 12, color: isSel ? Colors.white : AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class QueueSummary extends StatelessWidget {
  const QueueSummary({super.key, required this.items});
  final List<Appointment> items;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final waiting = items
        .where((a) => a.status == ApptStatus.confirmed || a.status == ApptStatus.pendingPayment)
        .length;
    final active = items.where((a) => a.isInProgress).length;
    final done = items.where((a) => a.isCompleted).length;
    Widget tile(String label, int n, Color bg, Color fg) => Expanded(
      child: Semantics(
        label: '$label: $n',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.tileRadius)),
          child: Column(
            children: [
              Text(
                '$n',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fg),
              ),
              Text(label, style: TextStyle(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        children: [
          tile(l.queueWaiting, waiting, AppColors.skyBg, AppColors.sky),
          const SizedBox(width: 8),
          tile(l.queueInProgress, active, AppColors.mint100, AppColors.primary),
          const SizedBox(width: 8),
          tile(l.queueDone, done, AppColors.mint50, AppColors.primaryLight),
        ],
      ),
    );
  }
}

class QueueCard extends StatelessWidget {
  const QueueCard({super.key, required this.appointment, required this.onTap});
  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = appointment;
    final urgentBorder = a.priority == 'emergency'
        ? AppColors.danger
        : a.priority == 'urgent'
        ? AppColors.warning
        : AppColors.border;
    return Card(
      key: Key('queue.${a.id}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: urgentBorder, width: a.priority == 'routine' ? 1 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(modeIcon(a.mode), size: 20, color: AppColors.primaryLight, semanticLabel: modeLabel(l, a.mode)),
                  const SizedBox(width: 6),
                  Text(
                    formatTime(context, a.startAt),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '· ${modeLabel(l, a.mode)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  ApptStatusChip(status: a.status),
                ],
              ),
              gap8,
              Text(a.patientName, style: Theme.of(context).textTheme.titleMedium),
              Text(ageGender(l, a.patientAge, a.patientGender), style: const TextStyle(color: AppColors.textSecondary)),
              if (a.reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(a.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              gap8,
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  PriorityChip(priority: a.priority),
                  if (a.episodeStatus != null)
                    TonePill(
                      label: episodeStatusLabel(l, a.episodeStatus!),
                      bg: AppColors.lavenderBg,
                      fg: AppColors.lavender,
                      semanticsPrefix: l.episodeLabel,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
