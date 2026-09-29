import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale_controller.dart';
import '../../core/providers.dart';
import '../../ui/l10n_helpers.dart';

/// App language (en / hi / te). Also saved to the profile (`PATCH /me`) so
/// server-generated text follows it.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.watch(localeControllerProvider);
    final current = c.locale?.languageCode ?? Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.languageTitle)),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => RadioGroup<String>(
          groupValue: current,
          onChanged: (code) async {
            if (code == null) return;
            await c.setLocale(code);
            ref.read(apiClientProvider).languageCode = code;
            try {
              await ref.read(authRepositoryProvider).updateLanguage(code);
            } catch (_) {}
          },
          child: ListView(
            children: [
              for (final code in LocaleController.supported)
                RadioListTile<String>(
                  key: Key('lang.$code'),
                  value: code,
                  title: Text(LocaleController.nativeName(code)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
