import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/illustrations.dart';
import '../emergency/fall_monitor.dart';
import '../wearables/wearable_resume_sync.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _go(int i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Foreground-only device features (fall detection, wearable resume-sync).
      body: FallDetectionHost(child: WearableResumeSync(child: navigationShell)),
      extendBody: false,
      bottomNavigationBar: CcBottomNav(index: navigationShell.currentIndex, onTap: _go),
    );
  }
}

/// Bottom navigation with the raised circular "Ask AI" centre button.
class CcBottomNav extends StatelessWidget {
  const CcBottomNav({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [BoxShadow(color: Color(0x140B5D45), blurRadius: 20, offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 76,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: l.navHome,
                selected: index == 0,
                onTap: () => onTap(0)),
            _NavItem(
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                label: l.navCare,
                selected: index == 1,
                onTap: () => onTap(1)),
            Expanded(child: _AskAiButton(selected: index == 2, onTap: () => onTap(2))),
            _NavItem(
                icon: Icons.description_outlined,
                activeIcon: Icons.description,
                label: l.navRecords,
                selected: index == 3,
                onTap: () => onTap(3)),
            _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: l.navProfile,
                selected: index == 4,
                onTap: () => onTap(4)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 26),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AskAiButton extends StatelessWidget {
  const _AskAiButton({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.navAskAi;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: OverflowBox(
          maxHeight: 110,
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: context.surface, width: 4),
                    boxShadow: Shadows.raised,
                  ),
                  child: const Center(child: EcgIcon(size: 30)),
                ),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.primary : context.textStrong)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
