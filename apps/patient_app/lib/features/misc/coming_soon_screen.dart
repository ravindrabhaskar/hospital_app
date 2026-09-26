import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/state_views.dart';

enum ComingSoonKind { govtSchemes, feature }

/// Shown for features that are switched off by a server flag (§21).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.kind, this.title});
  final ComingSoonKind kind;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final heading = switch (kind) {
      ComingSoonKind.govtSchemes => l.qxGovtSchemes,
      ComingSoonKind.feature => title ?? l.comingSoon,
    };
    return Scaffold(
      appBar: AppBar(title: Text(heading)),
      body: EmptyStateView(
        icon: kind == ComingSoonKind.govtSchemes ? Icons.account_balance_outlined : Icons.hourglass_empty,
        title: l.comingSoon,
        message: kind == ComingSoonKind.govtSchemes ? l.govtSchemesComingSoon : l.featureUnavailable,
      ),
    );
  }
}
