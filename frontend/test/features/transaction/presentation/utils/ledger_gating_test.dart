import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transaction/presentation/utils/ledger_gating.dart';

/// 장부 게이팅 가드.
///
/// ## 2026-08-12 — 이체 판정은 서버로 옮겼다
///
/// 2026-08-10 회차는 이체 축 판정을 FE `ledger_gating.dart` 한 곳으로 모았다.
/// 그런데 BE 합계는 "필터가 켜지면 이체 전량 제외" 라는 **다른 규칙**을 유지해서
/// 합계와 행이 다른 집합을 셌고, 기간 필터가 월을 넘으면 이체 행이 통째로 빠졌다.
///
/// 그래서 판정을 **서버 한 곳**(`TransferGating`)으로 옮겼다. 이 테스트는 이제
/// "FE 가 이체를 다시 판정하지 않는다" 를 고정한다 — 판정이 두 곳이 되는 순간
/// 같은 사고가 재발하기 때문이다.
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
    test('UnifiedFilterState 필드 수가 바뀌면 서버 판정을 갱신해야 한다', () {
      expect(
        const UnifiedFilterState().props.length,
        kUnifiedFilterAxisCount,
        reason: '필터 축이 바뀌었다. 서버를 먼저 갱신하라: '
            'CommonFilterParams 필드 → LedgerFilterAxis 항목 → TransferGating.handling '
            '(exhaustive when 이 컴파일로 강제). 그 다음 이 상수를 갱신한다.',
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
          reason: '이체 필터링은 서버(TransferGating)가 단독으로 한다. '
              '페이지에 "$banned" 형태의 인라인 필터링이 다시 들어왔다.',
        );
      }
    });

    // 장부는 공유 TransferBloc 을 쓰지 않는다 — 그 싱글톤에 장부 필터가 실리면
    // 이체 목록 화면·카드정산·정산 뷰·거래 폼이 함께 오염된다(측정: 소비자 6곳).
    test('거래 목록 페이지는 공유 TransferBloc 을 참조하지 않는다', () {
      final src = File(
        'lib/features/transaction/presentation/pages/transaction_list_page.dart',
      ).readAsStringSync();

      // 주석에서의 언급은 허용한다(왜 안 쓰는지 설명이 필요하다) — 실제 **사용**만 막는다.
      for (final banned in [
        'read<TransferBloc>',
        'watch<TransferBloc>',
        'getIt<TransferBloc>',
        'BlocBuilder<TransferBloc',
        'BlocProvider<TransferBloc',
        'BlocListener<TransferBloc',
      ]) {
        expect(
          src.contains(banned),
          isFalse,
          reason: '장부는 LedgerTransfersCubit(전용 소스)만 쓴다. 공유 TransferBloc 을 '
              '다시 사용하면("$banned") 필터가 다른 5개 화면으로 새어나간다.',
        );
      }
      expect(
        src.contains('LedgerTransfersCubit'),
        isTrue,
        reason: '장부 전용 이체 소스가 사라졌다.',
      );
    });

    // 이체 축 판정이 FE 로 되돌아오는 것을 막는다 (판정 2곳 = 재발 메커니즘).
    test('ledger_gating.dart 에 이체 축 판정이 없다', () {
      final src = File(
        'lib/features/transaction/presentation/utils/ledger_gating.dart',
      ).readAsStringSync();

      for (final banned in [
        '_transferMatches',
        '_transffersExcludedWholesale',
        '_transfersExcludedWholesale',
        'transferDate.compareTo',
        'f.amountMin',
        'f.paymentMethodIds',
        'f.needsReviewOnly',
      ]) {
        expect(
          src.contains(banned),
          isFalse,
          reason: '이체 판정("$banned")이 FE 로 돌아왔다. 판정은 서버 TransferGating '
              '한 곳이어야 한다 — 두 곳이 되면 "합계 ≠ 행" 이 재발한다.',
        );
      }
    });
  });

  group('이체는 서버 결과를 그대로 통과시킨다', () {
    test('이체에 없는 축이 켜져 있어도 FE 는 손대지 않는다 (서버가 이미 걸렀다)', () {
      // 서버가 카테고리 필터에서 이체를 전량 제외했다면 애초에 빈 리스트가 온다.
      // FE 가 또 판정하면 규칙이 두 곳이 되므로, 받은 것을 그대로 보여준다.
      final g = gateLedger(
        transactions: [tx()],
        transfers: [tf(id: 'a'), tf(id: 'b')],
        filter: const UnifiedFilterState(categoryIds: {'cat-1'}),
      );

      expect(g.transfers.map((t) => t.id), ['a', 'b']);
    });

    test('금액·기간·검색어 축에서도 FE 는 이체를 재판정하지 않는다', () {
      final g = gateLedger(
        transactions: const [],
        transfers: [
          tf(id: 'in', amount: 5000, date: '2026-08-10'),
          // 서버가 걸렀어야 하는 값이라도 FE 는 그대로 통과시킨다.
          tf(id: 'out', amount: 999999, date: '2026-01-01', description: '무관'),
        ],
        filter: const UnifiedFilterState(
          amountMin: 1000,
          amountMax: 9000,
          keyword: '생활비',
        ),
      );

      expect(g.transfers.map((t) => t.id), ['in', 'out']);
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
        transactions: [tx(), tx(id: 'tx2', type: 'INCOME')],
        transfers: [tf()],
        filter: const UnifiedFilterState(),
      );

      expect(g.transactions, hasLength(2));
      expect(g.transfers, hasLength(1));
    });

    test('지출 + 이체 선택 시 지출 거래와 이체가 함께 남는다', () {
      final g = gateLedger(
        transactions: [tx(type: 'EXPENSE'), tx(id: 'tx2', type: 'INCOME')],
        transfers: [tf()],
        filter: const UnifiedFilterState(
          transactionTypes: {'EXPENSE', 'TRANSFER'},
        ),
      );

      expect(g.transactions.map((t) => t.type), ['EXPENSE']);
      expect(g.transfers, hasLength(1));
    });
  });

  group('실효 검색어 규칙', () {
    test('빈 검색창은 VO 의 keyword 로 되돌아간다 (BE 전송 규칙과 동일)', () {
      expect(
        resolveLedgerKeyword(const UnifiedFilterState(keyword: '커피'), ''),
        '커피',
      );
    });

    test('검색창 입력이 VO 보다 우선한다', () {
      expect(
        resolveLedgerKeyword(const UnifiedFilterState(keyword: '커피'), '택시'),
        '택시',
      );
    });

    test('둘 다 없으면 빈 문자열', () {
      expect(resolveLedgerKeyword(const UnifiedFilterState(), null), '');
    });
  });
}
