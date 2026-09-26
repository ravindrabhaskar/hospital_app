import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import 'health_source.dart';
import 'wearable_sync.dart';

String healthMetricLabel(AppLocalizations l, HealthMetric m) => switch (m) {
      HealthMetric.steps => l.metricSteps,
      HealthMetric.heartRate => l.heartRate,
      HealthMetric.sleep => l.sleep,
      HealthMetric.spo2 => l.metricSpo2,
      HealthMetric.bloodPressure => l.metricBloodPressure,
      HealthMetric.glucose => l.metricGlucose,
      HealthMetric.weight => l.metricWeight,
    };

IconData healthMetricIcon(HealthMetric m) => switch (m) {
      HealthMetric.steps => Icons.directions_walk,
      HealthMetric.heartRate => Icons.favorite_outline,
      HealthMetric.sleep => Icons.bedtime_outlined,
      HealthMetric.spo2 => Icons.air,
      HealthMetric.bloodPressure => Icons.speed,
      HealthMetric.glucose => Icons.water_drop_outlined,
      HealthMetric.weight => Icons.monitor_weight_outlined,
    };

/// Profile → Linked devices / Home → Wearables (§40): reads Health Connect
/// (Android) or Apple Health (iOS) with per-type consent and syncs readings.
class WearablesScreen extends ConsumerStatefulWidget {
  const WearablesScreen({super.key});

  @override
  ConsumerState<WearablesScreen> createState() => _WearablesScreenState();
}

class _WearablesScreenState extends ConsumerState<WearablesScreen> {
  final Set<HealthMetric> _metrics = {...HealthMetric.values};
  HealthAvailability? _availability;
  bool _busy = false;
  bool _denied = false;

  HealthDataSource get _source => ref.read(healthDataSourceProvider);

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final a = await _source.availability();
    if (mounted) setState(() => _availability = a);
  }

  String _providerName(String code, List<WearableProvider> providers) {
    final l = context.l10n;
    final fromServer = providers.where((p) => p.code == code).firstOrNull?.name;
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    return code == 'apple_health' ? l.appleHealth : l.healthConnect;
  }

  Future<void> _connect() async {
    final l = context.l10n;
    final source = _source;
    setState(() {
      _busy = true;
      _denied = false;
    });
    try {
      final availability = await source.availability();
      if (!mounted) return;
      setState(() => _availability = availability);
      if (availability == HealthAvailability.notInstalled || availability == HealthAvailability.updateRequired) {
        await _promptInstall(availability);
        return;
      }
      if (availability != HealthAvailability.available) return;
      final granted = await source.requestPermissions(_metrics);
      if (!mounted) return;
      if (!granted) {
        setState(() => _denied = true);
        return;
      }
      final p = await ref.read(activePatientProvider.future);
      await ref.read(wearablesRepositoryProvider).connect(p.id, source.providerCode);
      ref.invalidate(wearableConnectionsProvider);
      final r = await ref.read(wearableSyncProvider.notifier).sync();
      if (mounted) showSnack(context, r == null ? l.deviceConnected : l.syncedReadings(r.sent));
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptInstall(HealthAvailability a) async {
    final l = context.l10n;
    final install = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.health_and_safety_outlined),
        title: Text(a == HealthAvailability.updateRequired ? l.healthConnectUpdateTitle : l.healthConnectMissingTitle),
        content: Text(l.healthConnectMissingBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.notNow)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.openPlayStore)),
        ],
      ),
    );
    if (install == true) await _source.openInstall();
  }

  Future<void> _syncNow() async {
    final l = context.l10n;
    try {
      final r = await ref.read(wearableSyncProvider.notifier).sync();
      if (mounted && r != null) showSnack(context, l.syncedReadings(r.sent));
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  Future<void> _disconnect(WearableConnection c) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.disconnectDevice),
        content: Text(l.disconnectDeviceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.disconnect)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(wearablesRepositoryProvider).revoke(c.id);
      if (c.provider == _source.providerCode) {
        await _source.revoke();
        await ref.read(wearableSyncProvider.notifier).forget();
      }
      ref.invalidate(wearableConnectionsProvider);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final providers = ref.watch(wearableProvidersProvider).value ?? const <WearableProvider>[];
    final conns = ref.watch(wearableConnectionsProvider);
    final syncState = ref.watch(wearableSyncProvider);
    final code = _source.providerCode;
    final unsupported = code.isEmpty || _availability == HealthAvailability.unsupported;
    final connected = [
      for (final c in conns.value ?? const <WearableConnection>[])
        if (c.isConnected) c,
    ];
    final mine = connected.where((c) => c.provider == code).firstOrNull;
    final others = providers.where((p) => p.code != 'health_connect' && p.code != 'apple_health').toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.connectWearable)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _checkAvailability();
                ref.invalidate(wearableProvidersProvider);
                ref.invalidate(wearableConnectionsProvider);
                await ref.read(wearableConnectionsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  CcCard(
                    child: Row(
                      children: [
                        ExcludeSemantics(child: Icon(Icons.watch, size: 72, color: context.textStrong)),
                        const SizedBox(width: Space.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.trackHealthRealtime, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(l.wearablePurpose, style: TextStyle(color: context.textMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  if (conns.hasError && !conns.hasValue)
                    ErrorStateView(
                        compact: true, error: conns.error!, onRetry: () => ref.invalidate(wearableConnectionsProvider))
                  else if (unsupported)
                    CcCard(
                      key: const Key('wearables-unsupported'),
                      color: context.skySurface,
                      child: Row(
                        children: [
                          const Icon(Icons.phone_android, color: AppColors.skyFg),
                          const SizedBox(width: Space.sm),
                          Expanded(child: Text(l.wearablesUnsupported)),
                        ],
                      ),
                    )
                  else if (mine != null)
                    _ConnectedCard(
                      name: _providerName(mine.provider, providers),
                      connection: mine,
                      syncState: syncState,
                      onSync: _syncNow,
                      onDisconnect: () => _disconnect(mine),
                    )
                  else ...[
                    Text(l.chooseDataToShare(_providerName(code, providers)),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: Space.sm),
                    CcCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final m in HealthMetric.values)
                            CheckboxListTile(
                              key: Key('metric-${m.name}'),
                              value: _metrics.contains(m),
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(() => v == true ? _metrics.add(m) : _metrics.remove(m)),
                              secondary: Icon(healthMetricIcon(m), color: AppColors.primaryLight),
                              title: Text(healthMetricLabel(l, m)),
                            ),
                        ],
                      ),
                    ),
                    if (_availability == HealthAvailability.notInstalled ||
                        _availability == HealthAvailability.updateRequired) ...[
                      const SizedBox(height: Space.md),
                      CcCard(
                        color: context.peachSurface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_availability == HealthAvailability.updateRequired
                                ? l.healthConnectUpdateTitle
                                : l.healthConnectMissingTitle,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(l.healthConnectMissingBody),
                            const SizedBox(height: Space.sm),
                            OutlinedButton.icon(
                              onPressed: () => _source.openInstall(),
                              icon: const Icon(Icons.shop_outlined),
                              label: Text(l.openPlayStore),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_denied) ...[
                      const SizedBox(height: Space.md),
                      CcCard(
                        key: const Key('wearables-denied'),
                        color: context.roseSurface,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.block, color: AppColors.danger),
                            const SizedBox(width: Space.sm),
                            Expanded(child: Text(l.healthPermissionDenied)),
                          ],
                        ),
                      ),
                    ],
                  ],
                  for (final c in connected.where((c) => c.provider != code))
                    Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: ListRowTile(
                        icon: Icons.devices_other,
                        title: _providerName(c.provider, providers),
                        subtitle: c.lastSyncAt != null
                            ? l.lastSynced(fmtDateTime(context, c.lastSyncAt!))
                            : l.connectedNotSynced,
                        trailing: TextButton(onPressed: () => _disconnect(c), child: Text(l.disconnect)),
                      ),
                    ),
                  if (others.isNotEmpty) ...[
                    SectionHeader(title: l.otherDevices),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final p in others)
                          Chip(
                            avatar: const Icon(Icons.watch_outlined, size: 18),
                            label: Text(p.comingSoon ? '${p.name} · ${l.comingSoon}' : p.name),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Space.md),
                  Text(l.wearableDataNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
                ],
              ),
            ),
          ),
          if (!unsupported && mine == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                child: PrimaryButton(
                  key: const Key('wearables-connect'),
                  label: l.connectDeviceName(_providerName(code, providers)),
                  loading: _busy || syncState.syncing,
                  onPressed: _metrics.isEmpty ? null : _connect,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({
    required this.name,
    required this.connection,
    required this.syncState,
    required this.onSync,
    required this.onDisconnect,
  });
  final String name;
  final WearableConnection connection;
  final WearableSyncState syncState;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = syncState.lastSyncedAt ?? connection.lastSyncAt;
    return CcCard(
      key: const Key('wearables-connected'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.favorite_outline, accent: Accent.rose, size: 44),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        syncState.syncing
                            ? l.syncing
                            : last != null
                                ? l.lastSynced(fmtDateTime(context, last))
                                : l.connectedNotSynced,
                        style: TextStyle(color: context.textMuted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: l.connected, icon: Icons.check),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: syncState.syncing ? null : onSync,
                  icon: syncState.syncing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: Text(l.syncNow),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  onPressed: onDisconnect,
                  child: Text(l.disconnect),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(l.autoSyncNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}
