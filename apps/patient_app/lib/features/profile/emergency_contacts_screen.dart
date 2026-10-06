import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../onboarding/emergency_contact_screen.dart' show EmergencyContactFields;

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyContacts)),
      body: AsyncView<PatientProfile>(
        value: ref.watch(patientProfileProvider),
        onRetry: () => ref.invalidate(patientProfileProvider),
        data: (p) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  Text(l.emergencyContactsFor(p.name), style: TextStyle(color: context.textMuted)),
                  const SizedBox(height: Space.md),
                  if (p.emergencyContacts.isEmpty)
                    EmptyStateView(
                        compact: true, icon: Icons.contact_phone_outlined, title: l.noEmergencyContacts),
                  for (final c in p.emergencyContacts)
                    ListRowTile(
                      icon: Icons.person_outline,
                      accent: Accent.rose,
                      title: c.name,
                      subtitle: '${c.relation} · ${c.phone}',
                      trailing: IconButton(
                        tooltip: l.remove,
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () async {
                          try {
                            await ref.read(patientRepositoryProvider).deleteEmergencyContact(p.id, c.id);
                            ref.invalidate(patientProfileProvider);
                          } catch (e) {
                            if (context.mounted) showSnack(context, errorMessage(context, e), error: true);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
                child: PrimaryButton(
                  label: l.addEmergencyContact,
                  icon: Icons.add,
                  onPressed: () => showModalBottomSheet<void>(
                    useRootNavigator: true,
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _AddContactSheet(patientId: p.id),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactSheet extends ConsumerStatefulWidget {
  const _AddContactSheet({required this.patientId});
  final String patientId;

  @override
  ConsumerState<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<_AddContactSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(patientRepositoryProvider).addEmergencyContact(widget.patientId,
          name: _name.text.trim(), phone: '+91${_phone.text.trim()}', relation: _relation.text.trim());
      ref.invalidate(patientProfileProvider);
      if (mounted) Navigator.pop(context);
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
      padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.addEmergencyContact, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.lg),
              EmergencyContactFields(name: _name, phone: _phone, relation: _relation),
              const SizedBox(height: Space.xl),
              PrimaryButton(label: l.save, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
