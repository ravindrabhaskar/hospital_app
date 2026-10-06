import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.vitals)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(vitalsProvider.future),
              child: AsyncView<List<VitalMeasurement>>(
                value: ref.watch(vitalsProvider),
                onRetry: () => ref.invalidate(vitalsProvider),
                isEmpty: (l) => l.isEmpty,
                empty: EmptyStateView(icon: Icons.monitor_heart_outlined, title: l.noVitals, message: l.noVitalsMessage),
                data: (list) => ListView.separated(
                  padding: const EdgeInsets.all(Space.screen),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (_, i) {
                    final v = list[i];
                    final value = v.value == v.value.roundToDouble()
                        ? v.value.toStringAsFixed(0)
                        : v.value.toStringAsFixed(1);
                    return CcCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const IconTile(icon: Icons.monitor_heart_outlined, accent: Accent.rose, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Labels.vitalType(l, v.type), style: Theme.of(context).textTheme.titleSmall),
                                Text(
                                  [fmtDateTime(context, v.measuredAt), ?v.recordedByName].join(' · '),
                                  style: TextStyle(fontSize: 12, color: context.textMuted),
                                ),
                                const SizedBox(height: 4),
                                StatusPill(
                                    label: Labels.provenance(l, v.source),
                                    color: Labels.provenanceColor(v.source)),
                              ],
                            ),
                          ),
                          Text('$value ${v.unit}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
              child: PrimaryButton(
                label: l.addVital,
                icon: Icons.add,
                onPressed: () => showModalBottomSheet<void>(
                  useRootNavigator: true,
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AddVitalSheet(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddVitalSheet extends ConsumerStatefulWidget {
  const AddVitalSheet({super.key});

  @override
  ConsumerState<AddVitalSheet> createState() => _AddVitalSheetState();
}

class _AddVitalSheetState extends ConsumerState<AddVitalSheet> {
  String _type = 'pulse';
  final _value = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final v = double.tryParse(_value.text.trim());
    if (v == null) {
      showSnack(context, l.enterValidNumber, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final p = await ref.read(activePatientProvider.future);
      await ref.read(recordsRepositoryProvider).addVital(
            patientId: p.id,
            type: _type,
            value: v,
            unit: VitalType.defaultUnits[_type] ?? '',
            measuredAt: DateTime.now(),
          );
      ref.invalidate(vitalsProvider);
      ref.invalidate(insightsTodayProvider);
      ref.invalidate(timelineProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.addVital, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.lg),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(labelText: l.vitalTypeLabel),
            items: [
              for (final t in VitalType.all) DropdownMenuItem(value: t, child: Text(Labels.vitalType(l, t))),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(labelText: l.value, suffixText: VitalType.defaultUnits[_type]),
          ),
          const SizedBox(height: Space.sm),
          Text(l.vitalSelfEnteredNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
          const SizedBox(height: Space.lg),
          PrimaryButton(label: l.save, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
