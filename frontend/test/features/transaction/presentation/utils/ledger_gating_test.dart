import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_gating.dart';

/// 2026-08-10 회귀 테스트 — "확인 필요 필터를 켰는데 이체가 보인다" (4회째 재발).
///
/// 이체 스트림 게이팅이 필터 축을 수동 나열하다 축을 빠뜨리던 사고를 구조적으로 막는다.
void main() {
  const author = TransactionAuthor(id: 'u1', nickname: '나');

  Transaction tx({
    String id = 'tx1',
    String type = 'EXPENSE',
    int amount = 1000,
    String date = '2026-08-10',
  }) =>
      Transaction(
        id: id,
        coupleId: 'c1',
        author: author,
        type: type,
        amount: amount,
        description: '커피',
        transactionDate: date,
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      );

  Transfer tf({
    String id = 'tf1',
    int amount = 5000,
    String date = '2026-08-10',
    String srcId = 'pm-bank',
    String dstId = 'pm-cash',
    String? description = '생활비 이체',
  }) =>
      Transfer(
        id: id,
        coupleId: 'c1',
        author: author,
        sourcePaymentMethod:
            PaymentMethodRef(id: srcId, name: '국민은행', type: 'BANK'),
        destinationPaymentMethod:
            PaymentMethodRef(id: dstId, name: '현금', type: 'CASH'),
        amount: amount,
        description: description,
        transferDate: date,
        createdAt: DateTime(2026, 8, 10),
      );

  group('필터 VO 축 가드', () {
    test('UnifiedFilterState 필드 수가 바뀌면 이체 게이팅을 갱신해야 한다', () {
      expect(
        const UnifiedFilterState().props.length,
        kUnifiedFilterAxisCount,
        reason: 'UnifiedFilterState 에 필드가 추가/삭제되었다. '
            'ledger_gating.dart 의 _transfersExcludedWholesale / _transferMatches 에 '
            '그 축의 이체 판정을 명시한 뒤 kUnifiedFilterAxisCount 를 갱신하라. '
            '(축 누락으로 이체가 필터를 무시하고 노출되던 사고의 재발 방지)',
      );
    });

    test('거래 목록 페이지가 이체를 직접 필터링하지 않는다 (인라인 게이팅 재도입 차단)', () {
      final src = File(
        'lib/features/transaction/presentation/pages/transaction_list_page.dart',
      ).readAsStringSync();
      for (final banned in [
        'transfers.where(',
        'filteredTransfers',
        'searchedTransfers',
        'dateFilteredTransfers',
      ]) {
        expect(
          src.contains(banned),
          isFalse,
          reason: '이체 게이팅은 ledger_gating.dart 의 gateLedger 단일 진입점에서만 한다. '
              '페이지에 "$banned" 형태의 인라인 필터링이 다시 들어왔다.',
        );
      }
    });
  });

  group('이체에 없는 축이 켜지면 이체는 전량 제외', () {
    test('needsReviewOnly — 확인/입력 필요만 보기', () {
      final g = gateLedger(
        transactions: [tx()],
        transfers: [tf()],
        filter: const UnifiedFilterState(needsReviewOnly: true),
      );
      expect(g.transfers, isEmpty);
      expect(g.transactions, hasLength(1)); // 거래는 BE 가 이미 좁혔다
    });

    test('카테고리 / 카테고리 그룹', () {
      expect(
        gateLedger(
          transactions: [tx()],
          transfers: [tf()],
          filter: const UnifiedFilterState(categoryIds: {'cat1'}),
        ).transfers,
        isEmpty,
      );
      expect(
        gateLedger(
          transactions: [tx()],
          transfers: [tf()],
          filter: const UnifiedFilterState(categoryGroupIds: {'g1'}),
        ).transfers,
        isEmpty,
      );
    });

    test('포켓', () {
      expect(
        gateLedger(
          transactions: [tx()],
          transfers: [tf()],
          filter: const UnifiedFilterState(pocketIds: {'p1'}),
        ).transfers,
        isEmpty,
      );
    });

    test('개인(PRIVATE) 공개범위 — 이체는 현재 전부 공유 취급', () {
      expect(
        gateLedger(
          transactions: [tx()],
          transfers: [tf()],
          filter: const UnifiedFilterState(visibility: 'PRIVATE'),
        ).transfers,
        isEmpty,
      );
      // 공유(SHARED) 는 이체를 숨기지 않는다.
      expect(
        gateLedger(
          transactions: [tx()],
          transfers: [tf()],
          filter: const UnifiedFilterState(visibility: 'SHARED'),
        ).transfers,
        hasLength(1),
      );
    });

    test('거래 유형에서 이체 미선택', () {
      expect(
        gateLedger(
          transactions: [tx()],
          transfers: [tf()],
          filter: const UnifiedFilterState(transactionTypes: {'EXPENSE'}),
        ).transfers,
        isEmpty,
      );
    });
  });

  group('이체에 적용 가능한 축은 실제로 매칭', () {
    test('금액 범위', () {
      const filter = UnifiedFilterState(amountMin: 1000, amountMax: 3000);
      final g = gateLedger(
        transactions: const [],
        transfers: [tf(id: 'in', amount: 2000), tf(id: 'out', amount: 9000)],
        filter: filter,
      );
      expect(g.transfers.map((t) => t.id), ['in']);
    });

    test('결제수단 복수 선택 — 전부 OR 매칭 (first 1개만 보던 버그)', () {
      const filter = UnifiedFilterState(paymentMethodIds: {'pm-a', 'pm-b'});
      final g = gateLedger(
        transactions: const [],
        transfers: [
          tf(id: 'a', srcId: 'pm-a', dstId: 'pm-z'),
          tf(id: 'b', srcId: 'pm-z', dstId: 'pm-b'),
          tf(id: 'c', srcId: 'pm-y', dstId: 'pm-z'),
        ],
        filter: filter,
      );
      expect(g.transfers.map((t) => t.id), ['a', 'b']);
    });

    test('기간', () {
      final filter = UnifiedFilterState(
        dateFrom: DateTime(2026, 8, 5),
        dateTo: DateTime(2026, 8, 10),
      );
      final g = gateLedger(
        transactions: const [],
        transfers: [
          tf(id: 'before', date: '2026-08-04'),
          tf(id: 'inside', date: '2026-08-07'),
          tf(id: 'edge', date: '2026-08-10'),
          tf(id: 'after', date: '2026-08-11'),
        ],
        filter: filter,
      );
      expect(g.transfers.map((t) => t.id), ['inside', 'edge']);
    });

    test('검색어 — 설명 / 출금·입금 결제수단명', () {
      final g = gateLedger(
        transactions: const [],
        transfers: [
          tf(id: 'desc', description: '월세 이체'),
          tf(id: 'pm', description: null),
          tf(id: 'none', description: '기타'),
        ],
        filter: const UnifiedFilterState(),
        keyword: '월세',
      );
      expect(g.transfers.map((t) => t.id), ['desc']);

      final byPm = gateLedger(
        transactions: const [],
        transfers: [tf(id: 'pm')],
        filter: const UnifiedFilterState(),
        keyword: '국민',
      );
      expect(byPm.transfers, hasLength(1));
    });

    test('빈 검색창은 VO 의 keyword 로 되돌아간다 (BE 전송 규칙과 동일)', () {
      // toTransactionFilter(keywordOverride: null) 이 filter.keyword 로 fallback 하므로
      // FE 게이팅도 같은 규칙이어야 행/합계가 어긋나지 않는다.
      expect(resolveLedgerKeyword(const UnifiedFilterState(keyword: '월세'), ''),
          '월세');
      expect(resolveLedgerKeyword(const UnifiedFilterState(keyword: '월세'), '커피'),
          '커피');
      expect(resolveLedgerKeyword(const UnifiedFilterState(), '  '), '');

      final g = gateLedger(
        transactions: const [],
        transfers: [tf(id: 'hit', description: '월세 이체'), tf(id: 'miss')],
        filter: const UnifiedFilterState(keyword: '월세'),
        keyword: '',
      );
      expect(g.transfers.map((t) => t.id), ['hit']);
    });
  });

  group('거래 스트림 타입 게이팅', () {
    test('이체만 선택하면 거래는 0건', () {
      final g = gateLedger(
        transactions: [tx(type: 'EXPENSE'), tx(id: 'tx2', type: 'INCOME')],
        transfers: [tf()],
        filter: const UnifiedFilterState(transactionTypes: {'TRANSFER'}),
      );
      expect(g.transactions, isEmpty);
      expect(g.transfers, hasLength(1));
    });

    test('필터 없음 = 전부 통과', () {
      final g = gateLedger(
        transactions: [tx()],
        transfers: [tf()],
        filter: const UnifiedFilterState(),
      );
      expect(g.transactions, hasLength(1));
      expect(g.transfers, hasLength(1));
    });
  });
}
