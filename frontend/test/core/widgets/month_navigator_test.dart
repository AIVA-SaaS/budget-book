import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/widgets/month_navigator.dart';

/// MonthNavigator 위젯 테스트.
///
/// 이 위젯은 렌더되는 화면 9곳이 공유하는데 2026-08-11 까지 전용 테스트가 **0건**이었다.
/// 페이지마다 테스트를 다는 대신 공용 위젯을 커버해 9곳을 한 번에 방어한다.
void main() {
  Widget host({
    int? year,
    int? month,
    required MonthCubit cubit,
    ValueChanged<({int year, int month})>? onMonthChanged,
    ValueChanged<DateTime>? onDatePicked,
  }) {
    return MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: MonthNavigator(
            year: year,
            month: month,
            onMonthChanged: onMonthChanged,
            onDatePicked: onDatePicked,
          ),
        ),
      ),
    );
  }

  IconButton todayButton(WidgetTester tester) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.today),
          matching: find.byType(IconButton),
        ),
      );

  group('"오늘" 버튼', () {
    testWidgets('이번 달을 보고 있으면 비활성', (tester) async {
      final now = DateTime.now();
      final cubit = MonthCubit();
      await tester.pumpWidget(
        host(year: now.year, month: now.month, cubit: cubit),
      );

      expect(todayButton(tester).onPressed, isNull);
    });

    testWidgets('다른 달을 보고 있으면 활성이고, 누르면 이번 달로 돌아온다', (tester) async {
      final cubit = MonthCubit();
      ({int year, int month})? changed;
      await tester.pumpWidget(host(
        year: 2020,
        month: 3,
        cubit: cubit,
        onMonthChanged: (m) => changed = m,
      ));

      expect(todayButton(tester).onPressed, isNotNull);

      await tester.tap(find.byIcon(Icons.today));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(changed, (year: now.year, month: now.month));
    });

    testWidgets('콜백이 없으면 MonthCubit 을 이번 달로 바꾼다', (tester) async {
      final cubit = MonthCubit();
      cubit.changeMonth(2020, 3);
      await tester.pumpWidget(host(cubit: cubit));

      await tester.tap(find.byIcon(Icons.today));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(cubit.state.year, now.year);
      expect(cubit.state.month, now.month);
    });
  });

  group('피커 진입 단계', () {
    testWidgets('onDatePicked 가 없으면 월 그리드로 진입한다', (tester) async {
      final cubit = MonthCubit();
      await tester.pumpWidget(host(year: 2026, month: 8, cubit: cubit));

      await tester.tap(find.text('2026년 8월'));
      await tester.pumpAndSettle();

      expect(find.text('월 선택'), findsOneWidget);
      expect(find.text('2026년'), findsOneWidget);
      expect(find.text('3월'), findsOneWidget);
    });

    testWidgets('onDatePicked 가 있으면 일 그리드로 진입한다 (거래 목록)', (tester) async {
      final cubit = MonthCubit();
      await tester.pumpWidget(host(
        year: 2026,
        month: 8,
        cubit: cubit,
        onDatePicked: (_) {},
      ));

      await tester.tap(find.text('2026년 8월'));
      await tester.pumpAndSettle();

      expect(find.text('날짜 선택'), findsOneWidget);
      expect(find.text('월 선택으로'), findsOneWidget);
    });
  });

  group('선택 결과 전달', () {
    testWidgets('월만 고르면 onMonthChanged 만 호출되고 onDatePicked 는 호출되지 않는다',
        (tester) async {
      final cubit = MonthCubit();
      ({int year, int month})? changed;
      DateTime? datePicked;
      await tester.pumpWidget(host(
        year: 2026,
        month: 8,
        cubit: cubit,
        onMonthChanged: (m) => changed = m,
        onDatePicked: null,
      ));

      await tester.tap(find.text('2026년 8월'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3월'));
      await tester.pumpAndSettle();

      expect(changed, (year: 2026, month: 3));
      expect(datePicked, isNull);
    });

    testWidgets('일까지 고르면 onDatePicked 와 onMonthChanged 가 모두 호출된다',
        (tester) async {
      final cubit = MonthCubit();
      ({int year, int month})? changed;
      DateTime? datePicked;
      await tester.pumpWidget(host(
        year: 2026,
        month: 8,
        cubit: cubit,
        onMonthChanged: (m) => changed = m,
        onDatePicked: (d) => datePicked = d,
      ));

      await tester.tap(find.text('2026년 8월'));
      await tester.pumpAndSettle();
      // 일 그리드로 진입해 있다 — 15일 선택 후 확정.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();

      expect(datePicked, DateTime(2026, 8, 15));
      expect(changed, (year: 2026, month: 8));
    });
  });

  group('좌우 화살표', () {
    testWidgets('연말/연초를 넘어간다', (tester) async {
      final cubit = MonthCubit();
      ({int year, int month})? changed;
      await tester.pumpWidget(host(
        year: 2026,
        month: 12,
        cubit: cubit,
        onMonthChanged: (m) => changed = m,
      ));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(changed, (year: 2027, month: 1));

      await tester.pumpWidget(host(
        year: 2026,
        month: 1,
        cubit: cubit,
        onMonthChanged: (m) => changed = m,
      ));
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(changed, (year: 2025, month: 12));
    });
  });
}
