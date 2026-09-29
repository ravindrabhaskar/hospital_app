import 'json.dart';

/// `InboxThread` (contract §34).
class InboxThread {
  const InboxThread({
    required this.careEpisodeId,
    required this.title,
    required this.patientId,
    required this.patientName,
    this.lastMessage,
    this.lastSenderName,
    this.lastAt,
    this.unread = 0,
  });

  final String careEpisodeId;
  final String title;
  final String patientId;
  final String patientName;
  final String? lastMessage;
  final String? lastSenderName;
  final DateTime? lastAt;
  final int unread;

  factory InboxThread.fromJson(Json j) => InboxThread(
    careEpisodeId: strOr(j['careEpisodeId']),
    title: strOr(j['title'], '–'),
    patientId: strOr(j['patientId']),
    patientName: strOr(j['patientName'], '–'),
    lastMessage: str(j['lastMessage']),
    lastSenderName: str(j['lastSenderName']),
    lastAt: dateOrNull(j['lastAt']),
    unread: intOrNull(j['unread']) ?? 0,
  );
}

/// `ChatMessage` (§34). `emergency_notice` is the fixed 108 safety template.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.careEpisodeId,
    required this.senderName,
    required this.senderRole,
    required this.kind,
    required this.text,
    this.senderUserId,
    this.attachmentRecordId,
    this.createdAt,
  });

  final String id;
  final String careEpisodeId;
  final String? senderUserId;
  final String senderName;
  final String senderRole;
  final String kind;
  final String text;
  final String? attachmentRecordId;
  final DateTime? createdAt;

  bool get isEmergency => kind == 'emergency_notice';
  bool get isSystem => kind == 'system' || senderRole == 'system';

  factory ChatMessage.fromJson(Json j) => ChatMessage(
    id: strOr(j['id']),
    careEpisodeId: strOr(j['careEpisodeId']),
    senderUserId: str(j['senderUserId']),
    senderName: strOr(j['senderName'], '–'),
    senderRole: strOr(j['senderRole'], 'system'),
    kind: strOr(j['kind'], 'text'),
    text: strOr(j['text']),
    attachmentRecordId: str(j['attachmentRecordId']),
    createdAt: dateOrNull(j['createdAt']),
  );
}

/// Appends [incoming] to [current], skipping ids already present (polling
/// with `?after=` can overlap with a message we just posted).
List<ChatMessage> mergeMessages(List<ChatMessage> current, List<ChatMessage> incoming) {
  final ids = current.map((m) => m.id).toSet();
  return [
    ...current,
    for (final m in incoming)
      if (ids.add(m.id)) m,
  ];
}
