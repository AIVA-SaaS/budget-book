import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';

/// 대시보드 위젯 등록 누락 가드 + 장부 URL 단일 소스 가드.
///
/// ## 왜 필요한가
///
/// 위젯 하나를 추가하려면 서로 떨어진 5곳을 손대야 한다(기본 목록 / 기본 설정값 /
/// 렌더 분기 / 설정 시트 분기 / 아이콘 매핑). 컴파일러는 이 중 무엇도 강제하지 않아서
/// "목록에는 보이는데 홈에는 안 나오는" / "아이콘만 회색 기본값인" 부분 동작이 쉽게 남는다
/// (메모리 `feedback_feature_impact_check`). 소스 스캔으로 이 연결을 고정한다.
///
/// 그리고 `dashboard_page.dart` 가 장부 URL 을 다시 문자열로 조립하기 시작하면
/// 월 누락(navigation_state, 3회 재발)이 되살아나므로 raw 리터럴도 함께 막는다.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final dashboardPage =
      read('lib/features/home/presentation/pages/dashboard_page.dart');
  final configPage =
      read('lib/features/settings/presentation/pages/home_config_page.dart');
  final settingsSheet =
      read('lib/features/home/presentation/widgets/widget_settings_sheet.dart');

  group('every default widget is wired everywhere', () {
    for (final widget in defaultDashboardWidgets) {
      test('${widget.id} renders on the dashboard', () {
        final needle = "case '${widget.id}':";
        expect(
          dashboardPage.contains(needle),
          isTrue,
          reason: '_buildWidgetById 에 "${widget.id}" 분기가 없다. '
              '위젯이 설정 목록에는 보이지만 홈에는 렌더되지 않는다.',
        );
      });

      test('${widget.id} has an icon mapping in the home config screen', () {
        expect(
          configPage.contains("case '${widget.icon}':"),
          isTrue,
          reason: '_getIconData 에 "${widget.icon}" 매핑이 없다. '
              '홈 화면 구성 목록에서 회색 Icons.widgets 로 보인다.',
        );
      });
    }
  });

  test('widgets that declare default settings expose a settings control', () {
    for (final entry in defaultWidgetSettings.entries) {
      final needle = "case '${entry.key}':";
      expect(
        settingsSheet.contains(needle),
        isTrue,
        reason: '"${entry.key}" 는 기본 설정값을 갖는데 설정 시트에 분기가 없다 → '
            '사용자가 값을 바꿀 방법이 없다.',
      );
    }
  });

  test('analysis tab no longer hosts the month-end review card', () {
    // 2026-08-18 — 사용자 요청으로 "월말 점검" 카드를 **삭제**했다("정보 자체를
    // 없애야 할 것 같다"). 분석 탭 크롬이 화면의 70%를 먹던 원인 중 138dp 다.
    //
    // 이 단정을 반전시킨 이유를 남긴다: 원래 이 가드는 2026-08-10 인시던트
    // (카드를 죽은 홈 화면에 얹어 라이브 도달 0) 의 재발 방지였다. 카드가
    // 사라졌으므로 **지켜야 할 것은 카드의 위치가 아니라 정산 기능의 도달성**이고,
    // 그 단정은 아래 테스트로 이관했다.
    final analysis =
        read('lib/features/analysis/presentation/pages/analysis_page.dart');
    expect(analysis.contains('ReconciliationSummaryCard'), isFalse);
    expect(analysis.contains('ReconciliationSummaryCubit'), isFalse);
  });

  test('정산 뷰는 거래 탭 뷰 토글로 여전히 도달 가능하다', () {
    // ★도달성 가드 이관처(2026-08-18). 월말 점검 카드가 유일한 진입점이 아니었기에
    // 삭제할 수 있었다 — 이 세그먼트가 사라지면 정산 기능이 고아가 된다.
    final ledger = read(
      'lib/features/transaction/presentation/pages/transaction_list_page.dart',
    );
    expect(ledger.contains('LedgerView.reconciliation'), isTrue,
        reason: '정산 뷰로 가는 마지막 진입점이다 — 지우면 기능이 도달 불가가 된다.');
    expect(ledger.contains('_TxViewMode.reconciliation'), isTrue);
    expect(ledger.contains('정산 보기'), isTrue,
        reason: '세그먼트 tooltip 이 사라지면 어포던스가 없다(2026-07-27 인시던트).');
  });

  test('the ledger URL is built through the single source', () {
    // 월 누락(navigation_state, 3회 재발)을 컴파일이 막게 하려면 ledgerLocation() 만
    // 써야 한다. 카드가 사라졌으므로 감시 대상을 정산 뷰 호스트로 옮긴다.
    final route = read('lib/core/utils/ledger_route.dart');
    expect(route.contains('required int year'), isTrue,
        reason: 'year/month 가 required 라야 컴파일이 월 누락을 막는다.');
    expect(route.contains('required int month'), isTrue);
  });

  test('dashboard never assembles a ledger URL by hand', () {
    // '/transactions/create' · '/transactions/detail' 은 다른 라우트라 대상이 아니다.
    expect(
      dashboardPage.contains("'/transactions?"),
      isFalse,
      reason: '장부 목록 URL 은 ledgerLocation() 단일 소스로만 만든다. '
          '문자열 조립이 다시 생기면 year/month 누락(navigation_state, 3회 재발)이 '
          '컴파일 타임 방어를 벗어난다.',
    );
    expect(
      dashboardPage.contains('ledgerLocation('),
      isTrue,
      reason: '헬퍼 사용 흔적이 사라졌다면 이관이 되돌려진 것이다.',
    );
  });
}
