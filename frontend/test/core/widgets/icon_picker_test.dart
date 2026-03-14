import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/icon_picker.dart';

void main() {
  group('resolveIcon', () {
    test('returns matching IconData for known icon name', () {
      expect(resolveIcon('restaurant'), Icons.restaurant);
      expect(resolveIcon('home'), Icons.home);
      expect(resolveIcon('shopping_bag'), Icons.shopping_bag);
    });

    test('returns default icon for null', () {
      expect(resolveIcon(null), Icons.account_balance_wallet);
    });

    test('returns default icon for unknown name', () {
      expect(resolveIcon('nonexistent_icon'), Icons.account_balance_wallet);
    });
  });

  group('availableIcons', () {
    test('contains expected finance-related icons', () {
      expect(availableIcons.containsKey('restaurant'), true);
      expect(availableIcons.containsKey('shopping_bag'), true);
      expect(availableIcons.containsKey('local_gas_station'), true);
      expect(availableIcons.containsKey('train'), true);
      expect(availableIcons.containsKey('movie'), true);
      expect(availableIcons.containsKey('home'), true);
      expect(availableIcons.containsKey('school'), true);
      expect(availableIcons.containsKey('medical_services'), true);
      expect(availableIcons.containsKey('sports_esports'), true);
      expect(availableIcons.containsKey('checkroom'), true);
      expect(availableIcons.containsKey('coffee'), true);
      expect(availableIcons.containsKey('phone_android'), true);
      expect(availableIcons.containsKey('build'), true);
      expect(availableIcons.containsKey('flight'), true);
    });
  });

  group('showIconPicker', () {
    testWidgets('shows icon picker bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showIconPicker(context: context);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('아이콘 선택'), findsOneWidget);
      // Should show icon grid items
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('returns selected icon name on tap', (tester) async {
      String? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  selectedResult = await showIconPicker(context: context);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap on the first icon in the grid
      final firstInkWell = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      await tester.tap(firstInkWell.first);
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(availableIcons.containsKey(selectedResult), true);
    });
  });
}
