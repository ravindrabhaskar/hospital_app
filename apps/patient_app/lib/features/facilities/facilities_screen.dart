import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/doctor.dart';
import '../../state/data_providers.dart';

Future<void> openDirections(double lat, double lng) => launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );

class FacilitiesScreen extends ConsumerStatefulWidget {
  const FacilitiesScreen({super.key, this.initialType});
  final String? initialType;

  @override
  ConsumerState<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends ConsumerState<FacilitiesScreen> {
  late String? _type = widget.initialType ?? 'hospital';
  ({double lat, double lng})? _loc;
  bool _locating = false;

  FacilityQuery get _query => (type: _type, q: null, lat: _loc?.lat, lng: _loc?.lng);

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final loc = await tryGetLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _loc = loc;
    });
    if (loc == null) showSnack(context, context.l10n.locationUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final types = ['hospital', 'clinic', 'lab', 'pharmacy'];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.qxFindHospitals),
        actions: [
          IconButton(
            tooltip: l.useMyLocation,
            onPressed: _locating ? null : _useLocation,
            icon: _locating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_loc == null ? Icons.my_location : Icons.gps_fixed),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: 8),
              children: [
                ChoiceChip(
                  label: Text(l.all),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                ),
                for (final t in types) ...[
                  const SizedBox(width: Space.sm),
                  ChoiceChip(
                    label: Text(Labels.facilityType(l, t)),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Facility>>(
              value: ref.watch(facilitiesProvider(_query)),
              onRetry: () => ref.invalidate(facilitiesProvider(_query)),
              isEmpty: (l) => l.isEmpty,
              empty: EmptyStateView(icon: Icons.location_off_outlined, title: l.noFacilities),
              data: (list) => ListView.separated(
                padding: const EdgeInsets.all(Space.screen),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (_, i) => FacilityCard(facility: list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FacilityCard extends StatelessWidget {
  const FacilityCard({super.key, required this.facility});
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = facility;
    return CcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(icon: Icons.local_hospital_outlined, accent: Accent.rose, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: Theme.of(context).textTheme.titleSmall),
                    Text('${f.address}, ${f.area}, ${f.city}',
                        style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                  ],
                ),
              ),
              if (f.distanceKm != null)
                Text(l.kmAway(f.distanceKm!.toStringAsFixed(1)),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(label: Labels.facilityType(l, f.type), color: AppColors.skyFg),
              if (f.emergency24x7) StatusPill(label: l.emergency247, color: AppColors.danger),
              if (f.verified) StatusPill(label: l.verified, icon: Icons.verified),
            ],
          ),
          if (f.services.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(f.services.join(' · '), style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: f.phone.isEmpty ? null : () => launchUrl(Uri(scheme: 'tel', path: f.phone)),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(l.call),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: f.lat == null || f.lng == null ? null : () => openDirections(f.lat!, f.lng!),
                  icon: const Icon(Icons.directions_outlined),
                  label: Text(l.directions),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
