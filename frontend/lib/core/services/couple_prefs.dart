import 'package:shared_preferences/shared_preferences.dart';

/// Couple-namespaced SharedPreferences helper.
/// All keys are prefixed with `{coupleId}_` to isolate data per couple.
class CouplePrefs {
  CouplePrefs._();

  static String _key(String coupleId, String name) => '${coupleId}_$name';

  static Future<String?> getString(String coupleId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(coupleId, name));
  }

  static Future<void> setString(
      String coupleId, String name, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(coupleId, name), value);
  }

  static Future<void> remove(String coupleId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(coupleId, name));
  }

  static Future<void> clearAll(String coupleId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('${coupleId}_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
