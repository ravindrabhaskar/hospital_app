import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/clinician_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/clinical.dart';
import '../../models/doctor.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

final scheduleProvider = FutureProvider.autoDispose<Schedule>(
  (ref) => ref.watch(clinicianRepositoryProvider).schedule(),
);

String blockIssueText(AppLocalizations l, BlockIssue i) => switch (i) {
  BlockIssue.invalidTime => l.blockInvalidTime,
  BlockIssue.endBeforeStart => l.blockEndBeforeStart,
  BlockIssue.tooShortForSlot => l.blockTooShort,
  BlockIssue.noModes => l.blockNoModes,
  BlockIssue.overlap => l.blockOverlap,
};

/// Schedule & leaves (contract §29).
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.scheduleTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.weeklyTab),
              Tab(text: l.leavesTab),
            ],
          ),
        ),
        body: AsyncBody<Schedule>(
          value: ref.watch(scheduleProvider),
          onRetry: () => ref.invalidate(scheduleProvider),
          data: (s) => TabBarView(
            children: [
              WeeklyEditor(initial: s.weekly, horizonDays: s.horizonDays),
              _Leaves(schedule: s),
            ],
          ),
        ),
      ),
    );
  }
}

class WeeklyEditor extends ConsumerStatefulWidget {
  const WeeklyEditor({super.key, required this.initial, this.horizonDays = 14});
  final List<WeeklyBlock> initial;
  final int horizonDays;

  @override
  ConsumerState<WeeklyEditor> createState() => _WeeklyEditorState();
}

class _WeeklyEditorState extends ConsumerState<WeeklyEditor> {
  late List<WeeklyBlock> _blocks = [...widget.initial];
  bool _dirty = false;
  bool _busy = false;

  Future<void> _edit([int? index]) async {
    final b = await showModalBottomSheet<WeeklyBlock>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlockEditor(initial: index == null ? null : _blocks[index]),
    );
    if (b == null) return;
    setState(() {
      if (index == null) {
        _blocks.add(b);
      } else {
        _blocks[index] = b;
      }
      _blocks.sort(
        (a, c) => a.weekday != c.weekday ? a.weekday.compareTo(c.weekday) : a.startMinutes.compareTo(c.startMinutes),
      );
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final s = await ref.read(clinicianRepositoryProvider).saveSchedule(_blocks);
      if (!mounted) return;
      setState(() {
        _blocks = [...s.weekly];
        _dirty = false;
      });
      showSnack(context, l.scheduleSaved);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final problems = validateWeekly(_blocks);
    final byIndex = <int, List<BlockProblem>>{};
    for (final p in problems) {
      byIndex.putIfAbsent(p.index, () => []).add(p);
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              Text(l.scheduleHint(widget.horizonDays), style: const TextStyle(color: AppColors.textSecondary)),
              gap12,
              if (_blocks.isEmpty) EmptyView(message: l.scheduleEmpty, icon: Icons.calendar_month_outlined),
              for (var i = 0; i < _blocks.length; i++)
                Card(
                  key: Key('block.$i'),
                  margin: const EdgeInsets.only(bottom: 8),
                  color: byIndex.containsKey(i) ? AppColors.dangerBg : null,
                  child: ListTile(
                    minVerticalPadding: 12,
                    title: Text('${weekdayName(context, _blocks[i].weekday)} · ${_blocks[i].start}–${_blocks[i].end}'),
                    subtitle: Text(
                      [
                        l.slotMinutes(_blocks[i].slotMins),
                        _blocks[i].modes.map((m) => modeLabel(l, m)).join(', '),
                        for (final p in byIndex[i] ?? const <BlockProblem>[]) blockIssueText(l, p.issue),
                      ].join('\n'),
                    ),
                    onTap: () => _edit(i),
                    trailing: IconButton(
                      tooltip: l.commonRemove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _blocks.removeAt(i);
                        _dirty = true;
                      }),
                    ),
                  ),
                ),
              TextButton.icon(
                key: const Key('addBlock'),
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: Text(l.addBlock),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: FilledButton(
            key: const Key('saveSchedule'),
            onPressed: !_dirty || _busy || problems.isNotEmpty ? null : _save,
            child: _busy ? const ButtonSpinner() : Text(problems.isEmpty ? l.saveSchedule : l.fixProblems),
          ),
        ),
      ],
    );
  }
}

class BlockEditor extends StatefulWidget {
  const BlockEditor({super.key, this.initial});
  final WeeklyBlock? initial;

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  late WeeklyBlock _b = widget.initial ?? const WeeklyBlock(weekday: 1, start: '09:00', end: '13:00');

  Future<void> _pickTime(bool start) async {
    final cur = hhmmToMinutes(start ? _b.start : _b.end);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (t == null) return;
    final v = minutesToHhmm(t.hour * 60 + t.minute);
    setState(() => _b = start ? _b.copyWith(start: v) : _b.copyWith(end: v));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final issues = validateWeekly([_b]);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text(l.blockTitle, style: Theme.of(context).textTheme.titleLarge),
        gap12,
        DropdownButtonFormField<int>(
          initialValue: _b.weekday,
          decoration: InputDecoration(labelText: l.weekday),
          items: [for (var d = 0; d < 7; d++) DropdownMenuItem(value: d, child: Text(weekdayName(context, d)))],
          onChanged: (v) => setState(() => _b = _b.copyWith(weekday: v)),
        ),
        gap12,
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => _pickTime(true), child: Text('${l.startTime}: ${_b.start}')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: () => _pickTime(false), child: Text('${l.endTime}: ${_b.end}')),
            ),
          ],
        ),
        gap12,
        DropdownButtonFormField<int>(
          initialValue: _b.slotMins,
          decoration: InputDecoration(labelText: l.slotLength),
          items: [for (final m in slotLengths) DropdownMenuItem(value: m, child: Text(l.slotMinutes(m)))],
          onChanged: (v) => setState(() => _b = _b.copyWith(slotMins: v)),
        ),
        gap12,
        Wrap(
          spacing: 8,
          children: [
            for (final m in consultModes)
              FilterChip(
                label: Text(modeLabel(l, m)),
                selected: _b.modes.contains(m),
                onSelected: (sel) => setState(
                  () => _b = _b.copyWith(modes: sel ? [..._b.modes, m] : _b.modes.where((x) => x != m).toList()),
                ),
              ),
          ],
        ),
        for (final p in issues) ...[
          gap8,
          Text(blockIssueText(l, p.issue), style: const TextStyle(color: AppColors.danger)),
        ],
        gap16,
        FilledButton(onPressed: issues.isEmpty ? () => Navigator.of(context).pop(_b) : null, child: Text(l.commonSave)),
      ],
    );
  }
}

class _Leaves extends ConsumerStatefulWidget {
  const _Leaves({required this.schedule});
  final Schedule schedule;

  @override
  ConsumerState<_Leaves> createState() => _LeavesState();
}

class _LeavesState extends ConsumerState<_Leaves> {
  bool _busy = false;

  Future<void> _add() async {
    final l = context.l10n;
    final now = ref.read(clockProvider)();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.addLeave),
        content: TextField(
          controller: reason,
          decoration: InputDecoration(labelText: l.leaveReason),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(clinicianRepositoryProvider).addLeave(ClinicianRepository.isoDate(date), reason.text);
      ref.invalidate(scheduleProvider);
      if (!mounted) return;
      if (res.conflicts.isNotEmpty) {
        await showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          builder: (_) => LeaveConflictsSheet(conflicts: res.conflicts),
        );
      } else {
        showSnack(context, l.leaveAdded);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Leave leave) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.leaveRemoveTitle),
        content: Text(l.leaveRemoveBody(formatIsoDate(context, leave.date))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
          FilledButton(
            key: const Key('leaveRemoveConfirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.commonRemove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(clinicianRepositoryProvider).deleteLeave(leave.id);
      ref.invalidate(scheduleProvider);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final leaves = widget.schedule.leaves;
    return Column(
      children: [
        Expanded(
          child: leaves.isEmpty
              ? EmptyView(message: l.leavesEmpty, icon: Icons.beach_access_outlined)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    for (final lv in leaves)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          minVerticalPadding: 12,
                          leading: const Icon(Icons.event_busy_outlined, color: AppColors.primaryLight),
                          title: Text(formatIsoDate(context, lv.date)),
                          subtitle: lv.reason == null ? null : Text(lv.reason!),
                          trailing: IconButton(
                            key: Key('leaveRemove.${lv.id}'),
                            tooltip: l.commonRemove,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy ? null : () => _delete(lv),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: FilledButton.icon(
            key: const Key('addLeave'),
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
            label: Text(l.addLeave),
          ),
        ),
      ],
    );
  }
}

/// Appointments on a leave day are not auto-cancelled (§29): list them so
/// the doctor can arrange rescheduling with the care team.
class LeaveConflictsSheet extends StatelessWidget {
  const LeaveConflictsSheet({super.key, required this.conflicts});
  final List<Appointment> conflicts;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      key: const Key('leaveConflicts'),
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: warningFg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.leaveConflictsTitle(conflicts.length), style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        gap8,
        Text(l.leaveConflictsBody),
        gap12,
        for (final a in conflicts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a.patientName),
            subtitle: Text('${formatDateTime(context, a.startAt)} · ${modeLabel(l, a.mode)}'),
          ),
        gap12,
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonOk)),
      ],
    );
  }
}
