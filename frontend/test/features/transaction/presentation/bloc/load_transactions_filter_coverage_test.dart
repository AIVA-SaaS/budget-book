import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';

/// 필터 전파 회귀 가드 (2026-07-27).
///
/// 배경: "월 이동/탭 복귀/파트너 sync 후 필터가 풀린다" 인시던트가 3회 재발했다.
/// 원인은 매번 동일 — 필터 필드를 손으로 나열하는 지점이 여러 곳 있어서 새 필터
/// (transactionTypes → needsReviewOnly) 를 한 곳에서 빠뜨렸다.
///
/// 구조적 수정: LoadTransactions 는 TransactionFilter VO 만 받고(생성자 봉인),
/// UI 상태 → VO 변환은 toTransactionFilter 한 곳, 라우터의 nav 필터 덮어쓰기는
/// withNavigationFilters 한 곳으로 고정했다.
///
/// 이 테스트는 그 세 관문이 **모든 필터 필드**를 실어 나르는지 검사한다.
/// 새 필터를 추가하면 `props` 개수 가드가 먼저 실패하므로, 매핑 추가를 강제한다.
void main() {
  // 모든 필드가 기본값과 다른 필터 (드롭 여부를 값 비교로 확인 가능).
  const fullFilter = TransactionFilter(
    keyword: '점심',
    categoryId: 'cat-1',
    categoryIds: {'cat-2', 'cat-3'},
    categoryGroupIds: {'grp-1'},
    paymentMethodId: 'pm-1',
    paymentMethodIds: {'pm-2'},
    pocketId: 'pk-1',
    pocketIds: {'pk-2'},
    amountMin: 1000,
    amountMax: 90000,
    dateFrom: '2026-07-01',
    dateTo: '2026-07-31',
    type: 'EXPENSE',
    transactionTypes: {'EXPENSE', 'TRANSFER'},
    visibility: 'SHARED',
    needsReviewOnly: true,
    reconciled: false,
  );

  group('필터 필드 개수 가드', () {
    test('TransactionFilter 에 필드가 추가되면 이 테스트를 갱신해야 한다', () {
      // 새 필터를 추가했다면:
      //   1) 이 숫자를 갱신
      //   2) fullFilter 에 값 추가
      //   3) toQueryParams / toTransactionFilter / withNavigationFilters 매핑 확인
      expect(fullFilter.props.length, 17,
          reason: '필터 필드 수 변경 감지 — 전파 경로 3곳의 매핑을 함께 갱신하세요');
    });

    test('fullFilter 는 모든 필드가 non-null/non-empty 여야 의미가 있다', () {
      expect(fullFilter.props.any((p) => p == null), isFalse);
      expect(
        fullFilter.props.whereType<Set<String>>().any((s) => s.isEmpty),
        isFalse,
      );
    });
  });

  group('LoadTransactions.fromFilter', () {
    test('필터 VO 를 한 필드도 잃지 않고 전달한다', () {
      final event = LoadTransactions.fromFilter(2026, 7, fullFilter);

      expect(event.year, 2026);
      expect(event.month, 7);
      expect(event.filter, fullFilter);
      // 위임 getter 도 동일 값 (기존 소비자 호환).
      expect(event.keyword, '점심');
      expect(event.transactionTypes, {'EXPENSE', 'TRANSFER'});
      expect(event.visibility, 'SHARED');
      expect(event.needsReviewOnly, isTrue);
    });

    test('clearDateRange 는 기간만 해제하고 나머지는 보존한다', () {
      final event =
          LoadTransactions.fromFilter(2026, 8, fullFilter, clearDateRange: true);

      expect(event.dateFrom, isNull);
      expect(event.dateTo, isNull);
      // 나머지 필드는 그대로 (특히 과거에 드롭됐던 두 필드).
      expect(event.transactionTypes, {'EXPENSE', 'TRANSFER'});
      expect(event.needsReviewOnly, isTrue);
      expect(event.filter, fullFilter.copyWith(clearDateRange: true));
    });

    test('scrollToDate 는 필터와 독립적으로 전달된다', () {
      final event = LoadTransactions.fromFilter(2026, 7, fullFilter,
          scrollToDate: '2026-07-15');
      expect(event.scrollToDate, '2026-07-15');
      expect(event.filter, fullFilter);
    });

    test('monthOnly 는 빈 필터임을 명시한다', () {
      final event = LoadTransactions.monthOnly(2026, 7);
      expect(event.filter, TransactionFilter.empty);
      expect(event.filter.hasAny, isFalse);
    });
  });

  group('UnifiedFilterState.toTransactionFilter', () {
    final uiState = UnifiedFilterState(
      dateFrom: DateTime(2026, 7, 1),
      dateTo: DateTime(2026, 7, 31),
      categoryIds: const {'cat-2'},
      categoryGroupIds: const {'grp-1'},
      paymentMethodIds: const {'pm-2'},
      pocketIds: const {'pk-2'},
      amountMin: 1000,
      amountMax: 90000,
      keyword: '커피',
      transactionTypes: const {'EXPENSE'},
      visibility: 'SHARED',
      needsReviewOnly: true,
    );

    test('UI 필터 상태의 모든 항목이 도메인 VO 로 옮겨진다', () {
      final f = uiState.toTransactionFilter();

      expect(f.keyword, '커피');
      expect(f.categoryIds, {'cat-2'});
      expect(f.categoryGroupIds, {'grp-1'});
      expect(f.paymentMethodIds, {'pm-2'});
      expect(f.pocketIds, {'pk-2'});
      expect(f.amountMin, 1000);
      expect(f.amountMax, 90000);
      expect(f.dateFrom, '2026-07-01');
      expect(f.dateTo, '2026-07-31');
      expect(f.transactionTypes, {'EXPENSE'});
      expect(f.visibility, 'SHARED');
      // 3회 재발의 마지막 누락 필드 — 반드시 전달돼야 한다.
      expect(f.needsReviewOnly, isTrue);
    });

    test('needsReviewOnly=false 는 미적용(null)으로 보낸다', () {
      final f = const UnifiedFilterState(needsReviewOnly: false)
          .toTransactionFilter();
      expect(f.needsReviewOnly, isNull);
      expect(f.toQueryParams().containsKey('needsReviewOnly'), isFalse);
    });

    test('keywordOverride 가 UI 상태의 keyword 를 대체한다', () {
      final f = uiState.toTransactionFilter(keywordOverride: '점심');
      expect(f.keyword, '점심');
    });
  });

  group('TransactionFilter.withNavigationFilters', () {
    test('nav 필터만 덮어쓰고 content 필터는 보존한다', () {
      final f = fullFilter.withNavigationFilters(
        categoryId: 'nav-cat',
        paymentMethodId: 'nav-pm',
        categoryIds: const {'nav-cat-2'},
        categoryGroupIds: const {'nav-grp'},
        paymentMethodIds: const {'nav-pm-2'},
        pocketIds: const {'nav-pk'},
      );

      // nav 소유 필드 = 인자 값
      expect(f.categoryId, 'nav-cat');
      expect(f.paymentMethodId, 'nav-pm');
      expect(f.categoryIds, {'nav-cat-2'});
      expect(f.categoryGroupIds, {'nav-grp'});
      expect(f.paymentMethodIds, {'nav-pm-2'});
      expect(f.pocketIds, {'nav-pk'});

      // content 필드 = 보존 (URL 진입 시 드롭됐던 needsReviewOnly 포함)
      expect(f.keyword, '점심');
      expect(f.amountMin, 1000);
      expect(f.amountMax, 90000);
      expect(f.dateFrom, '2026-07-01');
      expect(f.dateTo, '2026-07-31');
      expect(f.type, 'EXPENSE');
      expect(f.transactionTypes, {'EXPENSE', 'TRANSFER'});
      expect(f.visibility, 'SHARED');
      expect(f.needsReviewOnly, isTrue);
      expect(f.pocketId, 'pk-1');
    });

    test('인자를 생략하면 nav 필터가 해제된다 (carry 아님)', () {
      final f = fullFilter.withNavigationFilters();

      expect(f.categoryId, isNull);
      expect(f.paymentMethodId, isNull);
      expect(f.categoryIds, isEmpty);
      expect(f.categoryGroupIds, isEmpty);
      expect(f.paymentMethodIds, isEmpty);
      expect(f.pocketIds, isEmpty);
      // content 는 유지
      expect(f.keyword, '점심');
      expect(f.needsReviewOnly, isTrue);
    });
  });

  group('toQueryParams (FE→BE 전달)', () {
    test('needsReviewOnly=true 는 BE 로 전달된다', () {
      expect(fullFilter.toQueryParams()['needsReviewOnly'], isTrue);
    });

    test('reconciled=false 는 "미기록만" 을 뜻하므로 반드시 전달된다', () {
      // false 를 생략하면 전체 목록이 내려와 정산 뷰 상단이 오염된다.
      expect(fullFilter.toQueryParams()['reconciled'], isFalse);
      expect(
        const TransactionFilter().toQueryParams().containsKey('reconciled'),
        isFalse,
        reason: 'null 일 때만 생략',
      );
    });

    test('TRANSFER 의사-타입은 BE 로 보내지 않는다', () {
      final types =
          fullFilter.toQueryParams()['transactionTypes'] as List<dynamic>;
      expect(types, contains('EXPENSE'));
      expect(types, isNot(contains('TRANSFER')));
    });
  });
}
