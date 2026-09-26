import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/illustrations.dart';
import '../../core/widgets/state_views.dart';
import '../../models/ai.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import 'ai_controller.dart';
import 'voice_output.dart';
import 'voice_input.dart';

class AskAiScreen extends ConsumerStatefulWidget {
  const AskAiScreen({super.key, this.initialQuery, this.voice = false});
  final String? initialQuery;
  final bool voice;

  @override
  ConsumerState<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends ConsumerState<AskAiScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final VoiceInput _voice = VoiceInput();
  bool _listening = false;
  String? _handledQuery;
  String? _queuedQuery;
  bool _handledVoice = false;

  /// The last message was dictated: read the reply aloud (§40).
  bool _lastInputVoice = false;
  late final SpeechOutput _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(speechOutputProvider);
    _input.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant AskAiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _consumeRouteArgs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _consumeRouteArgs();
  }

  void _consumeRouteArgs() {
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty && q != _handledQuery) {
      _handledQuery = q;
      // Send once the conversation is ready (it may still be loading).
      _queuedQuery = q;
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushQueued());
    }
    if (widget.voice && !_handledVoice) {
      _handledVoice = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleVoice());
    }
  }

  void _flushQueued() {
    final q = _queuedQuery;
    if (q == null || !mounted) return;
    if (ref.read(askAiControllerProvider).conversation == null) return;
    _queuedQuery = null;
    _send(q);
  }

  @override
  void dispose() {
    _voice.stop();
    _tts.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text, {bool voice = false}) async {
    if (text.trim().isEmpty) return;
    // New input always interrupts a reply being read aloud.
    _tts.stop();
    _lastInputVoice = voice;
    _input.clear();
    _scrollToEnd();
    try {
      await ref.read(askAiControllerProvider.notifier).send(text, voice: voice);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
    _scrollToEnd();
  }

  Future<void> _toggleVoice() async {
    final l = context.l10n;
    if (!ref.read(featureFlagsProvider).voiceInput) return;
    if (_listening) {
      await _voice.stop();
      setState(() => _listening = false);
      return;
    }
    await _tts.stop();
    final lang = ref.read(localeProvider).languageCode;
    final result = await _voice.start(
      localeId: switch (lang) { 'hi' => 'hi_IN', 'te' => 'te_IN', _ => 'en_IN' },
      onPartial: (t) => _input.text = t,
      onFinal: (t) {
        if (!mounted) return;
        setState(() => _listening = false);
        if (t.trim().isNotEmpty) _send(t, voice: true);
      },
      onStopped: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    switch (result) {
      case VoiceStartResult.started:
        setState(() => _listening = true);
      case VoiceStartResult.permissionDenied:
        showSnack(context, l.micPermissionDenied, error: true);
      case VoiceStartResult.unavailable:
        showSnack(context, l.voiceUnavailable, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = ref.watch(askAiControllerProvider);
    final active = ref.watch(activePatientProvider).value;
    ref.listen(askAiControllerProvider.select((s) => s.messages.length), (_, _) => _scrollToEnd());
    ref.listen<ChatState>(askAiControllerProvider, (prev, next) {
      if (prev == null || !(_lastInputVoice || ref.read(readAloudProvider))) return;
      final texts = textsToSpeak(prev, next, l);
      if (texts.isNotEmpty) {
        _tts.speak(texts.join('. '), languageCode: ref.read(localeProvider).languageCode);
      }
    });
    final readAloud = ref.watch(readAloudProvider);
    ref.listen(askAiControllerProvider.select((s) => s.conversation?.id), (_, next) {
      if (next != null) WidgetsBinding.instance.addPostFrameCallback((_) => _flushQueued());
    });

    final flags = ref.watch(featureFlagsProvider);
    Widget body;
    if (!flags.aiAssistant) {
      body = EmptyStateView(
        icon: Icons.smart_toy_outlined,
        title: l.aiUnavailableTitle,
        message: l.aiUnavailableBody,
        actionLabel: l.bookDoctor,
        onAction: () => context.push('/doctors'),
      );
    } else if (st.consentRequired) {
      body = AiConsentPrompt(onGrant: () async {
        try {
          await ref.read(askAiControllerProvider.notifier).grantConsentAndContinue();
          ref.invalidate(consentsProvider);
        } on ApiException catch (e) {
          if (context.mounted) showSnack(context, errorMessage(context, e), error: true);
        }
      });
    } else if (st.loading && st.conversation == null) {
      body = const LoadingView();
    } else if (st.loadError != null && st.conversation == null) {
      body = ErrorStateView(
          error: st.loadError!,
          onRetry: () => ref.read(askAiControllerProvider.notifier).retryLoad());
    } else {
      body = ChatMessageList(
        state: st,
        controller: _scroll,
        onQuickReply: (t) => _send(t),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: Space.lg,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: context.mintSurface, shape: BoxShape.circle),
              child: const RobotAssistant(size: 34),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.aiAssistantTitle, style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration:
                            const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(l.online,
                          style: const TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: l.moreOptions,
            onSelected: (v) {
              if (v == 'new') ref.read(askAiControllerProvider.notifier).newConversation();
              if (v == 'sos') context.push('/sos');
              if (v == 'aloud') {
                if (readAloud) _tts.stop();
                ref.read(readAloudProvider.notifier).toggle();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'new', child: Text(l.newChat)),
              CheckedPopupMenuItem(
                key: const Key('read-aloud'),
                value: 'aloud',
                checked: readAloud,
                child: Text(l.readRepliesAloud),
              ),
              PopupMenuItem(value: 'sos', child: Text(l.qxEmergencySos)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (active != null && !active.isSelf)
            Container(
              width: double.infinity,
              color: context.mintSurface,
              padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: 6),
              child: Text(l.actingFor(active.name),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.primaryDark)),
            ),
          Expanded(child: body),
          if (!st.consentRequired && flags.aiAssistant)
            ChatComposer(
              voiceEnabled: flags.voiceInput,
              controller: _input,
              listening: _listening,
              sending: st.sending,
              onSend: () => _send(_input.text),
              onMic: _toggleVoice,
              failedText: st.failedText,
              onRetryFailed: st.failedText == null ? null : () => _send(st.failedText!),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Messages

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.state,
    required this.onQuickReply,
    this.controller,
  });
  final ChatState state;
  final ScrollController? controller;
  final ValueChanged<String> onQuickReply;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final msgs = state.messages;
    final progress = state.intakeProgress;
    final replies = state.sending ? const <String>[] : state.quickReplies;
    final starters = msgs.where((m) => m.isUser).isEmpty
        ? [l.starterHeadache, l.starterSymptoms, l.starterHomeCheckup, l.starterReport]
        : const <String>[];
    final hasSafetyBubble = msgs.any((m) => m.isSafetyAlert);
    final routing = state.routing;
    final showRoutingCard = routing != null && routing.isActionable && !state.isEmergency;
    // The routing card already shows the latest routing explanation, so skip its duplicate bubble.
    final hiddenRoutingIndex =
        showRoutingCard ? msgs.lastIndexWhere((m) => m.kind == 'routing') : -1;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.lg),
      children: [
        for (var i = 0; i < msgs.length; i++)
          if (i != hiddenRoutingIndex) ...[
          if (msgs[i].isSafetyAlert)
            SafetyAlertBubble(text: msgs[i].text, rules: msgs[i].safety?.triggeredRules ?? const [])
          else if (msgs[i].isUser)
            UserBubble(text: msgs[i].text)
          else
            AssistantBubble(
              message: msgs[i],
              progress: i == msgs.length - 1 ? progress : null,
            ),
          const SizedBox(height: Space.md),
        ],
        if (state.isEmergency && !hasSafetyBubble)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: SafetyAlertBubble(
                text: l.emergencyTemplate, rules: state.safety?.triggeredRules ?? const []),
          ),
        if (showRoutingCard)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: RoutingCard(routing: routing),
          ),
        if (state.sending) const TypingIndicator(),
        if (replies.isNotEmpty || starters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final r in (replies.isNotEmpty ? replies : starters))
                  QuickReplyChip(label: r, onTap: () => onQuickReply(r)),
              ],
            ),
          ),
      ],
    );
  }
}

class QuickReplyChip extends StatelessWidget {
  const QuickReplyChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.mint100, width: 1.4)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(label, style: TextStyle(color: context.textMuted, fontSize: 13.5)),
          ),
        ),
      ),
    );
  }
}

class AssistantBubble extends StatelessWidget {
  const AssistantBubble({super.key, required this.message, this.progress});
  final ChatMessage message;
  final (int, int)? progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: context.mintSurface, shape: BoxShape.circle),
          child: const RobotAssistant(size: 28),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
                topLeft: Radius.circular(4),
              ),
              border: Border.all(color: context.borderColor),
              boxShadow: Shadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: const TextStyle(fontSize: 14.5, height: 1.4)),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${progress!.$1}/${progress!.$2}',
                          semanticsLabel: context.l10n.questionProgress(progress!.$1, progress!.$2),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress!.$1 / progress!.$2,
                            minHeight: 5,
                            backgroundColor: AppColors.mint100,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                const AiGeneratedLabel(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4)),
        ),
      ),
    );
  }
}

class SafetyAlertBubble extends StatelessWidget {
  const SafetyAlertBubble({super.key, required this.text, this.rules = const []});
  final String text;
  final List<TriggeredRule> rules;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('safety-alert'),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: context.roseSurface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppColors.danger, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.emergencyAlertTitle,
                      style: const TextStyle(
                          color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text.isEmpty ? l.emergencyTemplate : text,
                style: const TextStyle(fontSize: 14.5, height: 1.4)),
            if (rules.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(rules.map((r) => r.title).join(' · '),
                  style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: AppConfig.emergencyHelpline)),
                    icon: const Icon(Icons.call),
                    label: Text(l.call108),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger)),
                    onPressed: () => context.push('/sos'),
                    icon: const Icon(Icons.sos),
                    label: Text(l.sosButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoutingCard extends ConsumerWidget {
  const RoutingCard({super.key, required this.routing});
  final Routing routing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDoctor = routing.action == 'book_doctor';
    String specialtyName = humanize(routing.suggestedSpecialty ?? 'general_physician');
    final specs = ref.watch(specialtiesProvider).value;
    if (specs != null) {
      for (final s in specs) {
        if (s.code == routing.suggestedSpecialty) specialtyName = s.name;
      }
    }
    final title = isDoctor ? l.routeBookDoctor(specialtyName) : l.routeBookHomeCheckup;
    return CcCard(
      color: context.mintSurface,
      borderColor: AppColors.mint100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                  icon: isDoctor ? Icons.medical_services_outlined : Icons.home_outlined,
                  accent: isDoctor ? Accent.teal : Accent.rose,
                  size: 44),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          if (routing.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(routing.explanation, style: TextStyle(color: context.textMuted)),
          ],
          const SizedBox(height: Space.md),
          PrimaryButton(
            label: isDoctor ? l.findDoctors : l.bookHomeCheckup,
            onPressed: () {
              final ep = routing.careEpisodeId;
              if (isDoctor) {
                context.push(Uri(path: '/doctors', queryParameters: {
                  'specialty': routing.suggestedSpecialty ?? 'general_physician',
                  'episode': ?ep,
                }).toString());
              } else {
                context.push(Uri(path: '/home-checkup/book', queryParameters: {
                  'episode': ?ep,
                }).toString());
              }
            },
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, bottom: Space.md),
      child: Row(
        children: [
          const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(context.l10n.assistantTyping,
              style: TextStyle(color: context.textMuted)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Composer

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.listening,
    required this.sending,
    required this.onSend,
    required this.onMic,
    this.failedText,
    this.onRetryFailed,
    this.voiceEnabled = true,
  });
  final bool voiceEnabled;
  final TextEditingController controller;
  final bool listening;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final String? failedText;
  final VoidCallback? onRetryFailed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasText = controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failedText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(l.messageNotSent,
                            style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
                    TextButton(onPressed: onRetryFailed, child: Text(l.retry)),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.only(left: 8, right: 4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(Radii.input),
                border: Border.all(color: context.borderColor),
                boxShadow: Shadows.card,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.sentiment_satisfied_alt_outlined, color: context.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: listening ? l.listening : l.typeOrSpeak,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  if (hasText)
                    IconButton.filled(
                      tooltip: l.send,
                      onPressed: sending ? null : onSend,
                      icon: const Icon(Icons.send_rounded),
                    )
                  else if (voiceEnabled)
                    IconButton.filled(
                      tooltip: listening ? l.stopListening : l.voiceInput,
                      style: IconButton.styleFrom(
                          backgroundColor: listening ? AppColors.danger : AppColors.primary),
                      onPressed: onMic,
                      icon: Icon(listening ? Icons.stop : Icons.mic),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiConsentPrompt extends StatefulWidget {
  const AiConsentPrompt({super.key, required this.onGrant});
  final Future<void> Function() onGrant;

  @override
  State<AiConsentPrompt> createState() => _AiConsentPromptState();
}

class _AiConsentPromptState extends State<AiConsentPrompt> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(Space.xxl),
      children: [
        const Center(child: RobotAssistant(size: 110)),
        const SizedBox(height: Space.xl),
        Text(l.aiConsentTitle,
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.md),
        Text(l.aiConsentBody,
            textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
        const SizedBox(height: Space.lg),
        CcCard(
          color: context.lavenderSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bullet(l.aiConsentPoint1),
              _Bullet(l.aiConsentPoint2),
              _Bullet(l.aiConsentPoint3),
            ],
          ),
        ),
        const SizedBox(height: Space.xxl),
        PrimaryButton(
          label: l.allowAiAssistance,
          loading: _busy,
          onPressed: () async {
            setState(() => _busy = true);
            await widget.onGrant();
            if (mounted) setState(() => _busy = false);
          },
        ),
        const SizedBox(height: Space.md),
        OutlinedButton(
          onPressed: () => context.push('/doctors'),
          child: Text(l.talkToDoctorInstead),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 18, color: AppColors.lavenderFg),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
