import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../core/server/server_actions.dart';
import '../../core/server/server_address_dialog.dart';
import '../../core/theme.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _phoneForm = GlobalKey<FormState>();
  final _otpForm = GlobalKey<FormState>();
  bool _otpSent = false;
  bool _busy = false;
  String? _devOtp;
  String? _error;

  /// The OTP request never reached the server (offline, wrong address...).
  bool _unreachable = false;

  String get _e164 => '+91${_phone.text.trim()}';

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_phoneForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _unreachable = false;
    });
    try {
      final res = await ref.read(authRepositoryProvider).requestOtp(_e164);
      setState(() {
        _otpSent = true;
        _devOtp = res.devOtp;
      });
    } catch (e) {
      if (!mounted) return;
      final unreachable = e is ApiException && e.isNetwork;
      setState(() {
        _unreachable = unreachable;
        _error = unreachable ? null : errorMessage(context.l10n, e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (!_otpForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref.read(authRepositoryProvider).verifyOtp(_e164, _otp.text.trim());
      await ref.read(authControllerProvider).signIn(session);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeServer() async {
    final changed = await openServerAddressDialog(context);
    if (changed && mounted) setState(() => _unreachable = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final server = ref.watch(serverSettingsProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.mint50, AppColors.mint100]),
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.medical_information_outlined, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: Text(l.loginTitle, style: text.headlineMedium?.copyWith(color: AppColors.primaryDark)),
                        ),
                        const SizedBox(height: 6),
                        Text(l.loginSubtitle, style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_otpSent)
                    Form(
                      key: _phoneForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: const Key('phoneField'),
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [AutofillHints.telephoneNumberNational],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              labelText: l.loginPhoneLabel,
                              hintText: l.loginPhoneHint,
                              prefixText: '+91 ',
                            ),
                            validator: (v) =>
                                RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '') ? null : l.loginPhoneInvalid,
                            onFieldSubmitted: (_) => _requestOtp(),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _requestOtp,
                            child: _busy ? const ButtonSpinner() : Text(l.loginSendOtp),
                          ),
                        ],
                      ),
                    )
                  else
                    Form(
                      key: _otpForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l.loginOtpSentTo('+91 ${_phone.text}'), style: text.bodyMedium),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('otpField'),
                            controller: _otp,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(labelText: l.loginOtpLabel),
                            validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : l.loginOtpInvalid,
                            onFieldSubmitted: (_) => _verify(),
                          ),
                          if (_devOtp != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.warningBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                l.loginDevOtpHint(_devOtp!),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _verify,
                            child: _busy ? const ButtonSpinner() : Text(l.loginVerify),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _otpSent = false;
                                    _otp.clear();
                                    _devOtp = null;
                                    _error = null;
                                  }),
                            child: Text(l.loginChangeNumber),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                  if (_unreachable) ...[
                    const SizedBox(height: 12),
                    ServerUnreachableNotice(
                      settings: server,
                      onChangeServer: _changeServer,
                      color: AppColors.danger,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Demo / QA builds only (hidden in https production builds).
                  ServerAddressChip(settings: server, onTap: _changeServer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
