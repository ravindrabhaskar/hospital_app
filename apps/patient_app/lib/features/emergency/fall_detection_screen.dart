import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import 'fall_monitor.dart';
import 'sos_screen.dart' show callHelpline;

/// Client-side countdown before we tell the user contacts are being alerted.
/// The server independently auto-escalates after FALL_RESPONSE_TIMEOUT_SEC.
const fallCountdownSeconds = 30;

class FallDetectionScreen extends ConsumerStatefulWidget {
  const FallDetectionScreen({super.key});

  @override
  ConsumerState<FallDetectionScreen> createState() => _FallDetectionScreenState();
}

class _FallDetectionScreenState extends ConsumerState<FallDetectionScreen> {
  bool _busy = false;

  Future<void> _simulate() async {
    setState(() => _busy = true);
    try {
      final p = await ref.read(activePatientProvider.future);
      final loc = await tryGetLocation(timeout: const Duration(seconds: 3));
      final ev = await ref
          .read(safetyRepositoryProvider)
          .reportFall(p.id, source: 'phone_sensor', lat: loc?.lat, lng: loc?.lng);
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => FallCheckScreen(event: ev)),
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.qxFallDetection)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          const Center(child: IconTile(icon: Icons.directions_run, accent: Accent.teal, size: 96)),
          const SizedBox(height: Space.lg),
          Text(l.fallTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.sm),
          Text(l.fallBody, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
          const SizedBox(height: Space.xl),
          if (ref.watch(featureFlagsProvider).fallDetection) ...[
            const FallDetectionToggle(),
            const SizedBox(height: Space.lg),
          ],
          CcCard(
            child: Column(
              children: [
                ListRowTile(icon: Icons.sensors, title: l.fallStep1),
                ListRowTile(icon: Icons.timer_outlined, accent: Accent.peach, title: l.fallStep2),
                ListRowTile(icon: Icons.notifications_active_outlined, accent: Accent.rose, title: l.fallStep3),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          ListRowTile(
            icon: Icons.contact_phone_outlined,
            accent: Accent.sky,
            title: l.emergencyContacts,
            subtitle: l.fallContactsHint,
            onTap: () => context.push('/profile/emergency-contacts'),
          ),
          ListRowTile(
            icon: Icons.watch_outlined,
            accent: Accent.lavender,
            title: l.qxWearables,
            subtitle: l.fallWearableHint,
            onTap: () => context.push('/wearables'),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(label: l.simulateFall, icon: Icons.science_outlined, loading: _busy, onPressed: _simulate),
          const SizedBox(height: Space.sm),
          Text(l.simulateFallNote,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}

/// Full-screen "Are you OK?" check with a countdown.
class FallCheckScreen extends ConsumerStatefulWidget {
  const FallCheckScreen({super.key, required this.event});
  final FallEvent event;

  @override
  ConsumerState<FallCheckScreen> createState() => _FallCheckScreenState();
}

class _FallCheckScreenState extends ConsumerState<FallCheckScreen> {
  int _left = fallCountdownSeconds;
  Timer? _timer;
  bool _busy = false;
  String? _outcome; // 'safe' | 'help' | 'timeout'

  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        setState(() => _outcome = 'timeout');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _respond(bool safe) async {
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      await ref.read(safetyRepositoryProvider).respondFall(widget.event.id, safe);
      if (mounted) setState(() => _outcome = safe ? 'safe' : 'help');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final danger = _outcome != 'safe';
    return Scaffold(
      backgroundColor: danger ? AppColors.dangerBgBottom : AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(_outcome == 'safe' ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: Colors.white, size: 80),
              const SizedBox(height: Space.lg),
              Semantics(
                liveRegion: true,
                child: Text(
                  switch (_outcome) {
                    'safe' => l.fallGladSafe,
                    'help' => l.fallHelpComing,
                    'timeout' => l.fallNoResponse,
                    _ => l.areYouOk,
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: Space.md),
              if (_outcome == null) ...[
                Text(l.fallDetectedBody,
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: Space.xl),
                Text('$_left',
                    semanticsLabel: l.secondsLeft(_left),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800)),
              ],
              const Spacer(),
              if (_outcome == null) ...[
                PrimaryButton(
                  label: l.imOk,
                  color: Colors.white,
                  foreground: AppColors.primary,
                  loading: _busy,
                  onPressed: () => _respond(true),
                ),
                const SizedBox(height: Space.md),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2)),
                  onPressed: _busy ? null : () => _respond(false),
                  child: Text(l.needHelp),
                ),
              ] else ...[
                if (_outcome != 'safe') ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.danger),
                    onPressed: () => callHelpline(),
                    icon: const Icon(Icons.call),
                    label: Text(l.call108),
                  ),
                  const SizedBox(height: Space.md),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/sos');
                    },
                    child: Text(l.openSos),
                  ),
                  const SizedBox(height: Space.md),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.close, style: const TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Opt-in switch for on-device (foreground-only) fall detection (§40).
class FallDetectionToggle extends ConsumerWidget {
  const FallDetectionToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final on = ref.watch(fallDetectionOptInProvider);
    final platform = ref.watch(appPlatformProvider);
    final supported = !kIsWeb && (platform == 'android' || platform == 'ios');
    return CcCard(
      key: const Key('fall-toggle-card'),
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const Key('fall-toggle'),
            value: on && supported,
            onChanged: supported ? (v) => ref.read(fallDetectionOptInProvider.notifier).set(v) : null,
            secondary: Icon(Icons.sensors, color: context.brand),
            title: Text(l.fallDetectToggle, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(supported ? (on ? l.fallDetectOn : l.fallDetectOff) : l.fallDetectUnsupported),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Note(icon: Icons.phone_android, text: l.fallForegroundOnly),
                const SizedBox(height: 6),
                _Note(icon: Icons.medical_information_outlined, text: l.fallNotMedicalDevice),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: context.textMuted))),
        ],
      );
}
