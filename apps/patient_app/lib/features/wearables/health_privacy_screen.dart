import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../state/core_providers.dart';

const healthPrivacyRoute = '/health-privacy';

/// Shown when Health Connect asks the app to explain its data use
/// (`ACTION_SHOW_PERMISSIONS_RATIONALE` / `VIEW_PERMISSION_USAGE`, routed by
/// MainActivity). Reachable without signing in.
class HealthPrivacyScreen extends ConsumerWidget {
  const HealthPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final privacyUrl = ref.watch(publicConfigProvider).legal.privacyUrl;
    final points = [l.healthPrivacyPoint1, l.healthPrivacyPoint2, l.healthPrivacyPoint3, l.healthPrivacyPoint4];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.healthDataPrivacy),
        leading: IconButton(
          tooltip: l.close,
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/splash'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          const Center(child: IconTile(icon: Icons.health_and_safety_outlined, accent: Accent.teal, size: 80)),
          const SizedBox(height: Space.lg),
          Text(l.healthPrivacyIntro, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.md),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p)),
                ],
              ),
            ),
          const SizedBox(height: Space.xl),
          if (privacyUrl.isNotEmpty)
            PrimaryButton(
              label: l.readPrivacyPolicy,
              icon: Icons.open_in_new,
              onPressed: () => openExternal(context, Uri.parse(privacyUrl)),
            ),
        ],
      ),
    );
  }
}
