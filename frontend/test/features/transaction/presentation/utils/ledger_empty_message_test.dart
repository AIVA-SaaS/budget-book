import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_empty_message.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_gating.dart'
    show kUnifiedFilterAxisCount;

/// 2026-08-10 — 결과 0건일 때 "왜 비었는지" 를 필터 기준으로 알려주는 문구.
void main() {
  group('필터 없음', () {
    test('기본 문구 + 거래 추가 액션', () {
      final m = buildLedgerEmptyMessage(const UnifiedFilterState());
      expect(m.title, '거래 내역이 없습니다');
      expect(m.subtitle, '이 달에 기록된 거래가 없습니다');
      expect(m.hasFilters, isFalse);
    });
  });

  group('단일 축 — 축 전용 문구', () {
    void expectTitle(UnifiedFilterState f, String title, {String? keyword}) {
      final m = buildLedgerEmptyMessage(f, keyword: keyword);
      expect(m.title, title);
      expect(m.hasFilters, isTrue);
      expect(m.subtitle, '필터를 해제하면 이 달의 다른 내역을 볼 수 있습니다');
    }

    test('확인/입력 필요', () {
      expectTitle(const UnifiedFilterState(needsReviewOnly: true),
          '확인/입력 필요한 거래가 없습니다');
    });

    test('거래 유형 단일 / 복수', () {
      expectTitle(
          const UnifiedFilterState(transactionTypes: {'TRANSFER'}), '이체 내역이 없습니다');
      expectTitle(
          const UnifiedFilterState(transactionTypes: {'EXPENSE'}), '지출 내역이 없습니다');
      // Set 순서와 무관하게 지출/수입/이체 고정 순서로 라벨링.
      expectTitle(
        const UnifiedFilterState(transactionTypes: {'TRANSFER', 'EXPENSE'}),
        '지출/이체 내역이 없습니다',
      );
    });

    test('공개 범위', () {
      expectTitle(const UnifiedFilterState(visibility: 'PRIVATE'), '개인 거래가 없습니다');
      expectTitle(const UnifiedFilterState(visibility: 'SHARED'), '공유 거래가 없습니다');
    });

    test('검색어', () {
      expectTitle(const UnifiedFilterState(), "'스타벅스' 검색 결과가 없습니다",
          keyword: '스타벅스');
    });

    test('카테고리 / 결제수단 / 포켓 / 금액 / 기간', () {
      expectTitle(const UnifiedFilterState(categoryIds: {'c1'}),
          '선택한 카테고리의 거래가 없습니다');
      expectTitle(const UnifiedFilterState(paymentMethodIds: {'p1'}),
          '선택한 결제수단의 거래가 없습니다');
      expectTitle(
          const UnifiedFilterState(pocketIds: {'k1'}), '선택한 포켓의 거래가 없습니다');
      expectTitle(
          const UnifiedFilterState(amountMin: 1000), '해당 금액대의 거래가 없습니다');
      expectTitle(
        UnifiedFilterState(
          dateFrom: DateTime(2026, 8, 1),
          dateTo: DateTime(2026, 8, 31),
        ),
        '선택한 기간에 거래가 없습니다',
      );
    });

    test("visibility 'ALL' 은 필터로 치지 않는다", () {
      final m = buildLedgerEmptyMessage(const UnifiedFilterState(visibility: 'ALL'));
      expect(m.hasFilters, isFalse);
      expect(m.title, '거래 내역이 없습니다');
    });
  });

  group('복수 축', () {
    test('제목은 최우선 축, 부제는 적용된 필터 나열', () {
      final m = buildLedgerEmptyMessage(
        const UnifiedFilterState(
          needsReviewOnly: true,
          transactionTypes: {'EXPENSE'},
          categoryIds: {'c1'},
        ),
      );
      expect(m.title, '확인/입력 필요한 거래가 없습니다');
      expect(m.subtitle, '적용된 필터: 확인 필요 · 지출 · 카테고리');
      expect(m.hasFilters, isTrue);
    });

    test('검색어도 축으로 합산된다', () {
      final m = buildLedgerEmptyMessage(
        const UnifiedFilterState(transactionTypes: {'INCOME'}),
        keyword: '월급',
      );
      expect(m.title, '수입 내역이 없습니다');
      expect(m.subtitle, "적용된 필터: 수입 · 검색어 '월급'");
    });
  });

  test('필터 VO 필드 수가 바뀌면 빈 상태 문구 축도 갱신해야 한다', () {
    expect(
      const UnifiedFilterState().props.length,
      kUnifiedFilterAxisCount,
      reason: 'UnifiedFilterState 에 필드가 추가/삭제되었다. '
          'ledger_empty_message.dart 의 _activeAxes 에 새 축의 문구를 추가하라.',
    );
  });
}
