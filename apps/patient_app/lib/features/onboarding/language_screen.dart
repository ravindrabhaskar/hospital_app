import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/illustrations.dart';
import '../../state/core_providers.dart';

/// Language choices shown in their own script so every user can find theirs.
const languageOptions = [
  ('en', 'English', 'English'),
  ('hi', 'हिन्दी', 'Hindi'),
  ('te', 'తెలుగు', 'Telugu'),
];

class LanguageSelectScreen extends ConsumerWidget {
  const LanguageSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(localeProvider).languageCode;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            const SizedBox(height: Space.xl),
            Center(child: RobotAssistant(size: 96, semanticLabel: l.robotSemantic)),
            const SizedBox(height: Space.xl),
            Text(l.chooseLanguageTitle,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Space.sm),
            Text(l.chooseLanguageSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.xxl),
            for (final (code, native, english) in languageOptions)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: LanguageOptionTile(
                  native: native,
                  english: english,
                  selected: current == code,
                  onTap: () => ref.read(localeProvider.notifier).set(code),
                ),
              ),
            const SizedBox(height: Space.xl),
            PrimaryButton(
              label: l.continueLabel,
              onPressed: () async {
                await ref.read(localeProvider.notifier).set(current);
                if (context.mounted) context.go('/auth/phone');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageOptionTile extends StatelessWidget {
  const LanguageOptionTile({
    super.key,
    required this.native,
    required this.english,
    required this.selected,
    required this.onTap,
  });
  final String native;
  final String english;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: CcCard(
        onTap: onTap,
        color: selected ? context.mintSurface : null,
        borderColor: selected ? AppColors.primary : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(native, style: Theme.of(context).textTheme.titleMedium),
                  Text(english, style: TextStyle(color: context.textMuted)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : context.textMuted),
          ],
        ),
      ),
    );
  }
}
