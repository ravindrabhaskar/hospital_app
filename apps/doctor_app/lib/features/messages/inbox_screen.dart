import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/messaging.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

final inboxProvider = FutureProvider.autoDispose<List<InboxThread>>(
  (ref) => ref.watch(clinicianRepositoryProvider).inbox(),
);

/// Care-team inbox (contract §34): one thread per care episode.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Semantics(header: true, child: Text(l.navMessages))),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(inboxProvider.future),
        child: AsyncBody<List<InboxThread>>(
          value: ref.watch(inboxProvider),
          onRetry: () => ref.invalidate(inboxProvider),
          data: (items) => items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: 360,
                      child: EmptyView(message: l.inboxEmpty, icon: Icons.forum_outlined),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => gap8,
                  itemBuilder: (context, i) {
                    final t = items[i];
                    return Card(
                      child: ListTile(
                        key: Key('thread.${t.careEpisodeId}'),
                        minVerticalPadding: 12,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.mint100,
                          child: Icon(Icons.forum_outlined, color: AppColors.primary),
                        ),
                        title: Text('${t.patientName} · ${t.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          t.lastMessage == null
                              ? l.noMessagesYet
                              : '${t.lastSenderName == null ? '' : '${t.lastSenderName}: '}${t.lastMessage}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatTime(context, t.lastAt), style: const TextStyle(fontSize: 12)),
                            if (t.unread > 0)
                              Semantics(
                                label: l.unreadCount(t.unread),
                                excludeSemantics: true,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('${t.unread}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await context.push('/messages/${t.careEpisodeId}', extra: '${t.patientName} · ${t.title}');
                          ref.invalidate(inboxProvider);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
