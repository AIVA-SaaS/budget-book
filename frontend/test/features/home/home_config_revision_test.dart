import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/features/home/data/home_config_service.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';

/// 설정 저장 → 홈 즉시 반영의 배선.
///
/// 홈 화면 구성 페이지는 shell 위에 push 되므로 대시보드 State 가 살아남는다.
/// 저장 시 revision 이 오르지 않으면 대시보드는 pull-to-refresh 전까지 옛 구성을
/// 계속 쓰고, 방금 켠 위젯이 안 보여 "기능이 없는 것처럼" 보인다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveConfig bumps the revision notifier', () async {
    final service = HomeConfigService();
    final before = HomeConfigService.revision.value;

    await service.saveConfig(List.of(defaultDashboardWidgets));

    expect(HomeConfigService.revision.value, before + 1);
  });

  test('updateWidgetSettings bumps it too (goes through saveConfig)', () async {
    final service = HomeConfigService();
    final before = HomeConfigService.revision.value;

    await service.updateWidgetSettings(
      List.of(defaultDashboardWidgets),
      kReconciliationWidgetId,
      {'showSubtotals': false},
    );

    expect(HomeConfigService.revision.value, before + 1);
  });

  test('listeners are notified on save', () async {
    final service = HomeConfigService();
    var notified = 0;
    void listener() => notified++;
    HomeConfigService.revision.addListener(listener);
    addTearDown(() => HomeConfigService.revision.removeListener(listener));

    await service.saveConfig(List.of(defaultDashboardWidgets));

    expect(notified, 1);
  });

  test('the month-end review widget is registered and defaults to off', () {
    final widget = defaultDashboardWidgets
        .firstWhere((w) => w.id == kReconciliationWidgetId);

    expect(widget.enabled, isFalse,
        reason: '기본 ON 이면 켜지 않은 사용자에게도 정산 요약 API 호출이 생긴다.');
    expect(widget.icon, 'fact_check',
        reason: '이미 번들에 있는 아이콘이어야 한다(폰트 subset 불변).');
  });

  test('a newly shipped widget is appended for existing users', () async {
    // 저장된 구성에 신규 id 가 없어도 loadConfig 가 끝에 붙여준다 —
    // 기존 사용자에게 마이그레이션 없이 노출되는 경로.
    final legacy = defaultDashboardWidgets
        .where((w) => w.id != kReconciliationWidgetId)
        .toList();
    await HomeConfigService().saveConfig(legacy);

    final loaded = await HomeConfigService().loadConfig();

    expect(
      loaded.any((c) => c.id == kReconciliationWidgetId),
      isTrue,
    );
  });
}
