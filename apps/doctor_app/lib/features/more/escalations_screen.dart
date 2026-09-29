import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/clinical.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

final escalationsProvider = FutureProvider.autoDispose<List<SafetyEvent>>(
  (ref) => ref.watch(clinicianRepositoryProvider).escalations(),
);

/// `GET /clinician/escalations` (contract §16).
class EscalationsScreen extends ConsumerWidget {
  const EscalationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.escalationsTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(escalationsProvider.future),
        child: AsyncBody<List<SafetyEvent>>(
          value: ref.watch(escalationsProvider),
          onRetry: () => ref.invalidate(escalationsProvider),
          data: (items) => items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: 320,
                      child: EmptyView(message: l.escalationsEmpty, icon: Icons.verified_outlined),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => gap8,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Card(
                      color: e.isEmergency ? AppColors.dangerBg : null,
                      child: ListTile(
                        minVerticalPadding: 12,
                        leading: Icon(
                          e.isEmergency ? Icons.emergency : Icons.warning_amber_rounded,
                          color: e.isEmergency ? AppColors.dangerDeep : warningFg,
                        ),
                        title: Text(e.patientName),
                        subtitle: Text(
                          [
                            levelLabel(l, e.level),
                            if (e.rules.isNotEmpty) e.rules.join(', '),
                            e.status,
                            formatDateTime(context, e.createdAt),
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/patients/${e.patientId}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
