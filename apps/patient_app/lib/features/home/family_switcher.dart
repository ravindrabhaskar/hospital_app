import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';

Future<void> showFamilySwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FamilySwitcherSheet(),
  );
}

class FamilySwitcherSheet extends ConsumerWidget {
  const FamilySwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final patients = ref.watch(patientsProvider);
    final activeId = ref.watch(activePatientProvider).value?.id;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.actingForTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.actingForSubtitle, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.lg),
            AsyncView<List<PatientSummary>>(
              value: patients,
              compact: true,
              onRetry: () => ref.invalidate(patientsProvider),
              data: (list) => Column(
                children: [
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: CcCard(
                        color: p.id == activeId ? context.mintSurface : null,
                        borderColor: p.id == activeId ? context.brand : null,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        onTap: () {
                          ref.read(activePatientIdProvider.notifier).select(p.id);
                          Navigator.of(context).pop();
                        },
                        child: Row(
                          children: [
                            Avatar(name: p.name, url: p.avatarUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: Theme.of(context).textTheme.titleSmall),
                                  Text(
                                    [
                                      Labels.relation(l, p.relation),
                                      if (p.age != null) l.ageYears(p.age!),
                                    ].join(' · '),
                                    style: TextStyle(color: context.textMuted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              p.id == activeId ? Icons.check_circle : Icons.radio_button_off,
                              color: p.id == activeId ? context.brand : context.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/profile/family');
                },
                icon: const Icon(Icons.group_add_outlined),
                label: Text(l.manageFamily),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
