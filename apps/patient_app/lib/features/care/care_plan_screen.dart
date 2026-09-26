import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/data_providers.dart';
import 'care_widgets.dart';

class CarePlanScreen extends ConsumerWidget {
  const CarePlanScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.carePlan)),
      body: AsyncView<CarePlan>(
        value: ref.watch(carePlanProvider(id)),
        onRetry: () => ref.invalidate(carePlanProvider(id)),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(carePlanProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              CcCard(
                color: context.mintSurface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.summary, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(l.byDoctor(p.doctorName), style: TextStyle(color: context.textMuted)),
                    if (p.followUpDueAt != null) ...[
                      const SizedBox(height: 8),
                      StatusPill(
                          label: l.followUpDue(fmtDate(context, p.followUpDueAt!)),
                          icon: Icons.update,
                          color: AppColors.skyFg),
                    ],
                  ],
                ),
              ),
              if (p.instructions.isNotEmpty) ...[
                SectionHeader(title: l.instructions),
                CcCard(child: Text(p.instructions, style: const TextStyle(height: 1.45))),
              ],
              SectionHeader(title: l.tasks),
              if (p.tasks.isEmpty)
                Text(l.noOpenTasks, style: TextStyle(color: context.textMuted))
              else
                for (final t in p.tasks) TaskTile(task: t),
              if (p.medications.isNotEmpty) ...[
                SectionHeader(title: l.medications, onSeeAll: () => context.push('/medications')),
                for (final m in p.medications) MedicationCard(medication: m),
              ],
              ListRowTile(
                icon: Icons.favorite_border,
                title: l.viewCareEpisode,
                onTap: () => context.push('/episodes/${p.careEpisodeId}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
