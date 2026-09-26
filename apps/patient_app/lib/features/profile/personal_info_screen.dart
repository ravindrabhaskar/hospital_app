import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/json.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../onboarding/profile_setup_screen.dart' show DateField;

final _selfProfileProvider = FutureProvider.autoDispose<PatientProfile?>((ref) async {
  final id = ref.watch(sessionProvider.select((s) => s.me?.selfPatientId));
  if (id == null) return null;
  return ref.watch(patientRepositoryProvider).get(id);
});

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _State();
}

class _State extends ConsumerState<PersonalInfoScreen> {
  final _form = GlobalKey<FormState>();
  TextEditingController? _name;
  TextEditingController? _email;
  DateTime? _dob;
  String? _gender;
  bool _saving = false;

  @override
  void dispose() {
    _name?.dispose();
    _email?.dispose();
    super.dispose();
  }

  void _init(PatientProfile? p) {
    if (_name != null) return;
    final me = ref.read(sessionProvider).me;
    _name = TextEditingController(text: me?.name ?? p?.name ?? '');
    _email = TextEditingController(text: me?.email ?? '');
    _dob = p?.dob == null ? null : DateTime.tryParse(p!.dob!);
    _gender = (p?.gender.isEmpty ?? true) ? null : p!.gender;
  }

  Future<void> _save(PatientProfile? p) async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final me = await ref.read(authRepositoryProvider).updateMe(
            name: _name!.text.trim(),
            email: _email!.text.trim().isEmpty ? null : _email!.text.trim(),
          );
      ref.read(sessionProvider.notifier).updateMe(me);
      if (p != null) {
        await ref.read(patientRepositoryProvider).update(p.id, {
          if (_dob != null) 'dob': ymd(_dob!),
          'gender': ?_gender,
        });
      }
      ref.invalidate(patientsProvider);
      if (mounted) {
        showSnack(context, l.saved);
        context.pop();
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
    final me = ref.watch(sessionProvider).me;
    return Scaffold(
      appBar: AppBar(title: Text(l.personalInformation)),
      body: AsyncView<PatientProfile?>(
        value: ref.watch(_selfProfileProvider),
        onRetry: () => ref.invalidate(_selfProfileProvider),
        data: (p) {
          _init(p);
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.fullName),
                  validator: (v) => (v == null || v.trim().length < 2) ? l.nameRequired : null,
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  initialValue: me?.phone ?? '',
                  enabled: false,
                  decoration: InputDecoration(labelText: l.phoneLabel),
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l.emailOptional),
                  validator: (v) => (v == null || v.trim().isEmpty ||
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                      ? null
                      : l.emailInvalid,
                ),
                const SizedBox(height: Space.lg),
                DateField(
                  label: l.dateOfBirth,
                  value: _dob,
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _dob ?? DateTime(1995),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now());
                    if (d != null) setState(() => _dob = d);
                  },
                ),
                const SizedBox(height: Space.lg),
                Wrap(
                  spacing: Space.sm,
                  children: [
                    for (final g in const ['male', 'female', 'other'])
                      ChoiceChip(
                        label: Text(Labels.gender(l, g)),
                        selected: _gender == g,
                        onSelected: (_) => setState(() => _gender = g),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xxl),
                PrimaryButton(label: l.save, loading: _saving, onPressed: () => _save(p)),
                const SizedBox(height: Space.md),
                Text(l.personalInfoNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
              ],
            ),
          );
        },
      ),
    );
  }
}
