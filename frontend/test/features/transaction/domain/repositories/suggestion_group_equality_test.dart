import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';

void main() {
  group('SuggestionGroup Equatable', () {
    test('same description = equal regardless of patterns', () {
      const a = SuggestionGroup(description: '스타벅스', patterns: []);
      const b = SuggestionGroup(description: '스타벅스', patterns: [
        SuggestionPattern(count: 5),
      ]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different description = not equal', () {
      const a = SuggestionGroup(description: '스타벅스', patterns: []);
      const b = SuggestionGroup(description: '투썸플레이스', patterns: []);
      expect(a == b, isFalse);
    });

    test('list.contains works after fetch refresh', () {
      const expanded =
          SuggestionGroup(description: '스타벅스', patterns: []);
      // Simulate a new fetch returning a new instance with updated patterns.
      final fresh = [
        const SuggestionGroup(description: '스타벅스', patterns: [
          SuggestionPattern(categoryId: 'c1', count: 10),
        ]),
        const SuggestionGroup(description: '맥도날드', patterns: []),
      ];
      expect(fresh.contains(expanded), isTrue,
          reason: 'expand 보존 로직이 description 매핑으로 동작해야 함');
    });

    test('SuggestionPattern equality by (categoryId, paymentMethodId)', () {
      const a = SuggestionPattern(
          categoryId: 'c1', paymentMethodId: 'p1', count: 5);
      const b = SuggestionPattern(
          categoryId: 'c1', paymentMethodId: 'p1', count: 99);
      expect(a, equals(b));
    });
  });
}
