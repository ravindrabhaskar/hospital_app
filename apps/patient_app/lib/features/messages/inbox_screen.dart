import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/engagement.dart';
import '../../state/data_providers.dart';

/// `/inbox`: one secure thread per care episode (§34).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.inbox)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(inboxProvider.future),
        child: AsyncView<List<InboxThread>>(
          value: ref.watch(inboxProvider),
          onRetry: () => ref.invalidate(inboxProvider),
          isEmpty: (list) => list.isEmpty,
          empty: ListView(children: [
            EmptyStateView(icon: Icons.forum_outlined, title: l.inboxEmpty, message: l.inboxEmptyBody),
          ]),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.all(Space.screen),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
            itemBuilder: (context, i) {
              if (i == list.length) {
                return Text(l.messagingNotForEmergencies,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textMuted));
              }
              return InboxThreadTile(thread: list[i]);
            },
          ),
        ),
      ),
    );
  }
}

class InboxThreadTile extends StatelessWidget {
  const InboxThreadTile({super.key, required this.thread});
  final InboxThread thread;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = thread;
    final unread = t.unread > 0;
    final preview = t.lastMessage == null
        ? l.noMessagesYet
        : [if (t.lastSenderName != null) '${t.lastSenderName}:', t.lastMessage!].join(' ');
    return CcCard(
      color: unread ? context.mintSurface : null,
      onTap: () => context.push('/care-episodes/${t.careEpisodeId}/messages'),
      semanticLabel: [t.title, t.patientName, preview, if (unread) l.unreadMessages(t.unread)].join('. '),
      child: ExcludeSemantics(
        child: Row(
          children: [
            const IconTile(icon: Icons.forum_outlined, accent: Accent.teal, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                      ),
                      if (t.lastAt != null)
                        Text(fmtDayMonth(context, t.lastAt!), style: TextStyle(fontSize: 11.5, color: context.textMuted)),
                    ],
                  ),
                  Text(t.patientName, style: TextStyle(fontSize: 12, color: context.textMuted)),
                  const SizedBox(height: 2),
                  Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              UnreadBadge(count: t.unread),
            ],
          ],
        ),
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(12)),
        child: Text(count > 99 ? '99+' : '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}
