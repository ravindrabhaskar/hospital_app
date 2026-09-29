import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/utils/location.dart';
import '../../core/utils/maps.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart';
import '../../l10n/app_localizations.dart';
import '../../models/doctor.dart';
import '../../models/services.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../../state/v13_providers.dart';
import '../payments/payment_sheet.dart';

// Private ambulance booking (API_CONTRACT §55). It never replaces 108:
// every screen keeps "Call 108" as the primary action.

String ambulanceStatusLabel(AppLocalizations l, String s) => switch (s) {
      'searching' => l.ambSearching,
      'assigned' => l.ambAssigned,
      'en_route' => l.ambEnRoute,
      'arrived' => l.ambArrived,
      'transporting' => l.ambTransporting,
      'completed' => l.ambCompleted,
      'cancelled' => l.ambCancelled,
      'no_vehicle' => l.ambNoVehicle,
      _ => humanize(s),
    };

/// The red "Call 108" banner shown at the top of every ambulance screen.
class Call108Banner extends StatelessWidget {
  const Call108Banner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return CcCard(
      color: context.roseSurface,
      borderColor: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.call108First, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.sm),
          PrimaryButton(
            key: const Key('call-108'),
            icon: Icons.call,
            color: AppColors.danger,
            foreground: Colors.white,
            label: l.callNumber(AppConfig.emergencyHelpline),
            onPressed: () => openExternal(context, telUri(AppConfig.emergencyHelpline)),
          ),
        ],
      ),
    );
  }
}

class AmbulanceBookScreen extends ConsumerStatefulWidget {
  const AmbulanceBookScreen({super.key});

  @override
  ConsumerState<AmbulanceBookScreen> createState() => _AmbulanceBookScreenState();
}

class _AmbulanceBookScreenState extends ConsumerState<AmbulanceBookScreen> {
  String _type = 'bls';
  ({double lat, double lng})? _loc;
  bool _locating = false;
  final _address = TextEditingController();
  final _reason = TextEditingController();
  String? _destination;
  bool _busy = false;
  final _action = IdempotentAction();

  @override
  void initState() {
    super.initState();
    _address.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _address.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final loc = await tryGetLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _loc = loc;
    });
    if (loc == null) showSnack(context, context.l10n.locationUnavailable);
  }

  Future<void> _book() async {
    final l = context.l10n;
    final loc = _loc;
    if (loc == null) return;
    setState(() => _busy = true);
    try {
      final patient = await ref.read(activePatientProvider.future);
      final res = await ref.read(ambulanceRepositoryProvider).request(
            patientId: patient.id,
            lat: loc.lat,
            lng: loc.lng,
            address: _address.text.trim().isEmpty ? l.currentLocation : _address.text.trim(),
            destinationFacilityId: _destination,
            type: _type,
            reason: _reason.text.trim().isEmpty ? l.ambulanceDefaultReason : _reason.text.trim(),
            idempotencyKey: _action.key,
          );
      _action.complete();
      if (!mounted) return;
      final pay = res.payment;
      if (pay != null && !pay.succeeded) {
        await showPaymentSheet(context, payment: pay, title: l.privateAmbulance);
        if (!mounted) return;
      }
      context.pushReplacement('/ambulance/${res.request.id}');
    } on ApiException catch (e) {
      if (!e.isOffline) _action.complete();
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final loc = _loc;
    final facilities = ref.watch(facilitiesProvider((type: 'hospital', q: null, lat: loc?.lat, lng: loc?.lng)));
    return Scaffold(
      appBar: AppBar(title: Text(l.bookPrivateAmbulance)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          const Call108Banner(),
          SectionHeader(title: l.ambulanceType),
          SegmentedButton<String>(
            key: const Key('amb-type'),
            segments: [
              ButtonSegment(value: 'bls', label: Text(l.ambBls)),
              ButtonSegment(value: 'als', label: Text(l.ambAls)),
            ],
            selected: {_type},
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
          const SizedBox(height: 6),
          Text(_type == 'bls' ? l.ambBlsDesc : l.ambAlsDesc, style: TextStyle(fontSize: 12.5, color: context.textMuted)),
          SectionHeader(title: l.pickupLocation),
          CcCard(
            child: Row(children: [
              Icon(loc == null ? Icons.location_off_outlined : Icons.my_location,
                  color: loc == null ? AppColors.danger : AppColors.primaryLight),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(loc == null
                    ? (_locating ? l.locating : l.locationUnavailable)
                    : l.gpsLocation(loc.lat.toStringAsFixed(5), loc.lng.toStringAsFixed(5))),
              ),
              TextButton(onPressed: _locating ? null : _locate, child: Text(l.useMyLocation)),
            ]),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _address,
            decoration: InputDecoration(labelText: l.pickupAddressHint),
          ),
          SectionHeader(title: l.destinationHospital),
          AsyncView<List<Facility>>(
            value: facilities,
            compact: true,
            onRetry: () => ref.invalidate(facilitiesProvider),
            data: (list) => DropdownButtonFormField<String?>(
              initialValue: _destination,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.destinationOptional),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.nearestSuitable)),
                for (final f in list)
                  DropdownMenuItem<String?>(
                    value: f.id,
                    child: Text([f.name, if (f.distanceKm != null) l.kmAway(f.distanceKm!.toStringAsFixed(1))].join(' · '),
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _destination = v),
            ),
          ),
          const SizedBox(height: Space.md),
          TextField(controller: _reason, maxLength: 200, decoration: InputDecoration(labelText: l.reasonOptional)),
          const SizedBox(height: Space.md),
          PrimaryButton(
            key: const Key('amb-book'),
            icon: Icons.local_shipping_outlined,
            label: l.requestAmbulance,
            loading: _busy,
            onPressed: loc == null ? null : _book,
          ),
          const SizedBox(height: Space.sm),
          Text(l.ambulanceNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}

/// Live tracking: polls `GET /ambulance/requests/:id` every 5 s while open.
class AmbulanceTrackingScreen extends ConsumerStatefulWidget {
  const AmbulanceTrackingScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<AmbulanceTrackingScreen> createState() => _AmbulanceTrackingScreenState();
}

class _AmbulanceTrackingScreenState extends ConsumerState<AmbulanceTrackingScreen> {
  AmbulanceRequest? _req;
  Object? _error;
  Timer? _timer;
  bool _polling = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(ref.read(ambulancePollIntervalProvider), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final r = await ref.read(ambulanceRepositoryProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _req = r;
        _error = null;
      });
      if (r.isTerminal) _timer?.cancel();
    } catch (e) {
      if (mounted && _req == null) setState(() => _error = e);
    } finally {
      _polling = false;
    }
  }

  Future<void> _cancel() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.cancelAmbulance),
        content: Text(l.cancelAmbulanceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.notNow)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.cancelAmbulance)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelling = true);
    try {
      final r = await ref.read(ambulanceRepositoryProvider).cancel(widget.id, l.cancelledByUser);
      if (mounted) setState(() => _req = r);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = _req;
    return Scaffold(
      appBar: AppBar(title: Text(l.ambulanceTracking)),
      body: r == null
          ? (_error != null
              ? ErrorStateView(
                  error: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                    _poll();
                  })
              : const LoadingView())
          : ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                const Call108Banner(),
                const SizedBox(height: Space.md),
                CcCard(
                  key: const Key('amb-status'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const IconTile(icon: Icons.local_shipping_outlined, accent: Accent.rose, size: 44),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(ambulanceStatusLabel(l, r.status),
                                key: const Key('amb-status-label'), style: Theme.of(context).textTheme.titleMedium),
                          ),
                        ),
                        StatusPill(label: r.type == 'als' ? l.ambAls : l.ambBls, color: AppColors.skyFg),
                      ]),
                      if (r.etaMinutes != null && !r.isTerminal) ...[
                        const SizedBox(height: Space.sm),
                        Text(l.etaMinutes(r.etaMinutes!),
                            key: const Key('amb-eta'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                      if (r.hasVehicle) ...[
                        const Divider(height: Space.xl),
                        LabeledValue(label: l.vehicle, value: r.vehicleNumber!),
                        if (r.driverName != null) LabeledValue(label: l.driver, value: r.driverName!),
                        if (r.driverPhoneMasked != null) LabeledValue(label: l.phoneLabel, value: r.driverPhoneMasked!),
                      ],
                      if (r.destination != null) LabeledValue(label: l.destinationHospital, value: r.destination!.name),
                      if (r.partnerName.isNotEmpty) LabeledValue(label: l.provider, value: r.partnerName),
                    ],
                  ),
                ),
                if (r.lat != null && r.lng != null) ...[
                  const SizedBox(height: Space.md),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('amb-map'),
                        onPressed: () => openExternal(context, googleMapsUri(r.lat!, r.lng!)),
                        icon: const Icon(Icons.map_outlined),
                        label: Text(l.openInMaps),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => openExternal(context, osmUri(r.lat!, r.lng!)),
                        child: Text(l.openStreetMap),
                      ),
                    ),
                  ]),
                  if (r.locationUpdatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l.locationUpdatedAt(fmtTime(context, r.locationUpdatedAt!)),
                          style: TextStyle(fontSize: 12, color: context.textMuted)),
                    ),
                ],
                SectionHeader(title: l.statusTimeline),
                StatusTimeline(
                  steps: buildTimelineSteps(
                    flow: AmbulanceRequest.flow,
                    current: r.status,
                    reached: {for (final t in r.timeline) t.status: t.at},
                    label: (s) => ambulanceStatusLabel(l, s),
                  ),
                ),
                if (r.status == 'no_vehicle') ...[
                  const SizedBox(height: Space.md),
                  NoticeBox(icon: Icons.error_outline, color: AppColors.danger, text: l.noVehicleBody),
                ],
                if (r.canCancel) ...[
                  const SizedBox(height: Space.lg),
                  OutlinedButton(
                    key: const Key('amb-cancel'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                    onPressed: _cancelling ? null : _cancel,
                    child: Text(l.cancelAmbulance),
                  ),
                ],
              ],
            ),
    );
  }
}
