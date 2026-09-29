import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../state/core_providers.dart';

/// The optional "invite code" step follows when wallet & offers are on (§60).
String nextAfterEmergency(WidgetRef ref) => ref.read(featureFlagsProvider).walletOffers ? '/onboarding/invite' : '/home';

class EmergencyContactSetupScreen extends ConsumerStatefulWidget {
  const EmergencyContactSetupScreen({super.key});

  @override
  ConsumerState<EmergencyContactSetupScreen> createState() => _State();
}

class _State extends ConsumerState<EmergencyContactSetupScreen> {
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
    final selfId = ref.read(sessionProvider).me?.selfPatientId;
    if (selfId == null) return context.go(nextAfterEmergency(ref));
    setState(() => _saving = true);
    try {
      await ref.read(patientRepositoryProvider).addEmergencyContact(selfId,
          name: _name.text.trim(),
          phone: '+91${_phone.text.trim()}',
          relation: _relation.text.trim());
      if (mounted) context.go(nextAfterEmergency(ref));
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
      appBar: AppBar(
        title: Text(l.emergencyContactTitle),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => context.go(nextAfterEmergency(ref)), child: Text(l.skip))],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              const Center(child: IconTile(icon: Icons.contact_phone_outlined, accent: Accent.rose, size: 72)),
              const SizedBox(height: Space.lg),
              Text(l.emergencyContactSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.xl),
              EmergencyContactFields(name: _name, phone: _phone, relation: _relation),
              const SizedBox(height: Space.xxxl),
              PrimaryButton(label: l.saveAndContinue, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class EmergencyContactFields extends StatelessWidget {
  const EmergencyContactFields(
      {super.key, required this.name, required this.phone, required this.relation});
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController relation;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        TextFormField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l.contactName),
          validator: (v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null,
        ),
        const SizedBox(height: Space.lg),
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l.phoneLabel, prefixText: '+91  ', counterText: ''),
          validator: (v) =>
              RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '') ? null : l.phoneInvalid,
        ),
        const SizedBox(height: Space.lg),
        TextFormField(
          controller: relation,
          decoration: InputDecoration(labelText: l.relationLabel, hintText: l.relationHint),
          validator: (v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null,
        ),
      ],
    );
  }
}
