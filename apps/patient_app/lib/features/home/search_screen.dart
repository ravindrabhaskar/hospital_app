import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../state/data_providers.dart';

/// HOME-03: search for symptoms (via AI), doctors, hospitals and medicines.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initial});
  final String? initial;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial ?? '');
  Timer? _debounce;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _q = widget.initial?.trim() ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _q = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.searchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
        ),
        actions: const [SizedBox(width: Space.md)],
      ),
      body: _q.length < 2
          ? EmptyStateView(icon: Icons.search, title: l.searchEmptyTitle, message: l.searchEmptyMessage)
          : ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                ListRowTile(
                  icon: Icons.auto_awesome,
                  accent: Accent.lavender,
                  title: l.askAiAbout(_q),
                  subtitle: l.symptomsViaAi,
                  onTap: () => context.go(Uri(path: '/ai', queryParameters: {'q': _q}).toString()),
                ),
                _Section(
                  title: l.doctors,
                  value: ref.watch(doctorsProvider((specialty: null, q: _q, mode: null))),
                  builder: (list) => [
                    for (final d in list.take(5))
                      ListRowTile(
                        icon: Labels.specialtyIcon(d.specialty),
                        title: d.name,
                        subtitle: d.specialtyName,
                        onTap: () => context.push('/doctors/${d.id}'),
                      ),
                  ],
                ),
                _Section(
                  title: l.hospitals,
                  value: ref.watch(facilitiesProvider((type: null, q: _q, lat: null, lng: null))),
                  builder: (list) => [
                    for (final f in list.take(5))
                      ListRowTile(
                        icon: Icons.local_hospital_outlined,
                        accent: Accent.rose,
                        title: f.name,
                        subtitle: '${Labels.facilityType(l, f.type)} · ${f.area}',
                        onTap: () => context.push('/facilities'),
                      ),
                  ],
                ),
                _Section(
                  title: l.medicines,
                  value: ref.watch(productsProvider((q: _q, category: null))),
                  builder: (list) => [
                    for (final p in list.take(5))
                      ListRowTile(
                        icon: Icons.medication_outlined,
                        accent: Accent.peach,
                        title: p.name,
                        subtitle: '${p.packSize} · ${money(p.price)}',
                        onTap: () => context.push('/pharmacy'),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Section<T> extends StatelessWidget {
  const _Section({required this.title, required this.value, required this.builder});
  final String title;
  final AsyncValue<List<T>> value;
  final List<Widget> Function(List<T>) builder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        AsyncView<List<T>>(
          value: value,
          compact: true,
          isEmpty: (l) => l.isEmpty,
          empty: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(context.l10n.noResults, style: TextStyle(color: context.textMuted)),
          ),
          data: (list) => Column(children: builder(list)),
        ),
      ],
    );
  }
}
