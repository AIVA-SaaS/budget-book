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

  group('연/월 한 화면', () {
    testWidgets('열면 연도 휠과 12개월이 동시에 보인다 — 연도 전용 단계는 없다', (tester) async {
      await open(tester);

      expect(find.text('연/월 선택'), findsOneWidget);
      expect(find.byType(ListWheelScrollView), findsOneWidget);
      expect(find.text('2026'), findsOneWidget); // 휠의 현재 연도
      expect(find.text('1월'), findsOneWidget);
      expect(find.text('12월'), findsOneWidget);

      // 왕복 단계가 사라졌다는 것이 이번 회차의 핵심이다.
      expect(find.text('연도 선택'), findsNothing);
      expect(find.text('월 선택'), findsNothing);
    });

    testWidgets('월을 고르면 확인 버튼 없이 즉시 닫힌다', (tester) async {
      MonthPickerResult? result;
      await open(tester, sink: (r) => result = r);

      await tester.tap(find.text('5월'));
      await tester.pumpAndSettle();

      expect(find.text('연/월 선택'), findsNothing);
      expect(result?.year, 2026);
      expect(result?.month, 5);
      expect(result?.day, isNull, reason: '월까지만 골랐으므로 day 는 비어 있어야 한다.');
    });

    testWidgets('연도 휠을 돌리면 그 연도 기준으로 월이 확정된다', (tester) async {
      MonthPickerResult? result;
      await open(tester, sink: (r) => result = r);

      // 아래로 끌면 이전 연도로 이동한다(휠 한 칸 = itemExtent 44).
      await tester.drag(find.byType(ListWheelScrollView), const Offset(0, 44));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);

      await tester.tap(find.text('3월'));
      await tester.pumpAndSettle();

      expect(result?.year, 2025);
      expect(result?.month, 3);
    });

    testWidgets('가운데가 아닌 연도를 탭해도 선택된다', (tester) async {
      MonthPickerResult? result;
      await open(tester, sink: (r) => result = r);

      await tester.tap(find.text('2027'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('9월'));
      await tester.pumpAndSettle();

      expect(result?.year, 2027);
      expect(result?.month, 9);
    });

    testWidgets('범위 밖의 달은 비활성이라 눌러도 닫히지 않는다', (tester) async {
      await open(
        tester,
        firstDate: DateTime(2026, 6),
        lastDate: DateTime(2026, 9, 30),
      );

      await tester.tap(find.text('2월'));
      await tester.pumpAndSettle();
      expect(find.text('연/월 선택'), findsOneWidget); // 여전히 열려 있다

      await tester.tap(find.text('7월'));
      await tester.pumpAndSettle();
      expect(find.text('연/월 선택'), findsNothing);
    });

    testWidgets('범위가 한 해뿐이면 휠에 다른 연도가 없다', (tester) async {
      await open(
        tester,
        firstDate: DateTime(2026),
        lastDate: DateTime(2026, 12, 31),
      );

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2025'), findsNothing);
      expect(find.text('2027'), findsNothing);
    });
  });

  group('일 그리드 (allowDaySelection)', () {
    testWidgets('일 그리드로 진입하며, CalendarDatePicker 를 쓰지 않는다', (tester) async {
      await open(tester, allowDaySelection: true);

      expect(find.text('날짜 선택'), findsOneWidget);
      expect(find.text('2026년 8월'), findsOneWidget);
      for (final w in ['일', '월', '화', '수', '목', '금', '토']) {
        expect(find.text(w), findsOneWidget, reason: '요일 헤더 $w 가 없다.');
      }
      expect(
        find.byType(CalendarDatePicker),
        findsNothing,
        reason: 'Material 내장 헤더(연도 목록 직행)가 다시 들어오면 요청 ②가 재발한다.',
      );
    });

    testWidgets('헤더의 연/월 라벨을 누르면 연/월 화면으로 올라간다', (tester) async {
      await open(tester, allowDaySelection: true);

      await tester.tap(find.text('2026년 8월'));
      await tester.pumpAndSettle();

      expect(find.text('연/월 선택'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('연도 선택'), findsNothing, reason: '연도 목록이 나오면 안 된다.');

      // 다른 달을 고르면 닫히지 않고 그 달의 일 그리드로 내려간다.
      await tester.tap(find.text('10월'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 10월'), findsOneWidget);
    });

    testWidgets('헤더 좌우 화살표로 달을 넘긴다 (해를 넘어도 이어진다)', (tester) async {
      await open(tester,
          initialYear: 2026, initialMonth: 12, allowDaySelection: true);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('2027년 1월'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('2026년 12월'), findsOneWidget);
    });

    testWidgets('날짜 1탭이 곧 확정이다', (tester) async {
      MonthPickerResult? result;
      await open(tester, allowDaySelection: true, sink: (r) => result = r);

      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      expect(result?.year, 2026);
      expect(result?.month, 8);
      expect(result?.day, 14);
    });

    testWidgets('달의 시작 요일만큼 앞칸이 비어 있다 (2026-08-01 = 토요일)', (tester) async {
      await open(tester, allowDaySelection: true);

      // 오프셋이 틀리면 달력 전체가 한 칸씩 밀린다 — 열 위치로 검증한다.
      expect(
        tester.getCenter(find.text('1')).dx,
        closeTo(tester.getCenter(find.text('토')).dx, 1.0),
      );
      expect(
        tester.getCenter(find.text('2')).dx,
        closeTo(tester.getCenter(find.text('일')).dx, 1.0),
      );
    });

    testWidgets('범위가 달 중간을 자르면 그 밖의 날은 비활성이다', (tester) async {
      MonthPickerResult? result;
      await open(
        tester,
        allowDaySelection: true,
        firstDate: DateTime(2026, 8, 10),
        lastDate: DateTime(2026, 8, 20),
        sink: (r) => result = r,
      );

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(find.text('날짜 선택'), findsOneWidget); // 여전히 열려 있다
      expect(result, isNull);

      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();
      expect(find.text('날짜 선택'), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(result?.day, 15);
    });
  });

  group('좁은 화면', () {
    testWidgets('320×640 에서 두 단계 모두 overflow 가 없다', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await open(tester, allowDaySelection: true);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('2026년 8월'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
