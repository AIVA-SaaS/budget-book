import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';

void main() {
  group('DashboardWidgetConfig', () {
    test('fromJson creates correct instance', () {
      final json = {
        'id': 'monthly_summary',
        'name': '월간 요약',
        'icon': 'account_balance_wallet',
        'enabled': true,
        'order': 0,
      };

      final config = DashboardWidgetConfig.fromJson(json);

      expect(config.id, 'monthly_summary');
      expect(config.name, '월간 요약');
      expect(config.icon, 'account_balance_wallet');
      expect(config.enabled, true);
      expect(config.order, 0);
      expect(config.settings, const <String, dynamic>{});
    });

    test('toJson produces correct map', () {
      const config = DashboardWidgetConfig(
        id: 'budget_usage',
        name: '예산 사용 현황',
        icon: 'pie_chart',
        enabled: false,
        order: 1,
      );

      final json = config.toJson();

      expect(json['id'], 'budget_usage');
      expect(json['name'], '예산 사용 현황');
      expect(json['icon'], 'pie_chart');
      expect(json['enabled'], false);
      expect(json['order'], 1);
      expect(json['settings'], const <String, dynamic>{});
    });

    test('roundtrip fromJson(toJson) preserves data', () {
      const original = DashboardWidgetConfig(
        id: 'asset_balance',
        name: '자산 현황',
        icon: 'account_balance',
        enabled: false,
        order: 4,
      );

      final restored = DashboardWidgetConfig.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.icon, original.icon);
      expect(restored.enabled, original.enabled);
      expect(restored.order, original.order);
      expect(restored.settings, original.settings);
    });

    test('copyWith overrides enabled and order', () {
      const config = DashboardWidgetConfig(
        id: 'test',
        name: 'Test',
        icon: 'star',
        enabled: true,
        order: 0,
      );

      final updated = config.copyWith(enabled: false, order: 3);

      expect(updated.id, 'test');
      expect(updated.name, 'Test');
      expect(updated.enabled, false);
      expect(updated.order, 3);
    });

    test('copyWith without arguments preserves values', () {
      const config = DashboardWidgetConfig(
        id: 'test',
        name: 'Test',
        icon: 'star',
        enabled: true,
        order: 2,
      );

      final copy = config.copyWith();

      expect(copy.enabled, true);
      expect(copy.order, 2);
    });

    test('fromJson defaults enabled to true when missing', () {
      final json = {
        'id': 'x',
        'name': 'X',
        'icon': 'star',
        'order': 0,
      };

      final config = DashboardWidgetConfig.fromJson(json);
      expect(config.enabled, true);
    });

    test('fromJson defaults order to 0 when missing', () {
      final json = {
        'id': 'x',
        'name': 'X',
        'icon': 'star',
        'enabled': false,
      };

      final config = DashboardWidgetConfig.fromJson(json);
      expect(config.order, 0);
    });

    // 개수 가드 — 위젯을 추가하면 여기서 먼저 실패해서 등록 5곳 점검을 강제한다
    // (렌더 분기·아이콘 매핑·설정 시트는 dashboard_widget_registry_guard_test 가 본다).
    test('defaultDashboardWidgets has 10 items', () {
      expect(defaultDashboardWidgets.length, 10);
    });

    test('defaultDashboardWidgets has asset_balance disabled', () {
      final assetBalance =
          defaultDashboardWidgets.firstWhere((c) => c.id == 'asset_balance');
      expect(assetBalance.enabled, false);
    });

    test('defaultDashboardWidgets has spending_plans disabled', () {
      final spendingPlans =
          defaultDashboardWidgets.firstWhere((c) => c.id == 'spending_plans');
      expect(spendingPlans.enabled, false);
      expect(spendingPlans.order, 6);
    });

    test('defaultDashboardWidgets orders are sequential', () {
      for (int i = 0; i < defaultDashboardWidgets.length; i++) {
        expect(defaultDashboardWidgets[i].order, i);
      }
    });

    test('defaultDashboardWidgets has monthly_trend disabled', () {
      final trend =
          defaultDashboardWidgets.firstWhere((c) => c.id == 'monthly_trend');
      expect(trend.enabled, false);
      expect(trend.order, 8);
    });

    test('defaultDashboardWidgets has category_breakdown disabled', () {
      final cat = defaultDashboardWidgets
          .firstWhere((c) => c.id == 'category_breakdown');
      expect(cat.enabled, false);
      expect(cat.order, 9);
    });

    test('settings field roundtrip', () {
      const config = DashboardWidgetConfig(
        id: 'monthly_trend',
        name: '월별 추이',
        icon: 'show_chart',
        order: 8,
        settings: {'months': 6, 'showItems': ['income', 'expense']},
      );

      final json = config.toJson();
      final restored = DashboardWidgetConfig.fromJson(json);

      expect(restored.settings['months'], 6);
      expect(restored.settings['showItems'], ['income', 'expense']);
    });

    test('copyWith settings', () {
      const config = DashboardWidgetConfig(
        id: 'test',
        name: 'Test',
        icon: 'star',
        order: 0,
        settings: {'count': 3},
      );

      final updated = config.copyWith(settings: {'count': 10});
      expect(updated.settings['count'], 10);
    });

    test('defaultWidgetSettings has entries for configurable widgets', () {
      expect(defaultWidgetSettings.containsKey('monthly_summary'), true);
      expect(defaultWidgetSettings.containsKey('budget_usage'), true);
      expect(defaultWidgetSettings.containsKey('recent_transactions'), true);
      expect(defaultWidgetSettings.containsKey('monthly_trend'), true);
      expect(defaultWidgetSettings.containsKey('category_breakdown'), true);
    });
  });
}
