import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/budget/presentation/widgets/budget_row_actions.dart';

class _MockBudgetBloc extends MockBloc<BudgetEvent, BudgetState>
    implements BudgetBloc {}

class _FakeDeleteBudget extends Fake implements DeleteBudget {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDeleteBudget());
  });

  late _MockBudgetBloc bloc;
  late List<String> visitedPaths;

  setUp(() {
    bloc = _MockBudgetBloc();
    when(() => bloc.state).thenReturn(const BudgetInitial());
    visitedPaths = [];
  });

  GoRouter buildRouter(Widget child) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/budgets/edit/:id',
          builder: (ctx, state) {
            visitedPaths.add(state.uri.toString());
            return const Scaffold(body: Text('EDIT_PAGE'));
          },
        ),
      ],
    );
  }

  Widget wrap(Widget child) {
    return BlocProvider<BudgetBloc>.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: buildRouter(child)),
    );
  }

  group('BudgetRowActions', () {
    testWidgets('row tap navigates to edit page', (tester) async {
      final widget = BudgetRowActions(
        budgetId: 'b1',
        categoryId: 'c1',
        categoryGroupId: null,
        label: '식비',
        dateFrom: null,
        dateTo: null,
        year: 2026,
        month: 4,
        onAfterDelete: () {},
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('row-content'),
        ),
      );

      await tester.pumpWidget(wrap(widget));
      await tester.tap(find.text('row-content'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT_PAGE'), findsOneWidget);
      expect(visitedPaths.first, contains('/budgets/edit/b1'));
      expect(visitedPaths.first, contains('year=2026'));
      expect(visitedPaths.first, contains('month=4'));
    });

    testWidgets('menuButton renders 3 menu items (transactions/edit/delete)',
        (tester) async {
      final menu = Builder(
        builder: (ctx) => BudgetRowActions.menuButton(
          context: ctx,
          budgetId: 'b1',
          categoryId: null,
          categoryGroupId: 'g1',
          label: '식비 그룹',
          dateFrom: '2026-04-01',
          dateTo: '2026-04-07',
          year: 2026,
          month: 4,
          onAfterDelete: () {},
        ),
      );

      await tester.pumpWidget(wrap(menu));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('거래 보기'), findsOneWidget);
      expect(find.text('수정'), findsOneWidget);
      expect(find.text('삭제'), findsOneWidget);
    });

    testWidgets('menuButton renders without throwing for total budget (both ids null)',
        (tester) async {
      final menu = Builder(
        builder: (ctx) => BudgetRowActions.menuButton(
          context: ctx,
          budgetId: 'b9',
          categoryId: null,
          categoryGroupId: null,
          label: '총 예산',
          dateFrom: null,
          dateTo: null,
          year: 2026,
          month: 5,
          onAfterDelete: () {},
        ),
      );

      await tester.pumpWidget(wrap(menu));
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets(
        'menu delete confirmed → DeleteBudget dispatched + onAfterDelete called',
        (tester) async {
      var afterDeleteCalled = 0;
      final menu = Builder(
        builder: (ctx) => BudgetRowActions.menuButton(
          context: ctx,
          budgetId: 'b-del',
          categoryId: 'c1',
          categoryGroupId: null,
          label: '주간 식비',
          dateFrom: '2026-04-01',
          dateTo: '2026-04-07',
          year: 2026,
          month: 4,
          onAfterDelete: () => afterDeleteCalled++,
        ),
      );

      await tester.pumpWidget(wrap(menu));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      expect(find.text('예산 삭제'), findsOneWidget);
      await tester.tap(find.text('삭제').last);
      await tester.pumpAndSettle();

      verify(() => bloc.add(any(that: isA<DeleteBudget>()
          .having((e) => e.id, 'id', 'b-del')))).called(1);
      expect(afterDeleteCalled, 1);
    });

    testWidgets('menu delete cancelled → no event, no callback', (tester) async {
      var afterDeleteCalled = 0;
      final menu = Builder(
        builder: (ctx) => BudgetRowActions.menuButton(
          context: ctx,
          budgetId: 'b-keep',
          categoryId: null,
          categoryGroupId: 'g1',
          label: '그룹 예산',
          dateFrom: null,
          dateTo: null,
          year: 2026,
          month: 4,
          onAfterDelete: () => afterDeleteCalled++,
        ),
      );

      await tester.pumpWidget(wrap(menu));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any(that: isA<DeleteBudget>())));
      expect(afterDeleteCalled, 0);
    });
  });
}
