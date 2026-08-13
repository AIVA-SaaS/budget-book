import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';

void main() {
  group('TransactionFilter', () {
    test('empty has no filters set', () {
      expect(TransactionFilter.empty.hasAny, isFalse);
    });

    test('hasAny detects any single filter', () {
      expect(const TransactionFilter(categoryId: 'c1').hasAny, isTrue);
      expect(const TransactionFilter(dateFrom: '2026-01-01').hasAny, isTrue);
      expect(const TransactionFilter(amountMin: 10000).hasAny, isTrue);
      expect(const TransactionFilter(type: 'EXPENSE').hasAny, isTrue);
    });

    test('equality via Equatable', () {
      const a = TransactionFilter(categoryId: 'c1', dateFrom: '2026-01-01');
      const b = TransactionFilter(categoryId: 'c1', dateFrom: '2026-01-01');
      const c = TransactionFilter(categoryId: 'c2', dateFrom: '2026-01-01');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith preserves untouched fields', () {
      const original = TransactionFilter(
        categoryId: 'c1',
        dateFrom: '2026-01-01',
        dateTo: '2026-01-31',
      );
      final updated = original.copyWith(categoryId: 'c2');
      expect(updated.categoryId, 'c2');
      expect(updated.dateFrom, '2026-01-01'); // 보존됨
      expect(updated.dateTo, '2026-01-31'); // 보존됨
    });

    // 회귀 방지: 과거 인시던트(2026-04-15) 에서 MonthSyncHandler 가
    // dateFrom/To, amountMin/Max, keyword, pocket, type 등을 drop 했음.
    // currentFilter 는 모든 필드를 왕복(round-trip) 으로 보존해야 함.
    test('round-trip preserves ALL filter fields — 월 변경 시 필터 drop 방지', () {
      const full = TransactionFilter(
        keyword: 'food',
        categoryId: 'c1',
        paymentMethodId: 'p1',
        pocketId: 'pk1',
        amountMin: 10000,
        amountMax: 50000,
        dateFrom: '2026-01-01',
        dateTo: '2026-01-31',
        type: 'EXPENSE',
        transactionTypes: {'EXPENSE', 'TRANSFER'},
        visibility: 'SHARED',
      );
      // copyWith without any change = identity
      expect(full.copyWith(), equals(full));
      // 모든 필드가 하나도 빠지지 않고 보존
      expect(full.keyword, 'food');
      expect(full.categoryId, 'c1');
      expect(full.paymentMethodId, 'p1');
      expect(full.pocketId, 'pk1');
      expect(full.amountMin, 10000);
      expect(full.amountMax, 50000);
      expect(full.dateFrom, '2026-01-01');
      expect(full.dateTo, '2026-01-31');
      expect(full.type, 'EXPENSE');
      expect(full.transactionTypes, {'EXPENSE', 'TRANSFER'});
      expect(full.visibility, 'SHARED');
    });

    group('toQueryParams — Phase 22 multi transactionTypes', () {
      test('EXPENSE+INCOME multi sends list, not singular', () {
        const f = TransactionFilter(
          transactionTypes: {'EXPENSE', 'INCOME'},
        );
        final params = f.toQueryParams();
        expect(params['transactionTypes'], isA<List>());
        final list = (params['transactionTypes'] as List).cast<String>();
        expect(list, containsAll(<String>['EXPENSE', 'INCOME']));
        // Multi (length > 1) should not set the singular backward-compat key.
        expect(params.containsKey('type'), isFalse);
      });

      // 2026-08-12 계약 변경 — TRANSFER 를 **그대로 보낸다**.
      // 예전에는 잘라 보냈고, 그래서 서버가 "타입 필터 없음" 으로 해석해 거래 전체를
      // 세고 FE 가 다시 걸렀다(판정 2곳 → "합계 ≠ 행"). 이제 서버가 두 스트림을 판정한다.
      test('TRANSFER is sent to BE so the server can gate both streams', () {
        const f = TransactionFilter(
          transactionTypes: {'EXPENSE', 'TRANSFER'},
        );
        final params = f.toQueryParams();
        final list = (params['transactionTypes'] as List).cast<String>();
        expect(list, containsAll(<String>['EXPENSE', 'TRANSFER']));
        // 복수 선택이므로 단수 `type` 은 보내지 않는다.
        expect(params.containsKey('type'), isFalse);
      });

      test('single-value multi sets both `transactionTypes` and legacy `type`',
          () {
        const f = TransactionFilter(transactionTypes: {'INCOME'});
        final params = f.toQueryParams();
        expect(params['type'], 'INCOME');
        expect(
          (params['transactionTypes'] as List).cast<String>(),
          equals(<String>['INCOME']),
        );
      });

      test('only TRANSFER → transactionTypes=[TRANSFER], no singular type', () {
        const f = TransactionFilter(transactionTypes: {'TRANSFER'});
        final params = f.toQueryParams();
        expect(
          (params['transactionTypes'] as List).cast<String>(),
          equals(<String>['TRANSFER']),
        );
        // TRANSFER 는 거래 타입이 아니다 → 단수 `type` 으로 보내면 BE 가 400 을 낸다.
        expect(params.containsKey('type'), isFalse);
      });

      test('includeTransfers / transactionOnly gating', () {
        expect(const TransactionFilter().includeTransfers, isTrue);
        expect(const TransactionFilter().transactionOnly, isFalse);
        expect(
          const TransactionFilter(transactionTypes: {'EXPENSE'})
              .includeTransfers,
          isFalse,
        );
        expect(
          const TransactionFilter(transactionTypes: {'EXPENSE'})
              .transactionOnly,
          isTrue,
        );
        expect(
          const TransactionFilter(transactionTypes: {'EXPENSE', 'TRANSFER'})
              .includeTransfers,
          isTrue,
        );
      });
    });
  });
}
