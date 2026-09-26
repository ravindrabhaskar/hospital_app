import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/token_store.dart';
import '../../core/storage/key_value_store.dart';
import '../../models/me.dart';
import '../../models/provider_profile.dart';
import '../offline/offline_queue.dart';
import '../offline/visit_cache.dart';
import '../visits/data/provider_repository.dart';
import 'auth_repository.dart';

enum AuthStatus {
  /// Restoring a saved session.
  initializing,

  /// No session: show login.
  signedOut,

  /// Signed in, but the account has no `provider` role.
  restricted,

  /// Provider whose verification is not `verified`.
  blocked,

  /// Verified provider: full app.
  ready,

  /// Session exists but identity could not be loaded (offline, no cache).
  error,

  /// The server answered `403 MFA_REQUIRED` (contract §22). Providers are not
  /// MFA-enforced, so this means an account/configuration issue for support.
  mfaRequired,
}

/// Owns the session and the provider's identity; drives router redirects.
class AuthController extends ChangeNotifier {
  AuthController({
    required this.tokens,
    required this.authRepository,
    required this.providerRepository,
    required this.store,
    required this.queue,
    required this.cache,
    this.onReady,
    this.onInactive,
  });

  final TokenStore tokens;
  final AuthRepository authRepository;
  final ProviderRepository providerRepository;
  final KeyValueStore store;
  final OfflineQueue queue;
  final VisitCache cache;

  /// Hooks for side effects (location reporting, queue replay).
  void Function(ProviderProfile profile)? onReady;
  void Function()? onInactive;

  /// Runs during logout while the session is still valid (e.g. DELETE /devices).
  Future<void> Function()? beforeLogout;

  /// Runs after every local wipe (logout, session expiry).
  Future<void> Function()? onSignedOut;

  AuthStatus _status = AuthStatus.initializing;
  Me? _me;
  ProviderProfile? _profile;
  ApiException? _error;
  bool _fromCache = false;
  String? _storedPhotoUrl;

  AuthStatus get status => _status;
  Me? get me => _me;
  ProviderProfile? get profile => _profile;
  ApiException? get error => _error;

  /// Profile photo: from `/provider/me` if the server sends it, else the URL
  /// returned by the last `POST /me/photo` on this device.
  String? get photoUrl => _profile?.photoUrl ?? _storedPhotoUrl;

  Future<void> setPhotoUrl(String url) async {
    _storedPhotoUrl = url;
    await store.write(StoreKeys.photoUrl, url);
    notifyListeners();
  }

  /// Identity came from the encrypted cache because the API was unreachable.
  bool get fromCache => _fromCache;

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
    await cache.purgeExpired();
    await loadIdentity();
  }

  /// After a successful OTP verification.
  Future<void> signIn(AuthSession session) async {
    await tokens.save(session.accessToken, session.refreshToken);
    _me = session.user;
    await loadIdentity();
  }

  /// Resolves which gate applies: restricted / blocked / ready.
  Future<void> loadIdentity() async {
    _error = null;
    _storedPhotoUrl ??= await store.read(StoreKeys.photoUrl);
    try {
      final me = await authRepository.me();
      _me = me;
      await store.write(StoreKeys.me, jsonEncode(me.toJson()));
      if (!me.isProvider) {
        _profile = null;
        _fromCache = false;
        _set(AuthStatus.restricted);
        return;
      }
      final profile = await providerRepository.me();
      await _applyProfile(profile, fromCache: false);
    } on ApiException catch (e) {
      if (e.isMfaRequired) {
        _error = e;
        onInactive?.call();
        _set(AuthStatus.mfaRequired);
        return;
      }
      if (e.statusCode == 403) {
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
      final meRaw = await store.read(StoreKeys.me);
      final profileRaw = await store.read(StoreKeys.providerProfile);
      if (meRaw == null) return false;
      _me = Me.fromJson(Map<String, dynamic>.from(jsonDecode(meRaw) as Map));
      if (!_me!.isProvider) {
        _set(AuthStatus.restricted);
        return true;
      }
      if (profileRaw == null) return false;
      final profile = ProviderProfile.fromJson(Map<String, dynamic>.from(jsonDecode(profileRaw) as Map));
      await _applyProfile(profile, fromCache: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyProfile(ProviderProfile profile, {required bool fromCache}) async {
    _profile = profile;
    _fromCache = fromCache;
    if (!fromCache) {
      await store.write(StoreKeys.providerProfile, jsonEncode(profile.toJson()));
    }
    if (profile.isVerified) {
      _set(AuthStatus.ready);
      onReady?.call(profile);
    } else {
      _set(AuthStatus.blocked);
      onInactive?.call(); // stop background work (location, sync)
    }
  }

  /// Re-checks verification (blocked screen "check again", profile refresh).
  Future<void> refreshProfile() => loadIdentity();

  /// Toggles duty; requires connectivity. Throws [ApiException] on failure.
  Future<void> setDuty(bool onDuty) async {
    final updated = await providerRepository.setDuty(onDuty);
    await _applyProfile(updated, fromCache: false);
  }

  /// Logs out and wipes every piece of local data (tokens, queue, cached PHI).
  Future<void> logout() async {
    try {
      await beforeLogout?.call();
    } catch (_) {}
    final refresh = tokens.refreshToken;
    if (refresh != null) {
      try {
        await authRepository.logout(refresh);
      } catch (_) {
        // Server-side revoke is best effort; local wipe always happens.
      }
    }
    await _clearLocal();
  }

  /// Called when the API reports the session is no longer valid.
  Future<void> handleSessionExpired() async {
    if (_status == AuthStatus.signedOut) return;
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    onInactive?.call();
    await tokens.clear();
    await queue.clear();
    await cache.clear();
    for (final key in StoreKeys.all) {
      await store.delete(key);
    }
    _me = null;
    _profile = null;
    _storedPhotoUrl = null;
    _fromCache = false;
    try {
      await onSignedOut?.call();
    } catch (_) {}
    _set(AuthStatus.signedOut);
  }
}
