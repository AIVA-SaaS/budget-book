import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 카드형 목록의 세로 리듬 **이관 완료**를 코드가 열거한다 (2026-08-24).
///
/// 왜 목록을 코드가 드나: 주석이 표면 목록을 들면 **반드시 어긋난다**
/// (calynda 2026-08-21 교훈 — 주석은 "좁은 표면 2개"라고 했지만 실제로는 한 곳이
/// 그리지 않고 있었다). 그래서 이 테스트가 목록의 단일 소스다.
///
/// 이관 판정: 그 파일에 **맨 `Card(` 생성자가 없다** = 세로 리듬을 `BbCardTile` 이
/// 소유한다. `Card(` 가 다시 나타나면 그 화면만 승인값에서 떨어져 나간다(3차의 재발 구도).
void main() {
  /// 살아있는 화면의 **카드형 목록** 호스트. 도달 경로:
  /// 하단 네비 '분석' → `AnalysisPage` → [예산] `BudgetListPage` · [통계] `StatisticsPage`
  /// (내부 탭 4: 카테고리별 · 추이 · 전년 비교 · 결제수단별),
  /// 그리고 `PeriodSummaryPage`(기간 요약, 별도 진입).
  const migratedHosts = <String>[
    // 분석 > 통계
    'lib/features/statistics/presentation/widgets/category_breakdown_tab.dart',
    'lib/features/statistics/presentation/widgets/payment_method_stats_tab.dart',
    'lib/features/statistics/presentation/widgets/year_comparison_tab.dart',
    'lib/features/statistics/presentation/widgets/summary_tab.dart',
    // 기간 요약(별도 진입) — 같은 계약
    'lib/features/statistics/presentation/widgets/period_budget_tab.dart',
    'lib/features/statistics/presentation/widgets/period_category_tab.dart',
    'lib/features/statistics/presentation/widgets/period_daily_tab.dart',
    'lib/features/statistics/presentation/widgets/period_payment_method_tab.dart',
    // 분석 > 예산 > 주간
    'lib/features/weekly_budget/presentation/widgets/week_summary_card.dart',
  ];

  /// `Card(` 는 잡고 `BbCardTile(` 는 잡지 않는다.
  final bareCard = RegExp(r'(?<![A-Za-z_])Card\(');

  group('카드형 목록 호스트는 BbCardTile 을 쓴다', () {
    for (final path in migratedHosts) {
      test(path, () {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '호스트가 사라졌거나 이동했다 — 목록을 갱신하라: $path');
        final src = file.readAsStringSync();
        expect(src.contains('BbCardTile('), isTrue,
            reason: '$path 가 BbCardTile 을 쓰지 않는다 = 이 화면만 승인값에서 떨어진다');
        expect(bareCard.allMatches(src), isEmpty,
            reason: '$path 에 맨 `Card(` 가 되살아났다. 세로 리듬이 다시 갈라진다 — '
                '카드형 항목 사이는 20.0dp @390 / 25.0 @960 이어야 한다');
      });
    }
  });

  group('도달성 — 죽은 화면은 이관 대상이 아니다', () {
    test('DashboardPage 는 라우팅되지 않는다(Card 최다 보유 27건이지만 미도달)', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      // AdminDashboardPage 는 별개다 — 관리자 화면은 살아 있다.
      final dead = RegExp(r'(?<!Admin)DashboardPage\(');
      expect(dead.allMatches(router), isEmpty,
          reason: 'DashboardPage 가 라우팅되기 시작했다면 이제 살아있는 화면이다 — '
              '카드형 목록 이관 대상 목록에 넣어라 (reference_dead_home_dashboard)');
    });

    test('이관 목록에 죽은 화면이 섞이지 않았다', () {
      expect(
          migratedHosts.where((p) => p.contains('dashboard_page.dart')), isEmpty,
          reason: '죽은 화면을 이관하면 작업량만 늘고 사용자에게 보이는 변화는 0이다');
    });
  });
}
