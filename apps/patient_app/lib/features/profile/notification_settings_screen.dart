import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../whatsapp/whatsapp_card.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _State();
}

class _State extends ConsumerState<NotificationSettingsScreen> {
  NotificationPreferences? _local;
  bool _saving = false;

  Future<void> _toggle(NotificationPreferences base, String key, bool v) async {
    final next = base.copyWith(key, v);
    setState(() {
      _local = next;
      _saving = true;
    });
    try {
      final saved = await ref.read(notificationRepositoryProvider).savePreferences(next);
      if (mounted) setState(() => _local = saved);
    } catch (e) {
      if (mounted) {
        setState(() => _local = base);
        showSnack(context, errorMessage(context, e), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unread = ref.watch(notificationsProvider).value?.unreadCount ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(l.notifications)),
      body: AsyncView<NotificationPreferences>(
        value: ref.watch(notificationPrefsProvider),
        onRetry: () => ref.invalidate(notificationPrefsProvider),
        data: (server) {
          final p = _local ?? server;
          final rows = [
            ('push', l.prefPush, p.push),
            ('sms', l.prefSms, p.sms),
            ('whatsapp', l.prefWhatsapp, p.whatsapp),
            ('email', l.prefEmail, p.email),
            ('marketing', l.prefMarketing, p.marketing),
          ];
          return ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              ListRowTile(
                icon: Icons.notifications_none,
                title: l.allNotifications,
                subtitle: unread > 0 ? l.notificationsUnread(unread) : null,
                onTap: () => context.push('/notifications'),
              ),
              SectionHeader(title: l.channels),
              CcCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final r in rows)
                      SwitchListTile(
                        value: r.$3,
                        title: Text(r.$2),
                        onChanged: _saving ? null : (v) => _toggle(p, r.$1, v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              const WhatsappAssistantCard(),
              const SizedBox(height: Space.md),
              Text(l.notificationPrivacyNote,
                  style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
          );
        },
      ),
    );
  }
}
