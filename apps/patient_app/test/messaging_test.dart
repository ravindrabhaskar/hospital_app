import 'package:care_companion_patient/data/repositories.dart';
import 'package:care_companion_patient/features/home/notifications_screen.dart' show resolveDeepLink;
import 'package:care_companion_patient/features/messages/thread_screen.dart';
import 'package:care_companion_patient/models/engagement.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

CareMessage msg(String id, String role, String text, {String? sender, String? userId, int minute = 0}) => CareMessage(
      id: id,
      careEpisodeId: 'e1',
      senderUserId: userId,
      senderName: sender ?? role,
      senderRole: role,
      text: text,
      attachmentRecordId: null,
      createdAt: DateTime(2026, 9, 26, 10, minute),
    );

class FakeMessagingRepository extends MessagingRepository {
  FakeMessagingRepository() : super(deadApiClient());

  final server = <CareMessage>[
    msg('m1', 'doctor', 'How is the headache today?', sender: 'Dr. Ananya Rao'),
  ];
  final calls = <String?>[];
  int reads = 0;
  final sent = <String>[];

  @override
  Future<List<InboxThread>> inbox() async => [
        InboxThread(
          careEpisodeId: 'e1',
          title: 'Headache follow-up',
          patientId: 'p-self',
          patientName: 'Vaibhav',
          lastMessage: null,
          lastSenderName: null,
          lastAt: null,
          unread: 0,
        ),
      ];

  @override
  Future<List<CareMessage>> messages(String episodeId, {String? after}) async {
    calls.add(after);
    if (after == null) return [...server];
    final i = server.indexWhere((m) => m.id == after);
    return server.sublist(i + 1);
  }

  @override
  Future<CareMessage> send(String episodeId, String text, {String? attachmentRecordId}) async {
    sent.add(text);
    final m = msg('m${server.length + 1}', 'patient', text, sender: 'Vaibhav', userId: 'u1', minute: 5);
    server.add(m);
    // The safety engine appends the fixed emergency template (§34).
    if (text.toLowerCase().contains('chest pain')) {
      server.add(msg('m${server.length + 1}', 'system',
          'This may be an emergency. Call 108 now or go to the nearest emergency department.',
          sender: 'CareCompanion', minute: 5));
    }
    return m;
  }

  @override
  Future<void> markRead(String episodeId) async => reads++;
}

void main() {
  testWidgets('thread polls every 10 s while open and shows new messages with role chips', (tester) async {
    useTallPhone(tester);
    final repo = FakeMessagingRepository();
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(const ThreadScreen(episodeId: 'e1'), overrides: [
      ...overrides,
      messagingRepositoryProvider.overrideWithValue(repo),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('How is the headache today?'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget); // sender role chip
    expect(repo.calls, [null]);
    expect(repo.reads, 1);

    // A coordinator replies on the server; nothing is fetched before 10 s.
    repo.server.add(msg('m2', 'coordinator', 'I have booked your follow-up.', sender: 'Priya'));
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('I have booked your follow-up.'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(repo.calls.last, 'm1'); // incremental: ?after=<last id>
    expect(find.text('I have booked your follow-up.'), findsOneWidget);
    expect(find.text('Care coordinator'), findsOneWidget);
    expect(repo.reads, 2);

    // Polling stops when the thread is closed.
    await tester.pumpWidget(const SizedBox());
    final before = repo.calls.length;
    await tester.pump(const Duration(seconds: 30));
    expect(repo.calls.length, before);
  });

  testWidgets('an emergency system message is shown in red with a Call 108 button', (tester) async {
    useTallPhone(tester);
    final repo = FakeMessagingRepository();
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(const ThreadScreen(episodeId: 'e1'), overrides: [
      ...overrides,
      messagingRepositoryProvider.overrideWithValue(repo),
    ]));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byKey(const Key('thread-input')), 'I have chest pain');
    await tester.pump();
    await tester.tap(find.byKey(const Key('thread-send')));
    await tester.pump();
    await tester.pump();

    expect(repo.sent, ['I have chest pain']);
    expect(find.text('I have chest pain'), findsOneWidget);
    // The system message arrives immediately (post-send poll), styled as an emergency.
    expect(find.byKey(const Key('emergency-message')), findsOneWidget);
    expect(find.byKey(const Key('emergency-call-108')), findsOneWidget);
    expect(find.textContaining('Call 108 now'), findsOneWidget);
    final box = tester.widget<Container>(find.byKey(const Key('emergency-message')));
    expect((box.decoration as BoxDecoration).gradient, isNotNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Enter (send action) sends the message (B30)', (tester) async {
    useTallPhone(tester);
    final repo = FakeMessagingRepository();
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(const ThreadScreen(episodeId: 'e1'), overrides: [
      ...overrides,
      messagingRepositoryProvider.overrideWithValue(repo),
    ]));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byKey(const Key('thread-input')), 'Feeling better');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump();
    expect(repo.sent, ['Feeling better']);

    // Nothing to send: Enter does nothing.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(repo.sent, ['Feeling better']);
    await tester.pumpWidget(const SizedBox());
  });

  test('push deep links to a thread open the thread screen', () {
    expect(resolveDeepLink('/care-episodes/e1/messages'), '/care-episodes/e1/messages');
    expect(resolveDeepLink('/care-episodes/e1'), '/episodes/e1');
    expect(resolveDeepLink('/prescriptions/rx1'), '/prescriptions/rx1');
    expect(resolveDeepLink('/payments/p1/invoice'), '/payments/p1/invoice');
  });

  test('only system messages that carry the helpline are emergency templates', () {
    expect(msg('a', 'system', 'Call 108 now').isEmergencyTemplate, isTrue);
    expect(msg('b', 'system', 'Your appointment moved').isEmergencyTemplate, isFalse);
    expect(msg('c', 'patient', 'should I call 108?').isEmergencyTemplate, isFalse);
  });
}
