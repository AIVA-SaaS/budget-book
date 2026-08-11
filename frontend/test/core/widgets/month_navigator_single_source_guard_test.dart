import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 월 이동 UI 단일 소스 + 도달성 가드.
///
/// ## 왜 필요한가 (하네스 `navigation_state` — 4회 재발)
///
/// - 2026-04-14 예산 3월 → 카드 선택 → 4월 거래 표시
/// - 2026-04-15 홈/예산 월 이동 후 거래 이동 시 현재 월로 리셋
/// - 2026-04-15 월 이동 시 카드 요약이 홈/예산에서 stale
/// - 2026-08-10 홈 대시보드에 위젯을 추가해 CI·배포까지 통과했는데 **죽은 화면이라 미노출**
///
/// 앞 3건의 구조적 이행은 `ledgerLocation()`(required year/month → 컴파일 에러)이 담당한다.
/// 이 파일은 **4번째 축**을 막는다 — "공용 월 UI 를 고쳤는데 어떤 화면에는 반영되지 않는다 /
/// 반영한 화면이 사용자에게 도달하지 않는다".
void main() {
  String read(String path) => File(path).readAsStringSync();

  final router = read('lib/core/router/app_router.dart');

  /// MonthNavigator 가 **실제로 렌더되는** 호스트 (2026-08-11 측정).
  ///
  /// 여기 없는 호출부 3곳은 파라미터로 꺼져 있어 화면에 나오지 않는다 —
  /// `statistics_page.dart:68` 과 `budget_list_page.dart:269/566` 은
  /// `if (showMonthNavigator …)` 안에 있고, 유일한 사용처인 `analysis_page` 가
  /// `showMonthNavigator: false` 로 넘긴다(`/budgets`·`/statistics` 는 분석 탭으로 redirect).
  /// **"13곳에 반영됐다" 고 세지 말 것.**
  const hosts = <String, String>{
    'lib/features/transaction/presentation/pages/transaction_list_page.dart':
        'TransactionListPage',
    'lib/features/analysis/presentation/pages/analysis_page.dart': 'AnalysisPage',
    'lib/features/transfer/presentation/pages/transfer_list_page.dart':
        'TransferListPage',
    'lib/features/payment_method/presentation/pages/payment_method_page.dart':
        'PaymentMethodPage',
    'lib/features/settings/presentation/pages/asset_management_page.dart':
        'AssetManagementPage',
    'lib/features/weekly_budget/presentation/pages/weekly_budget_page.dart':
        'WeeklyBudgetPage',
    'lib/features/weekly_budget/presentation/pages/weekly_settlement_page.dart':
        'WeeklySettlementPage',
    'lib/features/report/presentation/pages/report_page.dart': 'ReportPage',
    'lib/features/spending_plan/presentation/pages/spending_plan_list_page.dart':
        'SpendingPlanListPage',
  };

  group('S3 — 도달성 고정', () {
    hosts.forEach((path, pageClass) {
      test('$pageClass 은 MonthNavigator 를 쓰고 라우터에 등록돼 있다', () {
        expect(
          read(path).contains('MonthNavigator('),
          isTrue,
          reason: '$path 에서 MonthNavigator 가 사라졌다. 이 화면만 월 이동 개선에서 '
              '빠지게 된다 — 호스트 목록을 고치든 위젯을 되돌리든 결정이 필요하다.',
        );
        expect(
          router.contains(pageClass),
          isTrue,
          reason: '$pageClass 이 app_router 에서 사라졌다. 라우팅되지 않는 화면에 '
              '기능을 얹으면 사용자에게 도달하지 않는다(2026-08-10 인시던트).',
        );
      });
    });

    test('분석 탭은 예산/통계의 자체 MonthNavigator 를 꺼둔 채 감싼다', () {
      // 이 전제가 깨지면 분석 탭에 월 네비게이터가 두 개 나온다.
      final analysis =
          read('lib/features/analysis/presentation/pages/analysis_page.dart');
      expect('showMonthNavigator: false'.allMatches(analysis).length, 2);
    });
  });

  group('S1 — 자체 월 헤더 금지', () {
    test('월 헤더를 직접 만드는 파일은 month_navigator.dart 하나뿐이다', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        // 좌우 화살표 + 월 상태 변경을 한 파일이 동시에 갖고 있으면 자체 월 헤더다.
        if (src.contains('Icons.chevron_left') && src.contains('changeMonth(')) {
          offenders.add(entity.path.replaceAll(r'\', '/'));
        }
      }

      const allowed = 'lib/core/widgets/month_navigator.dart';
      // 홈 대시보드는 **미라우팅인 동안만** 예외다. 아래 테스트가 그 전제를 지킨다.
      const deadExemption =
          'lib/features/home/presentation/pages/dashboard_page.dart';

      expect(
        offenders.toSet().difference({allowed, deadExemption}),
        isEmpty,
        reason: '자체 월 헤더가 새로 생겼다. 월 네비게이터 개선(피커·오늘 버튼)이 '
            '그 화면에만 빠진다 — MonthNavigator 를 쓰라.',
      );
    });

    test('홈 예외는 홈이 미라우팅일 때만 유효하다', () {
      // `/home` 이 redirect 인 동안 dashboard_page 는 사용자에게 도달하지 않으므로
      // 자체 `_MonthHeader` 를 남겨둬도 무해하다. 홈을 되살리는 순간 이 테스트가 깨지고,
      // MonthNavigator 이행이 강제된다.
      final idx = router.indexOf("path: '/home'");
      expect(idx, greaterThan(-1), reason: "'/home' 라우트 자체가 사라졌다.");
      final block = router.substring(idx, idx + 200);
      expect(
        block.contains('redirect:'),
        isTrue,
        reason: '홈이 실제 화면으로 되살아났다. dashboard_page 의 `_MonthHeader` 를 '
            'MonthNavigator 로 이행하고 이 예외를 제거하라 — 지금 상태로 두면 홈만 '
            '월 피커·오늘 버튼이 없다.',
      );
    });
  });

  group('S2 — 월 피커 단일 소스', () {
    test('showMonthYearPickerDialog 호출부는 month_navigator.dart 하나뿐이다', () {
      final callers = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.endsWith('month_year_picker_dialog.dart')) continue; // 정의부
        if (entity.readAsStringSync().contains('showMonthYearPickerDialog(')) {
          callers.add(path);
        }
      }
      expect(callers, ['lib/core/widgets/month_navigator.dart']);
    });

    test('일 선택이 본질인 호출부는 기존 showCalendarPickerDialog 를 계속 쓴다', () {
      // 거래·이체·보험·지출계획·카드정산 폼과 기간 필터 등 17곳. 월 우선 피커로
      // 갈아끼우면 그쪽이 퇴보한다.
      final formPicker = read(
        'lib/features/transaction/presentation/pages/transaction_form_page.dart',
      );
      expect(formPicker.contains('showCalendarPickerDialog('), isTrue);
      expect(formPicker.contains('showMonthYearPickerDialog('), isFalse);
    });
  });

  group('요청 산출물이 위젯에 남아 있다', () {
    final navigator = read('lib/core/widgets/month_navigator.dart');

    test('월 피커로 연결돼 있다', () {
      expect(navigator.contains('showMonthYearPickerDialog('), isTrue);
      expect(
        navigator.contains('allowDaySelection: onDatePicked != null'),
        isTrue,
        reason: '거래 목록만 일 그리드로 진입한다는 규칙이 사라졌다.',
      );
    });

    test('"오늘" 버튼이 있다', () {
      expect(navigator.contains('Icons.today'), isTrue);
      expect(navigator.contains("'이번 달로'"), isTrue);
    });
  });
}
