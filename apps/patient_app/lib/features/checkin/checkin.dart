import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../../models/monitoring.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';

// Daily "I'm OK" check-in (API_CONTRACT §41).

String moodEmoji(int mood) => const ['😞', '🙁', '😐', '🙂', '😄'][(mood - 1).clamp(0, 4)];

String moodLabel(AppLocalizations l, int mood) =>
    [l.moodVeryLow, l.moodLow, l.moodOkay, l.moodGood, l.moodGreat][(mood - 1).clamp(0, 4)];

String checkinStatusLabel(AppLocalizations l, String status) => switch (status) {
      'ok' => l.checkinOk,
      'late' => l.checkinLate,
      'missed' => l.checkinMissed,
      _ => l.checkinPending,
    };

Color checkinStatusColor(String status) => switch (status) {
      'ok' => AppColors.primaryLight,
      'late' => AppColors.peachFg,
      'missed' => AppColors.danger,
      _ => AppColors.border,
    };

/// The prominent Home card. Hidden when check-in is disabled or unavailable.
class DailyCheckinCard extends ConsumerStatefulWidget {
  const DailyCheckinCard({super.key});

  @override
  ConsumerState<DailyCheckinCard> createState() => _DailyCheckinCardState();
}

class _DailyCheckinCardState extends ConsumerState<DailyCheckinCard> {
  int? _mood;
  bool _busy = false;
  CheckIn? _justDone;

  Future<void> _checkIn(PatientSummary p) async {
    setState(() => _busy = true);
    try {
      final c = await ref.read(checkinRepositoryProvider).checkIn(p.id, mood: _mood);
      if (!mounted) return;
      setState(() => _justDone = c);
      ref.invalidate(checkinHistoryProvider);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!ref.watch(featureFlagsProvider).dailyCheckin) return const SizedBox.shrink();
    final patient = ref.watch(activePatientProvider).value;
    final settings = ref.watch(checkinSettingsProvider);
    final history = ref.watch(checkinHistoryProvider);
    // Supportive, not blocking: errors and loading simply hide the card.
    if (patient == null || !settings.hasValue || settings.hasError) return const SizedBox.shrink();
    final today = _justDone ?? todaysCheckin(history.value ?? const [], DateTime.now());
    final state = checkinCardState(settings.value, today);
    if (state == CheckinCardState.hidden) return const SizedBox.shrink();
    final s = settings.value!;
    final window = l.checkinWindow(s.windowStart, s.windowEnd);

    if (!patient.isSelf) {
      // Family view: status only.
      final (text, color, icon) = switch (state) {
        CheckinCardState.done => (
            l.checkinFamilyDone(patient.name, today?.checkedInAt == null ? '' : fmtTime(context, today!.checkedInAt!)),
            AppColors.primaryLight,
            Icons.check_circle
          ),
        CheckinCardState.missed => (l.checkinFamilyMissed(patient.name), AppColors.danger, Icons.error_outline),
        _ => (l.checkinFamilyPending(patient.name, window), AppColors.peachFg, Icons.schedule),
      };
      return Padding(
        padding: const EdgeInsets.only(top: Space.xl),
        child: CcCard(
          key: const Key('checkin-family-card'),
          onTap: () => context.push('/checkin'),
          semanticLabel: text,
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: Space.md),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right, color: context.textMuted),
            ],
          ),
        ),
      );
    }

    if (state == CheckinCardState.done) {
      final at = today?.checkedInAt;
      return Padding(
        padding: const EdgeInsets.only(top: Space.xl),
        child: CcCard(
          key: const Key('checkin-done'),
          color: context.mintSurface,
          semanticLabel: l.checkinDoneAt(at == null ? '' : fmtTime(context, at)),
          child: Row(
            children: [
              Icon(Icons.verified, color: context.brand, size: 30),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.checkinThanks, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(l.checkinDoneAt(at == null ? '' : fmtTime(context, at)),
                        style: TextStyle(color: context.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              if (today?.mood != null) Text(moodEmoji(today!.mood!), style: const TextStyle(fontSize: 26)),
            ],
          ),
        ),
      );
    }

    final missed = state == CheckinCardState.missed;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Container(
        key: Key(missed ? 'checkin-missed' : 'checkin-pending'),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.card),
          gradient: LinearGradient(
            colors: missed
                ? [context.roseSurface, context.surface]
                : [context.mintSurface, context.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: missed ? AppColors.danger.withValues(alpha: 0.4) : context.borderColor),
          boxShadow: context.isDark ? null : Shadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(missed ? Icons.notification_important_outlined : Icons.wb_sunny_outlined,
                    color: missed ? AppColors.danger : AppColors.peachFg, size: 28),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.dailyCheckin, style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                Text(window, style: TextStyle(color: context.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(missed ? l.checkinMissedBody : l.checkinPrompt),
            const SizedBox(height: Space.md),
            Text(l.checkinMoodOptional, style: TextStyle(color: context.textMuted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var m = 1; m <= 5; m++)
                  Semantics(
                    button: true,
                    selected: _mood == m,
                    label: moodLabel(l, m),
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('checkin-mood-$m'),
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _mood = _mood == m ? null : m),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _mood == m ? AppColors.primaryLight.withValues(alpha: 0.18) : Colors.transparent,
                          border: Border.all(color: _mood == m ? AppColors.primaryLight : Colors.transparent, width: 2),
                        ),
                        child: Text(moodEmoji(m), style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            PrimaryButton(
              key: const Key('checkin-ok'),
              label: l.imOkToday,
              icon: Icons.check_circle_outline,
              loading: _busy,
              onPressed: () => _checkIn(patient),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 30-day strip of coloured dots (ok / late / missed / pending).
class CheckinHistoryStrip extends StatelessWidget {
  const CheckinHistoryStrip({super.key, required this.history});
  final List<CheckIn> history;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));
    final last = sorted.length > 30 ? sorted.sublist(sorted.length - 30) : sorted;
    final ok = last.where((c) => c.status == 'ok').length;
    final late = last.where((c) => c.status == 'late').length;
    final missed = last.where((c) => c.status == 'missed').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: l.checkinHistorySemantic(ok, late, missed),
          child: ExcludeSemantics(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final c in last)
                  Tooltip(
                    message: '${fmtYmd(context, c.date)} · ${checkinStatusLabel(l, c.status)}',
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.status == 'pending' ? Colors.transparent : checkinStatusColor(c.status),
                        shape: BoxShape.circle,
                        border: Border.all(color: checkinStatusColor(c.status), width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.md,
          children: [
            for (final s in ['ok', 'late', 'missed'])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: checkinStatusColor(s), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(checkinStatusLabel(l, s), style: TextStyle(fontSize: 12, color: context.textMuted)),
              ]),
          ],
        ),
      ],
    );
  }
}

/// `/checkin`: settings (family with `manage_care`) and the 30-day history.
class CheckinSettingsScreen extends ConsumerStatefulWidget {
  const CheckinSettingsScreen({super.key});

  @override
  ConsumerState<CheckinSettingsScreen> createState() => _CheckinSettingsScreenState();
}

class _CheckinSettingsScreenState extends ConsumerState<CheckinSettingsScreen> {
  CheckinSettings? _edit;
  bool _saving = false;

  static const escalationOptions = [30, 60, 90, 120, 180];

  Future<void> _pickTime(bool start) async {
    final s = _edit!;
    final current = hhmmToMinutes(start ? s.windowStart : s.windowEnd) ?? (start ? 480 : 600);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (t == null) return;
    final v = minutesToHhmm(t.hour * 60 + t.minute);
    setState(() => _edit = start ? s.copyWith(windowStart: v) : s.copyWith(windowEnd: v));
  }

  Future<void> _save(String patientId) async {
    final l = context.l10n;
    final s = _edit!;
    final a = hhmmToMinutes(s.windowStart), b = hhmmToMinutes(s.windowEnd);
    if (a == null || b == null || b <= a) {
      showSnack(context, l.checkinWindowInvalid, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(checkinRepositoryProvider).saveSettings(patientId, s);
      ref.invalidate(checkinSettingsProvider);
      if (!mounted) return;
      setState(() => _edit = saved);
      showSnack(context, l.saved);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final patient = ref.watch(activePatientProvider).value;
    final canManage = patient?.can(FamilyPermission.manageCare) ?? false;
    final settings = ref.watch(checkinSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.dailyCheckin)),
      body: AsyncView<CheckinSettings?>(
        value: settings,
        onRetry: () => ref.invalidate(checkinSettingsProvider),
        data: (server) {
          final s = _edit ??= (server ?? CheckinSettings.defaults);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(checkinHistoryProvider);
              await ref.read(checkinHistoryProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                if (patient != null) Text(l.checkinIntro(patient.name), style: TextStyle(color: context.textMuted)),
                const SizedBox(height: Space.md),
                if (!canManage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Text(l.checkinNoPermission, style: const TextStyle(color: AppColors.danger)),
                  ),
                CcCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('checkin-enabled'),
                        value: s.enabled,
                        title: Text(l.checkinEnable),
                        subtitle: Text(l.checkinEnableSub),
                        onChanged: canManage ? (v) => setState(() => _edit = s.copyWith(enabled: v)) : null,
                      ),
                      const Divider(indent: 16),
                      ListTile(
                        minTileHeight: 56,
                        leading: const Icon(Icons.schedule),
                        title: Text(l.checkinWindowStart),
                        trailing: Text(s.windowStart, style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: canManage ? () => _pickTime(true) : null,
                      ),
                      ListTile(
                        minTileHeight: 56,
                        leading: const Icon(Icons.schedule_outlined),
                        title: Text(l.checkinWindowEnd),
                        trailing: Text(s.windowEnd, style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: canManage ? () => _pickTime(false) : null,
                      ),
                      const Divider(indent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                        child: DropdownButtonFormField<int>(
                          initialValue:
                              escalationOptions.contains(s.escalateAfterMins) ? s.escalateAfterMins : null,
                          decoration: InputDecoration(labelText: l.checkinEscalateAfter),
                          items: [
                            for (final m in escalationOptions)
                              DropdownMenuItem(value: m, child: Text(l.minutesCount(m))),
                          ],
                          onChanged:
                              canManage ? (v) => setState(() => _edit = s.copyWith(escalateAfterMins: v)) : null,
                        ),
                      ),
                      SwitchListTile(
                        value: s.notifyFamily,
                        title: Text(l.checkinNotifyFamily),
                        onChanged: canManage ? (v) => setState(() => _edit = s.copyWith(notifyFamily: v)) : null,
                      ),
                      SwitchListTile(
                        value: s.notifyCoordinator,
                        title: Text(l.checkinNotifyCoordinator),
                        onChanged:
                            canManage ? (v) => setState(() => _edit = s.copyWith(notifyCoordinator: v)) : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.sm),
                Text(l.checkinHowItWorks, style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                const SizedBox(height: Space.lg),
                if (canManage && patient != null)
                  PrimaryButton(
                    key: const Key('checkin-save'),
                    label: l.save,
                    loading: _saving,
                    onPressed: () => _save(patient.id),
                  ),
                SectionHeader(title: l.checkinLast30Days),
                AsyncView<List<CheckIn>>(
                  value: ref.watch(checkinHistoryProvider),
                  compact: true,
                  onRetry: () => ref.invalidate(checkinHistoryProvider),
                  isEmpty: (list) => list.isEmpty,
                  empty: EmptyStateView(compact: true, icon: Icons.event_available, title: l.checkinNoHistory),
                  data: (list) => CcCard(child: CheckinHistoryStrip(history: list)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
