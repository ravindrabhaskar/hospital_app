import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/token_store.dart';
import '../../core/storage/key_value_store.dart';
import '../../data/auth_repository.dart';
import '../../data/clinician_repository.dart';
import '../../models/doctor.dart';
import '../../models/me.dart';

enum AuthStatus {
  /// Restoring a saved session.
  initializing,

  /// No session: show login.
  signedOut,

  /// Staff session that must pass TOTP (contract §22, `403 MFA_REQUIRED`).
  mfa,

  /// Signed in, but the account has no `doctor` role / doctor profile.
  restricted,

  /// Doctor: full app.
  ready,

  /// Session exists but identity could not be loaded (offline, no cache).
  error,
}

/// Owns the session and the doctor's identity; drives router redirects.
///
/// Flow: OTP -> `/me` -> not a doctor? restricted. Doctor -> load
/// `/doctor/me/profile`; `403 MFA_REQUIRED` -> mfa (enrol / verify /
/// recovery) -> ready. Any later `MFA_REQUIRED` also returns to mfa.
class AuthController extends ChangeNotifier {
  AuthController({required this.tokens, required this.authRepository, required this.clinician, required this.store});

  final TokenStore tokens;
  final AuthRepository authRepository;
  final ClinicianRepository clinician;
  final KeyValueStore store;

  /// Hooks for side effects (push registration).
  void Function()? onReady;
  Future<void> Function()? beforeLogout;
  Future<void> Function()? onSignedOut;

  AuthStatus _status = AuthStatus.initializing;
  Me? _me;
  DoctorProfile? _profile;
  ApiException? _error;
  bool _fromCache = false;

  AuthStatus get status => _status;
  Me? get me => _me;
  DoctorProfile? get profile => _profile;
  ApiException? get error => _error;
  bool get fromCache => _fromCache;

  String get displayName => _profile?.name ?? _me?.name ?? '';

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  Future<void> init() async {
    await tokens.load();
    if (!tokens.hasSession) {
      _set(AuthStatus.signedOut);
      return;
    }
    await loadIdentity();
  }

  /// After a successful OTP verification.
  Future<void> signIn(AuthSession session) async {
    await tokens.save(session.accessToken, session.refreshToken);
    _me = session.user;
    await loadIdentity();
  }

  /// After TOTP verification: the server returns a new MFA-verified session.
  Future<void> completeMfa(AuthSession session) async {
    await tokens.save(session.accessToken, session.refreshToken);
    _me = session.user;
    await loadIdentity();
  }

  Future<void> loadIdentity() async {
    _error = null;
    try {
      final me = await authRepository.me();
      _me = me;
      await store.write(StoreKeys.me, jsonEncode(me.toJson()));
      if (!me.isDoctor) {
        _profile = null;
        _set(AuthStatus.restricted);
        return;
      }
      // The first data call tells us whether the server enforces MFA.
      _profile = await clinician.profile();
      _fromCache = false;
      _set(AuthStatus.ready);
      onReady?.call();
    } on ApiException catch (e) {
      if (e.isMfaRequired) {
        _set(AuthStatus.mfa);
        return;
      }
      if (e.isForbidden || e.isNotFound) {
        _set(AuthStatus.restricted);
        return;
      }
      if (e.isUnauthenticated) {
        await _clearLocal();
        return;
      }
      if (e.isNetwork && await _restoreFromCache()) return;
      _error = e;
      _set(AuthStatus.error);
    }
  }

  Future<bool> _restoreFromCache() async {
    try {
      final raw = await store.read(StoreKeys.me);
      if (raw == null) return false;
      _me = Me.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      _fromCache = true;
      _set(_me!.isDoctor ? AuthStatus.ready : AuthStatus.restricted);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called by the API client on `403 MFA_REQUIRED`.
  void requireMfa() {
    if (_status == AuthStatus.ready || _status == AuthStatus.initializing) _set(AuthStatus.mfa);
  }

  void updateProfile(DoctorProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  /// Logs out and wipes local data.
  /// [timeout] bounds each server call (used when switching servers, where the
  /// old server may be unreachable); the local wipe always happens.
  Future<void> logout({Duration? timeout}) async {
    Future<void> bounded(Future<void> f) => timeout == null ? f : f.timeout(timeout);
    try {
      final before = beforeLogout?.call();
      if (before != null) await bounded(before);
    } catch (_) {}
    final refresh = tokens.refreshToken;
    if (refresh != null) {
      try {
        await bounded(authRepository.logout(refresh));
      } catch (_) {
        // Server-side revoke is best effort; local wipe always happens.
      }
    }
    await _clearLocal();
  }

  Future<void> handleSessionExpired() async {
    if (_status == AuthStatus.signedOut) return;
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    await tokens.clear();
    for (final key in StoreKeys.all) {
      await store.delete(key);
    }
    _me = null;
    _profile = null;
    _fromCache = false;
    try {
      await onSignedOut?.call();
    } catch (_) {}
    _set(AuthStatus.signedOut);
  }
}
