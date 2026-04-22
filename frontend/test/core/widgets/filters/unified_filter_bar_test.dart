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
    testWidgets('shows tune icon when advanced filters enabled',
        (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.category, FilterType.paymentMethod},
      ));
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('shows tune icon when dateRange is the only filter',
        (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.dateRange},
      ));
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('shows nothing when no filters enabled', (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {},
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

    testWidgets('shows active transactionType chip (multi)', (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.transactionType},
        state: const UnifiedFilterState(transactionTypes: {'EXPENSE'}),
      ));
      expect(find.text('지출'), findsOneWidget);
    });

    testWidgets('shows combined label when multiple types selected',
        (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.transactionType},
        state: const UnifiedFilterState(
          transactionTypes: {'EXPENSE', 'TRANSFER'},
        ),
      ));
      // Combined chip label joins selected type labels with '/'.
      expect(find.textContaining('지출'), findsOneWidget);
      expect(find.textContaining('이체'), findsOneWidget);
    });

    testWidgets('shows active visibility chip', (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {FilterType.visibility},
        state: const UnifiedFilterState(visibility: 'SHARED'),
      ));
      expect(find.text('공유'), findsOneWidget);
    });

    testWidgets('badge shows active filter count', (tester) async {
      await tester.pumpWidget(createWidget(
        state: const UnifiedFilterState(
          categoryIds: {'cat-1'},
          categoryName: '식비',
          paymentMethodIds: {'pm-1'},
          paymentMethodName: '신한카드',
        ),
      ));
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows overflow chip when more than 3 filters active',
        (tester) async {
      await tester.pumpWidget(createWidget(
        enabledFilters: {
          FilterType.transactionType,
          FilterType.visibility,
          FilterType.category,
          FilterType.paymentMethod,
        },
        state: const UnifiedFilterState(
          transactionTypes: {'EXPENSE'},
          visibility: 'SHARED',
          categoryIds: {'cat-1'},
          categoryName: '식비',
          paymentMethodIds: {'pm-1'},
          paymentMethodName: '신한카드',
        ),
      ));
      // First 3 chips shown, 4th as overflow
      expect(find.text('+1'), findsOneWidget);
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
