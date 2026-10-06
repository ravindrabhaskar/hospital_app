import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../models/ai.dart';
import '../../state/core_providers.dart';

class ChatState {
  const ChatState({
    this.conversation,
    this.messages = const [],
    this.intake,
    this.safety,
    this.routing,
    this.loading = true,
    this.sending = false,
    this.loadError,
    this.consentRequired = false,
    this.pendingText,
    this.failedText,
    this.maxMissing = 0,
  });

  final Conversation? conversation;
  final List<ChatMessage> messages;
  final Intake? intake;
  final SafetyResult? safety;
  final Routing? routing;
  final bool loading;
  final bool sending;
  final Object? loadError;
  final bool consentRequired;
  final String? pendingText;
  final String? failedText;
  final int maxMissing;

  bool get isEmergency =>
      (safety?.isEmergency ?? false) || messages.any((m) => m.isSafetyAlert);

  /// "step/total" style intake progress, or null when not in intake.
  (int, int)? get intakeProgress {
    final i = intake;
    if (i == null || i.complete || i.missingFields.isEmpty || maxMissing == 0) return null;
    if (routing != null && routing!.action != 'continue_intake') return null;
    if (i.progress != null) return i.progress;
    final step = (maxMissing - i.missingFields.length + 1).clamp(1, maxMissing);
    return (step, maxMissing);
  }

  List<String> get quickReplies {
    for (final m in messages.reversed) {
      if (!m.isUser) return m.quickReplies;
      break;
    }
    return const [];
  }

  ChatState copyWith({
    Conversation? conversation,
    List<ChatMessage>? messages,
    Intake? intake,
    SafetyResult? safety,
    Routing? routing,
    bool? loading,
    bool? sending,
    Object? loadError,
    bool clearLoadError = false,
    bool? consentRequired,
    String? pendingText,
    bool clearPending = false,
    String? failedText,
    bool clearFailed = false,
    int? maxMissing,
  }) =>
      ChatState(
        conversation: conversation ?? this.conversation,
        messages: messages ?? this.messages,
        intake: intake ?? this.intake,
        safety: safety ?? this.safety,
        routing: routing ?? this.routing,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        loadError: clearLoadError ? null : (loadError ?? this.loadError),
        consentRequired: consentRequired ?? this.consentRequired,
        pendingText: clearPending ? null : (pendingText ?? this.pendingText),
        failedText: clearFailed ? null : (failedText ?? this.failedText),
        maxMissing: maxMissing ?? this.maxMissing,
      );
}

class AskAiController extends Notifier<ChatState> {
  String? _patientId;

  @override
  ChatState build() {
    final pid = ref.watch(activePatientProvider.select((v) => v.value?.id));
    _patientId = pid;
    if (pid != null) Future.microtask(() => _load(pid));
    return const ChatState();
  }

  ChatState _fromConversation(Conversation c) {
    final missing = c.intake.missingFields.length;
    return ChatState(
      conversation: c,
      messages: c.messages,
      intake: c.intake,
      loading: false,
      maxMissing: missing,
      safety: c.messages.lastWhereOrNull((m) => m.safety != null)?.safety,
      routing: c.messages.lastWhereOrNull((m) => m.routing != null)?.routing,
    );
  }

  Future<void> _load(String pid, {bool forceNew = false}) async {
    final repo = ref.read(aiRepositoryProvider);
    state = state.copyWith(loading: true, clearLoadError: true);
    try {
      Conversation? conv;
      if (!forceNew) {
        final list = await repo.list(pid);
        // Resume only a recent conversation; an old one likely concerns a different problem.
        final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
        final active = list
            .where((c) => c.status == 'active' && c.updatedAt.isAfter(cutoff))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (active.isNotEmpty) conv = await repo.get(active.first.id);
      }
      conv ??= await repo.create(pid);
      if (_patientId != pid) return;
      state = _fromConversation(conv);
    } on ApiException catch (e) {
      if (_patientId != pid) return;
      if (e.isConsentRequired) {
        state = state.copyWith(loading: false, consentRequired: true);
      } else {
        state = state.copyWith(loading: false, loadError: e);
      }
    }
  }

  Future<void> retryLoad() async {
    final pid = _patientId;
    if (pid != null) await _load(pid);
  }

  Future<void> newConversation() async {
    final pid = _patientId;
    if (pid != null) await _load(pid, forceNew: true);
  }

  Future<void> send(String text, {bool voice = false}) async {
    final t = text.trim();
    if (t.isEmpty || state.sending) return;
    final conv = state.conversation;
    if (conv == null) {
      state = state.copyWith(pendingText: t);
      if (!state.consentRequired) await retryLoad();
      if (state.conversation == null) return;
      return send(t, voice: voice);
    }
    final optimistic = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      kind: 'text',
      text: t,
      quickReplies: const [],
      createdAt: DateTime.now(),
    );
    final before = state.messages;
    state = state.copyWith(
        messages: [...before, optimistic], sending: true, clearFailed: true, clearPending: true);
    try {
      final turn = await ref
          .read(aiRepositoryProvider)
          .send(conv.id, t, inputMode: voice ? 'voice' : 'text');
      final missing = turn.intake.missingFields.length;
      state = state.copyWith(
        messages: [...before, ...turn.messages],
        intake: turn.intake,
        safety: turn.safety,
        routing: turn.routing,
        sending: false,
        maxMissing: missing > state.maxMissing ? missing : state.maxMissing,
      );
    } on ApiException catch (e) {
      if (e.isConsentRequired) {
        state = state.copyWith(
            messages: before, sending: false, consentRequired: true, pendingText: t);
      } else {
        state = state.copyWith(messages: before, sending: false, failedText: t);
        rethrow;
      }
    }
  }

  Future<void> grantConsentAndContinue() async {
    await ref.read(consentRepositoryProvider).grantPurpose('ai_assistance');
    final pending = state.pendingText;
    state = state.copyWith(consentRequired: false);
    if (state.conversation == null) await retryLoad();
    if (pending != null && state.conversation != null) {
      await send(pending);
    }
  }
}

final askAiControllerProvider =
    NotifierProvider<AskAiController, ChatState>(AskAiController.new);

extension _LastWhere<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}
