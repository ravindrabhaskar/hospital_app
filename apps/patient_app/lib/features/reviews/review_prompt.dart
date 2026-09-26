import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/engagement.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

/// Pending-review targets the user dismissed ("Not now"), remembered locally
/// so the prompt does not nag.
class ReviewDismissals extends Notifier<Set<String>> {
  static const key = 'cc_review_dismissed';

  @override
  Set<String> build() {
    try {
      return (ref.read(sharedPrefsProvider).getStringList(key) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> dismiss(String targetId) async {
    state = {...state, targetId};
    try {
      // Keep the list bounded.
      final list = state.toList();
      await ref.read(sharedPrefsProvider).setStringList(key, list.length > 200 ? list.sublist(list.length - 200) : list);
    } catch (_) {}
  }
}

final reviewDismissalsProvider = NotifierProvider<ReviewDismissals, Set<String>>(ReviewDismissals.new);

/// The next pending review worth prompting for, or null.
final nextReviewPromptProvider = Provider<PendingReview?>((ref) {
  final patient = ref.watch(activePatientProvider).value;
  if (patient != null && !patient.can(FamilyPermission.manageCare)) return null;
  final pending = ref.watch(pendingReviewsProvider).value ?? const <PendingReview>[];
  final dismissed = ref.watch(reviewDismissalsProvider);
  for (final p in pending) {
    if (!dismissed.contains(p.targetId)) return p;
  }
  return null;
});

/// Shows the review bottom sheet once per app session when Home has a
/// completed visit or consultation waiting for a rating.
class ReviewPromptHost extends ConsumerStatefulWidget {
  const ReviewPromptHost({super.key});

  @override
  ConsumerState<ReviewPromptHost> createState() => _ReviewPromptHostState();
}

class _ReviewPromptHostState extends ConsumerState<ReviewPromptHost> {
  static final _shownThisSession = <String>{};
  bool _open = false;

  void _maybeShow(PendingReview? next) {
    if (next == null || _open || _shownThisSession.contains(next.targetId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _open) return;
      _open = true;
      _shownThisSession.add(next.targetId);
      await showReviewSheet(context, next);
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PendingReview?>(nextReviewPromptProvider, (_, next) => _maybeShow(next));
    _maybeShow(ref.read(nextReviewPromptProvider));
    return const SizedBox.shrink();
  }
}

Future<void> showReviewSheet(BuildContext context, PendingReview target) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReviewSheet(target: target),
    );

class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({super.key, required this.target});
  final PendingReview target;

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  int _rating = 0;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(reviewRepositoryProvider).submit(
            targetType: widget.target.targetType,
            targetId: widget.target.targetId,
            rating: _rating,
            text: _text.text,
          );
      ref.invalidate(pendingReviewsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(content: Text(r.published ? l.reviewThanksPublished : l.reviewThanksPending)));
    } on ApiException catch (e) {
      if (e.isConflict) {
        // Already reviewed (e.g. on another device): nothing left to do.
        ref.invalidate(pendingReviewsProvider);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notNow() async {
    await ref.read(reviewDismissalsProvider.notifier).dismiss(widget.target.targetId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = widget.target;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.reviewPromptTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                [t.title, ?t.subtitle, if (t.completedAt != null) fmtDate(context, t.completedAt!)].join(' · '),
                style: TextStyle(color: context.textMuted),
              ),
              const SizedBox(height: Space.lg),
              Semantics(
                label: l.yourRating,
                value: _rating == 0 ? l.notRatedYet : l.ratingOutOfFive(_rating),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var s = 1; s <= 5; s++)
                      IconButton(
                        key: Key('star-$s'),
                        tooltip: l.rateStars(s),
                        iconSize: 36,
                        onPressed: _busy ? null : () => setState(() => _rating = s),
                        icon: Icon(s <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: s <= _rating ? AppColors.warning : context.textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              TextField(
                key: const Key('review-text'),
                controller: _text,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(labelText: l.reviewCommentOptional, hintText: l.reviewCommentHint),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: context.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l.reviewModerationInfo, style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: Space.lg),
              PrimaryButton(
                key: const Key('review-submit'),
                label: l.submitReview,
                loading: _busy,
                onPressed: _rating == 0 ? null : _submit,
              ),
              const SizedBox(height: Space.xs),
              TextButton(
                key: const Key('review-dismiss'),
                onPressed: _busy ? null : _notNow,
                child: Text(l.notNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
