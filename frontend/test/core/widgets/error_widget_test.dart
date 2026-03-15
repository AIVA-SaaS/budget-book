import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/error_widget.dart';

void main() {
  group('AppErrorWidget', () {
    testWidgets('displays error icon and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(message: 'Something went wrong'),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(
              message: 'Error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(message: 'Error'),
          ),
        ),
      );

      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('shows home button when showHomeButton is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(
              message: 'Error',
              showHomeButton: true,
            ),
          ),
        ),
      );

      expect(find.text('홈으로'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('hides home button by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(message: 'Error'),
          ),
        ),
      );

      expect(find.text('홈으로'), findsNothing);
    });

    testWidgets('shows both retry and home buttons together', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(
              message: 'Error message',
              onRetry: () {},
              showHomeButton: true,
            ),
          ),
        ),
      );

      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('홈으로'), findsOneWidget);
      expect(find.text('Error message'), findsOneWidget);
    });
  });
}
