import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

const moodFaces = ['😣', '🙁', '😐', '🙂', '😄'];

class WellnessScreen extends ConsumerStatefulWidget {
  const WellnessScreen({super.key});

  @override
  ConsumerState<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends ConsumerState<WellnessScreen> {
  int? _score;
  final _note = TextEditingController();
  bool _share = false;
  bool _saving = false;
  MoodCheckInResult? _result;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    final s = _score;
    if (s == null) return;
    setState(() => _saving = true);
    try {
      final p = await ref.read(activePatientProvider.future);
      final r = await ref.read(wellnessRepositoryProvider).checkIn(p.id, s,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(), shareWithClinician: _share);
      ref.invalidate(moodsProvider);
      if (mounted) {
        setState(() {
          _result = r;
          _score = null;
          _note.clear();
        });
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final moodLabels = [l.moodVeryLow, l.moodLow, l.moodOkay, l.moodGood, l.moodGreat];
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.qxMentalWellness)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          Container(
            padding: const EdgeInsets.all(Space.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              gradient: const LinearGradient(colors: [AppColors.mint100, Color(0xFFFFF8DD)]),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.wellnessHeroTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primaryDark)),
                      const SizedBox(height: 6),
                      Text(l.wellnessHeroSubtitle, style: TextStyle(color: context.textMuted)),
                    ],
                  ),
                ),
                const ExcludeSemantics(child: Icon(Icons.spa, size: 64, color: AppColors.primaryLight)),
              ],
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: Space.lg),
            if (r.safety.isEmergency || r.safety.isUrgent)
              _MoodSafetyCard(message: r.supportMessage, emergency: r.safety.isEmergency)
            else
              CcCard(
                color: context.lavenderSurface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.supportMessage),
                    const SizedBox(height: 6),
                    const AiGeneratedLabel(),
                  ],
                ),
              ),
          ],
          SectionHeader(title: l.howAreYouFeeling),
          CcCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Semantics(
                        button: true,
                        selected: _score == i + 1,
                        label: moodLabels[i],
                        excludeSemantics: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _score = i + 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _score == i + 1 ? AppColors.mint100 : Colors.transparent,
                              border: Border.all(
                                  color: _score == i + 1 ? context.brand : Colors.transparent, width: 2),
                            ),
                            child: Text(moodFaces[i], style: const TextStyle(fontSize: 30)),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_score != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(moodLabels[_score! - 1], style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: l.moodNoteOptional),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _share,
                    onChanged: (v) => setState(() => _share = v),
                    title: Text(l.shareWithClinician),
                  ),
                  PrimaryButton(label: l.saveCheckIn, loading: _saving, onPressed: _checkIn),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          ListRowTile(
            icon: Icons.person_outline,
            accent: Accent.lavender,
            title: l.talkToTherapist,
            subtitle: l.talkToTherapistSub,
            onTap: () => context.push('/doctors?specialty=psychiatrist'),
          ),
          ListRowTile(
            icon: Icons.chat_bubble_outline,
            accent: Accent.sky,
            title: l.aiMoodSupport,
            subtitle: l.aiMoodSupportSub,
            onTap: () => context.go('/ai'),
          ),
          SectionHeader(title: l.meditationExercises),
          AsyncView<List<WellnessActivity>>(
            value: ref.watch(wellnessActivitiesProvider),
            compact: true,
            onRetry: () => ref.invalidate(wellnessActivitiesProvider),
            isEmpty: (l) => l.isEmpty,
            empty: EmptyStateView(compact: true, title: l.noActivities),
            data: (list) => Column(
              children: [
                for (final a in list)
                  ListRowTile(
                    icon: switch (a.kind) {
                      'breathing' => Icons.air,
                      'meditation' => Icons.self_improvement,
                      'journaling' => Icons.edit_note,
                      'sleep' => Icons.bedtime_outlined,
                      _ => Icons.spa_outlined,
                    },
                    accent: Accent.peach,
                    title: a.title,
                    subtitle: '${a.description} · ${l.durationMins(a.durationMins)}',
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(a.title),
                        content: Text(a.description),
                        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l.close))],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(title: l.moodTracker),
          AsyncView<List<MoodEntry>>(
            value: ref.watch(moodsProvider),
            compact: true,
            onRetry: () => ref.invalidate(moodsProvider),
            isEmpty: (l) => l.isEmpty,
            empty: EmptyStateView(compact: true, icon: Icons.mood, title: l.noMoodHistory),
            data: (list) => CcCard(
              child: Column(
                children: [
                  SizedBox(
                    height: 64,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final m in list.take(14).toList().reversed)
                          Expanded(
                            child: Tooltip(
                              message: '${fmtDate(context, m.createdAt)}: ${moodLabels[(m.score - 1).clamp(0, 4)]}',
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                height: 10.0 + m.score * 10,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.35 + m.score * 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  for (final m in list.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(moodFaces[(m.score - 1).clamp(0, 4)], style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(m.note ?? moodLabels[(m.score - 1).clamp(0, 4)])),
                          Text(fmtDayMonth(context, m.createdAt),
                              style: TextStyle(fontSize: 12, color: context.textMuted)),
                        ],
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

class _MoodSafetyCard extends StatelessWidget {
  const _MoodSafetyCard({required this.message, required this.emergency});
  final String message;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      child: CcCard(
        color: context.roseSurface,
        borderColor: AppColors.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(l.youAreNotAlone,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger))),
              ],
            ),
            const SizedBox(height: 6),
            Text(message.isEmpty ? l.moodSupportFallback : message),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: AppConfig.emergencyHelpline)),
                    icon: const Icon(Icons.call),
                    label: Text(l.call108),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(emergency ? '/sos' : '/doctors?specialty=psychiatrist'),
                    child: Text(emergency ? l.sosButton : l.talkToTherapist),
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
