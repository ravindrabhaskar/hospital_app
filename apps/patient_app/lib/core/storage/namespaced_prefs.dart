import 'package:shared_preferences/shared_preferences.dart';

/// A [SharedPreferences] view whose keys are all prefixed with [prefix].
///
/// Used when this app runs inside the all-in-one demo build next to other
/// CareCompanion apps: every preference the app reads or writes lands under
/// its own namespace, so the apps can't overwrite each other's settings or
/// caches. [getKeys] only reports this namespace (without the prefix) and
/// [clear] only removes this namespace. Standalone builds don't use it.
class NamespacedSharedPreferences implements SharedPreferences {
  NamespacedSharedPreferences(this._inner, this.prefix) : assert(prefix.isNotEmpty);

  final SharedPreferences _inner;
  final String prefix;

  String _k(String key) => '$prefix$key';

  @override
  Set<String> getKeys() => {
        for (final k in _inner.getKeys())
          if (k.startsWith(prefix)) k.substring(prefix.length),
      };

  @override
  Object? get(String key) => _inner.get(_k(key));

  @override
  bool? getBool(String key) => _inner.getBool(_k(key));

  @override
  int? getInt(String key) => _inner.getInt(_k(key));

  @override
  double? getDouble(String key) => _inner.getDouble(_k(key));

  @override
  String? getString(String key) => _inner.getString(_k(key));

  @override
  bool containsKey(String key) => _inner.containsKey(_k(key));

  @override
  List<String>? getStringList(String key) => _inner.getStringList(_k(key));

  @override
  Future<bool> setBool(String key, bool value) => _inner.setBool(_k(key), value);

  @override
  Future<bool> setInt(String key, int value) => _inner.setInt(_k(key), value);

  @override
  Future<bool> setDouble(String key, double value) => _inner.setDouble(_k(key), value);

  @override
  Future<bool> setString(String key, String value) => _inner.setString(_k(key), value);

  @override
  Future<bool> setStringList(String key, List<String> value) => _inner.setStringList(_k(key), value);

  @override
  Future<bool> remove(String key) => _inner.remove(_k(key));

  @override
  @Deprecated('This method is now a no-op, and should no longer be called.')
  Future<bool> commit() async => true;

  /// Removes only this namespace's keys.
  @override
  Future<bool> clear() async {
    var ok = true;
    for (final k in _inner.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      ok = await _inner.remove(k) && ok;
    }
    return ok;
  }

  @override
  Future<void> reload() => _inner.reload();
}

/// [prefs] itself when [prefix] is empty (standalone), otherwise a namespaced view.
SharedPreferences namespacedPrefs(SharedPreferences prefs, String prefix) =>
    prefix.isEmpty ? prefs : NamespacedSharedPreferences(prefs, prefix);
