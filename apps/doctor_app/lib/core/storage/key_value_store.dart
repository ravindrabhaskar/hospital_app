import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal async key/value store. The production implementation is backed by
/// [FlutterSecureStorage] (Android Keystore / iOS Keychain / WebCrypto), so
/// everything written here (tokens, the cached identity) is
/// encrypted at rest.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // A corrupted keystore entry must not crash the app; treat as missing.
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// In-memory store used by tests.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

/// Storage keys, kept in one place so logout can wipe them all.
class StoreKeys {
  StoreKeys._();
  static const accessToken = 'auth.accessToken';
  static const refreshToken = 'auth.refreshToken';
  static const me = 'auth.me';

  static const all = [accessToken, refreshToken, me];
}
