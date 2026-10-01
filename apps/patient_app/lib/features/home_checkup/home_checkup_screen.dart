import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/data_providers.dart';

class HomeCheckupScreen extends ConsumerWidget {
  const HomeCheckupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.qaHomeCheckup),
        actions: [
          IconButton(
            tooltip: l.myVisits,
            onPressed: () => context.go('/care?tab=visits'),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                const _HeroIllustration(),
                const SizedBox(height: Space.lg),
                Text(l.homeCheckupTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(l.homeCheckupSubtitle, style: TextStyle(color: context.textMuted)),
                const SizedBox(height: Space.lg),
                AsyncView<List<HomeVisitService>>(
                  value: ref.watch(homeVisitServicesProvider),
                  compact: true,
                  onRetry: () => ref.invalidate(homeVisitServicesProvider),
                  isEmpty: (l) => l.isEmpty,
                  empty: EmptyStateView(compact: true, title: l.noServices),
                  data: (list) => Column(
                    children: [
                      for (final s in list)
                        ListRowTile(
                          icon: Labels.homeServiceIcon(s.code),
                          title: s.name,
                          subtitle: '${s.description}\n${money(s.price)} · ${l.durationMins(s.durationMins)}',
                          onTap: () => context.push('/home-checkup/book?service=${s.code}'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
              child: PrimaryButton(
                label: l.bookHomeCheckup,
                onPressed: () => context.push('/home-checkup/book'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.card),
          gradient: const LinearGradient(
            colors: [AppColors.mint100, Color(0xFFF7E6EE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), shape: BoxShape.circle),
                child: Icon(Icons.medical_services_rounded, size: 52, color: context.brand),
              ),
            ),
            Positioned(
              right: 28,
              bottom: 22,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), shape: BoxShape.circle),
                child: const Icon(Icons.elderly_rounded, size: 50, color: AppColors.peachFg),
              ),
            ),
            const Positioned(
              right: 140,
              top: 40,
              child: Icon(Icons.favorite, color: AppColors.roseFg, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
