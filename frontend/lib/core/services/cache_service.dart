import 'package:shared_preferences/shared_preferences.dart';

/// A simple cache service backed by SharedPreferences with TTL support.
/// Used to cache frequently accessed list data (categories, payment methods).
class CacheService {
  static const Duration defaultTtl = Duration(minutes: 5);
  static const String _ttlSuffix = '_ttl';

  /// Caches a JSON string under the given key with TTL.
  Future<void> cacheData(String key, String jsonString,
      {Duration ttl = defaultTtl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonString);
    final expiresAt =
        DateTime.now().add(ttl).millisecondsSinceEpoch;
    await prefs.setInt('$key$_ttlSuffix', expiresAt);
  }

  /// Returns cached data if available and not expired, otherwise null.
  Future<String?> getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt('$key$_ttlSuffix');
    if (expiresAt == null) return null;

    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      // TTL expired, remove cached data
      await prefs.remove(key);
      await prefs.remove('$key$_ttlSuffix');
      return null;
    }

    return prefs.getString(key);
  }

  /// Removes cached data for the given key.
  Future<void> removeCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('$key$_ttlSuffix');
  }
}
