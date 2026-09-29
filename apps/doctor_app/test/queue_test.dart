import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<List> pumpToday(WidgetTester tester, Handler handler) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final b = mockBackend(handler);
    await tester.pumpWidget(testApp(const TodayScreen(), overrides: commonOverrides(b.client), scaffold: false));
    await tester.pumpAndSettle();
    return b.requests;
  }

  testWidgets('renders the queue with status and priority chips and summary counts', (tester) async {
    final requests = await pumpToday(
      tester,
      (req, path) => path == '/clinician/queue'
          ? {
              'items': [
                queueItem(id: 'a1', status: 'confirmed', priority: 'routine', patient: 'Ramesh Kumar'),
                queueItem(
                  id: 'a2',
                  status: 'in_progress',
                  priority: 'urgent',
                  patient: 'Lakshmi',
                  start: '2026-09-29T05:00:00.000Z',
                ),
                queueItem(
                  id: 'a3',
                  status: 'completed',
                  priority: 'emergency',
                  patient: 'Vaibhav',
                  start: '2026-09-29T06:00:00.000Z',
                ),
              ],
              'nextCursor': null,
            }
          : null,
    );
    expect(requests.single.url.queryParameters['date'], '2026-09-29');
    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('Lakshmi'), findsOneWidget);
    expect(find.byKey(const Key('apptStatus.confirmed')), findsOneWidget);
    expect(find.byKey(const Key('apptStatus.in_progress')), findsOneWidget);
    expect(find.byKey(const Key('apptStatus.completed')), findsOneWidget);
    expect(find.byKey(const Key('priority.urgent')), findsOneWidget);
    expect(find.byKey(const Key('priority.emergency')), findsOneWidget);
    expect(find.text('68 y · Male'), findsNWidgets(3));
    expect(find.text('Care scheduled'), findsNWidgets(3));
    // Summary: 1 waiting, 1 in progress, 1 done.
    expect(find.bySemanticsLabel('Waiting: 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Done: 1'), findsOneWidget);
  });

  testWidgets('empty day shows the empty state; choosing another day refetches', (tester) async {
    final requests = await pumpToday(tester, (req, path) => {'items': [], 'nextCursor': null});
    expect(find.text('No consultations on this day.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('day.2026-09-30')));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['date'], '2026-09-30');
  });

  testWidgets('offline error shows a retry', (tester) async {
    await pumpToday(tester, (req, path) => throw Exception('socket'));
    expect(find.text("Can't reach CareCompanion. Check your connection."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('unauthorized (403) shows the no-access state without retry', (tester) async {
    await pumpToday(tester, (req, path) => errorResponse(403, 'FORBIDDEN', 'nope'));
    expect(find.text("You don't have access to this."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
