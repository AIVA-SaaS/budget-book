import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';

/// Persists dashboard widget configuration (order + visibility) via SharedPreferences.
class HomeConfigService {
  static const _key = 'dashboard_widget_config';

  /// Loads saved config or returns defaults.
  ///
  /// When new widget IDs are introduced in [defaultDashboardWidgets] that are
  /// absent from the persisted list, they are appended at the end so users
  /// automatically see new widgets without losing their existing order.
  Future<List<DashboardWidgetConfig>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) {
      return List<DashboardWidgetConfig>.from(defaultDashboardWidgets);
    }
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      final saved = decoded
          .map((e) =>
              DashboardWidgetConfig.fromJson(e as Map<String, dynamic>))
          .toList();

      // Remove widgets that no longer exist in defaults (e.g. renamed 'wishlist' → 'spending_plans')
      final defaultIds = defaultDashboardWidgets.map((d) => d.id).toSet();
      saved.removeWhere((c) => !defaultIds.contains(c.id));

      // Merge: append any new default widgets not present in the saved list.
      final savedIds = saved.map((c) => c.id).toSet();
      int nextOrder = saved.isEmpty
          ? 0
          : saved.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 1;
      for (final def in defaultDashboardWidgets) {
        if (!savedIds.contains(def.id)) {
          saved.add(def.copyWith(order: nextOrder));
          nextOrder++;
        }
      }

      return saved;
    } catch (_) {
      return List<DashboardWidgetConfig>.from(defaultDashboardWidgets);
    }
  }

  /// Persists the given config list.
  Future<void> saveConfig(List<DashboardWidgetConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr =
        jsonEncode(configs.map((c) => c.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }
}
