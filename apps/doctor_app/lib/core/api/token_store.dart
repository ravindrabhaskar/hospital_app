import '../storage/key_value_store.dart';

/// Holds the session tokens in memory, persisted in encrypted storage.
class TokenStore {
  TokenStore(this._store);

  final KeyValueStore _store;
  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null && _refresh!.isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    _access = await _store.read(StoreKeys.accessToken);
    _refresh = await _store.read(StoreKeys.refreshToken);
    _loaded = true;
  }

  Future<void> save(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    await _store.write(StoreKeys.accessToken, access);
    await _store.write(StoreKeys.refreshToken, refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _store.delete(StoreKeys.accessToken);
    await _store.delete(StoreKeys.refreshToken);
  }
}
