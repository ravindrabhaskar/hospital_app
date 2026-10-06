import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

// ------------------------------------------------------------------ ABHA helpers (§39)

/// Digits only, at most 14.
String abhaDigits(String input) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  return d.length > 14 ? d.substring(0, 14) : d;
}

/// Formats (possibly partial) ABHA digits as `XX-XXXX-XXXX-XXXX`.
String formatAbhaNumber(String input) {
  final d = abhaDigits(input);
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 6 || i == 10) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
}

/// A complete ABHA number has exactly 14 digits.
bool isValidAbhaNumber(String input) => RegExp(r'^\d{14}$').hasMatch(input.replaceAll('-', '').trim()) &&
    RegExp(r'^[\d-]+$').hasMatch(input.trim());

/// ABHA address: `name@abdm` (production) or `name@sbx` (sandbox).
bool isValidAbhaAddress(String input) =>
    RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._]{2,31}@(abdm|sbx)$').hasMatch(input.trim());

/// Live `XX-XXXX-XXXX-XXXX` formatting while typing.
class AbhaNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatAbhaNumber(newValue.text);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

// ------------------------------------------------------------------ UI

/// Profile → Health Profile → "ABHA (Health ID)".
class AbhaSection extends ConsumerStatefulWidget {
  const AbhaSection({super.key, required this.profile});
  final PatientProfile profile;

  @override
  ConsumerState<AbhaSection> createState() => _AbhaSectionState();
}

class _AbhaSectionState extends ConsumerState<AbhaSection> {
  bool _verifying = false;

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => AbhaEditSheet(profile: widget.profile),
    );
    if (saved == true) ref.invalidate(patientProfileProvider);
  }

  Future<void> _verify() async {
    final l = context.l10n;
    setState(() => _verifying = true);
    try {
      await ref.read(patientRepositoryProvider).verifyAbha(widget.profile.id);
      ref.invalidate(patientProfileProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 503 || e.code == 'DEPENDENCY_UNAVAILABLE') {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.hourglass_top),
            title: Text(l.abhaVerifyComingSoonTitle),
            content: Text(l.abhaVerifyComingSoon),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l.ok))],
          ),
        );
      } else {
        showSnack(context, errorMessage(context, e), error: true);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = widget.profile.abha;
    final hasAny = (a?.number ?? '').isNotEmpty || (a?.address ?? '').isNotEmpty;
    final verified = a?.verified ?? false;
    return CcCard(
      key: const Key('abha-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.badge_outlined, accent: Accent.sky, size: 40),
              const SizedBox(width: Space.md),
              Expanded(child: Text(l.abhaTitle, style: Theme.of(context).textTheme.titleSmall)),
              if (hasAny)
                StatusPill(
                  key: const Key('abha-status'),
                  label: verified ? l.verified : l.notVerified,
                  color: verified ? AppColors.primaryLight : AppColors.peachFg,
                  icon: verified ? Icons.verified : Icons.pending_outlined,
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (!hasAny)
            Text(l.abhaIntro, style: TextStyle(color: context.textMuted))
          else ...[
            LabeledValue(label: l.abhaNumber, value: a?.number == null ? '—' : formatAbhaNumber(a!.number!)),
            LabeledValue(label: l.abhaAddress, value: a?.address ?? '—'),
          ],
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('abha-edit'),
                  onPressed: _edit,
                  icon: Icon(hasAny ? Icons.edit_outlined : Icons.add),
                  label: Text(hasAny ? l.edit : l.addAbha),
                ),
              ),
              if (hasAny && !verified) ...[
                const SizedBox(width: Space.sm),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('abha-verify'),
                    onPressed: _verifying ? null : _verify,
                    icon: _verifying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(l.verify),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class AbhaEditSheet extends ConsumerStatefulWidget {
  const AbhaEditSheet({super.key, required this.profile});
  final PatientProfile profile;

  @override
  ConsumerState<AbhaEditSheet> createState() => _AbhaEditSheetState();
}

class _AbhaEditSheetState extends ConsumerState<AbhaEditSheet> {
  late final _number = TextEditingController(text: formatAbhaNumber(widget.profile.abha?.number ?? ''));
  late final _address = TextEditingController(text: widget.profile.abha?.address ?? '');
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = abhaDigits(_number.text);
      final a = _address.text.trim();
      await ref.read(patientRepositoryProvider).update(widget.profile.id, {
        if (n.isNotEmpty) 'abhaNumber': n,
        if (a.isNotEmpty) 'abhaAddress': a,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.abhaTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.sm),
              Text(l.abhaEditHint, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.lg),
              TextFormField(
                key: const Key('abha-number'),
                controller: _number,
                keyboardType: TextInputType.number,
                inputFormatters: [AbhaNumberFormatter()],
                decoration: InputDecoration(labelText: l.abhaNumber, hintText: 'XX-XXXX-XXXX-XXXX'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty && _address.text.trim().isEmpty) return l.abhaEnterOne;
                  if (t.isNotEmpty && !isValidAbhaNumber(t)) return l.abhaNumberInvalid;
                  return null;
                },
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                key: const Key('abha-address'),
                controller: _address,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(labelText: l.abhaAddress, hintText: 'name@abdm'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isNotEmpty && !isValidAbhaAddress(t)) return l.abhaAddressInvalid;
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: Space.lg),
              PrimaryButton(key: const Key('abha-save'), label: l.save, loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
