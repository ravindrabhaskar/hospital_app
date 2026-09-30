import 'package:flutter/material.dart';

import 'roles.dart';

const _mint = Color(0xFFEEF7F2);
const _green = Color(0xFF0B5D45);

ThemeData _theme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _green, primary: _green, surface: Colors.white),
  scaffoldBackgroundColor: _mint,
  useMaterial3: true,
);

/// The role chooser shown on launch (unless a choice is remembered).
class RoleChooserApp extends StatelessWidget {
  const RoleChooserApp({super.key, required this.onChoose});

  final void Function(DemoRole role, bool remember) onChoose;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CareCompanion All-in-One',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: RoleChooserScreen(onChoose: onChoose),
  );
}

class RoleChooserScreen extends StatefulWidget {
  const RoleChooserScreen({super.key, required this.onChoose});

  final void Function(DemoRole role, bool remember) onChoose;

  @override
  State<RoleChooserScreen> createState() => _RoleChooserScreenState();
}

class _RoleChooserScreenState extends State<RoleChooserScreen> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // A short, fixed list: a Column keeps every card built (and findable).
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Welcome to CareCompanion',
                      style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: _green),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Who are you? Pick the app to open.', style: text.bodyLarge),
                  const SizedBox(height: 20),
                  for (final role in DemoRole.values) ...[
                    RoleCard(role: role, onTap: () => widget.onChoose(role, _remember)),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      key: const Key('rememberChoice'),
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v),
                      title: const Text('Remember my choice'),
                      subtitle: const Text(
                        'Open that app directly next time. "Switch app" in Profile / More brings you back here.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Demo build: the three CareCompanion apps in one. Each keeps its own sign-in and data.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large tappable card for one role, in that app's brand colour and icon.
class RoleCard extends StatelessWidget {
  const RoleCard({super.key, required this.role, required this.onTap});

  final DemoRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: Key('role.${role.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: role.color, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  role.asset,
                  width: 64,
                  height: 64,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: role.color),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.headline, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(role.appName, style: text.labelLarge?.copyWith(color: role.color)),
                    const SizedBox(height: 6),
                    Text(role.description, style: text.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: role.color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while an app's bootstrap runs (normally a split second), or if it failed.
class LaunchingApp extends StatelessWidget {
  const LaunchingApp({super.key, required this.role, this.error, required this.onBack});

  final DemoRole role;
  final Object? error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(role.asset, width: 96, height: 96, errorBuilder: (_, _, _) => const SizedBox(height: 96)),
              const SizedBox(height: 24),
              if (error == null) ...[
                CircularProgressIndicator(color: role.color),
                const SizedBox(height: 16),
                Text('Opening ${role.appName}…'),
              ] else ...[
                Text('${role.appName} could not start.', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onBack, child: const Text('Back to the app chooser')),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
