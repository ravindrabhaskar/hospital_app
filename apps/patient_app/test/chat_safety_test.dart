import 'package:care_companion_patient/data/repositories.dart';
import 'package:care_companion_patient/features/ai/ask_ai_screen.dart';
import 'package:care_companion_patient/models/ai.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

ChatMessage msg(String id, String role, String kind, String text,
        {List<String> replies = const [], SafetyResult? safety}) =>
    ChatMessage(
      id: id,
      role: role,
      kind: kind,
      text: text,
      quickReplies: replies,
      createdAt: DateTime(2026, 9, 26, 9),
      safety: safety,
    );

final emergency = SafetyResult(
  level: 'emergency',
  triggeredRules: [TriggeredRule(ruleId: 'R-CHEST', title: 'Chest pain with breathlessness', action: 'show_emergency')],
  rulePackVersion: 'fixture-0.1',
  rulePackStatus: 'fixture_unapproved',
);

class FakeAiRepository extends AiRepository {
  FakeAiRepository() : super(deadApiClient());
  final sent = <String>[];

  @override
  Future<List<Conversation>> list(String patientId) async => [];

  @override
  Future<Conversation> create(String patientId) async => Conversation(
        id: 'c1',
        patientId: patientId,
        patientName: 'Vaibhav',
        status: 'active',
        careEpisodeId: null,
        messages: [msg('m0', 'assistant', 'text', 'Hi Vaibhav! How can I help you today?')],
        intake: Intake.empty(),
        createdAt: DateTime(2026, 9, 26),
        updatedAt: DateTime(2026, 9, 26),
      );

  @override
  Future<AssistantTurn> send(String conversationId, String text, {String inputMode = 'text'}) async {
    sent.add(text);
    return AssistantTurn(
      messages: [
        msg('m1', 'user', 'text', text),
        msg('m2', 'assistant', 'safety_alert',
            'This could be a medical emergency. Call 108 now or press SOS.',
            safety: emergency),
      ],
      intake: Intake.empty(),
      safety: emergency,
      routing: Routing(action: 'emergency', suggestedSpecialty: null, careEpisodeId: 'e9', explanation: ''),
      conversationStatus: 'routed',
    );
  }
}

void main() {
  testWidgets('chat renders a red emergency safety alert with Call 108 and SOS', (tester) async {
    useTallPhone(tester, height: 1600);
    final fake = FakeAiRepository();
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(
      const AskAiScreen(initialQuery: 'Severe chest pain and I cannot breathe'),
      overrides: [...overrides, aiRepositoryProvider.overrideWithValue(fake)],
    ));
    // Load conversation, then the post-frame send of the initial query.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(fake.sent, ['Severe chest pain and I cannot breathe']);
    expect(find.text('Severe chest pain and I cannot breathe'), findsOneWidget);
    expect(find.byKey(const Key('safety-alert')), findsOneWidget);
    expect(find.text('This may be an emergency'), findsOneWidget);
    expect(find.text('Call 108'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    // Assistant text carries the AI marker.
    expect(find.text('AI-generated · not a diagnosis'), findsWidgets);
    // No routing card to book a doctor while in emergency.
    expect(find.text('Find doctors'), findsNothing);
  });
}
