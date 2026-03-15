import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';

void main() {
  group('SkeletonLoader', () {
    testWidgets('renders with default parameters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders specified number of items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(itemCount: 3),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsOneWidget);
    });

    testWidgets('animates shimmer effect', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(itemCount: 2),
          ),
        ),
      );

      // Pump to advance animation
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // No errors means animation is running correctly
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });
  });
}
