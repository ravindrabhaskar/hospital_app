import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../data/auth_repository.dart';
import '../../models/json.dart';
import '../../models/me.dart';

/// Steps of the staff TOTP flow (contract §22).
enum MfaStep {
  /// Nothing started yet.
  idle,

  /// Not enrolled: shows the secret + otpauth link and asks for the first code.
  enrol,

  /// Enrolment confirmed: shows the 10 single-use recovery codes once.
  recoveryCodes,

  /// Enrolled: asks for the current authenticator code.
  verify,

  /// Fallback: asks for one recovery code.
  recovery,

  /// Verified; the MFA-verified session was handed to [MfaController.onVerified].
  done,
}

/// Why the last attempt failed.
enum MfaError { wrongCode, invalidFormat, locked, network, other }

/// State machine for enrolment -> verification -> recovery fallback.
/// UI-independent so it is unit tested.
class MfaController extends ChangeNotifier {
  MfaController({required this.repository, required this.onVerified});

  final AuthRepository repository;

  /// Receives the MFA-verified session (tokens are rotated by the server).
  final Future<void> Function(AuthSession session) onVerified;

  static final _totp = RegExp(r'^\d{6}$');
  static final _recovery = RegExp(r'^[A-Za-z0-9-]{6,32}$');

  MfaStep _step = MfaStep.idle;
  bool _busy = false;
  MfaError? _error;
  String? _errorMessage;
  int? _attemptsRemaining;
  TotpEnrollment? _enrollment;
  List<String> _recoveryCodes = const [];
  AuthSession? _pendingSession;

  MfaStep get step => _step;
  bool get busy => _busy;
  MfaError? get error => _error;
  String? get errorMessage => _errorMessage;
  int? get attemptsRemaining => _attemptsRemaining;
  TotpEnrollment? get enrollment => _enrollment;
  List<String> get recoveryCodes => _recoveryCodes;

  static bool isTotpFormat(String code) => _totp.hasMatch(code.trim());
  static bool isRecoveryFormat(String code) => _recovery.hasMatch(code.trim());

  /// Chooses the first step from `Me.mfaEnrolled`.
  Future<void> begin(Me me) async {
    if (me.mfaEnrolled) {
      _go(MfaStep.verify);
    } else {
      await startEnrolment();
    }
  }

  Future<void> startEnrolment() => _run(_enrol);

  Future<void> _enrol() async {
    try {
      _enrollment = await repository.enrollTotp();
      _go(MfaStep.enrol);
    } on ApiException catch (e) {
      if (e.isConflict) {
        // Already enrolled (e.g. on another device): verify instead.
        _go(MfaStep.verify);
        return;
      }
      rethrow;
    }
  }

  Future<void> confirmEnrolment(String code) async {
    if (!isTotpFormat(code)) return _formatError();
    await _run(() async {
      final res = await repository.confirmTotp(code.trim());
      _recoveryCodes = res.recoveryCodes;
      _pendingSession = res.session;
      _go(MfaStep.recoveryCodes);
    });
  }

  /// The doctor saved the recovery codes: finish with the verified session.
  Future<void> acknowledgeRecoveryCodes() async {
    final session = _pendingSession;
    if (_step != MfaStep.recoveryCodes || session == null) return;
    _pendingSession = null;
    _recoveryCodes = const [];
    _go(MfaStep.done);
    await onVerified(session);
  }

  Future<void> verifyCode(String code) async {
    if (!isTotpFormat(code)) return _formatError();
    await _run(() async {
      try {
        final session = await repository.verifyMfa(code: code.trim());
        _go(MfaStep.done);
        await onVerified(session);
      } on ApiException catch (e) {
        if (e.isConflict && e.details['enrolled'] == false) {
          await _enrol();
          return;
        }
        rethrow;
      }
    });
  }

  Future<void> verifyRecoveryCode(String code) async {
    if (!isRecoveryFormat(code)) return _formatError();
    await _run(() async {
      final session = await repository.verifyMfa(recoveryCode: code.trim());
      _go(MfaStep.done);
      await onVerified(session);
    });
  }

  void useRecoveryCode() {
    if (_step == MfaStep.verify) _go(MfaStep.recovery);
  }

  void useAuthenticator() {
    if (_step == MfaStep.recovery) _go(MfaStep.verify);
  }

  void _go(MfaStep step) {
    _step = step;
    _error = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _formatError() {
    _error = MfaError.invalidFormat;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _errorMessage = null;
    notifyListeners();
    try {
      await body();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      if (e.isRateLimited) {
        _error = MfaError.locked;
      } else if (e.isValidation) {
        _error = MfaError.wrongCode;
        _attemptsRemaining = intOrNull(e.details['attemptsRemaining']);
      } else if (e.isNetwork) {
        _error = MfaError.network;
      } else {
        _error = MfaError.other;
      }
    } catch (_) {
      _error = MfaError.other;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
