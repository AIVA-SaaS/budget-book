import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/color_picker.dart';

void main() {
  group('parseHexColor', () {
    test('parses valid hex color string', () {
      final color = parseHexColor('#FF5733');
      expect(color, const Color(0xFFFF5733));
    });

    test('returns grey for null', () {
      expect(parseHexColor(null), Colors.grey);
    });

    test('returns grey for invalid string', () {
      expect(parseHexColor('not-a-color'), Colors.grey);
    });

    test('handles hex without # prefix', () {
      final color = parseHexColor('2196F3');
      expect(color, const Color(0xFF2196F3));
    });
  });

  group('presetColors', () {
    test('contains expected number of colors', () {
      expect(presetColors.length, 32);
    });

    test('all colors start with #', () {
      for (final hex in presetColors) {
        expect(hex.startsWith('#'), true, reason: '$hex should start with #');
      }
    });

    test('all colors are parseable', () {
      for (final hex in presetColors) {
        final color = parseHexColor(hex);
        expect(color, isNot(Colors.grey),
            reason: '$hex should parse to a valid color');
      }
    });
  });

  group('showColorPicker', () {
    testWidgets('shows color picker bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showColorPicker(context: context);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('색상 선택'), findsOneWidget);
    });

    testWidgets('returns selected color on tap', (tester) async {
      String? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  selectedResult = await showColorPicker(context: context);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap on the first color circle
      final inkWells = find.descendant(
        of: find.byType(Wrap),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWells.first);
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(presetColors.contains(selectedResult), true);
    });

    testWidgets('shows check mark on selected color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showColorPicker(
                    context: context,
                    selectedColor: '#FF5733',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should show a check icon for the selected color
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
