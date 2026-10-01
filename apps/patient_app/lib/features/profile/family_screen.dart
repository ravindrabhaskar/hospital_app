import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/json.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../onboarding/profile_setup_screen.dart' show DateField;

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final patients = ref.watch(patientsProvider);
    final active = ref.watch(activePatientProvider).value;
    final grants = ref.watch(familyAccessProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.familyMembers)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyAccessProvider);
          ref.invalidate(patientsProvider);
          await ref.read(patientsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Text(l.familyIntro, style: TextStyle(color: context.textMuted)),
            SectionHeader(
              title: l.peopleYouCareFor,
              trailing: TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                    context: context, isScrollControlled: true, builder: (_) => const AddDependentSheet()),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l.addDependent),
              ),
            ),
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
                        borderColor: p.id == active?.id ? context.brand : null,
                        onTap: () => ref.read(activePatientIdProvider.notifier).select(p.id),
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
                                    [Labels.relation(l, p.relation), if (p.age != null) l.ageYears(p.age!)].join(' · '),
                                    style: TextStyle(fontSize: 12.5, color: context.textMuted),
                                  ),
                                  if (!p.isSelf)
                                    Text(
                                      p.permissions.map((x) => Labels.familyPermission(l, x)).join(', '),
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.primaryLight),
                                    ),
                                ],
                              ),
                            ),
                            if (p.id == active?.id) StatusPill(label: l.actingNow),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (active != null)
              SectionHeader(
                title: l.caregiversFor(active.name),
                trailing: TextButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                      context: context, isScrollControlled: true, builder: (_) => const InviteCaregiverSheet()),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(l.invite),
                ),
              ),
            AsyncView<List<FamilyAccessGrant>>(
              value: grants,
              compact: true,
              onRetry: () => ref.invalidate(familyAccessProvider),
              isEmpty: (l) => l.where((g) => g.isActive).isEmpty,
              empty: Text(l.noCaregivers, style: TextStyle(color: context.textMuted)),
              data: (list) => Column(
                children: [
                  for (final g in list.where((g) => g.isActive))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: CcCard(
                        child: Row(
                          children: [
                            Avatar(name: g.granteeName ?? g.granteePhone, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.granteeName ?? g.granteePhone,
                                      style: Theme.of(context).textTheme.titleSmall),
                                  Text('${g.relation} · ${g.granteePhone}',
                                      style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                                  Text(g.permissions.map((x) => Labels.familyPermission(l, x)).join(', '),
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.primaryLight)),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: Text(l.revokeAccess),
                                    content: Text(l.revokeAccessBody(g.granteeName ?? g.granteePhone)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                                      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.revoke)),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                try {
                                  await ref.read(patientRepositoryProvider).revokeGrant(g.id);
                                  ref.invalidate(familyAccessProvider);
                                } catch (e) {
                                  if (context.mounted) showSnack(context, errorMessage(context, e), error: true);
                                }
                              },
                              child: Text(l.revoke),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddDependentSheet extends ConsumerStatefulWidget {
  const AddDependentSheet({super.key});

  @override
  ConsumerState<AddDependentSheet> createState() => _AddDependentSheetState();
}

class _AddDependentSheetState extends ConsumerState<AddDependentSheet> {
  final _name = TextEditingController();
  final _relation = TextEditingController();
  DateTime? _dob;
  String _gender = 'female';
  String? _blood;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_name.text.trim().isEmpty || _relation.text.trim().isEmpty || _dob == null) {
      showSnack(context, l.fillRequired, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(patientRepositoryProvider).addDependent(
            name: _name.text.trim(),
            dob: ymd(_dob!),
            gender: _gender,
            relation: _relation.text.trim(),
            bloodGroup: _blood,
          );
      ref.invalidate(patientsProvider);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.addDependent, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.addDependentSub, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.lg),
            TextField(controller: _name, decoration: InputDecoration(labelText: l.fullName)),
            const SizedBox(height: Space.md),
            TextField(controller: _relation, decoration: InputDecoration(labelText: l.relationLabel, hintText: l.relationHint)),
            const SizedBox(height: Space.md),
            DateField(
              label: l.dateOfBirth,
              value: _dob,
              onTap: () async {
                final d = await showDatePicker(
                    context: context, initialDate: DateTime(1960), firstDate: DateTime(1900), lastDate: DateTime.now());
                if (d != null) setState(() => _dob = d);
              },
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final g in const ['male', 'female', 'other'])
                  ChoiceChip(
                      label: Text(Labels.gender(l, g)),
                      selected: _gender == g,
                      onSelected: (_) => setState(() => _gender = g)),
              ],
            ),
            const SizedBox(height: Space.md),
            DropdownButtonFormField<String>(
              initialValue: _blood,
              decoration: InputDecoration(labelText: l.bloodGroupOptional),
              items: [
                for (final b in const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'])
                  DropdownMenuItem(value: b, child: Text(b)),
              ],
              onChanged: (v) => setState(() => _blood = v),
            ),
            const SizedBox(height: Space.xl),
            PrimaryButton(label: l.add, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class InviteCaregiverSheet extends ConsumerStatefulWidget {
  const InviteCaregiverSheet({super.key});

  @override
  ConsumerState<InviteCaregiverSheet> createState() => _InviteCaregiverSheetState();
}

class _InviteCaregiverSheetState extends ConsumerState<InviteCaregiverSheet> {
  final _phone = TextEditingController();
  final _relation = TextEditingController();
  final Set<String> _perms = {FamilyPermission.viewRecords, FamilyPermission.receiveAlerts};
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final l = context.l10n;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim())) {
      showSnack(context, l.phoneInvalid, error: true);
      return;
    }
    if (_relation.text.trim().isEmpty || _perms.isEmpty) {
      showSnack(context, l.fillRequired, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final p = await ref.read(activePatientProvider.future);
      await ref.read(patientRepositoryProvider).inviteCaregiver(p.id,
          phone: '+91${_phone.text.trim()}', relation: _relation.text.trim(), permissions: _perms.toList());
      ref.invalidate(familyAccessProvider);
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, l.caregiverInvited);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final active = ref.watch(activePatientProvider).value;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.inviteCaregiver, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.inviteCaregiverSub(active?.name ?? ''), style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l.phoneLabel, prefixText: '+91  ', counterText: ''),
            ),
            const SizedBox(height: Space.md),
            TextField(controller: _relation, decoration: InputDecoration(labelText: l.relationLabel, hintText: l.relationHint)),
            const SizedBox(height: Space.md),
            Text(l.permissions, style: Theme.of(context).textTheme.titleSmall),
            for (final perm in FamilyPermission.all)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _perms.contains(perm),
                onChanged: (v) => setState(() => v == true ? _perms.add(perm) : _perms.remove(perm)),
                title: Text(Labels.familyPermission(l, perm)),
                subtitle: Text(switch (perm) {
                  FamilyPermission.viewRecords => l.permViewRecordsDesc,
                  FamilyPermission.manageCare => l.permManageCareDesc,
                  FamilyPermission.book => l.permBookDesc,
                  _ => l.permReceiveAlertsDesc,
                }, style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: Space.md),
            PrimaryButton(label: l.sendInvite, loading: _saving, onPressed: _invite),
          ],
        ),
      ),
    );
  }
}
