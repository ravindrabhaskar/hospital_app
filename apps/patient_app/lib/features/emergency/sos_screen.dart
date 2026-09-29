import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/state_views.dart';
import '../../models/doctor.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import '../facilities/facilities_screen.dart' show openDirections;

Future<void> callHelpline([String number = AppConfig.emergencyHelpline]) =>
    launchUrl(Uri(scheme: 'tel', path: number));

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _trigger();
        });
  final _action = IdempotentAction();
  bool _sending = false;
  SosResult? _result;
  String? _error;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _confirmThenTrigger() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.sendSosTitle),
        content: Text(l.sendSosBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.sendSos),
          ),
        ],
      ),
    );
    if (ok == true) _trigger();
  }

  Future<void> _trigger() async {
    if (_sending) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final patient = await ref.read(activePatientProvider.future);
      final loc = await tryGetLocation();
      final r = await ref.read(safetyRepositoryProvider).sos(
            patient.id,
            lat: loc?.lat,
            lng: loc?.lng,
            idempotencyKey: _action.key,
          );
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      // Keep the key on network failure so the retry is de-duplicated.
      if (!e.isOffline) _action.complete();
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _hold.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.dangerBgBottom,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(l.emergency, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.dangerBgTop, AppColors.dangerBgBottom],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                Text(_result == null ? l.sosSubtitle : l.sosSentTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
                const SizedBox(height: Space.xxl),
                if (_result == null) _sosButton(context) else _SosResultView(result: _result!),
                if (_error != null) ...[
                  const SizedBox(height: Space.lg),
                  Container(
                    padding: const EdgeInsets.all(Space.md),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text('${l.sosFailed}\n$_error',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  ),
                ],
                const SizedBox(height: Space.xxl),
                if (_result == null)
                  _ActionCard(
                    icon: Icons.location_on,
                    title: l.sendLocation,
                    subtitle: l.toEmergencyContacts,
                    onTap: _sending ? null : _confirmThenTrigger,
                  ),
                const SizedBox(height: Space.md),
                _ActionCard(
                  icon: Icons.call,
                  title: l.callAmbulance,
                  subtitle: l.helpline108,
                  onTap: () => callHelpline(),
                ),
                if (ref.watch(featureFlagsProvider).ambulanceBooking) ...[
                  const SizedBox(height: Space.md),
                  _ActionCard(
                    key: const Key('book-private-ambulance'),
                    icon: Icons.local_shipping_outlined,
                    title: l.bookPrivateAmbulance,
                    subtitle: l.bookPrivateAmbulanceSub,
                    onTap: () => context.push('/ambulance/book'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sosButton(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Semantics(
          button: true,
          label: l.sosSemantic,
          onTap: _confirmThenTrigger,
          excludeSemantics: true,
          child: GestureDetector(
            onTapDown: (_) => _hold.forward(),
            onTapUp: (_) {
              if (_hold.status != AnimationStatus.completed) _hold.reverse();
            },
            onTapCancel: () {
              if (_hold.status != AnimationStatus.completed) _hold.reverse();
            },
            child: AnimatedBuilder(
              animation: _hold,
              builder: (context, _) => SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    SizedBox(
                      width: 214,
                      height: 214,
                      child: CircularProgressIndicator(
                        value: _hold.value,
                        strokeWidth: 8,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.danger,
                        border: Border.all(color: Colors.white, width: 6),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
                      ),
                      child: _sending
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.call, color: Colors.white, size: 44),
                                Text(l.sosButton,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Text(l.holdToSend, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({super.key, required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.danger),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(subtitle, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosResultView extends StatelessWidget {
  const _SosResultView({required this.result});
  final SosResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const white = TextStyle(color: Colors.white);
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 64),
          const SizedBox(height: Space.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.danger),
            onPressed: () => callHelpline(result.helpline),
            icon: const Icon(Icons.call),
            label: Text(l.callNumber(result.helpline)),
          ),
          const SizedBox(height: Space.lg),
          Text(l.notifiedContacts, style: white.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          if (result.notifiedContacts.isEmpty)
            Text(l.noEmergencyContacts, style: white)
          else
            for (final c in result.notifiedContacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person, color: Colors.white),
                title: Text(c.name, style: white),
                subtitle: Text(c.phoneMasked, style: const TextStyle(color: Colors.white70)),
              ),
          if (result.notifiedContacts.isEmpty)
            TextButton(
              onPressed: () => context.push('/profile/emergency-contacts'),
              child: Text(l.addEmergencyContact, style: white.copyWith(decoration: TextDecoration.underline)),
            ),
          const SizedBox(height: Space.md),
          Text(l.nearestEmergencyFacilities, style: white.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          for (final f in result.nearestEmergencyFacilities) _FacilityRow(facility: f),
          if (result.careEpisodeId != null)
            TextButton(
              onPressed: () => context.push('/episodes/${result.careEpisodeId}'),
              child: Text(l.viewCareEpisode, style: white.copyWith(decoration: TextDecoration.underline)),
            ),
        ],
      ),
    );
  }
}

class _FacilityRow extends StatelessWidget {
  const _FacilityRow({required this.facility});
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = facility;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.sm),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(
                  [f.area, if (f.distanceKm != null) l.kmAway(f.distanceKm!.toStringAsFixed(1))].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.call,
            onPressed: () => callHelpline(f.phone),
            icon: const Icon(Icons.call, color: Colors.white),
          ),
          if (f.lat != null && f.lng != null)
            IconButton(
              tooltip: l.directions,
              onPressed: () => openDirections(f.lat!, f.lng!),
              icon: const Icon(Icons.directions, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
