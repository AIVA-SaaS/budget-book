import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/pages/budget_form_page.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/core/widgets/period_selector.dart';

class MockBudgetBloc extends MockBloc<BudgetEvent, BudgetState>
    implements BudgetBloc {}

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

class MockPocketBloc extends MockBloc<PocketEvent, PocketState>
    implements PocketBloc {}

class MockCategoryGroupBloc
    extends MockBloc<CategoryGroupEvent, CategoryGroupState>
    implements CategoryGroupBloc {}

void main() {
  late MockBudgetBloc mockBudgetBloc;
  late MockCategoryBloc mockCategoryBloc;
  late MockPocketBloc mockPocketBloc;

  final tCategories = [
    Category(
      id: 'cat-1',
      name: '식비',
      type: 'EXPENSE',
      icon: 'restaurant',
      color: '#FF5733',
      isDefault: true,
      displayOrder: 1,
      createdAt: DateTime(2026),
    ),
    Category(
      id: 'cat-2',
      name: '교통비',
      type: 'EXPENSE',
      icon: 'directions_car',
      color: '#3498DB',
      isDefault: true,
      displayOrder: 2,
      createdAt: DateTime(2026),
    ),
  ];

  final tBudget = Budget(
    id: 'budget-1',
    coupleId: 'couple-1',
    category: const TransactionCategory(
      id: 'cat-1',
      name: '식비',
      type: 'EXPENSE',
    ),
    yearMonth: '2026-03',
    amount: 150000,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final tOverallBudget = Budget(
    id: 'budget-2',
    coupleId: 'couple-1',
    category: null,
    yearMonth: '2026-03',
    amount: 150000,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  late MockCategoryGroupBloc mockCategoryGroupBloc;

  setUp(() {
    mockBudgetBloc = MockBudgetBloc();
    mockCategoryBloc = MockCategoryBloc();
    mockPocketBloc = MockPocketBloc();
    mockCategoryGroupBloc = MockCategoryGroupBloc();
    when(() => mockCategoryGroupBloc.state)
        .thenReturn(const CategoryGroupLoaded([]));

    // Register mocks in GetIt for budget_form_page initState
    final getIt = GetIt.instance;
    if (getIt.isRegistered<CategoryGroupBloc>()) {
      getIt.unregister<CategoryGroupBloc>();
    }
    if (getIt.isRegistered<CategoryBloc>()) {
      getIt.unregister<CategoryBloc>();
    }
    getIt.registerSingleton<CategoryGroupBloc>(mockCategoryGroupBloc);
    getIt.registerSingleton<CategoryBloc>(mockCategoryBloc);
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<CategoryGroupBloc>()) {
      getIt.unregister<CategoryGroupBloc>();
    }
    if (getIt.isRegistered<CategoryBloc>()) {
      getIt.unregister<CategoryBloc>();
    }
  });

  Widget buildTestWidget({
    String? budgetId,
    List<Budget> budgets = const [],
    int year = 2026,
    int month = 3,
  }) {
    when(() => mockBudgetBloc.state).thenReturn(BudgetLoaded(
      budgets: budgets,
      year: year,
      month: month,
    ));
    when(() => mockCategoryBloc.state)
        .thenReturn(CategoryLoaded(tCategories));
    when(() => mockPocketBloc.state)
        .thenReturn(const PocketLoaded([]));
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BudgetBloc>.value(value: mockBudgetBloc),
          BlocProvider<CategoryBloc>.value(value: mockCategoryBloc),
          BlocProvider<PocketBloc>.value(value: mockPocketBloc),
        ],
        child: BudgetFormPage(
          budgetId: budgetId,
          year: year,
          month: month,
        ),
      ),
    );
  }

  group('BudgetFormPage', () {
    testWidgets('shows create form title when no budgetId', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('예산 추가'), findsOneWidget);
    });

    testWidgets('shows edit form title when budgetId provided',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budgetId: 'budget-1',
        budgets: [tBudget],
      ));
      await tester.pumpAndSettle();
      expect(find.text('예산 수정'), findsOneWidget);
    });

    testWidgets('shows amount input field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('예산 금액'), findsOneWidget);
    });

    testWidgets('shows optional category picker in create mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('카테고리 (선택)'), findsOneWidget);
    });

    testWidgets('validates empty amount', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      // Tap submit without entering amount
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('금액을 입력하세요'), findsOneWidget);
    });

    testWidgets('validates zero amount', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      // Find the amount TextFormField (first one after month selector)
      final amountFields = find.byType(TextFormField);
      await tester.enterText(amountFields.first, '0');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('0보다 큰 금액을 입력하세요'), findsOneWidget);
    });

    testWidgets('shows PeriodSelector widget', (tester) async {
      await tester.pumpWidget(buildTestWidget(year: 2026, month: 3));
      expect(find.byType(PeriodSelector), findsOneWidget);
    });

    testWidgets('shows period type label', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('예산 기간'), findsOneWidget);
    });

    testWidgets('shows submit button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('저장'), findsOneWidget);
    });

    testWidgets('shows category picker editable in edit mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budgetId: 'budget-1',
        budgets: [tBudget],
      ));
      await tester.pumpAndSettle();
      // Category picker should be shown (editable), not read-only text
      expect(find.text('카테고리는 수정할 수 없습니다'), findsNothing);
      expect(find.text('카테고리 (선택)'), findsOneWidget);
    });

    testWidgets('pre-fills amount in edit mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        budgetId: 'budget-2',
        budgets: [tOverallBudget],
      ));
      await tester.pumpAndSettle();
      expect(find.text('150,000'), findsOneWidget);
    });

    testWidgets('shows "기간 미지정" text for NONE period type by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('기간 미지정'), findsOneWidget);
    });
  });
}
