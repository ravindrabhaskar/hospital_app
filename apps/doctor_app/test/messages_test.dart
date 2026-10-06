import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/features/common/file_viewer.dart';
import 'package:care_companion_doctor/features/messages/thread_screen.dart';
import 'package:care_companion_doctor/models/messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Map<String, dynamic> msg(
  String id, {
  String kind = 'text',
  String role = 'patient',
  String text = 'Hello doctor',
  String? attachment,
}) => {
  'id': id,
  'careEpisodeId': 'ep-1',
  'senderUserId': role == 'system' ? null : 'u-$role',
  'senderName': role == 'system' ? 'CareCompanion' : 'Ramesh',
  'senderRole': role,
  'kind': kind,
  'text': text,
  'attachmentRecordId': attachment,
  'createdAt': '2026-09-29T05:00:00.000Z',
};

const _png1x1 = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];

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

  testWidgets('a record attached by the patient shows as a chip that opens the file (B12)', (tester) async {
    final b = mockBackend((req, path) {
      if (path == '/records/rec-1') {
        return {
          'id': 'rec-1',
          'patientId': 'p-1',
          'type': 'visit_summary',
          'title': 'Home visit summary',
          'recordDate': '2026-10-04',
          // An image keeps the test off pdfx (no PDF renderer on the test host).
          'mimeType': 'image/png',
          'hasFile': true,
        };
      }
      if (path == '/records/rec-1/file') return http.Response.bytes(_png1x1, 200, headers: {'content-type': 'image/png'});
      return null;
    });
    final m = ChatMessage.fromJson(msg('m5', text: 'attaching my home visit summary', attachment: 'rec-1'));
    expect(m.attachmentRecordId, 'rec-1');
    await tester.pumpWidget(testApp(MessageBubble(message: m, mine: false), overrides: commonOverrides(b.client)));
    await tester.pumpAndSettle();

    final chip = find.byKey(const Key('attachment.m5'));
    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('Home visit summary')), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.textContaining('Visit summary')), findsOneWidget);
    expect(find.text('attaching my home visit summary'), findsOneWidget);

    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FileViewerScreen), findsOneWidget);
    expect(b.requests.any((r) => r.url.path.endsWith('/records/rec-1/file')), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an attachment that cannot be loaded says so instead of disappearing', (tester) async {
    final b = mockBackend((req, path) => null);
    final m = ChatMessage.fromJson(msg('m6', attachment: 'gone'));
    await tester.pumpWidget(testApp(MessageBubble(message: m, mine: true), overrides: commonOverrides(b.client)));
    await tester.pumpAndSettle();
    expect(find.text('Attached record unavailable'), findsOneWidget);
  });

  testWidgets('messages without an attachment show no chip', (tester) async {
    await tester.pumpWidget(testApp(MessageBubble(message: ChatMessage.fromJson(msg('m7')), mine: false)));
    expect(find.byKey(const Key('attachment.m7')), findsNothing);
  });
}
