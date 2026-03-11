import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
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

class MockBudgetBloc extends MockBloc<BudgetEvent, BudgetState>
    implements BudgetBloc {}

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

void main() {
  late MockBudgetBloc mockBudgetBloc;
  late MockCategoryBloc mockCategoryBloc;

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

  setUp(() {
    mockBudgetBloc = MockBudgetBloc();
    mockCategoryBloc = MockCategoryBloc();
  });

  Widget buildTestWidget({Budget? budget, int year = 2026, int month = 3}) {
    when(() => mockBudgetBloc.state).thenReturn(const BudgetLoaded(
      budgets: [],
      year: 2026,
      month: 3,
    ));
    when(() => mockCategoryBloc.state)
        .thenReturn(CategoryLoaded(tCategories));
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BudgetBloc>.value(value: mockBudgetBloc),
          BlocProvider<CategoryBloc>.value(value: mockCategoryBloc),
        ],
        child: BudgetFormPage(
          budget: budget,
          year: year,
          month: month,
        ),
      ),
    );
  }

  group('BudgetFormPage', () {
    testWidgets('shows create form title when no budget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('예산 추가'), findsOneWidget);
    });

    testWidgets('shows edit form title when budget provided', (tester) async {
      final budget = Budget(
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
      await tester.pumpWidget(buildTestWidget(budget: budget));
      expect(find.text('예산 수정'), findsOneWidget);
    });

    testWidgets('shows amount input field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('예산 금액'), findsOneWidget);
    });

    testWidgets('shows overall budget switch in create mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('전체 예산'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('validates empty amount', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      // Toggle overall budget to bypass category validation
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // Tap submit
      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
      expect(find.text('금액을 입력하세요'), findsOneWidget);
    });

    testWidgets('validates zero amount', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
      expect(find.text('0보다 큰 금액을 입력하세요'), findsOneWidget);
    });

    testWidgets('shows month selector', (tester) async {
      await tester.pumpWidget(buildTestWidget(year: 2026, month: 3));
      expect(find.text('2026년 3월'), findsOneWidget);
    });

    testWidgets('shows submit button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('추가'), findsOneWidget);
    });

    testWidgets('shows category non-editable in edit mode', (tester) async {
      final budget = Budget(
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
      await tester.pumpWidget(buildTestWidget(budget: budget));
      expect(find.text('카테고리는 수정할 수 없습니다'), findsOneWidget);
    });

    testWidgets('pre-fills amount in edit mode', (tester) async {
      final budget = Budget(
        id: 'budget-1',
        coupleId: 'couple-1',
        category: null,
        yearMonth: '2026-03',
        amount: 150000,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(buildTestWidget(budget: budget));
      expect(find.text('150000'), findsOneWidget);
    });
  });
}
