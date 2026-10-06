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
import '../../state/core_providers.dart';
import 'onboarding_resume.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  DateTime? _dob;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(sessionProvider).me;
    _name = TextEditingController(text: me?.name ?? '');
    _email = TextEditingController(text: me?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final me = await ref.read(authRepositoryProvider).updateMe(
            name: _name.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          );
      final selfId = me.selfPatientId;
      if (selfId != null && (_dob != null || _gender != null)) {
        await ref.read(patientRepositoryProvider).update(selfId, {
          if (_dob != null) 'dob': ymd(_dob!),
          'gender': ?_gender,
        });
      }
      // Onboarding counts as complete from here on; remember the remaining
      // optional steps so a reload resumes them instead of skipping to Home.
      await ref.read(onboardingResumeProvider.notifier).set(me.id, '/onboarding/emergency');
      await ref.read(sessionProvider.notifier).refreshMe();
      ref.invalidate(patientsProvider);
      if (mounted) context.go('/onboarding/emergency');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.profileSetupTitle), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              Text(l.profileSetupSubtitle, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.xl),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.fullName),
                validator: (v) => (v == null || v.trim().length < 2) ? l.nameRequired : null,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l.emailOptional),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
                      ? null
                      : l.emailInvalid;
                },
              ),
              const SizedBox(height: Space.lg),
              DateField(label: l.dateOfBirth, value: _dob, onTap: _pickDob),
              const SizedBox(height: Space.lg),
              Text(l.gender, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: Space.sm),
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
              const SizedBox(height: Space.xxxl),
              PrimaryButton(label: l.continueLabel, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? context.l10n.selectDate : fmtDate(context, value!)),
      ),
    );
  }
}
