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

    test('defaultDashboardWidgets has 6 items', () {
      expect(defaultDashboardWidgets.length, 6);
    });

    test('defaultDashboardWidgets has asset_balance disabled', () {
      final assetBalance =
          defaultDashboardWidgets.firstWhere((c) => c.id == 'asset_balance');
      expect(assetBalance.enabled, false);
    });

    test('defaultDashboardWidgets orders are sequential', () {
      for (int i = 0; i < defaultDashboardWidgets.length; i++) {
        expect(defaultDashboardWidgets[i].order, i);
      }
    });
  });
}
