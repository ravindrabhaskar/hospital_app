import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../models/provider_application.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'application_repository.dart';

/// Language names stored in `languages` (the same values doctors use).
const applicationLanguages = [
  'English', 'Hindi', 'Telugu', 'Tamil', 'Kannada', 'Malayalam', 'Marathi', 'Bengali', 'Urdu', 'Odia',
];

/// Multi-step application form (contract §30): role → qualification →
/// languages and areas → review. Used for new applications and for
/// "Edit & resubmit" (prefilled).
class ApplicationForm extends StatefulWidget {
  const ApplicationForm({
    super.key,
    required this.repository,
    required this.onSubmit,
    this.initial,
    this.busy = false,
    this.onCancel,
  });

  final ApplicationRepository repository;
  final ApplicationDraft? initial;

  /// Returns normally on success; throws [ApiException] on failure.
  final Future<void> Function(ApplicationDraft draft) onSubmit;
  final VoidCallback? onCancel;
  final bool busy;

  bool get isEdit => initial != null;

  @override
  State<ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends State<ApplicationForm> {
  late final ApplicationDraft _draft = widget.initial ?? ApplicationDraft();
  final _detailsKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _draft.fullName);
  late final _qualification = TextEditingController(text: _draft.qualification);
  late final _regNumber = TextEditingController(text: _draft.registrationNumber);
  late final _regCouncil = TextEditingController(text: _draft.registrationCouncil);
  late final _experience =
      TextEditingController(text: widget.initial == null ? '' : _draft.experienceYears.toString());
  final _pincode = TextEditingController();

  int _step = 0;
  bool _languagesError = false;
  String? _pincodeError;
  bool _checkingPincode = false;
  List<Specialty>? _specialties;
  bool _specialtiesFailed = false;

  @override
  void initState() {
    super.initState();
    if (_draft.isDoctor) _loadSpecialties();
  }

  @override
  void dispose() {
    for (final c in [_name, _qualification, _regNumber, _regCouncil, _experience, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSpecialties() async {
    if (_specialties != null) return;
    try {
      final items = await widget.repository.specialties();
      if (mounted) setState(() => _specialties = items);
    } catch (_) {
      if (mounted) setState(() => _specialtiesFailed = true);
    }
  }

  void _syncDetails() {
    _draft
      ..fullName = _name.text
      ..qualification = _qualification.text
      ..registrationNumber = _regNumber.text
      ..registrationCouncil = _regCouncil.text
      ..experienceYears = int.tryParse(_experience.text.trim()) ?? 0;
  }

  bool _validateStep(int step) {
    switch (step) {
      case 1:
        _syncDetails();
        return _detailsKey.currentState?.validate() ?? false;
      case 2:
        setState(() => _languagesError = _draft.languages.isEmpty);
        return _draft.languages.isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep(_step)) return;
    if (_step < 3) setState(() => _step++);
  }

  Future<void> _submit() async {
    for (final s in [1, 2]) {
      if (!_validateStep(s)) {
        setState(() => _step = s);
        return;
      }
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSubmit(_draft);
      messenger.showSnackBar(SnackBar(content: Text(l.onbSubmitted)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l, e))));
    }
  }

  Future<void> _addPincode() async {
    final l = context.l10n;
    final pin = _pincode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _pincodeError = l.onbPincodeInvalid);
      return;
    }
    setState(() {
      _pincodeError = null;
      _checkingPincode = true;
    });
    try {
      final r = await widget.repository.serviceability(pin);
      if (!mounted) return;
      setState(() {
        if (r.serviceable && r.zoneId != null) {
          if (!_draft.zones.any((z) => z.id == r.zoneId)) {
            _draft.zones.add(ZoneChoice(id: r.zoneId!, name: r.zoneName));
          }
          _pincode.clear();
        } else {
          _pincodeError = l.onbAreaNotServiceable(pin);
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _pincodeError = errorMessage(l, e));
    } finally {
      if (mounted) setState(() => _checkingPincode = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? context.l10n.onbRequired : null;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Stepper(
      key: const Key('applicationStepper'),
      currentStep: _step,
      onStepTapped: (s) {
        if (s < _step || _validateStep(_step)) setState(() => _step = s);
      },
      controlsBuilder: (context, details) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            if (details.currentStep < 3)
              Expanded(
                child: FilledButton(
                    key: Key('onbNext.${details.stepIndex}'), onPressed: _next, child: Text(l.onbNext)),
              )
            else
              Expanded(
                child: FilledButton(
                  key: const Key('onbSubmit'),
                  onPressed: widget.busy ? null : _submit,
                  child: widget.busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.isEdit ? l.onbResubmit : l.onbSubmit),
                ),
              ),
            const SizedBox(width: 8),
            if (details.currentStep > 0)
              TextButton(onPressed: () => setState(() => _step--), child: Text(l.commonBack)),
          ],
        ),
      ),
      steps: [
        Step(
          title: Text(l.onbStepRole),
          isActive: _step >= 0,
          state: _step > 0 ? StepState.complete : StepState.indexed,
          content: _roleStep(),
        ),
        Step(
          title: Text(l.onbStepDetails),
          isActive: _step >= 1,
          state: _step > 1 ? StepState.complete : StepState.indexed,
          content: _detailsStep(),
        ),
        Step(
          title: Text(l.onbStepAreas),
          isActive: _step >= 2,
          state: _step > 2 ? StepState.complete : StepState.indexed,
          content: _areasStep(),
        ),
        Step(title: Text(l.onbStepReview), isActive: _step >= 3, content: _reviewStep()),
      ],
    );
  }

  Widget _roleStep() {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.onbTypeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        RadioGroup<String>(
          groupValue: _draft.type,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _draft.type = v);
            if (v == 'doctor') _loadSpecialties();
          },
          child: Column(
            children: [
              for (final t in applicationTypes)
                RadioListTile<String>(
                  key: Key('onbType.$t'),
                  contentPadding: EdgeInsets.zero,
                  value: t,
                  title: Text(providerTypeLabel(l, t)),
                ),
            ],
          ),
        ),
        if (_draft.isDoctor)
          Container(
            key: const Key('onbDoctorNote'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.skyBg, borderRadius: BorderRadius.circular(12)),
            child: Text(l.onbDoctorNote),
          ),
      ],
    );
  }

  Widget _detailsStep() {
    final l = context.l10n;
    return Form(
      key: _detailsKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('onbFullName'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.onbFullName),
            validator: _required,
          ),
          TextFormField(
            key: const Key('onbQualification'),
            controller: _qualification,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.onbQualification),
            validator: _required,
          ),
          TextFormField(
            key: const Key('onbRegNumber'),
            controller: _regNumber,
            maxLength: 60,
            decoration: InputDecoration(labelText: l.onbRegNumber),
            validator: _required,
          ),
          TextFormField(
            key: const Key('onbRegCouncil'),
            controller: _regCouncil,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.onbRegCouncil),
          ),
          if (_draft.isDoctor) ...[
            if (_specialties != null && _specialties!.isNotEmpty)
              DropdownButtonFormField<String>(
                key: const Key('onbSpecialty'),
                initialValue: _specialties!.any((s) => s.code == _draft.specialty) ? _draft.specialty : null,
                decoration: InputDecoration(labelText: l.onbSpecialty),
                items: [for (final s in _specialties!) DropdownMenuItem(value: s.code, child: Text(s.name))],
                onChanged: (v) => _draft.specialty = v,
                validator: (v) => v == null ? l.onbRequired : null,
              )
            else if (_specialtiesFailed)
              TextFormField(
                key: const Key('onbSpecialtyCode'),
                initialValue: _draft.specialty,
                decoration: InputDecoration(labelText: l.onbSpecialty),
                onChanged: (v) => _draft.specialty = v.trim().isEmpty ? null : v.trim(),
                validator: _required,
              )
            else
              const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            const SizedBox(height: 12),
          ],
          TextFormField(
            key: const Key('onbExperience'),
            controller: _experience,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            decoration: InputDecoration(labelText: l.onbExperience),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              return n == null || n < 0 || n > 60 ? l.onbExperienceInvalid : null;
            },
          ),
        ],
      ),
    );
  }

  Widget _areasStep() {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.onbLanguages, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final lang in applicationLanguages)
              FilterChip(
                key: Key('onbLang.$lang'),
                label: Text(lang),
                selected: _draft.languages.contains(lang),
                onSelected: (on) => setState(() {
                  on ? _draft.languages.add(lang) : _draft.languages.remove(lang);
                  if (on) _languagesError = false;
                }),
              ),
          ],
        ),
        if (_languagesError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.onbLanguagesRequired, style: const TextStyle(color: AppColors.danger)),
          ),
        const SizedBox(height: 20),
        Text(l.onbAreas, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(l.onbAreasHint, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('onbPincode'),
                controller: _pincode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: InputDecoration(labelText: l.onbPincode, errorText: _pincodeError, errorMaxLines: 3),
                onSubmitted: (_) => _addPincode(),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton(
                key: const Key('onbAddArea'),
                onPressed: _checkingPincode ? null : _addPincode,
                child: _checkingPincode
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.onbAddArea),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final z in _draft.zones)
              InputChip(
                key: Key('onbZone.${z.id}'),
                label: Text(z.name ?? l.onbZoneSaved),
                onDeleted: () => setState(() => _draft.zones.remove(z)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final l = context.l10n;
    _syncDetails();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledValue(icon: Icons.badge_outlined, label: l.onbTypeLabel, value: providerTypeLabel(l, _draft.type)),
        LabeledValue(icon: Icons.person_outline, label: l.onbFullName, value: _draft.fullName.trim()),
        LabeledValue(icon: Icons.school_outlined, label: l.onbQualification, value: _draft.qualification.trim()),
        LabeledValue(
          icon: Icons.verified_outlined,
          label: l.onbRegNumber,
          value: [_draft.registrationNumber.trim(), _draft.registrationCouncil.trim()]
              .where((s) => s.isNotEmpty)
              .join(' · '),
        ),
        LabeledValue(icon: Icons.work_history_outlined, label: l.onbExperience, value: '${_draft.experienceYears}'),
        LabeledValue(icon: Icons.translate, label: l.onbLanguages, value: _draft.languages.join(', ')),
        LabeledValue(
          icon: Icons.place_outlined,
          label: l.onbAreas,
          value: _draft.zones.isEmpty
              ? l.commonNotAvailable
              : _draft.zones.map((z) => z.name ?? l.onbZoneSaved).join(', '),
        ),
        if (!widget.isEdit) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.mint50, borderRadius: BorderRadius.circular(12)),
            child: Text(l.onbReviewDocsNote),
          ),
        ],
        if (widget.onCancel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: widget.onCancel, child: Text(l.onbCancelEdit)),
          ),
      ],
    );
  }
}
