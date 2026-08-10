import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';

/// Persists dashboard widget configuration (order + visibility + settings) via SharedPreferences.
class HomeConfigService {
  static const _key = 'dashboard_widget_config';

  /// Bumped on every successful [saveConfig].
  ///
  /// The dashboard used to re-read this config only in initState and on
  /// pull-to-refresh. Since the config screen is pushed on top of the shell, the
  /// dashboard's State survives the round trip — so toggling a widget on did
  /// nothing visible until the user happened to pull-to-refresh, which reads as
  /// "the feature is broken". Every write path goes through [saveConfig], so
  /// listening here covers reorder, on/off and per-widget settings alike.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

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

      // Remove widgets that no longer exist in defaults (e.g. renamed 'wishlist' -> 'spending_plans')
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
    revision.value++;
  }

  /// Gets settings for a specific widget, merging saved with defaults.
  Map<String, dynamic> getWidgetSettings(DashboardWidgetConfig config) {
    final defaults = defaultWidgetSettings[config.id] ?? {};
    return {...defaults, ...config.settings};
  }

  /// Updates settings for a specific widget in the config list and persists.
  Future<List<DashboardWidgetConfig>> updateWidgetSettings(
    List<DashboardWidgetConfig> configs,
    String widgetId,
    Map<String, dynamic> newSettings,
  ) async {
    final updated = configs.map((c) {
      if (c.id == widgetId) {
        return c.copyWith(settings: newSettings);
      }
      return c;
    }).toList();
    await saveConfig(updated);
    return updated;
  }
}
