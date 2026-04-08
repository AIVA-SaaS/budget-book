import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/amount_input_field.dart';

void main() {
  Widget buildWidget({
    TextEditingController? controller,
    String labelText = '금액',
    FormFieldValidator<String>? validator,
  }) {
    final ctrl = controller ?? TextEditingController();
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AmountInputField(
            controller: ctrl,
            labelText: labelText,
            validator: validator,
          ),
        ),
      ),
    );
  }

  group('AmountInputField', () {
    testWidgets('renders label and three action buttons', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('금액'), findsOneWidget);
      // Three icon buttons: add, remove, close
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('clear button resets amount to 0', (tester) async {
      final controller = TextEditingController(text: '50,000');
      await tester.pumpWidget(buildWidget(controller: controller));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.text, '0');
    });

    testWidgets('add button opens dialog and adds amount', (tester) async {
      final controller = TextEditingController(text: '10,000');
      await tester.pumpWidget(buildWidget(controller: controller));

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('금액 더하기'), findsOneWidget);

      // Enter amount in dialog
      await tester.enterText(find.byType(TextField).last, '5000');
      await tester.pump();

      // Tap the add button in dialog
      await tester.tap(find.text('더하기'));
      await tester.pumpAndSettle();

      expect(controller.text, '15,000');
    });

    testWidgets('subtract button opens dialog and subtracts amount',
        (tester) async {
      final controller = TextEditingController(text: '10,000');
      await tester.pumpWidget(buildWidget(controller: controller));

      // Tap subtract button
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('금액 빼기'), findsOneWidget);

      // Enter amount in dialog
      await tester.enterText(find.byType(TextField).last, '3000');
      await tester.pump();

      // Tap the subtract button in dialog
      await tester.tap(find.text('빼기'));
      await tester.pumpAndSettle();

      expect(controller.text, '7,000');
    });

    testWidgets('subtract does not go below zero', (tester) async {
      final controller = TextEditingController(text: '1,000');
      await tester.pumpWidget(buildWidget(controller: controller));

      // Tap subtract button
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Enter amount larger than current
      await tester.enterText(find.byType(TextField).last, '5000');
      await tester.pump();

      await tester.tap(find.text('빼기'));
      await tester.pumpAndSettle();

      expect(controller.text, '0');
    });

    testWidgets('cancel dialog does not change amount', (tester) async {
      final controller = TextEditingController(text: '10,000');
      await tester.pumpWidget(buildWidget(controller: controller));

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(controller.text, '10,000');
    });

    testWidgets('add to empty field treats current as 0', (tester) async {
      final controller = TextEditingController(text: '');
      await tester.pumpWidget(buildWidget(controller: controller));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '5000');
      await tester.pump();

      await tester.tap(find.text('더하기'));
      await tester.pumpAndSettle();

      expect(controller.text, '5,000');
    });
  });
}
