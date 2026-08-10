import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/utils/ledger_route.dart';

/// 장부 목록 URL 단일 소스 (`ledgerLocation`) 와 뷰 모드 전환 규칙.
///
/// 이 헬퍼는 navigation_state 인시던트 3건(월이 목적지에 안 따라감)의 재발 방지
/// 조치다. year/month 가 required 라는 사실 자체는 컴파일러가 지키므로 여기서는
/// **직렬화 결과**와 **전환 규칙**을 고정한다.
void main() {
  group('ledgerLocation', () {
    test('always carries year and month', () {
      final uri = Uri.parse(ledgerLocation(year: 2026, month: 3));

      expect(uri.path, '/transactions');
      expect(uri.queryParameters['year'], '2026');
      expect(uri.queryParameters['month'], '3');
    });

    test('omits optional params that were not given', () {
      final uri = Uri.parse(ledgerLocation(year: 2026, month: 3));

      expect(uri.queryParameters.keys, unorderedEquals(['year', 'month']));
    });

    test('serialises the view mode by enum name', () {
      final uri = Uri.parse(ledgerLocation(
        year: 2026,
        month: 3,
        view: LedgerView.reconciliation,
      ));

      expect(uri.queryParameters['view'], 'reconciliation');
    });

    test('round-trips a payment method filter with an unescaped name', () {
      final uri = Uri.parse(ledgerLocation(
        year: 2026,
        month: 3,
        paymentMethodId: 'pm-1',
        paymentMethodName: '카카오 페이',
      ));

      expect(uri.queryParameters['paymentMethodId'], 'pm-1');
      // Decoded back to the original — the router reads state.uri.queryParameters,
      // which undoes whatever encoding was applied.
      expect(uri.queryParameters['paymentMethodName'], '카카오 페이');
    });

    test('round-trips a category filter', () {
      final uri = Uri.parse(ledgerLocation(
        year: 2026,
        month: 3,
        categoryId: 'cat-9',
        categoryName: '식비 & 외식',
      ));

      expect(uri.queryParameters['categoryId'], 'cat-9');
      expect(uri.queryParameters['categoryName'], '식비 & 외식');
    });

    test('keeps an explicitly empty category name (existing behaviour)', () {
      final uri = Uri.parse(ledgerLocation(
        year: 2026,
        month: 3,
        categoryId: 'cat-9',
        categoryName: '',
      ));

      expect(uri.queryParameters.containsKey('categoryName'), isTrue);
      expect(uri.queryParameters['categoryName'], '');
    });
  });

  group('parseLedgerView', () {
    test('parses known modes', () {
      expect(parseLedgerView('list'), LedgerView.list);
      expect(parseLedgerView('calendar'), LedgerView.calendar);
      expect(parseLedgerView('reconciliation'), LedgerView.reconciliation);
    });

    test('returns null for null or unknown values', () {
      expect(parseLedgerView(null), isNull);
      expect(parseLedgerView(''), isNull);
      expect(parseLedgerView('summary'), isNull);
    });
  });

  group('nextLedgerViewOnUpdate', () {
    test('null -> value switches', () {
      expect(
        nextLedgerViewOnUpdate(previous: null, current: 'reconciliation'),
        LedgerView.reconciliation,
      );
    });

    test('value -> different value switches', () {
      expect(
        nextLedgerViewOnUpdate(previous: 'list', current: 'calendar'),
        LedgerView.calendar,
      );
    });

    test('value -> null is NOT a reset signal', () {
      // 정산 뷰 → 거래 수정 저장 → '/transactions?year&month' 로 복귀할 때의 경로.
      // 여기서 리스트로 되돌리면 사용자가 보던 뷰에서 튕긴다.
      expect(
        nextLedgerViewOnUpdate(previous: 'reconciliation', current: null),
        isNull,
      );
    });

    test('unchanged value does nothing', () {
      expect(
        nextLedgerViewOnUpdate(
            previous: 'reconciliation', current: 'reconciliation'),
        isNull,
      );
    });

    test('unknown value does nothing', () {
      expect(
        nextLedgerViewOnUpdate(previous: null, current: 'bogus'),
        isNull,
      );
    });
  });
}
