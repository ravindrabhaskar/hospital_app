import 'package:shared_preferences/shared_preferences.dart';

import 'roles.dart';

/// Persists the "Remember my choice" role. Its key is outside the three apps'
/// namespaces (`patient.`, `provider.`, `doctor.`), so no app can touch it.
class RoleStore {
  RoleStore(this._prefs);

  static const rememberedRoleKey = 'all_in_one.rememberedRole';

  final SharedPreferences _prefs;

  DemoRole? get rememberedRole => DemoRole.fromId(_prefs.getString(rememberedRoleKey));

  Future<void> remember(DemoRole role) => _prefs.setString(rememberedRoleKey, role.id);

  Future<void> forget() => _prefs.remove(rememberedRoleKey);
}
