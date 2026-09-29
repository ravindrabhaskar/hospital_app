import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/utils/location.dart';
import '../../core/utils/maps.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart' show NoticeBox;
import '../../models/engagement_v13.dart';
import '../../models/monitoring.dart' show hhmmToMinutes, minutesToHhmm;
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';

// Dementia safety: safe zone, companion mode and SOS button (§56).

// ---------------------------------------------------------------- Companion mode state

class CompanionModeState {
  const CompanionModeState({required this.consented, required this.enabled});
  final bool consented;
  final bool enabled;
}

/// Companion mode (elder side). It can only be switched on after the
/// explicit consent screen was accepted on this device.
class CompanionModeNotifier extends Notifier<CompanionModeState> {
  static const consentKey = 'cc_companion_consent';
  static const enabledKey = 'cc_companion_on';

  @override
  CompanionModeState build() {
    try {
      final p = ref.read(sharedPrefsProvider);
      final consented = p.getBool(consentKey) ?? false;
      return CompanionModeState(consented: consented, enabled: consented && (p.getBool(enabledKey) ?? false));
    } catch (_) {
      return const CompanionModeState(consented: false, enabled: false);
    }
  }

  Future<void> _persist() async {
    try {
      final p = ref.read(sharedPrefsProvider);
      await p.setBool(consentKey, state.consented);
      await p.setBool(enabledKey, state.enabled);
    } catch (_) {}
  }

  /// Records the explicit consent (does not switch it on by itself).
  Future<void> giveConsent() async {
    state = CompanionModeState(consented: true, enabled: state.enabled);
    await _persist();
  }

  /// Turns companion mode on; returns false (and stays off) without consent.
  Future<bool> enable() async {
    if (!state.consented) return false;
    state = const CompanionModeState(consented: true, enabled: true);
    await _persist();
    return true;
  }

  Future<void> disable() async {
    state = CompanionModeState(consented: state.consented, enabled: false);
    await _persist();
  }

  /// Withdraws consent and switches off.
  Future<void> withdraw() async {
    state = const CompanionModeState(consented: false, enabled: false);
    await _persist();
  }
}

final companionModeProvider =
    NotifierProvider<CompanionModeNotifier, CompanionModeState>(CompanionModeNotifier.new);

/// Location ping interval while companion mode is on (5 min, foreground only).
final companionIntervalProvider = Provider<Duration>((ref) => const Duration(minutes: 5));

/// Sends a foreground location every 5 minutes while the app is open and
/// companion mode is on. No background service (by design).
class CompanionModeHost extends ConsumerStatefulWidget {
  const CompanionModeHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CompanionModeHost> createState() => _CompanionModeHostState();
}

class _CompanionModeHostState extends ConsumerState<CompanionModeHost> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _sync();
    } else if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _sync() {
    if (!mounted) return;
    final on = ref.read(companionModeProvider).enabled;
    _timer?.cancel();
    _timer = null;
    if (!on) return;
    _ping();
    _timer = Timer.periodic(ref.read(companionIntervalProvider), (_) => _ping());
  }

  Future<void> _ping() async {
    try {
      final me = ref.read(sessionProvider).me;
      final pid = me?.selfPatientId;
      if (pid == null) return;
      final loc = await tryGetLocation();
      if (loc == null) return;
      double acc = 50;
      try {
        acc = (await Geolocator.getLastKnownPosition())?.accuracy ?? 50;
      } catch (_) {}
      await ref.read(safeZoneRepositoryProvider).postLocation(pid, lat: loc.lat, lng: loc.lng, accuracyM: acc);
    } catch (_) {
      // Best effort; the next tick retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(companionModeProvider, (_, _) => _sync());
    return widget.child;
  }
}

// ---------------------------------------------------------------- Hub

class SafetyHubScreen extends ConsumerWidget {
  const SafetyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final active = ref.watch(activePatientProvider).value;
    final companion = ref.watch(companionModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.safetyLocation)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          Text(l.safetyIntro, style: TextStyle(color: context.textMuted)),
          const SizedBox(height: Space.md),
          if (active != null && !active.isSelf) ...[
            ListRowTile(
              icon: Icons.radar,
              accent: Accent.teal,
              title: l.safeZone,
              subtitle: l.safeZoneSub(active.name),
              onTap: () => context.push('/safety/safe-zone'),
            ),
          ] else
            ListRowTile(
              icon: Icons.radar,
              accent: Accent.teal,
              title: l.safeZone,
              subtitle: l.safeZoneSelfSub,
              onTap: () => context.push('/safety/safe-zone'),
            ),
          ListRowTile(
            icon: Icons.share_location,
            accent: Accent.lavender,
            title: l.companionMode,
            subtitle: companion.enabled ? l.companionOn : l.companionModeSub,
            onTap: () => context.push('/safety/companion'),
          ),
          ListRowTile(
            icon: Icons.sos,
            accent: Accent.rose,
            title: l.sosButtonPairing,
            subtitle: l.sosButtonPairingSub,
            onTap: () => context.push('/safety/sos-button'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Safe zone (family)

class SafeZoneScreen extends ConsumerStatefulWidget {
  const SafeZoneScreen({super.key});

  @override
  ConsumerState<SafeZoneScreen> createState() => _SafeZoneScreenState();
}

class _SafeZoneScreenState extends ConsumerState<SafeZoneScreen> {
  SafeZone? _edit;
  final _label = TextEditingController();
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    final loc = await tryGetLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (loc != null) {
        final z = _edit!;
        _edit = SafeZone(
            enabled: z.enabled,
            centerLat: loc.lat,
            centerLng: loc.lng,
            radiusMeters: z.radiusMeters,
            activeFrom: z.activeFrom,
            activeTo: z.activeTo);
      }
    });
    if (loc == null) showSnack(context, context.l10n.locationUnavailable);
  }

  SafeZone _copy({bool? enabled, int? radius, String? from, String? to, bool clearHours = false}) {
    final z = _edit!;
    return SafeZone(
      enabled: enabled ?? z.enabled,
      centerLat: z.centerLat,
      centerLng: z.centerLng,
      radiusMeters: radius ?? z.radiusMeters,
      label: _label.text,
      activeFrom: clearHours ? null : (from ?? z.activeFrom),
      activeTo: clearHours ? null : (to ?? z.activeTo),
    );
  }

  Future<void> _pickHour(bool from) async {
    final z = _edit!;
    final cur = hhmmToMinutes((from ? z.activeFrom : z.activeTo) ?? (from ? '07:00' : '21:00')) ?? 0;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null) return;
    final v = minutesToHhmm(t.hour * 60 + t.minute);
    setState(() => _edit = from ? _copy(from: v) : _copy(to: v));
  }

  Future<void> _save(String patientId) async {
    final l = context.l10n;
    final z = _copy();
    if (!z.hasCenter) {
      showSnack(context, l.safeZoneNeedsCenter, error: true);
      return;
    }
    if (validateSafeZoneRadius(z.radiusMeters) != null) {
      showSnack(context, l.safeZoneRadiusInvalid, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(safeZoneRepositoryProvider).save(patientId, z);
      ref.invalidate(safeZoneProvider);
      if (!mounted) return;
      setState(() => _edit = saved);
      showSnack(context, l.saved);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final patient = ref.watch(activePatientProvider).value;
    final canManage = patient?.can(FamilyPermission.manageCare) ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.safeZone)),
      body: AsyncView<SafeZone?>(
        value: ref.watch(safeZoneProvider),
        onRetry: () => ref.invalidate(safeZoneProvider),
        data: (server) {
          if (_edit == null) {
            _edit = server ?? SafeZone.empty;
            _label.text = server?.label ?? '';
          }
          final z = _edit!;
          return ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              if (patient != null) Text(l.safeZoneIntro(patient.name), style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.md),
              const LastKnownLocationCard(),
              const SizedBox(height: Space.md),
              if (!canManage)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Text(l.checkinNoPermission, style: const TextStyle(color: AppColors.danger)),
                ),
              CcCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  SwitchListTile(
                    key: const Key('zone-enabled'),
                    value: z.enabled,
                    title: Text(l.safeZoneAlerts),
                    subtitle: Text(l.safeZoneAlertsSub),
                    onChanged: canManage ? (v) => setState(() => _edit = _copy(enabled: v)) : null,
                  ),
                  const Divider(indent: 16),
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.home_outlined),
                    title: Text(l.zoneCentre),
                    subtitle: Text(z.hasCenter
                        ? l.gpsLocation(z.centerLat!.toStringAsFixed(5), z.centerLng!.toStringAsFixed(5))
                        : l.notSet),
                    trailing: TextButton(
                      key: const Key('zone-use-current'),
                      onPressed: canManage && !_locating ? _useCurrent : null,
                      child: Text(l.useCurrentLocation),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: TextField(controller: _label, decoration: InputDecoration(labelText: l.zoneLabelHint)),
                  ),
                  const SizedBox(height: Space.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Row(children: [
                      Expanded(child: Text(l.radius)),
                      Text(l.metersValue(z.radiusMeters), key: const Key('zone-radius-value'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Slider(
                    key: const Key('zone-radius'),
                    value: z.radiusMeters.clamp(safeZoneMinRadius, safeZoneMaxRadius).toDouble(),
                    min: safeZoneMinRadius.toDouble(),
                    max: safeZoneMaxRadius.toDouble(),
                    divisions: 49,
                    label: l.metersValue(z.radiusMeters),
                    semanticFormatterCallback: (v) => l.metersValue(v.round()),
                    onChanged: canManage ? (v) => setState(() => _edit = _copy(radius: (v / 100).round() * 100)) : null,
                  ),
                  const Divider(indent: 16),
                  SwitchListTile(
                    value: z.activeFrom != null,
                    title: Text(l.activeHoursOnly),
                    subtitle: Text(z.activeFrom == null ? l.alwaysActive : '${z.activeFrom} – ${z.activeTo ?? '—'}'),
                    onChanged: canManage
                        ? (v) => setState(() => _edit = v ? _copy(from: '07:00', to: '21:00') : _copy(clearHours: true))
                        : null,
                  ),
                  if (z.activeFrom != null)
                    Row(children: [
                      Expanded(
                        child: ListTile(
                          title: Text(l.from),
                          trailing: Text(z.activeFrom!),
                          onTap: canManage ? () => _pickHour(true) : null,
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text(l.to),
                          trailing: Text(z.activeTo ?? '—'),
                          onTap: canManage ? () => _pickHour(false) : null,
                        ),
                      ),
                    ]),
                ]),
              ),
              const SizedBox(height: Space.md),
              NoticeBox(icon: Icons.privacy_tip_outlined, color: AppColors.skyFg, text: l.safeZonePrivacy),
              const SizedBox(height: Space.lg),
              if (canManage && patient != null)
                PrimaryButton(key: const Key('zone-save'), label: l.save, loading: _saving, onPressed: () => _save(patient.id)),
            ],
          );
        },
      ),
    );
  }
}

class LastKnownLocationCard extends ConsumerWidget {
  const LastKnownLocationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView<LatestLocation?>(
      value: ref.watch(latestLocationProvider),
      compact: true,
      onRetry: () => ref.invalidate(latestLocationProvider),
      data: (loc) => CcCard(
        key: const Key('last-location'),
        color: loc == null ? null : (loc.inside ? context.mintSurface : context.roseSurface),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(loc == null ? Icons.location_searching : (loc.inside ? Icons.home : Icons.warning_amber_rounded),
                color: loc == null ? context.textMuted : (loc.inside ? AppColors.primaryLight : AppColors.danger)),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(l.lastKnownLocation, style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: l.refresh,
              onPressed: () => ref.invalidate(latestLocationProvider),
              icon: const Icon(Icons.refresh),
            ),
          ]),
          if (loc == null)
            Text(l.noLocationYet, style: TextStyle(color: context.textMuted))
          else ...[
            Text(loc.inside ? l.insideSafeZone : l.outsideSafeZone),
            if (loc.at != null)
              Text(l.updatedAt(fmtDateTime(context, loc.at!)), style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              key: const Key('last-location-map'),
              onPressed: () => openExternal(context, googleMapsUri(loc.lat, loc.lng)),
              icon: const Icon(Icons.map_outlined),
              label: Text(l.openInMaps),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Companion mode (elder)

class CompanionModeScreen extends ConsumerWidget {
  const CompanionModeScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final n = ref.read(companionModeProvider.notifier);
    if (!on) return n.disable();
    if (!ref.read(companionModeProvider).consented) {
      final agreed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CompanionConsentScreen(), fullscreenDialog: true),
      );
      if (agreed != true) return;
      await n.giveConsent();
    }
    await n.enable();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(companionModeProvider);
    final active = ref.watch(activePatientProvider).value;
    final isSelf = active?.isSelf ?? true;
    return Scaffold(
      appBar: AppBar(title: Text(l.companionMode)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          const Center(child: IconTile(icon: Icons.share_location, accent: Accent.lavender, size: 72)),
          const SizedBox(height: Space.lg),
          Text(l.companionIntro, style: TextStyle(color: context.textMuted)),
          const SizedBox(height: Space.md),
          if (!isSelf)
            NoticeBox(icon: Icons.phone_android, text: l.companionOwnDevice)
          else
            CcCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                key: const Key('companion-toggle'),
                value: s.enabled,
                title: Text(l.companionMode),
                subtitle: Text(s.enabled ? l.companionOn : l.companionOff),
                onChanged: (v) => _toggle(context, ref, v),
              ),
            ),
          const SizedBox(height: Space.md),
          Text(l.companionForegroundOnly, style: TextStyle(fontSize: 12.5, color: context.textMuted)),
          if (s.consented) ...[
            const SizedBox(height: Space.md),
            TextButton(
              key: const Key('companion-withdraw'),
              onPressed: () => ref.read(companionModeProvider.notifier).withdraw(),
              child: Text(l.withdrawConsent),
            ),
          ],
        ],
      ),
    );
  }
}

/// Explicit consent before any location is shared.
class CompanionConsentScreen extends StatefulWidget {
  const CompanionConsentScreen({super.key});

  @override
  State<CompanionConsentScreen> createState() => _CompanionConsentScreenState();
}

class _CompanionConsentScreenState extends State<CompanionConsentScreen> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final points = [l.companionConsent1, l.companionConsent2, l.companionConsent3, l.companionConsent4];
    return Scaffold(
      appBar: AppBar(title: Text(l.companionConsentTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline, color: AppColors.primaryLight),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(p)),
              ]),
            ),
          CheckboxListTile(
            key: const Key('companion-agree'),
            value: _agree,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l.companionConsentAgree),
            onChanged: (v) => setState(() => _agree = v ?? false),
          ),
          const SizedBox(height: Space.md),
          PrimaryButton(
            key: const Key('companion-accept'),
            label: l.agreeAndTurnOn,
            onPressed: _agree ? () => Navigator.pop(context, true) : null,
          ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.notNow)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- SOS button pairing

class SosButtonScreen extends ConsumerStatefulWidget {
  const SosButtonScreen({super.key});

  @override
  ConsumerState<SosButtonScreen> createState() => _SosButtonScreenState();
}

class _SosButtonScreenState extends ConsumerState<SosButtonScreen> {
  final _deviceId = TextEditingController();
  final _model = TextEditingController();
  bool _busy = false;
  List<SosDevice> _devices = const [];

  /// The contract has no list endpoint, so paired devices are remembered
  /// on this device (per patient).
  String _key(String pid) => 'cc_sos_devices_$pid';

  @override
  void initState() {
    super.initState();
    _deviceId.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pid = (await ref.read(activePatientProvider.future)).id;
      final raw = ref.read(sharedPrefsProvider).getString(_key(pid));
      if (raw == null || !mounted) return;
      setState(() => _devices = [
            for (final e in (jsonDecode(raw) as List)) SosDevice.fromJson(Map<String, dynamic>.from(e as Map)),
          ]);
    } catch (_) {}
  }

  Future<void> _store(String pid) async {
    try {
      await ref.read(sharedPrefsProvider).setString(_key(pid), jsonEncode([for (final d in _devices) d.toJson()]));
    } catch (_) {}
  }

  Future<void> _pair() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final pid = (await ref.read(activePatientProvider.future)).id;
      final d = await ref.read(safeZoneRepositoryProvider).pair(pid,
          deviceId: _deviceId.text.trim(), model: _model.text.trim().isEmpty ? 'SOS button' : _model.text.trim());
      setState(() => _devices = [..._devices, d]);
      await _store(pid);
      _deviceId.clear();
      _model.clear();
      if (mounted) showSnack(context, l.sosButtonPaired);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpair(SosDevice d) async {
    try {
      final pid = (await ref.read(activePatientProvider.future)).id;
      await ref.read(safeZoneRepositoryProvider).unpair(pid, d.id);
      setState(() => _devices = _devices.where((x) => x.id != d.id).toList());
      await _store(pid);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.sosButtonPairing)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          Text(l.sosButtonIntro, style: TextStyle(color: context.textMuted)),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('sos-device-id'),
            controller: _deviceId,
            decoration: InputDecoration(labelText: l.deviceId, helperText: l.deviceIdHelp),
          ),
          const SizedBox(height: Space.md),
          TextField(controller: _model, decoration: InputDecoration(labelText: l.deviceModelOptional)),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            key: const Key('sos-pair'),
            label: l.pairDevice,
            loading: _busy,
            onPressed: _deviceId.text.trim().length < 4 ? null : _pair,
          ),
          SectionHeader(title: l.pairedDevices),
          if (_devices.isEmpty)
            Text(l.noPairedDevices, style: TextStyle(color: context.textMuted))
          else
            for (final d in _devices)
              ListRowTile(
                icon: Icons.sos,
                accent: Accent.rose,
                title: d.model,
                subtitle: [d.deviceId, if (d.pairedAt != null) fmtDate(context, d.pairedAt!)].join(' · '),
                trailing: IconButton(
                  tooltip: l.unpair,
                  onPressed: () => _unpair(d),
                  icon: const Icon(Icons.link_off, color: AppColors.danger),
                ),
              ),
          const SizedBox(height: Space.md),
          Text(l.sosButtonNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}
