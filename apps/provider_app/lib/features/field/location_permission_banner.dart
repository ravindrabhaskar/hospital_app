import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location_permission.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/l10n_helpers.dart';

/// In-app rationale shown before the system location prompt. Returns true
/// when the provider chose to continue.
Future<bool> showLocationRationale(BuildContext context) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('locationRationale'),
      icon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
      title: Text(l.locRationaleTitle),
      content: SingleChildScrollView(child: Text(l.locRationaleBody)),
      actions: [
        TextButton(
          key: const Key('locationNotNow'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.locRationaleNotNow),
        ),
        FilledButton(
          key: const Key('locationContinue'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.locRationaleAllow),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void _showDenied(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(key: const Key('locationDeniedSnack'), content: Text(text), duration: const Duration(seconds: 6)));
}

/// One-time automatic ask (Home, after sign-in): rationale first, then the
/// system prompt. A refusal shows a non-blocking message and is remembered,
/// so the app does not ask again on every launch.
Future<void> maybePromptForLocation(BuildContext context, WidgetRef ref) async {
  final access = ref.read(locationAccessProvider);
  if (!await access.shouldAutoPrompt() || !context.mounted) return;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final go = await showLocationRationale(context);
  await access.markAsked();
  if (!go) {
    _showDenied(messenger, l.locDeniedMessage);
    return;
  }
  final result = await access.requestFromUser();
  if (result != LocationAccess.granted) _showDenied(messenger, l.locDeniedMessage);
}

/// "Turn on location" (Route tab banner, Profile).
Future<void> turnOnLocation(BuildContext context, WidgetRef ref) async {
  final access = ref.read(locationAccessProvider);
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (access.access == LocationAccess.denied) {
    final go = await showLocationRationale(context);
    if (!go) return;
  }
  final result = await access.requestFromUser();
  if (result == LocationAccess.deniedForever) {
    _showDenied(messenger, l.locBlocked);
  } else if (result == LocationAccess.denied) {
    _showDenied(messenger, l.locDeniedMessage);
  }
}

/// "Location is off" banner with a "Turn on location" action. Hidden when
/// location is allowed (or its state is unknown).
class LocationPermissionBanner extends ConsumerStatefulWidget {
  const LocationPermissionBanner({super.key});

  @override
  ConsumerState<LocationPermissionBanner> createState() => _LocationPermissionBannerState();
}

class _LocationPermissionBannerState extends ConsumerState<LocationPermissionBanner> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    ref.read(locationAccessProvider).refresh();
    // Back from the system Settings: pick up the new state.
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(locationAccessProvider).refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final access = ref.watch(locationAccessProvider);
    return ListenableBuilder(
      listenable: access,
      builder: (context, _) {
        if (!access.needsAction) return const SizedBox.shrink();
        final text = switch (access.access) {
          LocationAccess.serviceOff => l.locServiceOff,
          LocationAccess.deniedForever => l.locBlocked,
          _ => l.locOffBanner,
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            key: const Key('locationOffBanner'),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
              border: Border.all(color: AppColors.warning),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_off_outlined, color: Color(0xFF9A5A10)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text)),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const Key('locationTurnOn'),
                    onPressed: () => turnOnLocation(context, ref),
                    child: Text(access.access == LocationAccess.denied ? l.locTurnOn : l.locOpenSettings),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
