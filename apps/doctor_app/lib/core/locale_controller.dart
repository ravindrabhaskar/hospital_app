import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language (en / hi / te), persisted in shared preferences
/// (not sensitive, so it doesn't need encrypted storage).
class LocaleController extends ChangeNotifier {
  static const supported = ['en', 'hi', 'te'];
  /// [keyPrefix] namespaces the preference (all-in-one demo build).
  LocaleController({String keyPrefix = ''}) : _key = '${keyPrefix}app.locale';

  final String _key;

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null && supported.contains(code)) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLocale(String code) async {
    if (!supported.contains(code)) return;
    _locale = Locale(code);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (_) {}
  }

  static String nativeName(String code) {
    switch (code) {
      case 'hi':
        return 'हिन्दी';
      case 'te':
        return 'తెలుగు';
      default:
        return 'English';
    }
  }
}
