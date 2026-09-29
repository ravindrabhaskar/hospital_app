import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/clinical.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// `GET /clinician/patients?q=` (only patients linked to this doctor).
final patientSearchProvider = FutureProvider.autoDispose.family<List<Patient>, String>(
  (ref, q) => ref.watch(clinicianRepositoryProvider).patients(q),
);

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
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
    final results = ref.watch(patientSearchProvider(_q));
    return Scaffold(
      appBar: AppBar(title: Semantics(header: true, child: Text(l.navPatients))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 4, AppSpacing.screen, 8),
            child: TextField(
              key: const Key('patientSearch'),
              controller: _search,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.patientSearchHint),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(patientSearchProvider(_q).future),
              child: AsyncBody<List<Patient>>(
                value: results,
                onRetry: () => ref.invalidate(patientSearchProvider(_q)),
                data: (items) => items.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 320,
                            child: EmptyView(
                              message: _q.isEmpty ? l.patientsEmpty : l.patientsNoMatch,
                              icon: Icons.person_search_outlined,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => gap8,
                        itemBuilder: (context, i) {
                          final p = items[i];
                          return Card(
                            child: ListTile(
                              key: Key('patient.${p.id}'),
                              minVerticalPadding: 12,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.mint100,
                                foregroundImage: p.avatarUrl == null ? null : NetworkImage(p.avatarUrl!),
                                child: Text(
                                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                                  style: const TextStyle(color: AppColors.primary),
                                ),
                              ),
                              title: Text(p.name),
                              subtitle: Text(ageGender(l, p.age, p.gender)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/patients/${p.id}'),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
