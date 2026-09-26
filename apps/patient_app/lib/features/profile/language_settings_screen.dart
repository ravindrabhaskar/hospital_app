import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../state/core_providers.dart';
import '../onboarding/language_screen.dart' show LanguageOptionTile, languageOptions;

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  Future<void> _set(BuildContext context, WidgetRef ref, String code) async {
    final previous = ref.read(localeProvider).languageCode;
    await ref.read(localeProvider.notifier).set(code);
    try {
      final me = await ref.read(authRepositoryProvider).updateMe(language: code);
      ref.read(sessionProvider.notifier).updateMe(me);
    } on ApiException catch (e) {
      // Keep the local choice working offline but tell the user the server did not save it.
      if (context.mounted && !e.isOffline) {
        await ref.read(localeProvider.notifier).set(previous);
      }
      if (context.mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(localeProvider).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.language)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          Text(l.languageSettingsSub, style: TextStyle(color: context.textMuted)),
          const SizedBox(height: Space.lg),
          for (final (code, native, english) in languageOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: LanguageOptionTile(
                native: native,
                english: english,
                selected: current == code,
                onTap: () => _set(context, ref, code),
              ),
            ),
          const SizedBox(height: Space.sm),
          Text(l.medicalTermsNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}
