import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/server/server_actions.dart';
import '../../core/server/server_address_dialog.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/illustrations.dart';
import '../../core/widgets/state_views.dart';
import '../../state/core_providers.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  /// The OTP request never reached the server (offline, wrong address...).
  bool _unreachable = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_ctrl.text.trim());

  Future<void> _submit() async {
    if (!_valid) {
      setState(() => _error = context.l10n.phoneInvalid);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _unreachable = false;
    });
    final phone = '+91${_ctrl.text.trim()}';
    try {
      final res = await ref.read(authRepositoryProvider).requestOtp(phone);
      if (!mounted) return;
      context.push(Uri(path: '/auth/otp', queryParameters: {
        'phone': phone,
        'devOtp': ?res.devOtp,
      }).toString());
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _unreachable = e.isOffline;
          _error = e.isOffline ? null : errorMessage(context, e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeServer() async {
    final changed = await openServerAddressDialog(context);
    if (changed && mounted) setState(() => _unreachable = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final server = ref.watch(serverSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/welcome/language'),
            icon: const Icon(Icons.translate, size: 18),
            label: Text(l.changeLanguage),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Center(child: RobotAssistant(size: 84, semanticLabel: l.robotSemantic)),
            const SizedBox(height: Space.xl),
            Text(l.phoneTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Space.sm),
            Text(l.phoneSubtitle, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.xxl),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.phoneLabel,
                prefixText: '+91  ',
                counterText: '',
                errorText: _error,
              ),
              onChanged: (_) => setState(() {
                _error = null;
                _unreachable = false;
              }),
              onSubmitted: (_) => _submit(),
            ),
            if (_unreachable) ...[
              const SizedBox(height: Space.sm),
              ServerUnreachableNotice(
                settings: server,
                onChangeServer: _changeServer,
              ),
            ],
            const SizedBox(height: Space.xxl),
            PrimaryButton(label: l.sendOtp, loading: _loading, onPressed: _submit),
            const SizedBox(height: Space.lg),
            Text(l.phoneDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 12)),
            const SizedBox(height: Space.lg),
            // Demo / QA builds only (hidden in https production builds).
            ServerAddressChip(settings: server, onTap: _changeServer),
          ],
        ),
      ),
    );
  }
}
