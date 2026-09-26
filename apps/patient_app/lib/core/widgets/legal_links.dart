import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/core_providers.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import '../utils/links.dart';

/// "Privacy policy · Terms of use" links from `PublicConfig.legal` (§21).
/// Renders nothing when the server has not provided the URLs.
class LegalLinks extends ConsumerWidget {
  const LegalLinks({super.key, this.center = true});
  final bool center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final legal = ref.watch(publicConfigProvider).legal;
    final links = <(String, String)>[
      if (legal.privacyUrl.isNotEmpty) (l.consentPrivacy, legal.privacyUrl),
      if (legal.termsUrl.isNotEmpty) (l.consentTerms, legal.termsUrl),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < links.length; i++) ...[
          if (i > 0) Text('·', style: TextStyle(color: context.textMuted)),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 40),
              textStyle: const TextStyle(fontSize: 12.5, decoration: TextDecoration.underline),
            ),
            onPressed: () => openExternal(context, Uri.parse(links[i].$2)),
            child: Text(links[i].$1),
          ),
        ],
      ],
    );
  }
}
