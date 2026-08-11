import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_book/core/widgets/month_year_picker_dialog.dart';

void main() {
  /// 다이얼로그를 띄운다. 닫힐 때의 반환값은 [sink] 로 흘려보낸다
  /// (다이얼로그가 열려 있는 동안에는 `await` 이 끝나지 않으므로 리턴값으로 받을 수 없다).
  Future<void> open(
    WidgetTester tester, {
    int initialYear = 2026,
    int initialMonth = 8,
    DateTime? firstDate,
    DateTime? lastDate,
    bool allowDaySelection = false,
    void Function(MonthPickerResult?)? sink,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await showMonthYearPickerDialog(
                context: context,
                initialYear: initialYear,
                initialMonth: initialMonth,
                firstDate: firstDate,
                lastDate: lastDate,
                allowDaySelection: allowDaySelection,
              );
              sink?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('월 그리드로 진입하고 달을 고르면 즉시 닫힌다', (tester) async {
    MonthPickerResult? result;
    await open(tester, sink: (r) => result = r);

    expect(find.text('월 선택'), findsOneWidget);
    expect(find.text('1월'), findsOneWidget);
    expect(find.text('12월'), findsOneWidget);

    await tester.tap(find.text('5월'));
    await tester.pumpAndSettle();

    expect(find.text('월 선택'), findsNothing); // 확인 버튼 없이 1탭으로 확정
    expect(result?.year, 2026);
    expect(result?.month, 5);
    expect(result?.day, isNull, reason: '월까지만 골랐으므로 day 는 비어 있어야 한다.');
  });

  testWidgets('헤더를 누르면 연도 그리드로 올라가고, 연도를 고르면 월 그리드로 내려온다',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('2026년'));
    await tester.pumpAndSettle();
    expect(find.text('연도 선택'), findsOneWidget);
    expect(find.text('2024년'), findsOneWidget);

    await tester.tap(find.text('2024년'));
    await tester.pumpAndSettle();
    expect(find.text('월 선택'), findsOneWidget);
    expect(find.text('2024년'), findsOneWidget); // 헤더가 고른 연도를 반영
  });

  testWidgets('연도 좌우 화살표로 표시 연도를 바꾼다', (tester) async {
    await open(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('2027년'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('2026년'), findsOneWidget);
  });

  testWidgets('범위 밖의 달은 비활성이라 눌러도 닫히지 않는다', (tester) async {
    await open(
      tester,
      initialYear: 2026,
      initialMonth: 8,
      firstDate: DateTime(2026, 6),
      lastDate: DateTime(2026, 9, 30),
    );

    await tester.tap(find.text('2월'));
    await tester.pumpAndSettle();
    expect(find.text('월 선택'), findsOneWidget); // 여전히 열려 있다

    await tester.tap(find.text('7월'));
    await tester.pumpAndSettle();
    expect(find.text('월 선택'), findsNothing);
  });

  testWidgets('범위를 벗어나는 연도 이동 화살표는 비활성', (tester) async {
    await open(
      tester,
      firstDate: DateTime(2026),
      lastDate: DateTime(2026, 12, 31),
    );

    final prev = tester.widget<IconButton>(find.ancestor(
      of: find.byIcon(Icons.chevron_left),
      matching: find.byType(IconButton),
    ));
    expect(prev.onPressed, isNull);
  });

  group('allowDaySelection', () {
    testWidgets('일 그리드로 진입하고, 월 선택으로 올라갔다가 다시 내려올 수 있다',
        (tester) async {
      MonthPickerResult? result;
      await open(tester, allowDaySelection: true, sink: (r) => result = r);

      expect(find.text('날짜 선택'), findsOneWidget);

      await tester.tap(find.text('월 선택으로'));
      await tester.pumpAndSettle();
      expect(find.text('월 선택'), findsOneWidget);

      // 다른 달을 고르면 닫히지 않고 그 달의 일 그리드로 내려간다.
      await tester.tap(find.text('4월'));
      await tester.pumpAndSettle();
      expect(find.text('날짜 선택'), findsOneWidget);

      // 달력이 실제로 4월을 그리고 있는지는 고른 날짜로 확인한다
      // (테스트 환경은 로케일 델리게이트가 없어 헤더가 영문으로 나온다).
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      expect(result?.year, 2026);
      expect(result?.month, 4);
      expect(result?.day, 10);
    });
  });
}
