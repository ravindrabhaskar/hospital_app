import 'package:care_companion_doctor/bootstrap.dart';
import 'package:care_companion_patient/bootstrap.dart';
import 'package:care_companion_provider/bootstrap.dart';
import 'package:flutter/material.dart';

import 'chooser_screen.dart';
import 'role_store.dart';
import 'roles.dart';

/// Builds one bundled app. [storagePrefix] isolates its storage; [onSwitchApp]
/// adds its "Switch app" entry (Profile / More).
typedef AppBuilder = Future<Widget> Function({required String storagePrefix, required VoidCallback onSwitchApp});

/// The real apps, through their public bootstraps.
final Map<DemoRole, AppBuilder> defaultAppBuilders = {
  DemoRole.patient: ({required storagePrefix, required onSwitchApp}) =>
      buildPatientApp(storagePrefix: storagePrefix, onSwitchApp: onSwitchApp),
  DemoRole.provider: ({required storagePrefix, required onSwitchApp}) =>
      buildProviderApp(storagePrefix: storagePrefix, onSwitchApp: onSwitchApp),
  DemoRole.doctor: ({required storagePrefix, required onSwitchApp}) =>
      buildDoctorApp(storagePrefix: storagePrefix, onSwitchApp: onSwitchApp),
};

/// Root widget: the role chooser, or the chosen app running exactly as its
/// standalone build does (its own MaterialApp, router, theme, l10n, API
/// client, push and force-update logic), with its storage namespaced.
class AllInOneRoot extends StatefulWidget {
  const AllInOneRoot({super.key, required this.store, this.initialRole, this.builders = const {}});

  final RoleStore store;

  /// Opened straight away (a remembered choice, or a Health Connect launch).
  final DemoRole? initialRole;

  /// Overrides entries of [defaultAppBuilders] (tests).
  final Map<DemoRole, AppBuilder> builders;

  @override
  State<AllInOneRoot> createState() => _AllInOneRootState();
}

class _AllInOneRootState extends State<AllInOneRoot> {
  DemoRole? _role;
  Future<Widget>? _app;

  /// Bumped on every launch so a re-opened app gets a brand-new element tree
  /// (and a fresh ProviderScope) instead of reusing the previous one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRole;
    if (initial != null) _launch(initial);
  }

  void _launch(DemoRole role) {
    final builder = widget.builders[role] ?? defaultAppBuilders[role]!;
    _role = role;
    _generation++;
    _app = builder(storagePrefix: role.storagePrefix, onSwitchApp: _switchApp);
  }

  Future<void> _choose(DemoRole role, bool remember) async {
    if (remember) {
      await widget.store.remember(role);
    } else {
      await widget.store.forget();
    }
    if (!mounted) return;
    setState(() => _launch(role));
  }

  /// "Switch app": forget the remembered choice and go back to the chooser.
  /// The running app's tree (and its ProviderScope) is disposed.
  Future<void> _switchApp() async {
    await widget.store.forget();
    if (!mounted) return;
    setState(() {
      _role = null;
      _app = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = _role;
    final app = _app;
    if (role == null || app == null) {
      return RoleChooserApp(onChoose: _choose);
    }
    return FutureBuilder<Widget>(
      key: ValueKey('${role.id}#$_generation'),
      future: app,
      builder: (context, snap) {
        if (snap.hasData) return KeyedSubtree(key: ValueKey('app.${role.id}#$_generation'), child: snap.data!);
        return LaunchingApp(role: role, error: snap.error, onBack: _switchApp);
      },
    );
  }
}
