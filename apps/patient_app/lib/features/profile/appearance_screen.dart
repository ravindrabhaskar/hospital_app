import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../l10n/app_localizations.dart';
import '../../state/core_providers.dart';

String themeModeLabel(AppLocalizations l, ThemeMode m) => switch (m) {
      ThemeMode.system => l.themeSystem,
      ThemeMode.light => l.themeLight,
      ThemeMode.dark => l.themeDark,
    };

/// Profile → Appearance: System / Light / Dark (persisted).
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.appearance)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          CcCard(
            padding: EdgeInsets.zero,
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (m) {
                if (m != null) ref.read(themeModeProvider.notifier).set(m);
              },
              child: Column(
                children: [
                  for (final m in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      key: Key('theme-${m.name}'),
                      value: m,
                      title: Text(themeModeLabel(l, m)),
                      subtitle: m == ThemeMode.system ? Text(l.themeSystemSub) : null,
                      secondary: Icon(switch (m) {
                        ThemeMode.system => Icons.brightness_auto_outlined,
                        ThemeMode.light => Icons.light_mode_outlined,
                        ThemeMode.dark => Icons.dark_mode_outlined,
                      }),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
