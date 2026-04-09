import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/core/widgets/filters/unified_filter_bar.dart';

void main() {
  Widget createWidget({
    Set<FilterType> enabledFilters = const {
      FilterType.dateRange,
      FilterType.category,
      FilterType.paymentMethod,
    },
    UnifiedFilterState state = const UnifiedFilterState(),
    ValueChanged<UnifiedFilterState>? onFilterChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: UnifiedFilterBar(
          enabledFilters: enabledFilters,
          state: state,
          onFilterChanged: onFilterChanged ?? (_) {},
        ),
      ),
    );
  }

  group('UnifiedFilterBar', () {
    testWidgets('shows filter button when advanced filters enabled',
        (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.category, FilterType.paymentMethod},
      ));
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('shows date range button when dateRange enabled',
        (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.dateRange},
      ));
      expect(find.byIcon(Icons.date_range), findsOneWidget);
    });

    testWidgets('hides filter button when no advanced filters', (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.dateRange},
      ));
      expect(find.byIcon(Icons.tune), findsNothing);
    });

    testWidgets('shows active category chip', (tester) async {
      await tester.pumpWidget(createWidget(
        state: const UnifiedFilterState(
          categoryIds: {'cat-1'},
          categoryName: '식비',
        ),
      ));
      expect(find.text('카테고리: 식비'), findsOneWidget);
    });

    testWidgets('shows active payment method chip', (tester) async {
      await tester.pumpWidget(createWidget(
        state: const UnifiedFilterState(
          paymentMethodIds: {'pm-1'},
          paymentMethodName: '신한카드',
        ),
      ));
      expect(find.text('결제수단: 신한카드'), findsOneWidget);
    });

    testWidgets('shows active amount chip', (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.amountRange},
        state: const UnifiedFilterState(amountMin: 1000, amountMax: 5000),
      ));
      expect(find.textContaining('금액:'), findsOneWidget);
    });

    testWidgets('shows active date range chip', (tester) async {
      await tester.pumpWidget(createWidget(
        state: UnifiedFilterState(
          dateFrom: DateTime(2026, 4, 1),
          dateTo: DateTime(2026, 4, 30),
          dateRangeLabel: '이번 달',
        ),
      ));
      expect(find.text('이번 달'), findsOneWidget);
    });

    testWidgets('removing category chip calls onFilterChanged', (tester) async {
      UnifiedFilterState? result;
      await tester.pumpWidget(createWidget(
        state: const UnifiedFilterState(
          categoryIds: {'cat-1'},
          categoryName: '식비',
        ),
        onFilterChanged: (s) => result = s,
      ));

      // Find the delete icon on the chip
      final chipFinder = find.text('카테고리: 식비');
      expect(chipFinder, findsOneWidget);

      // Tap the delete button (close icon on InputChip)
      final deleteIcon = find.descendant(
        of: find.ancestor(
          of: chipFinder,
          matching: find.byType(InputChip),
        ),
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(deleteIcon);

      expect(result, isNotNull);
      expect(result!.categoryIds, isEmpty);
    });

    testWidgets('no chips shown when no active filters', (tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(InputChip), findsNothing);
    });
  });
}
