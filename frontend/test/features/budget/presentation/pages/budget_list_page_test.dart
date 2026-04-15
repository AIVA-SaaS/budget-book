import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/pages/budget_list_page.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_bloc.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_event.dart';
import 'package:budget_book/features/weekly_budget/presentation/bloc/weekly_budget_state.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';

class MockBudgetBloc extends MockBloc<BudgetEvent, BudgetState>
    implements BudgetBloc {}

class MockPaymentMethodBloc
    extends MockBloc<PaymentMethodEvent, PaymentMethodState>
    implements PaymentMethodBloc {}

class MockWeeklyBudgetBloc
    extends MockBloc<WeeklyBudgetEvent, WeeklyBudgetState>
    implements WeeklyBudgetBloc {}

class MockCoupleBloc extends MockBloc<CoupleEvent, CoupleState>
    implements CoupleBloc {}

void main() {
  late MockBudgetBloc mockBudgetBloc;
  late MockPaymentMethodBloc mockPaymentMethodBloc;
  late MockWeeklyBudgetBloc mockWeeklyBudgetBloc;

  const tCategory = TransactionCategory(
    id: 'cat-1',
    name: '식비',
    type: 'EXPENSE',
    icon: 'restaurant',
    color: '#FF5733',
  );

  final tBudget1 = Budget(
    id: 'budget-1',
    coupleId: 'couple-1',
    category: tCategory,
    yearMonth: '2026-03',
    amount: 150000,
    createdAt: DateTime.parse('2026-03-01T12:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T12:00:00Z'),
  );

  final tBudget2 = Budget(
    id: 'budget-2',
    coupleId: 'couple-1',
    category: null,
    yearMonth: '2026-03',
    amount: 3000000,
    createdAt: DateTime.parse('2026-03-01T12:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T12:00:00Z'),
  );

  const tSummary = BudgetSummary(
    yearMonth: '2026-03',
    totalBudget: 3150000,
    totalSpent: 1800000,
    items: [
      BudgetSummaryItem(
        category: tCategory,
        budgetAmount: 150000,
        spentAmount: 95000,
        remainingAmount: 55000,
        usageRate: 63.3,
      ),
      BudgetSummaryItem(
        category: null,
        budgetAmount: 3000000,
        spentAmount: 1705000,
        remainingAmount: 1295000,
        usageRate: 56.8,
      ),
    ],
  );

  setUp(() {
    mockBudgetBloc = MockBudgetBloc();

    mockPaymentMethodBloc = MockPaymentMethodBloc();
    when(() => mockPaymentMethodBloc.state)
        .thenReturn(const PaymentMethodInitial());

    mockWeeklyBudgetBloc = MockWeeklyBudgetBloc();
    when(() => mockWeeklyBudgetBloc.state)
        .thenReturn(const WeeklyBudgetInitial());

    // Register in GetIt so that getIt<PaymentMethodBloc>() and
    // getIt<WeeklyBudgetBloc>() calls inside the page find the mocks.
    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
    if (getIt.isRegistered<WeeklyBudgetBloc>()) {
      getIt.unregister<WeeklyBudgetBloc>();
    }
    if (getIt.isRegistered<CoupleBloc>()) {
      getIt.unregister<CoupleBloc>();
    }
    getIt.registerSingleton<PaymentMethodBloc>(mockPaymentMethodBloc);
    getIt.registerSingleton<WeeklyBudgetBloc>(mockWeeklyBudgetBloc);
    final mockCoupleBloc = MockCoupleBloc();
    when(() => mockCoupleBloc.state).thenReturn(const CoupleNotLinked());
    getIt.registerSingleton<CoupleBloc>(mockCoupleBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<PaymentMethodBloc>()) {
      getIt.unregister<PaymentMethodBloc>();
    }
    if (getIt.isRegistered<WeeklyBudgetBloc>()) {
      getIt.unregister<WeeklyBudgetBloc>();
    }
    if (getIt.isRegistered<CoupleBloc>()) {
      getIt.unregister<CoupleBloc>();
    }
  });

  Widget buildTestWidget({BudgetState? initialState}) {
    if (initialState != null) {
      when(() => mockBudgetBloc.state).thenReturn(initialState);
    }
    // BudgetLoaded의 year/month와 MonthCubit state를 맞춰 UI가 기대값 표시
    final monthCubit = MonthCubit();
    if (initialState is BudgetLoaded) {
      monthCubit.changeMonth(initialState.year, initialState.month);
    }
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BudgetBloc>.value(value: mockBudgetBloc),
          BlocProvider<MonthCubit>.value(value: monthCubit),
        ],
        child: const BudgetListPage(),
      ),
    );
  }

  group('BudgetListPage', () {
    testWidgets('shows loading indicator when BudgetLoading',
        (tester) async {
      when(() => mockBudgetBloc.state).thenReturn(const BudgetLoading());
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('shows empty state when no budgets', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialState: const BudgetLoaded(
          budgets: [],
          year: 2026,
          month: 3,
        ),
      ));
      expect(find.text('이 달에 설정된 예산이 없습니다'), findsOneWidget);
    });

    testWidgets('shows budget list when loaded', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialState: BudgetLoaded(
          budgets: [tBudget1, tBudget2],
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
      ));
      expect(find.text('식비'), findsOneWidget);
      expect(find.text('전체 예산'), findsWidgets);
    });

    testWidgets('shows summary card when summary available', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialState: BudgetLoaded(
          budgets: [tBudget1, tBudget2],
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
      ));
      expect(find.text('이번 달 예산'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      when(() => mockBudgetBloc.state)
          .thenReturn(const BudgetError('Error loading'));
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('예산을 불러오지 못했습니다'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('shows month navigator', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialState: const BudgetLoaded(
          budgets: [],
          year: 2026,
          month: 3,
        ),
      ));
      expect(find.text('2026년 3월'), findsOneWidget);
    });

    testWidgets('has FAB for adding budget', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialState: const BudgetLoaded(
          budgets: [],
          year: 2026,
          month: 3,
        ),
      ));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows progress indicator with remaining amount',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialState: BudgetLoaded(
          budgets: [tBudget1, tBudget2],
          summary: tSummary,
          year: 2026,
          month: 3,
        ),
      ));
      // Summary card shows remaining
      expect(find.textContaining('남음'), findsOneWidget);
    });
  });
}
