import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/filters/amount_range_filter.dart';

void main() {
  group('AmountRangeFilter', () {
    testWidgets('renders min and max fields', (tester) async {
      final minCtrl = TextEditingController();
      final maxCtrl = TextEditingController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AmountRangeFilter(
            minController: minCtrl,
            maxController: maxCtrl,
          ),
        ),
      ));

      expect(find.text('금액 범위'), findsOneWidget);
      expect(find.text('최소 금액'), findsOneWidget);
      expect(find.text('최대 금액'), findsOneWidget);
      expect(find.text('~'), findsOneWidget);
    });

    testWidgets('shows initial values from controllers', (tester) async {
      final minCtrl = TextEditingController(text: '1000');
      final maxCtrl = TextEditingController(text: '5000');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AmountRangeFilter(
            minController: minCtrl,
            maxController: maxCtrl,
          ),
        ),
      ));

      expect(find.text('1000'), findsOneWidget);
      expect(find.text('5000'), findsOneWidget);
    });

    testWidgets('allows text input', (tester) async {
      final minCtrl = TextEditingController();
      final maxCtrl = TextEditingController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AmountRangeFilter(
            minController: minCtrl,
            maxController: maxCtrl,
          ),
        ),
      ));

      await tester.enterText(
          find.widgetWithText(TextField, '최소 금액'), '2000');
      expect(minCtrl.text, '2000');
    });
  });
}
