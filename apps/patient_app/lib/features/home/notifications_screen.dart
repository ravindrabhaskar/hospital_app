import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/load_more.dart';
import '../../core/widgets/state_views.dart';
import '../../models/json.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

/// Deep links the app knows how to open (contract example: `/appointments/<id>`).
String? resolveDeepLink(String? link) {
  if (link == null || link.isEmpty) return null;
  // Care-team thread (§34): `/care-episodes/<id>/messages` opens the thread.
  if (RegExp(r'^/care-episodes/[^/]+/messages/?$').hasMatch(link)) {
    return link.endsWith('/') ? link.substring(0, link.length - 1) : link;
  }
  const known = [
    '/appointments/',
    '/home-visits/',
    '/episodes/',
    '/care-episodes/',
    '/records/',
    '/care-plans/',
    '/medications',
    '/prescriptions/',
    '/inbox',
    '/schemes',
    '/profile/family-plan',
  ];
  for (final k in known) {
    if (link.startsWith(k)) {
      return link.startsWith('/care-episodes/') ? link.replaceFirst('/care-episodes/', '/episodes/') : link;
    }
  }
  // `/payments/<id>/invoice`
  if (RegExp(r'^/payments/[^/]+/invoice$').hasMatch(link)) return link;
  return null;
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  (IconData, Accent) _style(String c) => switch (c) {
        'appointment' => (Icons.event_outlined, Accent.sky),
        'home_visit' => (Icons.home_outlined, Accent.rose),
        'medication' => (Icons.medication_outlined, Accent.peach),
        'care_plan' => (Icons.assignment_outlined, Accent.teal),
        'safety' => (Icons.warning_amber_rounded, Accent.rose),
        'record' => (Icons.description_outlined, Accent.lavender),
        'payment' => (Icons.payments_outlined, Accent.teal),
        _ => (Icons.notifications_none, Accent.sky),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationRepositoryProvider).markAllRead();
                ref.invalidate(notificationsProvider);
              } catch (e) {
                if (context.mounted) showSnack(context, errorMessage(context, e), error: true);
              }
            },
            child: Text(l.markAllRead),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
        child: AsyncView<NotificationPage>(
          value: v,
          onRetry: () => ref.invalidate(notificationsProvider),
          isEmpty: (p) => p.items.isEmpty,
          empty: EmptyStateView(
              icon: Icons.notifications_off_outlined, title: l.noNotifications),
          data: (page) => PagedItems<AppNotification>(
            first: page.items,
            nextCursor: page.nextCursor,
            fetch: (cursor) async {
              final p = await ref.read(notificationRepositoryProvider).list(cursor: cursor);
              return Page(p.items, p.nextCursor);
            },
            builder: (context, items, footer) => ListView.separated(
            padding: const EdgeInsets.all(Space.screen),
            itemCount: items.length + (footer == null ? 0 : 1),
            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
            itemBuilder: (context, i) {
              if (i == items.length) return footer!;
              final n = items[i];
              final (icon, accent) = _style(n.category);
              return CcCard(
                color: n.read ? null : context.mintSurface,
                borderColor: n.critical ? AppColors.danger : null,
                onTap: () async {
                  if (!n.read) {
                    try {
                      await ref.read(notificationRepositoryProvider).markRead(n.id);
                      ref.invalidate(notificationsProvider);
                    } catch (_) {}
                  }
                  final target = resolveDeepLink(n.deepLink);
                  if (target != null && context.mounted) context.push(target);
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(icon: icon, accent: accent, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title,
                              style: TextStyle(
                                  fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(n.body, style: TextStyle(color: context.textMuted)),
                          const SizedBox(height: 4),
                          Text(fmtDateTime(context, n.createdAt),
                              style: TextStyle(fontSize: 11.5, color: context.textMuted)),
                        ],
                      ),
                    ),
                    if (!n.read)
                      Semantics(
                        label: l.unread,
                        child: Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}
