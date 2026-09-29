import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/features/messages/thread_screen.dart';
import 'package:care_companion_doctor/models/messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Map<String, dynamic> msg(String id, {String kind = 'text', String role = 'patient', String text = 'Hello doctor'}) => {
  'id': id,
  'careEpisodeId': 'ep-1',
  'senderUserId': role == 'system' ? null : 'u-$role',
  'senderName': role == 'system' ? 'CareCompanion' : 'Ramesh',
  'senderRole': role,
  'kind': kind,
  'text': text,
  'attachmentRecordId': null,
  'createdAt': '2026-09-29T05:00:00.000Z',
};

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('emergency_notice renders as a red safety notice', (tester) async {
    final m = ChatMessage.fromJson(msg('m1', kind: 'emergency_notice', role: 'system', text: 'Call 108 now.'));
    await tester.pumpWidget(testApp(MessageBubble(message: m, mine: false)));
    final box = find.byKey(const Key('emergency.m1'));
    expect(box, findsOneWidget);
    final deco = tester.widget<Container>(box).decoration as BoxDecoration;
    expect(deco.color, AppColors.dangerBg);
    expect(find.text('Emergency safety notice'), findsOneWidget);
    expect(find.text('Call 108 now.'), findsOneWidget);
  });

  testWidgets('ordinary messages are not styled as emergencies', (tester) async {
    await tester.pumpWidget(testApp(MessageBubble(message: ChatMessage.fromJson(msg('m2')), mine: false)));
    expect(find.byKey(const Key('message.m2')), findsOneWidget);
    expect(find.text('Emergency safety notice'), findsNothing);
  });

  test('mergeMessages drops duplicates from overlapping polls', () {
    final a = ChatMessage.fromJson(msg('1'));
    final b = ChatMessage.fromJson(msg('2'));
    final c = ChatMessage.fromJson(msg('3'));
    expect(mergeMessages([a, b], [b, c]).map((m) => m.id), ['1', '2', '3']);
  });

  testWidgets('thread loads, marks read, polls with ?after= every 10 s and sends', (tester) async {
    var polled = false;
    final b = mockBackend((req, path) {
      if (path == '/care-episodes/ep-1/messages' && req.method == 'GET') {
        final after = req.url.queryParameters['after'];
        if (after == null) {
          return {
            'items': [msg('1'), msg('2', kind: 'emergency_notice', role: 'system', text: 'Call 108.')],
          };
        }
        polled = true;
        return {
          'items': after == '2' ? [msg('3', text: 'Feeling dizzy')] : [],
        };
      }
      if (path == '/care-episodes/ep-1/messages' && req.method == 'POST') {
        return msg('4', role: 'doctor', text: 'Please check BP');
      }
      if (path == '/care-episodes/ep-1/messages/read') return {};
      return null;
    });
    await tester.pumpWidget(
      testApp(
        const ThreadScreen(episodeId: 'ep-1', title: 'Ramesh'),
        overrides: commonOverrides(b.client),
        scaffold: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emergency.2')), findsOneWidget);
    expect(b.requests.any((r) => r.url.path.endsWith('/messages/read')), isTrue);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(polled, isTrue);
    expect(find.text('Feeling dizzy'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('messageField')), 'Please check BP');
    await tester.pump();
    await tester.tap(find.byKey(const Key('messageSend')));
    await tester.pumpAndSettle();
    expect(find.text('Please check BP'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
