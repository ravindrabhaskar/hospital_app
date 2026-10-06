import 'package:care_companion_patient/data/repositories.dart';
import 'package:care_companion_patient/features/reviews/review_prompt.dart';
import 'package:care_companion_patient/models/engagement.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeReviewRepository extends ReviewRepository {
  FakeReviewRepository(this.pendingItems, {this.status = 'published'}) : super(deadApiClient());
  final List<PendingReview> pendingItems;
  final String status;
  final submitted = <Map<String, Object?>>[];

  @override
  Future<List<PendingReview>> pending(String patientId) async =>
      pendingItems.where((p) => !submitted.any((s) => s['targetId'] == p.targetId)).toList();

  @override
  Future<SubmittedReview> submit({
    required String targetType,
    required String targetId,
    required int rating,
    String? text,
  }) async {
    submitted.add({'targetType': targetType, 'targetId': targetId, 'rating': rating, 'text': text});
    return SubmittedReview(
        id: 'rv1', status: text == null || text.isEmpty ? 'published' : status, rating: rating, text: text);
  }
}

PendingReview pending(String id) => PendingReview(
      targetType: 'appointment',
      targetId: id,
      title: 'Consultation with Dr. Ananya Rao',
      subtitle: 'Video',
      completedAt: DateTime(2026, 9, 24),
    );

Future<(FakeReviewRepository, ProviderContainer)> pumpPrompt(WidgetTester tester, String id,
    {String status = 'published'}) async {
  useTallPhone(tester);
  final repo = FakeReviewRepository([pending(id)], status: status);
  final overrides = await baseOverrides();
  late ProviderContainer container;
  await tester.pumpWidget(testApp(
    Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const Scaffold(body: ReviewPromptHost());
    }),
    overrides: [...overrides, reviewRepositoryProvider.overrideWithValue(repo)],
  ));
  await tester.pumpAndSettle();
  return (repo, container);
}

void main() {
  testWidgets('prompt appears for a pending review and submits a rating-only review', (tester) async {
    final (repo, _) = await pumpPrompt(tester, 'appt-submit');

    expect(find.text('How was your care?'), findsOneWidget);
    expect(find.textContaining('Consultation with Dr. Ananya Rao'), findsOneWidget);
    expect(find.textContaining('A rating on its own is published right away'), findsOneWidget);

    // Submit is disabled until a star is chosen.
    final submit = find.byKey(const Key('review-submit'));
    expect(tester.widget<FilledButton>(find.descendant(of: submit, matching: find.byType(FilledButton))).onPressed,
        isNull);

    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repo.submitted.single, {'targetType': 'appointment', 'targetId': 'appt-submit', 'rating': 4, 'text': ''});
    expect(find.text('How was your care?'), findsNothing);
    expect(find.text('Thank you! Your rating is published.'), findsOneWidget);
  });

  testWidgets('a review with a comment is sent for moderation', (tester) async {
    final (repo, _) = await pumpPrompt(tester, 'appt-comment', status: 'pending');
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.enterText(find.byKey(const Key('review-text')), 'Very caring doctor');
    await tester.tap(find.byKey(const Key('review-submit')));
    await tester.pumpAndSettle();
    expect(repo.submitted.single['text'], 'Very caring doctor');
    expect(find.text('Thank you! Your review will appear after a quick check.'), findsOneWidget);
  });

  testWidgets('"Not now" dismisses the prompt and remembers it locally', (tester) async {
    final (repo, container) = await pumpPrompt(tester, 'appt-dismiss');
    await tester.tap(find.byKey(const Key('review-dismiss')));
    await tester.pumpAndSettle();

    expect(find.text('How was your care?'), findsNothing);
    expect(repo.submitted, isEmpty);
    expect(container.read(reviewDismissalsProvider), contains('appt-dismiss'));
    expect(container.read(sharedPrefsProvider).getStringList(ReviewDismissals.key), contains('appt-dismiss'));
    expect(container.read(nextReviewPromptProvider), isNull);
  });

  testWidgets('closing the sheet persists like "Not now" and snoozes other pending reviews (B15)',
      (tester) async {
    useTallPhone(tester);
    final repo = FakeReviewRepository([pending('visit-1'), pending('visit-2')]);
    final overrides = await baseOverrides();
    late ProviderContainer container;
    await tester.pumpWidget(testApp(
      Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return const Scaffold(body: ReviewPromptHost());
      }),
      overrides: [...overrides, reviewRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('How was your care?'), findsOneWidget);

    // Dismiss by tapping outside the sheet (no "Not now").
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('How was your care?'), findsNothing);
    expect(container.read(reviewDismissalsProvider), contains('visit-1'));
    final prefs = container.read(sharedPrefsProvider);
    expect(prefs.getInt(ReviewSnooze.key), isNotNull, reason: 'snooze survives a reload');
    // visit-2 is still pending, but the prompt is snoozed.
    expect(container.read(nextReviewPromptProvider), isNull);
    expect(container.read(reviewSnoozeProvider.notifier).isSnoozed(DateTime.now().add(const Duration(days: 4))),
        isFalse);
  });
}
