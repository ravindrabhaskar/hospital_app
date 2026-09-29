import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// Bottom navigation: Today, Patients, Messages, More.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: OfflineBanner()),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            key: const Key('nav.today'),
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l.navToday,
          ),
          NavigationDestination(
            key: const Key('nav.patients'),
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l.navPatients,
          ),
          NavigationDestination(
            key: const Key('nav.messages'),
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: l.navMessages,
          ),
          NavigationDestination(
            key: const Key('nav.more'),
            icon: const Icon(Icons.menu),
            selectedIcon: const Icon(Icons.menu_open),
            label: l.navMore,
          ),
        ],
      ),
    );
  }
}
