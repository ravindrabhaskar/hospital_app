import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/clinical.dart';
import '../../models/messaging.dart';
import '../common/file_viewer.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// A care-team thread (contract §34). Polls every 10 s while open using
/// `?after=<last id>`; `emergency_notice` messages are styled red.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.episodeId, this.title});
  final String episodeId;
  final String? title;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _text = TextEditingController();
  List<ChatMessage> _messages = const [];
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _load();
    _poll = Timer.periodic(AppConfig.messagePollInterval, (_) => _fetchNew());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(clinicianRepositoryProvider).messages(widget.episodeId);
      if (!mounted) return;
      setState(() => _messages = items);
      _markRead();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchNew() async {
    if (_loading || _error != null) return;
    try {
      final after = _messages.isEmpty ? null : _messages.last.id;
      final items = await ref.read(clinicianRepositoryProvider).messages(widget.episodeId, after: after);
      if (!mounted || items.isEmpty) return;
      setState(() => _messages = mergeMessages(_messages, items));
      _markRead();
    } catch (_) {
      // Transient: the next tick tries again.
    }
  }

  void _markRead() {
    ref.read(clinicianRepositoryProvider).markRead(widget.episodeId).catchError((_) {});
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await ref.read(clinicianRepositoryProvider).sendMessage(widget.episodeId, text);
      if (!mounted) return;
      _text.clear();
      setState(() => _messages = mergeMessages(_messages, [m]));
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context.l10n, e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(authControllerProvider).me?.id;
    Widget body;
    if (_loading && _messages.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _messages.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_messages.isEmpty) {
      body = EmptyView(message: l.noMessagesYet, icon: Icons.forum_outlined);
    } else {
      body = ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(AppSpacing.screen),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final m = _messages[_messages.length - 1 - i];
          return MessageBubble(message: m, mine: me != null && m.senderUserId == me);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l.careTeamThread, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('messageField'),
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: InputDecoration(hintText: l.messageHint, counterText: ''),
                    ),
                  ),
                  IconButton(
                    key: const Key('messageSend'),
                    tooltip: l.send,
                    onPressed: _text.text.trim().isEmpty || _sending ? null : _send,
                    icon: _sending
                        ? const ButtonSpinner(color: AppColors.primary)
                        : const Icon(Icons.send, color: AppColors.primary),
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

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = message;
    if (m.isEmergency) {
      return Semantics(
        container: true,
        label: '${l.emergencyNotice}: ${m.text}',
        excludeSemantics: true,
        child: Container(
          key: Key('emergency.${m.id}'),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.dangerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emergency, color: AppColors.dangerDeep),
                  const SizedBox(width: 6),
                  Text(
                    l.emergencyNotice,
                    style: const TextStyle(color: AppColors.dangerDeep, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                m.text,
                style: const TextStyle(color: AppColors.dangerDeep, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(formatDateTime(context, m.createdAt), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
    }
    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            m.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          key: Key('message.${m.id}'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  m.senderName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                ),
              Text(m.text, style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary)),
              if (m.attachmentRecordId != null) ...[
                const SizedBox(height: 6),
                AttachmentChip(key: Key('attachment.${m.id}'), recordId: m.attachmentRecordId!),
              ],
              const SizedBox(height: 2),
              Text(
                formatTime(context, m.createdAt),
                style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A record the sender attached (`attachmentRecordId`, contract §34),
/// fetched with `GET /records/:id`.
final attachmentRecordProvider = FutureProvider.autoDispose.family<MedicalRecord, String>(
  (ref, id) => ref.watch(clinicianRepositoryProvider).record(id),
);

/// Chip under a message: record title + type; tap opens the original file.
class AttachmentChip extends ConsumerWidget {
  const AttachmentChip({super.key, required this.recordId});
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final value = ref.watch(attachmentRecordProvider(recordId));
    final r = value.value;
    final String title;
    final String? subtitle;
    if (r != null) {
      title = r.title;
      subtitle = [recordTypeLabel(l, r.type), if (r.recordDate != null) formatIsoDate(context, r.recordDate)].join(' · ');
    } else if (value.hasError) {
      title = l.attachmentUnavailable;
      subtitle = null;
    } else {
      title = l.attachedRecord;
      subtitle = null;
    }
    final repo = ref.read(clinicianRepositoryProvider);
    VoidCallback? onTap;
    if (r != null) {
      onTap = r.hasFile
          ? () => openFile(
              context,
              title: r.title,
              mimeType: r.mimeType ?? 'application/pdf',
              load: () => repo.recordFile(r.id),
            )
          : () => showSnack(context, l.attachmentNoFile);
    } else if (value.hasError) {
      onTap = () => ref.invalidate(attachmentRecordProvider(recordId));
    }
    return Semantics(
      button: onTap != null,
      label: [l.attachedRecord, title, ?subtitle].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.mint50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    r?.isImage == true ? Icons.image_outlined : Icons.description_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (r != null && r.hasFile) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                  ] else if (r == null && !value.hasError) ...[
                    const SizedBox(width: 6),
                    const ButtonSpinner(color: AppColors.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
