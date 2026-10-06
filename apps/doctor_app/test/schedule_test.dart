import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/features/more/schedule_screen.dart';
import 'package:care_companion_doctor/models/clinical.dart';
import 'package:care_companion_doctor/models/doctor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

WeeklyBlock b(int day, String s, String e, {int slot = 30, List<String> modes = const ['video']}) =>
    WeeklyBlock(weekday: day, start: s, end: e, slotMins: slot, modes: modes);

void main() {
  setUp(() => useGoogleFonts = false);

  test('overlapping blocks on the same day are flagged', () {
    final p = validateWeekly([b(1, '09:00', '13:00'), b(1, '12:30', '15:00')]);
    expect(p.single.issue, BlockIssue.overlap);
    expect(p.single.index, 1);
    expect(p.single.otherIndex, 0);
  });

  test('touching blocks and other days do not overlap', () {
    expect(validateWeekly([b(1, '09:00', '13:00'), b(1, '13:00', '17:00'), b(2, '09:00', '13:00')]), isEmpty);
  });

  test('a block inside another is an overlap', () {
    expect(validateWeekly([b(3, '09:00', '18:00'), b(3, '10:00', '11:00')]).single.issue, BlockIssue.overlap);
  });

  test('end before start, too short for a slot, no modes, invalid time', () {
    expect(validateWeekly([b(1, '13:00', '09:00')]).single.issue, BlockIssue.endBeforeStart);
    expect(validateWeekly([b(1, '09:00', '09:20', slot: 30)]).single.issue, BlockIssue.tooShortForSlot);
    expect(validateWeekly([b(1, '09:00', '10:00', modes: const [])]).single.issue, BlockIssue.noModes);
    expect(validateWeekly([b(1, '25:00', '26:00')]).single.issue, BlockIssue.invalidTime);
  });

  test('time helpers round-trip', () {
    expect(hhmmToMinutes('09:30'), 570);
    expect(minutesToHhmm(570), '09:30');
    expect(hhmmToMinutes('9:5'), -1);
  });

  testWidgets('weekly editor disables save and marks overlapping blocks', (tester) async {
    await tester.pumpWidget(
      testApp(WeeklyEditor(initial: [b(1, '09:00', '13:00'), b(1, '12:00', '14:00')]), scaffold: true),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Overlaps other hours'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.byKey(const Key('saveSchedule')));
    expect(save.onPressed, isNull);
    expect(find.text('Fix the highlighted hours'), findsOneWidget);
  });

  testWidgets('leave conflicts sheet lists the booked consultations', (tester) async {
    await tester.pumpWidget(testApp(LeaveConflictsSheet(conflicts: [Appointment.fromJson(queueItem())])));
    expect(find.text('1 booked consultations on this day'), findsOneWidget);
    expect(find.text('Ramesh Kumar'), findsOneWidget);
  });

  testWidgets('removing a leave asks for confirmation first (B29)', (tester) async {
    final be = mockBackend((req, path) {
      if (path == '/doctor/me/schedule') {
        return {
          'weekly': [],
          'leaves': [
            {'id': 'lv-1', 'date': '2026-10-14', 'reason': 'Conference'},
          ],
        };
      }
      if (path == '/doctor/me/leaves/lv-1' && req.method == 'DELETE') return {};
      return null;
    });
    bool deleted() => be.requests.any((r) => r.method == 'DELETE');
    await tester.pumpWidget(testApp(const ScheduleScreen(), overrides: commonOverrides(be.client), scaffold: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaves'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('leaveRemove.lv-1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this leave?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted(), isFalse);

    await tester.tap(find.byKey(const Key('leaveRemove.lv-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leaveRemoveConfirm')));
    await tester.pumpAndSettle();
    expect(deleted(), isTrue);
  });
}
