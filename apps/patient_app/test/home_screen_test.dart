import 'package:care_companion_patient/core/api/api_client.dart';
import 'package:care_companion_patient/data/repositories.dart';
import 'package:care_companion_patient/features/home/home_screen.dart';
import 'package:care_companion_patient/models/care.dart';
import 'package:care_companion_patient/models/misc.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakeCarePlanRepository extends CarePlanRepository {
  FakeCarePlanRepository() : super(deadApiClient());
  @override
  Future<List<Reminder>> remindersToday(String patientId) async => [
        Reminder(
          id: 'r1',
          kind: 'medication',
          title: 'Metformin 500mg',
          subtitle: 'After breakfast',
          at: DateTime.now().add(const Duration(hours: 1)),
          status: 'pending',
          refId: 'm1',
        ),
      ];
}

class FakeEpisodeRepository extends EpisodeRepository {
  FakeEpisodeRepository() : super(deadApiClient());
  @override
  Future<List<CareEpisode>> list(String patientId, {bool? active, String? status}) async => [
        CareEpisode(
          id: 'e1',
          patientId: patientId,
          patientName: 'Vaibhav',
          title: 'Headache follow-up',
          concern: 'Headache for 2 days',
          status: 'CARE_SCHEDULED',
          priority: 'routine',
          ownerUserId: null,
          ownerName: null,
          nextAction: 'Video consultation tomorrow',
          createdAt: DateTime(2026, 9, 20),
          updatedAt: DateTime(2026, 9, 21),
        ),
      ];
}

class FakeSafetyRepository extends SafetyRepository {
  FakeSafetyRepository(this.insights) : super(deadApiClient());
  final List<Insight> insights;
  @override
  Future<List<Insight>> insightsToday(String patientId) async => insights;
}

class FakeNotificationRepository extends NotificationRepository {
  FakeNotificationRepository() : super(deadApiClient());
  @override
  Future<NotificationPage> list({String? cursor}) async => NotificationPage(const [], 2);
}

final sampleInsights = [
  Insight(
      type: 'heart_rate',
      label: 'Heart Rate',
      value: '78',
      unit: 'bpm',
      status: 'Normal',
      goal: null,
      source: 'device',
      measuredAt: null),
  Insight(
      type: 'steps',
      label: 'Steps',
      value: '5420',
      unit: '',
      status: null,
      goal: 10000,
      source: 'device',
      measuredAt: null),
];

Future<void> pumpHome(WidgetTester tester, List<Insight> insights) async {
  useTallPhone(tester);
  final overrides = await baseOverrides();
  await tester.pumpWidget(testApp(const HomeScreen(), overrides: [
    ...overrides,
    carePlanRepositoryProvider.overrideWithValue(FakeCarePlanRepository()),
    episodeRepositoryProvider.overrideWithValue(FakeEpisodeRepository()),
    safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository(insights)),
    notificationRepositoryProvider.overrideWithValue(FakeNotificationRepository()),
  ]));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('home renders greeting, AI hero, quick actions and data sections', (tester) async {
    await pumpHome(tester, sampleInsights);

    expect(find.textContaining('Vaibhav 👋'), findsOneWidget);
    expect(find.text('Your health, our priority.'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.text('Talk to a Doctor'), findsOneWidget);
    expect(find.text('Home Checkup'), findsOneWidget);
    expect(find.text('Upload Report'), findsOneWidget);
    expect(find.text('Order Medicines'), findsOneWidget);
    expect(find.text('Care for every stage of life'), findsOneWidget);
    expect(find.text('Quick Access'), findsOneWidget);
    expect(find.bySemanticsLabel('Emergency SOS'), findsOneWidget);
    // Govt schemes now defaults on (§38): no "Coming soon" badge on Home.
    expect(find.text('Coming soon'), findsNothing);
    // Reminders + active episodes from the fake repositories.
    expect(find.text('Metformin 500mg'), findsOneWidget);
    expect(find.text('Headache follow-up'), findsOneWidget);
    // Insights rendered because data exists.
    expect(find.byKey(const Key('insights-section')), findsOneWidget);
    expect(find.text('78 bpm'), findsOneWidget);
    // Unread dot is announced through semantics on the bell.
    expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
  });

  testWidgets('insights section is hidden when the API returns no data', (tester) async {
    await pumpHome(tester, const []);

    expect(find.text('Quick Access'), findsOneWidget);
    expect(find.byKey(const Key('insights-section')), findsNothing);
    expect(find.text("Today's Insights"), findsNothing);
  });

  test('idempotent action reuses the key until completed', () {
    final a = IdempotentAction();
    final k1 = a.key;
    expect(a.key, k1);
    a.complete();
    expect(a.key, isNot(k1));
  });
}
