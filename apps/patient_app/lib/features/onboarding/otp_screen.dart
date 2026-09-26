import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../state/core_providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.devOtp});
  final String phone;
  final String? devOtp;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _devOtp;
  int _resendIn = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _devOtp = widget.devOtp;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _resendIn = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _ctrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = context.l10n.otpInvalid);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ref.read(authRepositoryProvider).verifyOtp(
            widget.phone,
            otp,
            deviceName: kIsWeb ? 'web' : defaultTargetPlatform.name,
          );
      await ref.read(sessionProvider.notifier).signIn(session);
      // Router redirect takes over (onboarding or home).
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error =
            e.isValidation || e.isUnauthenticated ? context.l10n.otpWrong : errorMessage(context, e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final r = await ref.read(authRepositoryProvider).requestOtp(widget.phone);
      if (!mounted) return;
      setState(() => _devOtp = r.devOtp);
      _startTimer();
      showSnack(context, context.l10n.otpResent);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Text(l.otpTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Space.sm),
            Text(l.otpSubtitle(widget.phone),
                style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.xxl),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w700),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                errorText: _error,
                labelText: l.otpLabel,
              ),
              onChanged: (v) {
                setState(() => _error = null);
                if (v.length == 6) _verify();
              },
            ),
            if (_devOtp != null) ...[
              const SizedBox(height: Space.md),
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: context.peachSurface,
                  borderRadius: BorderRadius.circular(Radii.tile),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.developer_mode, color: AppColors.peachFg),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text(l.devOtpHint(_devOtp!))),
                    TextButton(
                      onPressed: () {
                        _ctrl.text = _devOtp!;
                        _verify();
                      },
                      child: Text(l.useCode),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Space.xxl),
            PrimaryButton(label: l.verify, loading: _loading, onPressed: _verify),
            const SizedBox(height: Space.md),
            Center(
              child: TextButton(
                onPressed: _resendIn > 0 ? null : _resend,
                child: Text(_resendIn > 0 ? l.resendIn(_resendIn) : l.resendOtp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
