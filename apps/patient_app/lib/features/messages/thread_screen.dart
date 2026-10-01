import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../../models/engagement.dart';
import '../../models/records.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

/// How often an open thread checks for new messages (§34: every 10 s).
final messagePollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 10));

String senderRoleLabel(AppLocalizations l, String role) => switch (role) {
      'doctor' => l.roleDoctor,
      'coordinator' => l.roleCoordinator,
      'care_team' => l.roleCareTeam,
      'family' => l.roleFamily,
      'patient' => l.rolePatient,
      _ => l.roleSystem,
    };

Color senderRoleColor(String role) => switch (role) {
      'doctor' => AppColors.skyFg,
      'coordinator' => AppColors.lavenderFg,
      'care_team' => AppColors.primaryLight,
      _ => AppColors.peachFg,
    };

/// `/care-episodes/:id/messages`: the secure care-team thread of one episode.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.episodeId});
  final String episodeId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<CareMessage> _messages = const [];
  bool _loading = true;
  Object? _error;
  bool _sending = false;
  bool _polling = false;
  MedicalRecord? _attachment;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Poll only while the thread is visible.
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _poll();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(messagePollIntervalProvider), (_) => _poll());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(messagingRepositoryProvider).messages(widget.episodeId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _markRead();
      _startPolling();
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_polling || _loading || _error != null) return;
    _polling = true;
    try {
      final after = _messages.isEmpty ? null : _messages.last.id;
      final fresh = await ref.read(messagingRepositoryProvider).messages(widget.episodeId, after: after);
      if (!mounted || fresh.isEmpty) return;
      _merge(fresh);
      _markRead();
    } catch (_) {
      // Transient: the next tick retries; the banner is not worth the noise.
    } finally {
      _polling = false;
    }
  }

  void _merge(List<CareMessage> fresh) {
    final seen = {for (final m in _messages) m.id};
    final add = fresh.where((m) => !seen.contains(m.id)).toList();
    if (add.isEmpty) return;
    setState(() => _messages = [..._messages, ...add]);
    _scrollToEnd();
  }

  Future<void> _markRead() async {
    try {
      await ref.read(messagingRepositoryProvider).markRead(widget.episodeId);
      ref.invalidate(inboxProvider);
    } catch (_) {}
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await ref
          .read(messagingRepositoryProvider)
          .send(widget.episodeId, text, attachmentRecordId: _attachment?.id);
      if (!mounted) return;
      _input.clear();
      setState(() => _attachment = null);
      _merge([m]);
      // A safety system message may have been appended right after ours.
      await _poll();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment(String? patientId) async {
    final pid = patientId ?? (await ref.read(activePatientProvider.future)).id;
    if (!mounted) return;
    final r = await showModalBottomSheet<MedicalRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordPickerSheet(patientId: pid),
    );
    if (r != null && mounted) setState(() => _attachment = r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final thread = ref.watch(inboxProvider).value?.where((t) => t.careEpisodeId == widget.episodeId).firstOrNull;
    final myId = ref.watch(sessionProvider).me?.id;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(thread?.title ?? l.careTeamMessages, overflow: TextOverflow.ellipsis),
            if (thread != null)
              Text(thread.patientName, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.careEpisode,
            onPressed: () => context.push('/episodes/${widget.episodeId}'),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorStateView(error: _error!, onRetry: _load)
                    : _messages.isEmpty
                        ? EmptyStateView(
                            icon: Icons.forum_outlined, title: l.noMessagesYet, message: l.noMessagesYetBody)
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(Space.lg),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final m = _messages[i];
                              if (m.isEmergencyTemplate) return EmergencyMessageCard(message: m);
                              if (m.isSystem) return SystemMessageCard(message: m);
                              return MessageBubble(
                                  message: m, mine: m.senderUserId != null && m.senderUserId == myId);
                            },
                          ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            attachment: _attachment,
            enabled: !_loading && _error == null,
            onAttach: () => _pickAttachment(thread?.patientId),
            onClearAttachment: () => setState(() => _attachment = null),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});
  final CareMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = message;
    final bg = mine ? AppColors.primary : context.surface;
    final fg = mine ? Colors.white : context.textStrong;
    final role = senderRoleLabel(l, m.senderRole);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Semantics(
          container: true,
          label: mine ? l.youSaid(m.text) : l.senderSaid('${m.senderName}, $role', m.text),
          child: ExcludeSemantics(
            child: Container(
              margin: const EdgeInsets.only(bottom: Space.sm),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
                border: mine ? null : Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(m.senderName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          StatusPill(label: role, color: senderRoleColor(m.senderRole)),
                        ],
                      ),
                    ),
                  Text(m.text, style: TextStyle(color: fg, height: 1.35)),
                  if (m.attachmentRecordId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ActionChip(
                        avatar: Icon(Icons.attach_file, size: 16, color: mine ? context.brand : null),
                        label: Text(l.attachedRecord),
                        onPressed: () => context.push('/records/${m.attachmentRecordId}'),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(fmtTime(context, m.createdAt),
                        style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : context.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SystemMessageCard extends StatelessWidget {
  const SystemMessageCard({super.key, required this.message});
  final CareMessage message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: context.skySurface,
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.skyFg),
              const SizedBox(width: 8),
              Expanded(child: Text(message.text, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      );
}

/// The fixed 108 safety template (§34), always shown in red with a call action.
class EmergencyMessageCard extends StatelessWidget {
  const EmergencyMessageCard({super.key, required this.message});
  final CareMessage message;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const Key('emergency-message'),
        margin: const EdgeInsets.symmetric(vertical: Space.sm),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.dangerBgTop, AppColors.dangerBgBottom]),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.emergencyAlertTitle,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(message.text, style: const TextStyle(color: Colors.white, height: 1.4)),
            const SizedBox(height: Space.md),
            FilledButton.icon(
              key: const Key('emergency-call-108'),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.danger),
              onPressed: () => openExternal(context, telUri(AppConfig.emergencyHelpline)),
              icon: const Icon(Icons.call),
              label: Text(l.call108),
            ),
            const SizedBox(height: Space.sm),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
              onPressed: () => context.push('/sos'),
              child: Text(l.openSos),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.attachment,
    required this.enabled,
    required this.onAttach,
    required this.onClearAttachment,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final MedicalRecord? attachment;
  final bool enabled;
  final VoidCallback onAttach;
  final VoidCallback onClearAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canSend = enabled && !sending && controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, Space.sm),
        decoration: BoxDecoration(
          color: context.surface,
          border: Border(top: BorderSide(color: context.borderColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachment != null)
              Padding(
                padding: const EdgeInsets.only(left: Space.sm, bottom: Space.xs),
                child: InputChip(
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  label: Text(attachment!.title, overflow: TextOverflow.ellipsis),
                  onDeleted: onClearAttachment,
                  deleteButtonTooltipMessage: l.remove,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l.attachRecord,
                  onPressed: enabled && !sending ? onAttach : null,
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('thread-input'),
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: l.messageHint,
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  key: const Key('thread-send'),
                  tooltip: l.send,
                  onPressed: canSend ? onSend : null,
                  icon: sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.sm, 2, Space.sm, 0),
              child: Text(l.messagingNotForEmergencies, style: TextStyle(fontSize: 11, color: context.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks one of the patient's existing records to attach.
class RecordPickerSheet extends ConsumerWidget {
  const RecordPickerSheet({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: FutureBuilder<List<MedicalRecord>>(
          future: ref.read(recordsRepositoryProvider).list(patientId),
          builder: (context, snap) {
            Widget body;
            if (snap.hasError) {
              body = ErrorStateView(error: snap.error!, compact: true);
            } else if (!snap.hasData) {
              body = const LoadingView(compact: true);
            } else if (snap.data!.isEmpty) {
              body = EmptyStateView(compact: true, icon: Icons.folder_open, title: l.noRecordsTitle);
            } else {
              body = ListView(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                children: [
                  for (final r in snap.data!)
                    ListRowTile(
                      icon: Labels.recordIcon(r.type),
                      accent: Labels.recordAccent(r.type),
                      title: r.title,
                      subtitle: [fmtYmd(context, r.recordDate), Labels.recordType(l, r.type)].join(' • '),
                      onTap: () => Navigator.of(context).pop(r),
                    ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
                  child: Text(l.attachRecord, style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}
