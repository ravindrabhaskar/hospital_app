import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/me.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'mfa_controller.dart';

/// Staff two-step verification (contract §22): enrol (secret + otpauth link,
/// no QR needed on the same phone) -> recovery codes, or verify with the
/// authenticator code / a recovery code.
class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  late final MfaController _mfa;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    _mfa = MfaController(repository: ref.read(authRepositoryProvider), onVerified: auth.completeMfa);
    final me = auth.me ?? const Me(id: '', phone: '', name: null, roles: [], language: 'en', providerId: null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mfa.begin(me));
  }

  @override
  void dispose() {
    _mfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListenableBuilder(
                listenable: _mfa,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.mint100,
                        child: Icon(Icons.phonelink_lock_outlined, size: 36, color: AppColors.primary),
                      ),
                    ),
                    gap16,
                    Semantics(
                      header: true,
                      child: Text(
                        l.mfaTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    gap16,
                    MfaStepView(controller: _mfa),
                    gap16,
                    TextButton(onPressed: () => ref.read(authControllerProvider).logout(), child: Text(l.commonLogout)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The step body; separate from the screen so tests can drive it directly.
class MfaStepView extends StatefulWidget {
  const MfaStepView({super.key, required this.controller});
  final MfaController controller;

  @override
  State<MfaStepView> createState() => _MfaStepViewState();
}

class _MfaStepViewState extends State<MfaStepView> {
  final _code = TextEditingController();
  bool _saved = false;
  MfaStep? _lastStep;

  MfaController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _code.text;
    switch (c.step) {
      case MfaStep.enrol:
        c.confirmEnrolment(v);
      case MfaStep.verify:
        c.verifyCode(v);
      case MfaStep.recovery:
        c.verifyRecoveryCode(v);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_lastStep != c.step) {
      _lastStep = c.step;
      _code.clear();
    }
    switch (c.step) {
      case MfaStep.idle:
      case MfaStep.done:
        return c.error != null ? _errorWithRetry(l) : const LoadingView();
      case MfaStep.enrol:
        return _enrol(l);
      case MfaStep.recoveryCodes:
        return _recoveryCodes(l);
      case MfaStep.verify:
        return _verify(l, recovery: false);
      case MfaStep.recovery:
        return _verify(l, recovery: true);
    }
  }

  Widget _errorWithRetry(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _error(l),
      gap12,
      OutlinedButton(onPressed: c.startEnrolment, child: Text(l.commonRetry)),
    ],
  );

  Widget _error(AppLocalizations l) {
    final e = c.error;
    if (e == null) return const SizedBox.shrink();
    final String text = switch (e) {
      MfaError.wrongCode => c.attemptsRemaining == null ? l.mfaWrongCode : l.mfaWrongCodeAttempts(c.attemptsRemaining!),
      MfaError.invalidFormat => c.step == MfaStep.recovery ? l.mfaRecoveryInvalid : l.mfaCodeInvalid,
      MfaError.locked => l.mfaLocked,
      MfaError.network => l.errorNetwork,
      MfaError.other => c.errorMessage ?? l.errorGeneric,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('mfaError'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.dangerDeep, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _codeField(AppLocalizations l, {required bool recovery}) => TextField(
    key: Key(recovery ? 'mfaRecoveryField' : 'mfaCodeField'),
    controller: _code,
    keyboardType: recovery ? TextInputType.text : TextInputType.number,
    autofillHints: recovery ? null : const [AutofillHints.oneTimeCode],
    textCapitalization: recovery ? TextCapitalization.characters : TextCapitalization.none,
    inputFormatters: recovery
        ? [LengthLimitingTextInputFormatter(32)]
        : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
    decoration: InputDecoration(labelText: recovery ? l.mfaRecoveryLabel : l.mfaCodeLabel),
    onSubmitted: (_) => _submit(),
  );

  Widget _submitButton(String label) => FilledButton(
    key: const Key('mfaSubmit'),
    onPressed: c.busy ? null : _submit,
    child: c.busy ? const ButtonSpinner() : Text(label),
  );

  Widget _enrol(AppLocalizations l) {
    final en = c.enrollment!;
    return Column(
      key: const Key('mfaEnrol'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.mfaEnrolIntro, textAlign: TextAlign.center),
        gap16,
        SectionCard(
          title: l.mfaStep1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.mfaOpenAppHint, style: const TextStyle(color: AppColors.textSecondary)),
              gap12,
              FilledButton.tonalIcon(
                key: const Key('mfaOpenAuthenticator'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => openExternal(context, Uri.parse(en.otpauthUrl)),
                icon: const Icon(Icons.open_in_new),
                label: Text(l.mfaOpenAuthenticator),
              ),
              gap12,
              Text(l.mfaSecretLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      en.groupedSecret,
                      key: const Key('mfaSecret'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: l.mfaCopySecret,
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: en.secret));
                      if (mounted) showSnack(context, l.copied);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        gap12,
        SectionCard(
          title: l.mfaStep2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _codeField(l, recovery: false),
              gap12,
              _error(l),
              if (c.error != null) gap12,
              _submitButton(l.mfaTurnOn),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recoveryCodes(AppLocalizations l) => Column(
    key: const Key('mfaRecoveryCodes'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
        child: Text(l.mfaRecoveryIntro, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      gap12,
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final code in c.recoveryCodes)
                SizedBox(
                  width: 140,
                  child: SelectableText(
                    code,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
      gap8,
      OutlinedButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: c.recoveryCodes.join('\n')));
          if (mounted) showSnack(context, l.copied);
        },
        icon: const Icon(Icons.copy),
        label: Text(l.mfaCopyCodes),
      ),
      gap8,
      CheckboxListTile(
        key: const Key('mfaSavedCheckbox'),
        contentPadding: EdgeInsets.zero,
        value: _saved,
        onChanged: (v) => setState(() => _saved = v ?? false),
        title: Text(l.mfaSavedCodes),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      FilledButton(
        key: const Key('mfaContinue'),
        onPressed: _saved ? c.acknowledgeRecoveryCodes : null,
        child: Text(l.commonContinue),
      ),
    ],
  );

  Widget _verify(AppLocalizations l, {required bool recovery}) => Column(
    key: Key(recovery ? 'mfaRecovery' : 'mfaVerify'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(recovery ? l.mfaRecoveryPrompt : l.mfaVerifyPrompt, textAlign: TextAlign.center),
      gap16,
      _codeField(l, recovery: recovery),
      gap12,
      _error(l),
      if (c.error != null) gap12,
      _submitButton(l.mfaVerify),
      gap8,
      TextButton(
        key: const Key('mfaSwitchMode'),
        onPressed: c.busy ? null : (recovery ? c.useAuthenticator : c.useRecoveryCode),
        child: Text(recovery ? l.mfaUseAuthenticator : l.mfaUseRecovery),
      ),
    ],
  );
}
