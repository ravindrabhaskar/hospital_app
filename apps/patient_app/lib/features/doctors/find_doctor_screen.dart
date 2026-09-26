import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/doctor.dart';
import '../../state/data_providers.dart';

class FindDoctorScreen extends ConsumerStatefulWidget {
  const FindDoctorScreen({super.key, this.specialty, this.mode, this.careEpisodeId});
  final String? specialty;
  final String? mode;
  final String? careEpisodeId;

  @override
  ConsumerState<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends ConsumerState<FindDoctorScreen> {
  late String? _specialty = widget.specialty;
  late String? _mode = widget.mode;
  String _q = '';
  Timer? _debounce;
  final _favorites = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  DoctorQuery get _query => (specialty: _specialty, q: _q.isEmpty ? null : _q, mode: _mode);

  void _openDoctor(Doctor d) {
    context.push(Uri(path: '/doctors/${d.id}', queryParameters: {
      'episode': ?widget.careEpisodeId,
    }).toString());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final specs = ref.watch(specialtiesProvider);
    final doctors = ref.watch(doctorsProvider(_query));
    return Scaffold(
      appBar: AppBar(title: Text(l.findADoctor), centerTitle: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.sm),
            child: TextField(
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400),
                    () => mounted ? setState(() => _q = v.trim()) : null);
              },
              decoration: InputDecoration(
                hintText: l.searchDoctorsHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.input),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.input),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          SizedBox(
            height: 104,
            child: specs.when(
              loading: () => const LoadingView(compact: true),
              error: (e, _) => ErrorStateView(
                  compact: true, error: e, onRetry: () => ref.invalidate(specialtiesProvider)),
              data: (list) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                itemBuilder: (_, i) {
                  final s = list[i];
                  final sel = _specialty == s.code;
                  return SpecialtyChip(
                    specialty: s,
                    index: i,
                    selected: sel,
                    onTap: () => setState(() => _specialty = sel ? null : s.code),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 0),
            child: SectionHeader(title: l.topDoctorsNearYou),
          ),
          Expanded(
            child: AsyncView<List<Doctor>>(
              value: doctors,
              onRetry: () => ref.invalidate(doctorsProvider(_query)),
              isEmpty: (l) => l.isEmpty,
              empty: EmptyStateView(
                icon: Icons.person_search_outlined,
                title: l.noDoctorsTitle,
                message: l.noDoctorsMessage,
                actionLabel: l.clearFilters,
                onAction: () => setState(() {
                  _specialty = null;
                  _mode = null;
                }),
              ),
              data: (list) => RefreshIndicator(
                onRefresh: () => ref.refresh(doctorsProvider(_query).future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (_, i) => DoctorCard(
                    doctor: list[i],
                    favorite: _favorites.contains(list[i].id),
                    onFavorite: () => setState(() => _favorites.contains(list[i].id)
                        ? _favorites.remove(list[i].id)
                        : _favorites.add(list[i].id)),
                    onTap: () => _openDoctor(list[i]),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.sm),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      icon: Icons.videocam_outlined,
                      label: l.videoConsult,
                      selected: _mode == 'video',
                      onTap: () => setState(() => _mode = _mode == 'video' ? null : 'video'),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _ModeChip(
                      icon: Icons.add_business_outlined,
                      label: l.modeInClinic,
                      selected: _mode == 'in_clinic',
                      onTap: () => setState(() => _mode = _mode == 'in_clinic' ? null : 'in_clinic'),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _ModeChip(
                      icon: Icons.home_outlined,
                      label: l.homeVisit,
                      selected: false,
                      onTap: () => context.push('/home-checkup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? (context.isDark ? context.mintSurface : AppColors.mint100) : context.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: selected ? AppColors.primary : context.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: selected ? AppColors.primary : context.textStrong)),
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

class SpecialtyChip extends StatelessWidget {
  const SpecialtyChip({
    super.key,
    required this.specialty,
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final Specialty specialty;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Labels.specialtyAccent(index);
    return Semantics(
      selected: selected,
      button: true,
      label: specialty.name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.tile),
        onTap: onTap,
        child: Container(
          width: 84,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? AppColors.mint100 : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
          ),
          child: Column(
            children: [
              IconTile(icon: Labels.specialtyIcon(specialty.code), accent: accent, size: 50),
              const SizedBox(height: 4),
              Text(specialty.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  const DoctorCard({
    super.key,
    required this.doctor,
    required this.onTap,
    this.favorite = false,
    this.onFavorite,
  });
  final Doctor doctor;
  final VoidCallback onTap;
  final bool favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = doctor;
    return CcCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoctorPhoto(name: d.name, url: d.photoUrl, width: 76, height: 84, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(d.name, style: Theme.of(context).textTheme.titleSmall)),
                    if (d.verified)
                      Tooltip(
                        message: l.verified,
                        child: const Icon(Icons.verified, size: 16, color: AppColors.skyFg),
                      ),
                  ],
                ),
                Text(d.specialtyName, style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(l.yearsExperience(d.experienceYears),
                          style: const TextStyle(fontSize: 12.5)),
                    ),
                    const Text('  •  ', style: TextStyle(fontSize: 12.5)),
                    const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                    Text(' ${d.rating.toStringAsFixed(1)} (${d.ratingCount})',
                        style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(money(d.fees.video),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(width: 10),
                    if (d.availableNow || d.nextAvailableAt != null)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: AppColors.primaryLight, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                d.availableNow
                                    ? l.availableNow
                                    : l.nextAvailable(fmtDateTime(context, d.nextAvailableAt!)),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.primaryLight, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (d.rankingFactors.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final f in d.rankingFactors.take(3))
                        StatusPill(label: f, color: AppColors.skyFg),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onFavorite != null)
            IconButton(
              tooltip: favorite ? l.removeFavorite : l.addFavorite,
              onPressed: onFavorite,
              icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? AppColors.danger : context.textMuted),
            ),
        ],
      ),
    );
  }
}
