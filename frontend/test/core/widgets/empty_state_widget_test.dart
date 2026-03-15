import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: '거래 내역이 없습니다',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.text('거래 내역이 없습니다'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: '거래 내역이 없습니다',
              subtitle: '이 달에 기록된 거래가 없습니다',
            ),
          ),
        ),
      );

      expect(find.text('이 달에 기록된 거래가 없습니다'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: '거래 내역이 없습니다',
            ),
          ),
        ),
      );

      // Only title and icon, no subtitle
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders action button when label and callback provided',
        (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: '거래 내역이 없습니다',
              actionLabel: '거래 추가',
              onAction: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('거래 추가'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.text('거래 추가'));
      expect(pressed, isTrue);
    });

    testWidgets('does not render action button when no callback',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: '거래 내역이 없습니다',
              actionLabel: '거래 추가',
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
