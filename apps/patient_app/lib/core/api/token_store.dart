import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredTokens {
  const StoredTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

/// Persists the session tokens. Secure storage on device; the in-memory
/// implementation is used in tests.
abstract class TokenStore {
  Future<StoredTokens?> read();
  Future<void> write(StoredTokens tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  /// [keyPrefix] namespaces the keys (all-in-one demo build); empty keeps
  /// the standalone keys.
  SecureTokenStore([FlutterSecureStorage? storage, String keyPrefix = ''])
      : _storage = storage ?? const FlutterSecureStorage(),
        _kAccess = '$keyPrefix$accessKey',
        _kRefresh = '$keyPrefix$refreshKey';

  final FlutterSecureStorage _storage;
  static const accessKey = 'cc_access_token';
  static const refreshKey = 'cc_refresh_token';
  final String _kAccess;
  final String _kRefresh;

  StoredTokens? _cache;

  @override
  Future<StoredTokens?> read() async {
    if (_cache != null) return _cache;
    try {
      final a = await _storage.read(key: _kAccess);
      final r = await _storage.read(key: _kRefresh);
      if (a == null || r == null) return null;
      return _cache = StoredTokens(accessToken: a, refreshToken: r);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(StoredTokens tokens) async {
    _cache = tokens;
    try {
      await _storage.write(key: _kAccess, value: tokens.accessToken);
      await _storage.write(key: _kRefresh, value: tokens.refreshToken);
    } catch (_) {
      // Keep the in-memory copy so the session continues for this run.
    }
  }

  @override
  Future<void> clear() async {
    _cache = null;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (_) {}
  }
}

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);
  StoredTokens? _tokens;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
