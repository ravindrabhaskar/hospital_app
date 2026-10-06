import 'package:care_companion_provider/features/visits/domain/visit_lifecycle.dart';
import 'package:care_companion_provider/features/visits/ui/lifecycle_panel.dart';
import 'package:care_companion_provider/features/visits/ui/visit_detail_screen.dart';
import 'package:care_companion_provider/models/home_visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('VisitLifecycle.nextActionFor', () {
    const expected = {
      VisitStatus.requested: NextAction.awaitingAssignment,
      VisitStatus.assigned: NextAction.acceptOrReject,
      VisitStatus.accepted: NextAction.startTravel,
      VisitStatus.enRoute: NextAction.markArrived,
      VisitStatus.arrived: NextAction.verifyPatient,
      VisitStatus.inProgress: NextAction.recordCare,
      VisitStatus.escalated: NextAction.completeEscalated,
      VisitStatus.completed: NextAction.done,
      VisitStatus.cancelled: NextAction.cancelled,
      VisitStatus.unassigned: NextAction.reassigned,
    };
    expected.forEach((status, action) {
      test('$status -> $action', () => expect(VisitLifecycle.nextActionFor(status), action));
    });

    test('escalate only while in progress; care recording in progress or escalated', () {
      expect(VisitLifecycle.canEscalate(VisitStatus.inProgress), isTrue);
      expect(VisitLifecycle.canEscalate(VisitStatus.arrived), isFalse);
      expect(VisitLifecycle.canRecordCare(VisitStatus.escalated), isTrue);
      expect(VisitLifecycle.canRecordCare(VisitStatus.arrived), isFalse);
    });

    test('full address only after acceptance', () {
      expect(VisitLifecycle.showFullAddress(VisitStatus.assigned), isFalse);
      expect(VisitLifecycle.showFullAddress(VisitStatus.accepted), isTrue);
    });

    test('optimistic transitions follow the contract state machine', () {
      var v = visit(status: VisitStatus.assigned);
      final at = DateTime.utc(2026, 9, 26, 9);
      for (final (type, next) in [
        (VisitActionType.accept, VisitStatus.accepted),
        (VisitActionType.enRoute, VisitStatus.enRoute),
        (VisitActionType.arrived, VisitStatus.arrived),
        (VisitActionType.verifyIdentity, VisitStatus.inProgress),
        (VisitActionType.escalate, VisitStatus.escalated),
        (VisitActionType.complete, VisitStatus.completed),
      ]) {
        v = VisitLifecycle.applyOptimistic(v, type, {'etaMinutes': 12, 'reason': 'r', 'severity': 'urgent', 'summary': 's'}, at);
        expect(v.status, next);
        expect(v.pendingSync, isTrue);
      }
      expect(v.timeline.last.status, VisitStatus.completed);
      expect(v.escalation!.severity, 'urgent');
    });
  });

  group('NextActionPanel shows the correct next action for each status', () {
    const actionKeys = [
      'action.accept',
      'action.reject',
      'action.startTravel',
      'action.navigate',
      'action.arrived',
      'action.verify',
      'action.complete',
    ];
    const expectations = <String, Set<String>>{
      VisitStatus.assigned: {'action.accept', 'action.reject'},
      VisitStatus.accepted: {'action.startTravel', 'action.navigate'},
      VisitStatus.enRoute: {'action.navigate', 'action.arrived'},
      VisitStatus.arrived: {'action.verify'},
      VisitStatus.inProgress: {'action.complete'},
      VisitStatus.escalated: {'action.complete'},
      VisitStatus.completed: {},
      VisitStatus.cancelled: {},
      VisitStatus.unassigned: {},
      VisitStatus.requested: {},
    };

    expectations.forEach((status, keys) {
      testWidgets(status, (tester) async {
        await tester.pumpWidget(testApp(NextActionPanel(
          visit: visit(status: status),
          onAction: (_, _) async {},
          onNavigate: () {},
        )));
        for (final k in actionKeys) {
          expect(find.byKey(Key(k)), keys.contains(k) ? findsOneWidget : findsNothing, reason: '$status / $k');
        }
        if (keys.isEmpty) expect(find.byKey(const Key('nextInfo')), findsOneWidget);
      });
    });

    testWidgets('verify requires a 4-digit code and explicit consent', (tester) async {
      final calls = <(VisitActionType, Map<String, dynamic>)>[];
      await tester.pumpWidget(testApp(NextActionPanel(
        visit: visit(status: VisitStatus.arrived),
        onAction: (t, b) async => calls.add((t, b)),
        onNavigate: () {},
      )));

      await tester.enterText(find.byKey(const Key('visitCodeField')), '4821');
      await tester.tap(find.byKey(const Key('action.verify')));
      await tester.pump();
      expect(calls, isEmpty, reason: 'consent not confirmed');
      expect(find.text('Consent must be confirmed before starting'), findsOneWidget);

      await tester.tap(find.byKey(const Key('consentCheckbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('action.verify')));
      await tester.pump();
      expect(calls.single.$1, VisitActionType.verifyIdentity);
      expect(calls.single.$2, {'visitCode': '4821', 'consentConfirmed': true});
    });

    testWidgets('B29: a rejected visit code (panel rebuilt) keeps the consent tick', (tester) async {
      var consent = false;
      Widget panel(String key) => testApp(StatefulBuilder(
            builder: (context, setState) => NextActionPanel(
              key: ValueKey(key),
              visit: visit(status: VisitStatus.arrived),
              consent: consent,
              onConsentChanged: (v) => setState(() => consent = v),
              onAction: (_, _) async {},
              onNavigate: () {},
            ),
          ));
      await tester.pumpWidget(panel('panel-arrived'));
      await tester.tap(find.byKey(const Key('consentCheckbox')));
      await tester.pump();
      expect(consent, isTrue);

      // Optimistic in_progress then rollback: the keyed panel is recreated.
      await tester.pumpWidget(panel('panel-in_progress'));
      await tester.pumpWidget(panel('panel-arrived'));
      final box = tester.widget<CheckboxListTile>(find.byKey(const Key('consentCheckbox')));
      expect(box.value, isTrue);
    });

    testWidgets('start travel sends etaMinutes', (tester) async {
      final calls = <(VisitActionType, Map<String, dynamic>)>[];
      await tester.pumpWidget(testApp(NextActionPanel(
        visit: visit(status: VisitStatus.accepted),
        onAction: (t, b) async => calls.add((t, b)),
        onNavigate: () {},
      )));
      await tester.enterText(find.byKey(const Key('etaField')), '25');
      await tester.tap(find.byKey(const Key('action.startTravel')));
      await tester.pump();
      expect(calls.single.$1, VisitActionType.enRoute);
      expect(calls.single.$2, {'etaMinutes': 25});
    });

    testWidgets('stepper exposes progress to screen readers', (tester) async {
      await tester.pumpWidget(testApp(const VisitStepper(status: VisitStatus.arrived)));
      expect(find.bySemanticsLabel('Visit progress: step 4 of 6'), findsOneWidget);
    });
  });

  testWidgets('allergies from patientContext are highlighted', (tester) async {
    await tester.pumpWidget(testApp(PatientContextCard(visit: visit(status: VisitStatus.inProgress))));
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Hypertension'), findsOneWidget);
    expect(find.text('Metformin 500mg'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Penicillin'));
    expect(text.style!.fontWeight, FontWeight.w700);
  });
}
