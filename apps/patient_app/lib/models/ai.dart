import 'json.dart';

class IntakeField {
  IntakeField({required this.value, required this.source, required this.confidence});
  final Object? value;
  final String? source;
  final double? confidence;

  bool get hasValue {
    final v = value;
    if (v == null) return false;
    if (v is String) return v.isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  factory IntakeField.fromJson(Json j) => IntakeField(
        value: j['value'],
        source: strOrNull(j, 'source'),
        confidence: dblOrNull(j, 'confidence'),
      );

  static IntakeField empty() => IntakeField(value: null, source: null, confidence: null);
}

class Intake {
  Intake({
    required this.fields,
    required this.missingFields,
    required this.complete,
    this.progress,
  });

  static const fieldKeys = [
    'chiefComplaint',
    'durationText',
    'severity',
    'associatedSymptoms',
    'relevantHistory',
    'currentMedications',
    'allergies',
  ];

  final Map<String, IntakeField> fields;
  final List<String> missingFields;
  final bool complete;

  /// Server-computed "question step of total" (monotonic); null from older servers.
  final (int, int)? progress;

  static (int, int)? _progress(Object? p) {
    if (p is! Map) return null;
    final step = p['step'], total = p['total'];
    if (step is! num || total is! num || total <= 0) return null;
    return (step.toInt(), total.toInt());
  }

  factory Intake.fromJson(Json j) => Intake(
        fields: {
          for (final k in fieldKeys)
            k: j[k] is Map ? IntakeField.fromJson(asJson(j[k])) : IntakeField.empty(),
        },
        missingFields: strList(j, 'missingFields'),
        complete: boolOf(j, 'complete'),
        progress: _progress(j['progress']),
      );

  static Intake empty() => Intake(fields: const {}, missingFields: const [], complete: false);
}

class TriggeredRule {
  TriggeredRule({required this.ruleId, required this.title, required this.action});
  final String ruleId;
  final String title;
  final String action;

  factory TriggeredRule.fromJson(Json j) => TriggeredRule(
        ruleId: str(j, 'ruleId'),
        title: str(j, 'title'),
        action: str(j, 'action'),
      );
}

class SafetyResult {
  SafetyResult({
    required this.level,
    required this.triggeredRules,
    required this.rulePackVersion,
    required this.rulePackStatus,
  });
  final String level;
  final List<TriggeredRule> triggeredRules;
  final String rulePackVersion;
  final String rulePackStatus;

  bool get isEmergency => level == 'emergency';
  bool get isUrgent => level == 'urgent';

  factory SafetyResult.fromJson(Json j) => SafetyResult(
        level: str(j, 'level', 'none'),
        triggeredRules: listOf(j['triggeredRules'], TriggeredRule.fromJson),
        rulePackVersion: str(j, 'rulePackVersion'),
        rulePackStatus: str(j, 'rulePackStatus'),
      );
}

class Routing {
  Routing({
    required this.action,
    required this.suggestedSpecialty,
    required this.careEpisodeId,
    required this.explanation,
  });
  final String action;
  final String? suggestedSpecialty;
  final String? careEpisodeId;
  final String explanation;

  bool get isActionable => action == 'book_doctor' || action == 'home_visit';

  factory Routing.fromJson(Json j) => Routing(
        action: str(j, 'action', 'continue_intake'),
        suggestedSpecialty: strOrNull(j, 'suggestedSpecialty'),
        careEpisodeId: strOrNull(j, 'careEpisodeId'),
        explanation: str(j, 'explanation'),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.kind,
    required this.text,
    required this.quickReplies,
    required this.createdAt,
    this.routing,
    this.safety,
  });
  final String id;
  final String role;
  final String kind;
  final String text;
  final List<String> quickReplies;
  final DateTime createdAt;
  final Routing? routing;
  final SafetyResult? safety;

  bool get isUser => role == 'user';
  bool get isSafetyAlert =>
      kind == 'safety_alert' || (safety?.isEmergency ?? false);

  factory ChatMessage.fromJson(Json j) => ChatMessage(
        id: str(j, 'id'),
        role: str(j, 'role'),
        kind: str(j, 'kind', 'text'),
        text: str(j, 'text'),
        quickReplies: strList(j, 'quickReplies'),
        createdAt: dateOf(j, 'createdAt'),
        routing: j['routing'] is Map ? Routing.fromJson(asJson(j['routing'])) : null,
        safety: j['safety'] is Map ? SafetyResult.fromJson(asJson(j['safety'])) : null,
      );
}

class Conversation {
  Conversation({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.careEpisodeId,
    required this.messages,
    required this.intake,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String patientId;
  final String patientName;
  final String status;
  final String? careEpisodeId;
  final List<ChatMessage> messages;
  final Intake intake;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Conversation.fromJson(Json j) => Conversation(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        status: str(j, 'status', 'active'),
        careEpisodeId: strOrNull(j, 'careEpisodeId'),
        messages: listOf(j['messages'], ChatMessage.fromJson),
        intake: j['intake'] is Map ? Intake.fromJson(asJson(j['intake'])) : Intake.empty(),
        createdAt: dateOf(j, 'createdAt'),
        updatedAt: dateOf(j, 'updatedAt'),
      );
}

class AssistantTurn {
  AssistantTurn({
    required this.messages,
    required this.intake,
    required this.safety,
    required this.routing,
    required this.conversationStatus,
  });
  final List<ChatMessage> messages;
  final Intake intake;
  final SafetyResult safety;
  final Routing routing;
  final String conversationStatus;

  factory AssistantTurn.fromJson(Json j) => AssistantTurn(
        messages: listOf(j['messages'], ChatMessage.fromJson),
        intake: j['intake'] is Map ? Intake.fromJson(asJson(j['intake'])) : Intake.empty(),
        safety: SafetyResult.fromJson(asJson(j['safety'])),
        routing: Routing.fromJson(asJson(j['routing'])),
        conversationStatus: str(j, 'conversationStatus', 'active'),
      );
}
