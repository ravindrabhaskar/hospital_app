import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/engagement_v13.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';

/// Profile → Notifications: the WhatsApp assistant opt-in (§43).
class WhatsappAssistantCard extends ConsumerStatefulWidget {
  const WhatsappAssistantCard({super.key});

  @override
  ConsumerState<WhatsappAssistantCard> createState() => _WhatsappAssistantCardState();
}

class _WhatsappAssistantCardState extends ConsumerState<WhatsappAssistantCard> {
  WhatsappStatus? _local;
  bool _saving = false;

  Future<void> _toggle(bool v) async {
    setState(() => _saving = true);
    try {
      final s = await ref.read(whatsappRepositoryProvider).setOptIn(v);
      if (!mounted) return;
      setState(() => _local = s);
      showSnack(context, v ? context.l10n.whatsappOptedIn : context.l10n.whatsappOptedOut);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!ref.watch(featureFlagsProvider).whatsappAssistant) return const SizedBox.shrink();
    final v = ref.watch(whatsappStatusProvider);
    return CcCard(
      key: const Key('whatsapp-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.chat_outlined, accent: Accent.teal, size: 44),
              const SizedBox(width: Space.md),
              Expanded(child: Text(l.whatsappAssistant, style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(l.whatsappExplain, style: TextStyle(color: context.textMuted)),
          const SizedBox(height: Space.sm),
          AsyncView<WhatsappStatus>(
            value: v,
            compact: true,
            onRetry: () => ref.invalidate(whatsappStatusProvider),
            data: (server) {
              final s = _local ?? server;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const Key('whatsapp-toggle'),
                    contentPadding: EdgeInsets.zero,
                    value: s.optedIn,
                    title: Text(l.whatsappOptIn),
                    subtitle: s.phone.isEmpty ? null : Text(s.phone),
                    onChanged: _saving ? null : _toggle,
                  ),
                  Text(l.whatsappPrivacyNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
                  const SizedBox(height: Space.sm),
                  OutlinedButton.icon(
                    key: const Key('whatsapp-try'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const WhatsappCommandsSheet(),
                    ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(l.whatsappTryIt),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Try it": the commands the assistant understands.
class WhatsappCommandsSheet extends StatelessWidget {
  const WhatsappCommandsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final commands = [
      ('TODAY', l.waCmdToday),
      ('CHECKIN', l.waCmdCheckin),
      ('BP 138/88', l.waCmdBp),
      ('SUGAR 142', l.waCmdSugar),
      ('BOOK', l.waCmdBook),
      ('STOP', l.waCmdStop),
      ('START', l.waCmdStart),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.whatsappTryIt, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.sm),
              Text(l.whatsappTryIntro, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.md),
              for (final (cmd, desc) in commands)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: context.mintSurface, borderRadius: BorderRadius.circular(8)),
                    child: Text(cmd, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  ),
                  title: Text(desc),
                  trailing: IconButton(
                    tooltip: l.copyCommand(cmd),
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: cmd));
                      showSnack(context, l.copied);
                    },
                  ),
                ),
              const SizedBox(height: Space.sm),
              Text(l.whatsappNoDiagnosis, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
