import 'json.dart';

// ---------- Ratings & reviews (§33) ----------

class PendingReview {
  PendingReview({
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.subtitle,
    required this.completedAt,
  });
  final String targetType;
  final String targetId;
  final String title;
  final String? subtitle;
  final DateTime? completedAt;

  factory PendingReview.fromJson(Json j) => PendingReview(
        targetType: str(j, 'targetType'),
        targetId: str(j, 'targetId'),
        title: str(j, 'title'),
        subtitle: strOrNull(j, 'subtitle'),
        completedAt: dateOrNull(j, 'completedAt'),
      );
}

class SubmittedReview {
  SubmittedReview({required this.id, required this.status, required this.rating, required this.text});
  final String id;
  final String status;
  final int rating;
  final String? text;

  bool get published => status == 'published';

  factory SubmittedReview.fromJson(Json j) => SubmittedReview(
        id: str(j, 'id'),
        status: str(j, 'status'),
        rating: intOf(j, 'rating'),
        text: strOrNull(j, 'text'),
      );
}

// ---------- Care-team messaging (§34) ----------

class InboxThread {
  InboxThread({
    required this.careEpisodeId,
    required this.title,
    required this.patientId,
    required this.patientName,
    required this.lastMessage,
    required this.lastSenderName,
    required this.lastAt,
    required this.unread,
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
        careEpisodeId: str(j, 'careEpisodeId'),
        title: str(j, 'title'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        lastMessage: strOrNull(j, 'lastMessage'),
        lastSenderName: strOrNull(j, 'lastSenderName'),
        lastAt: dateOrNull(j, 'lastAt'),
        unread: intOf(j, 'unread'),
      );
}

/// A care-team thread message (named to avoid clashing with the AI chat's
/// `ChatMessage`).
class CareMessage {
  CareMessage({
    required this.id,
    required this.careEpisodeId,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.attachmentRecordId,
    required this.createdAt,
    this.kind,
  });
  final String id;
  final String careEpisodeId;
  final String? senderUserId;
  final String senderName;
  final String senderRole;
  final String text;
  final String? attachmentRecordId;
  final DateTime createdAt;

  /// `text`, `emergency_notice` (the fixed 108 safety template) or `system`.
  /// Null only from older servers.
  final String? kind;

  bool get isSystem => senderRole == 'system';

  /// The fixed 108 template the server appends when a patient message is
  /// classified `emergency` (§34). Older servers without `kind` fall back to
  /// detecting the helpline number in a system message.
  bool get isEmergencyTemplate => kind != null
      ? kind == 'emergency_notice'
      : isSystem && RegExp(r'\b108\b').hasMatch(text);

  bool get fromPatientSide => senderRole == 'patient' || senderRole == 'family';

  factory CareMessage.fromJson(Json j) => CareMessage(
        id: str(j, 'id'),
        careEpisodeId: str(j, 'careEpisodeId'),
        senderUserId: strOrNull(j, 'senderUserId'),
        senderName: str(j, 'senderName'),
        senderRole: str(j, 'senderRole', 'system'),
        text: str(j, 'text'),
        attachmentRecordId: strOrNull(j, 'attachmentRecordId'),
        createdAt: dateOf(j, 'createdAt'),
        kind: strOrNull(j, 'kind'),
      );
}

// ---------- Government health schemes (§38) ----------

class Scheme {
  Scheme({
    required this.id,
    required this.name,
    required this.authority,
    required this.level,
    required this.state,
    required this.summary,
    required this.benefits,
    required this.eligibilityHints,
    required this.documentsTypicallyNeeded,
    required this.officialUrl,
    required this.helpline,
    required this.lastReviewedAt,
    required this.disclaimer,
  });
  final String id;
  final String name;
  final String authority;
  final String level;
  final String? state;
  final String summary;
  final List<String> benefits;
  final List<String> eligibilityHints;
  final List<String> documentsTypicallyNeeded;
  final String officialUrl;
  final String? helpline;
  final DateTime? lastReviewedAt;
  final String disclaimer;

  bool get isCentral => level == 'central';

  factory Scheme.fromJson(Json j) => Scheme(
        id: str(j, 'id'),
        name: str(j, 'name'),
        authority: str(j, 'authority'),
        level: str(j, 'level', 'central'),
        state: strOrNull(j, 'state'),
        summary: str(j, 'summary'),
        benefits: strList(j, 'benefits'),
        eligibilityHints: strList(j, 'eligibilityHints'),
        documentsTypicallyNeeded: strList(j, 'documentsTypicallyNeeded'),
        officialUrl: str(j, 'officialUrl'),
        helpline: strOrNull(j, 'helpline'),
        lastReviewedAt: dateOrNull(j, 'lastReviewedAt'),
        disclaimer: str(j, 'disclaimer'),
      );
}
