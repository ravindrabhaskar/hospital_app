import 'package:care_companion_doctor/core/push/push_service.dart';
import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/features/patients/snapshot_view.dart';
import 'package:care_companion_doctor/models/clinical.dart';
import 'package:care_companion_doctor/models/public_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(() => useGoogleFonts = false);

  test('push deep links map to in-app routes', () {
    expect(PushService.routeForDeepLink('/appointments/abc-1'), '/consultation/abc-1');
    expect(PushService.routeForDeepLink('/care-episodes/ep-9/messages'), '/messages/ep-9');
    expect(PushService.routeForDeepLink('/clinician/second-opinions/x'), '/more/second-opinions');
    expect(PushService.routeForDeepLink(null), isNull);
    expect(PushService.routeForDeepLink('/unknown'), isNull);
  });

  test('version comparison for force update', () {
    expect(isVersionBelow('1.0.0', '1.0.1'), isTrue);
    expect(isVersionBelow('1.10.0', '1.9.9'), isFalse);
    expect(isVersionBelow('1.0.0+5', '1.0.0'), isFalse);
  });

  test('public config reads doctor minimum versions', () {
    final c = PublicConfig.fromJson({
      'minAppVersion': {'doctorAndroid': '1.2.0', 'doctorIos': '1.3.0', 'providerAndroid': '9.9.9'},
    });
    expect(c.minDoctorAndroid, '1.2.0');
    expect(c.minDoctorIos, '1.3.0');
  });

  test('snapshot parsing keeps the latest vital per type', () {
    final s = ClinicalSnapshot.fromJson({
      ...snapshotJson(),
      'recentVitals': [
        {'id': 'a', 'type': 'pulse', 'value': 70, 'unit': 'bpm', 'measuredAt': '2026-09-27T08:00:00.000Z'},
        {'id': 'b', 'type': 'pulse', 'value': 88, 'unit': 'bpm', 'measuredAt': '2026-09-28T08:00:00.000Z'},
      ],
    });
    expect(s.latestVitals.single.value, 88);
    expect(s.aiSummary!.claims.single.sources.single.label, 'BP 150/95');
  });

  testWidgets('snapshot: allergies in red, AI summary in the lavender advisory card with source chips', (tester) async {
    final s = ClinicalSnapshot.fromJson(snapshotJson());
    await tester.pumpWidget(testApp(SingleChildScrollView(child: SnapshotSummary(snapshot: s))));
    final banner = tester.widget<Container>(find.byKey(const Key('allergyBanner')));
    expect((banner.decoration as BoxDecoration).color, AppColors.dangerBg);
    expect(find.textContaining('Penicillin'), findsOneWidget);
    expect(find.byKey(const Key('aiAdvisoryCard')), findsOneWidget);
    expect(find.text('AI-generated · advisory, not a diagnosis'), findsOneWidget);
    expect(find.byKey(const Key('aiSourceChip')), findsOneWidget);
    final card = tester.widget<Container>(find.byKey(const Key('aiAdvisoryCard')));
    expect((card.decoration as BoxDecoration).color, AppColors.lavenderBg);
    expect(find.text('Amlodipine 5mg'), findsOneWidget);
  });

  testWidgets('no allergies shows a neutral banner', (tester) async {
    final j = snapshotJson();
    (j['patient'] as Map)['allergies'] = [];
    await tester.pumpWidget(
      testApp(SingleChildScrollView(child: SnapshotSummary(snapshot: ClinicalSnapshot.fromJson(j)))),
    );
    expect(find.text('No known allergies recorded'), findsOneWidget);
  });

  testWidgets('interactive targets meet 48dp on the snapshot', (tester) async {
    final s = ClinicalSnapshot.fromJson(snapshotJson());
    await tester.pumpWidget(testApp(SingleChildScrollView(child: SnapshotSummary(snapshot: s))));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}
