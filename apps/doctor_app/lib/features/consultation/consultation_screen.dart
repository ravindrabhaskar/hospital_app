import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/clinical.dart';
import '../../models/json.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import '../patients/patient_providers.dart';
import '../patients/snapshot_view.dart';
import '../today/today_screen.dart';
import 'care_plan_screen.dart';
import 'prescription_writer.dart';
import 'quick_forms.dart';
import 'scribe_screen.dart';

const outcomes = ['care_plan', 'resolved', 'refer', 'home_visit'];

/// Consultation workspace: snapshot, start/complete, notes, AI scribe,
/// prescription, care plan, referral, programs, exercise/diet, video.
class ConsultationScreen extends ConsumerStatefulWidget {
  const ConsultationScreen({super.key, required this.appointmentId, this.initial});
  final String appointmentId;
  final Appointment? initial;

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final _notes = TextEditingController();
  Appointment? _override;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _refreshQueue() => ref.invalidate(queueProvider);

  Future<void> _start(Appointment a) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(clinicianRepositoryProvider).start(a.id);
      setState(() => _override = updated);
      _refreshQueue();
      if (mounted) showSnack(context, l.consultStarted);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(Appointment a) async {
    final l = context.l10n;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => CompleteDialog(initialNotes: _notes.text),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(clinicianRepositoryProvider).complete(a.id, notes: result.$1, outcome: result.$2);
      setState(() => _override = updated);
      _refreshQueue();
      if (mounted) showSnack(context, l.consultCompleted);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEpisodeNote(Appointment a) async {
    final l = context.l10n;
    final text = _notes.text.trim();
    if (text.isEmpty || a.careEpisodeId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(clinicianRepositoryProvider).addEpisodeNote(a.careEpisodeId!, text);
      if (mounted) showSnack(context, l.noteSaved);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _push<T>(Widget page) =>
      Navigator.of(context, rootNavigator: true).push<T>(MaterialPageRoute(builder: (_) => page));

  Future<void> _openScribe(Appointment a) async {
    final text = await _push<String>(ScribeScreen(appointmentId: a.id));
    if (text == null || text.isEmpty || !mounted) return;
    final current = _notes.text.trimRight();
    _notes.text = current.isEmpty ? text : '$current\n\n$text';
    showSnack(context, context.l10n.scribeInserted);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fetched = ref.watch(appointmentProvider(widget.appointmentId));
    final appt = _override ?? fetched.value ?? widget.initial;
    if (appt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.consultTitle)),
        body: fetched.hasError
            ? ErrorView(error: fetched.error!, onRetry: () => ref.invalidate(appointmentProvider(widget.appointmentId)))
            : const LoadingView(),
      );
    }
    final snap = ref.watch(snapshotProvider(appt.patientId));
    return Scaffold(
      appBar: AppBar(
        title: Text(appt.patientName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l.openPatient,
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () => context.push('/patients/${appt.patientId}'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(appointmentProvider(widget.appointmentId));
            ref.invalidate(snapshotProvider(appt.patientId));
            await ref.read(snapshotProvider(appt.patientId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              _Header(appointment: appt),
              gap12,
              _Actions(appointment: appt, busy: _busy, onStart: () => _start(appt), onComplete: () => _complete(appt)),
              gap16,
              AsyncBody(
                value: snap,
                onRetry: () => ref.invalidate(snapshotProvider(appt.patientId)),
                data: (s) => SnapshotSummary(snapshot: s),
              ),
              gap16,
              SectionCard(
                title: l.notesTitle,
                icon: Icons.edit_note,
                trailing: TextButton.icon(
                  key: const Key('openScribe'),
                  onPressed: () => _openScribe(appt),
                  icon: const Icon(Icons.auto_awesome, color: AppColors.lavender),
                  label: Text(l.scribeTitle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('notesField'),
                      controller: _notes,
                      minLines: 5,
                      maxLines: 14,
                      decoration: InputDecoration(hintText: l.notesHint),
                    ),
                    gap8,
                    Text(l.notesSaveHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (appt.careEpisodeId != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : () => _saveEpisodeNote(appt),
                          child: Text(l.saveEpisodeNote),
                        ),
                      ),
                  ],
                ),
              ),
              gap16,
              _Tools(
                appointment: appt,
                onPrescribe: () async {
                  final ok = await _push<bool>(PrescriptionWriter(appointment: appt));
                  if (ok == true) {
                    ref.invalidate(prescriptionsProvider(appt.patientId));
                    ref.invalidate(snapshotProvider(appt.patientId));
                  }
                },
                onCarePlan: appt.careEpisodeId == null
                    ? null
                    : () => _push<bool>(CarePlanScreen(careEpisodeId: appt.careEpisodeId!)),
                onRefer: appt.careEpisodeId == null
                    ? null
                    : () => _push<bool>(ReferralScreen(careEpisodeId: appt.careEpisodeId!)),
                onEnrol: () =>
                    _push<bool>(EnrollProgramScreen(patientId: appt.patientId, careEpisodeId: appt.careEpisodeId)),
                onExercise: () =>
                    _push<bool>(ExercisePlanScreen(patientId: appt.patientId, careEpisodeId: appt.careEpisodeId)),
                onDiet: () => _push<bool>(DietPlanScreen(patientId: appt.patientId)),
                onMessages: appt.careEpisodeId == null
                    ? null
                    : () => context.push('/messages/${appt.careEpisodeId}', extra: appt.patientName),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = appointment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(modeIcon(a.mode), color: AppColors.primaryLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${formatDateTime(context, a.startAt)} · ${modeLabel(l, a.mode)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ApptStatusChip(status: a.status),
              ],
            ),
            gap8,
            Text(ageGender(l, a.patientAge, a.patientGender), style: const TextStyle(color: AppColors.textSecondary)),
            if (a.reason.isNotEmpty) ...[gap8, LabeledValue(label: l.reasonLabel, value: a.reason)],
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
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.appointment, required this.busy, required this.onStart, required this.onComplete});
  final Appointment appointment;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = appointment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a.isVideoOrAudio && !a.isCompleted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              key: const Key('joinVideo'),
              onPressed: () => showVideoSheet(context, a),
              icon: Icon(a.mode == 'audio' ? Icons.call : Icons.videocam),
              label: Text(l.joinVideo),
            ),
          ),
        if (a.canStart)
          FilledButton.icon(
            key: const Key('startConsult'),
            onPressed: busy ? null : onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.startConsult),
          ),
        if (a.isInProgress)
          FilledButton.icon(
            key: const Key('completeConsult'),
            onPressed: busy ? null : onComplete,
            icon: const Icon(Icons.check),
            label: Text(l.completeConsult),
          ),
        if (a.isCompleted && a.clinicianNotes != null) ...[
          SectionCard(title: l.savedNotes, child: Text(a.clinicianNotes!)),
        ],
      ],
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.appointment,
    required this.onPrescribe,
    required this.onCarePlan,
    required this.onRefer,
    required this.onEnrol,
    required this.onExercise,
    required this.onDiet,
    required this.onMessages,
  });

  final Appointment appointment;
  final VoidCallback onPrescribe;
  final VoidCallback? onCarePlan;
  final VoidCallback? onRefer;
  final VoidCallback onEnrol;
  final VoidCallback onExercise;
  final VoidCallback onDiet;
  final VoidCallback? onMessages;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canRx = appointment.canPrescribe;
    Widget tool(String key, IconData icon, String label, VoidCallback? onTap, Color bg, Color fg, {String? hint}) =>
        ListTile(
          key: Key('tool.$key'),
          minVerticalPadding: 12,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: fg),
          ),
          title: Text(label),
          subtitle: hint == null ? null : Text(hint, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          enabled: onTap != null,
          onTap: onTap,
        );
    return SectionCard(
      title: l.toolsTitle,
      child: Column(
        children: [
          tool(
            'rx',
            Icons.receipt_long_outlined,
            l.rxTitle,
            canRx ? onPrescribe : null,
            AppColors.mint100,
            AppColors.primary,
            hint: canRx ? null : l.rxNeedsStart,
          ),
          tool('carePlan', Icons.checklist, l.carePlanTitle, onCarePlan, AppColors.skyBg, AppColors.sky),
          tool('refer', Icons.local_hospital_outlined, l.referTitle, onRefer, AppColors.dangerBg, AppColors.dangerDeep),
          tool('enrol', Icons.monitor_heart_outlined, l.enrolTitle, onEnrol, AppColors.lavenderBg, AppColors.lavender),
          tool('exercise', Icons.directions_run, l.exerciseTitle, onExercise, AppColors.warningBg, warningFg),
          tool('diet', Icons.restaurant_outlined, l.dietTitle, onDiet, AppColors.mint50, AppColors.primaryLight),
          tool('messages', Icons.forum_outlined, l.careTeamThread, onMessages, AppColors.skyBg, AppColors.sky),
        ],
      ),
    );
  }
}

/// Notes + outcome for `POST /clinician/appointments/:id/complete`.
class CompleteDialog extends StatefulWidget {
  const CompleteDialog({super.key, this.initialNotes = ''});
  final String initialNotes;

  @override
  State<CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<CompleteDialog> {
  late final _notes = TextEditingController(text: widget.initialNotes);
  String _outcome = 'care_plan';

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.completeConsult),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('completeNotes'),
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l.notesTitle),
            ),
            gap12,
            DropdownButtonFormField<String>(
              initialValue: _outcome,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.outcomeLabel),
              items: [for (final o in outcomes) DropdownMenuItem(value: o, child: Text(outcomeLabel(l, o)))],
              onChanged: (v) => setState(() => _outcome = v ?? 'care_plan'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonCancel)),
        FilledButton(
          key: const Key('completeConfirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
          onPressed: _notes.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop((_notes.text.trim(), _outcome)),
          child: Text(l.commonConfirm),
        ),
      ],
    );
  }
}

/// Video-session window (contract §26): opens 10 min before start, closes
/// 60 min after end; the room opens outside the app via url_launcher.
Future<void> showVideoSheet(BuildContext context, Appointment a) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (_) => VideoSessionSheet(appointment: a),
);

class VideoSessionSheet extends ConsumerStatefulWidget {
  const VideoSessionSheet({super.key, required this.appointment});
  final Appointment appointment;

  @override
  ConsumerState<VideoSessionSheet> createState() => _VideoSessionSheetState();
}

class _VideoSessionSheetState extends ConsumerState<VideoSessionSheet> {
  late Future<VideoSession> _future = _load();

  Future<VideoSession> _load() => ref.read(clinicianRepositoryProvider).videoSession(widget.appointment.id);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: FutureBuilder<VideoSession>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 160, child: LoadingView());
          final e = snap.error;
          if (e != null) {
            final opensAt = e is ApiException && e.isConflict ? dateOrNull(e.details['opensAt']) : null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.schedule, size: 40, color: AppColors.textSecondary),
                gap12,
                Text(
                  opensAt != null ? l.videoOpensAt(formatDateTime(context, opensAt)) : errorMessage(l, e),
                  key: const Key('videoNotOpen'),
                  textAlign: TextAlign.center,
                ),
                gap12,
                OutlinedButton(onPressed: () => setState(() => _future = _load()), child: Text(l.commonRetry)),
              ],
            );
          }
          final s = snap.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.videoTitle, style: Theme.of(context).textTheme.titleLarge),
              gap8,
              LabeledValue(
                label: l.videoWindow,
                value: '${formatDateTime(context, s.opensAt)} – ${formatDateTime(context, s.expiresAt)}',
              ),
              if (widget.appointment.mode == 'audio') Text(l.videoAudioHint),
              gap12,
              FilledButton.icon(
                key: const Key('videoJoinNow'),
                onPressed: s.joinUrl.isEmpty ? null : () => openExternal(context, Uri.parse(s.joinUrl)),
                icon: const Icon(Icons.open_in_new),
                label: Text(l.joinVideo),
              ),
            ],
          );
        },
      ),
    );
  }
}
