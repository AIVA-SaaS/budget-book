import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/models/unified_filter_state.dart';
import 'package:budget_book/core/widgets/filters/unified_filter_bar.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';

class MockPaymentMethodBloc
    extends MockBloc<PaymentMethodEvent, PaymentMethodState>
    implements PaymentMethodBloc {}

class MockPocketBloc extends MockBloc<PocketEvent, PocketState>
    implements PocketBloc {}

void main() {
  late MockPaymentMethodBloc mockPaymentMethodBloc;
  late MockPocketBloc mockPocketBloc;

  setUp(() {
    mockPaymentMethodBloc = MockPaymentMethodBloc();
    mockPocketBloc = MockPocketBloc();
    when(() => mockPaymentMethodBloc.state)
        .thenReturn(const PaymentMethodLoaded([]));
    when(() => mockPocketBloc.state).thenReturn(const PocketLoaded([]));

    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
    if (getIt.isRegistered<PocketBloc>()) {
      getIt.unregister<PocketBloc>();
    }
    getIt.registerSingleton<PaymentMethodBloc>(mockPaymentMethodBloc);
    getIt.registerSingleton<PocketBloc>(mockPocketBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
    if (getIt.isRegistered<PocketBloc>()) {
      getIt.unregister<PocketBloc>();
    }
  });

  Widget buildHarness({
    Set<FilterType> enabledFilters = const {FilterType.dateRange},
    UnifiedFilterState state = const UnifiedFilterState(),
    required ValueChanged<UnifiedFilterState> onFilterChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: UnifiedFilterBar(
          enabledFilters: enabledFilters,
          state: state,
          onFilterChanged: onFilterChanged,
        ),
      ),
    );
  }

  group('UnifiedFilterBar apply flow (PR-A)', () {
    testWidgets(
        'tapping "이번 주" preset keeps outer sheet open + does not call onFilterChanged',
        (tester) async {
      int callCount = 0;
      UnifiedFilterState? lastState;
      await tester.pumpWidget(buildHarness(
        onFilterChanged: (s) {
          callCount++;
          lastState = s;
        },
      ));

      // Open the advanced filter sheet.
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.text('필터'), findsOneWidget);

      // Open the date range preset sheet.
      await tester.tap(find.text('기간 변경'));
      await tester.pumpAndSettle();
      expect(find.text('기간 필터'), findsOneWidget);

      // Tap "이번 주" preset.
      await tester.tap(find.text('이번 주'));
      await tester.pumpAndSettle();

      // Date range sheet should have closed, but outer filter sheet remains open.
      expect(find.text('기간 필터'), findsNothing);
      expect(find.text('필터'), findsOneWidget);
      // onFilterChanged must not have been invoked yet (apply flow).
      expect(callCount, 0);
      expect(lastState, isNull);
    });

    testWidgets(
        '"이번 주" preset → 적용 button propagates dateFrom/dateTo/dateRangeLabel',
        (tester) async {
      int callCount = 0;
      UnifiedFilterState? result;
      await tester.pumpWidget(buildHarness(
        onFilterChanged: (s) {
          callCount++;
          result = s;
        },
      ));

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('기간 변경'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('이번 주'));
      await tester.pumpAndSettle();

      // Now tap "적용".
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(result, isNotNull);
      expect(result!.dateFrom, isNotNull);
      expect(result!.dateTo, isNotNull);
      expect(result!.dateRangeLabel, '이번 주');
    });

    testWidgets(
        'X button next to date range keeps outer sheet open + 적용 clears dateFrom',
        (tester) async {
      int callCount = 0;
      UnifiedFilterState? result;
      await tester.pumpWidget(buildHarness(
        state: UnifiedFilterState(
          dateFrom: DateTime(2026, 4, 1),
          dateTo: DateTime(2026, 4, 30),
          dateRangeLabel: '이번 달',
        ),
        onFilterChanged: (s) {
          callCount++;
          result = s;
        },
      ));

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // The X IconButton only appears when a date range is currently set.
      // Find Icons.clear inside the sheet and tap it.
      final clearIcon = find.byIcon(Icons.clear);
      expect(clearIcon, findsOneWidget);
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();

      // Outer filter sheet must remain open; no onFilterChanged yet.
      expect(find.text('필터'), findsOneWidget);
      expect(callCount, 0);

      // After clearing, the label should now read "전체 기간" within the sheet.
      expect(find.text('전체 기간'), findsOneWidget);

      // Now tap 적용 — dateFrom should be null.
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(result, isNotNull);
      expect(result!.dateFrom, isNull);
      expect(result!.dateTo, isNull);
      expect(result!.dateRangeLabel, isNull);
    });
  });
}
