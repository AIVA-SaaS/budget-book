import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';
import 'package:budget_book/features/home/presentation/widgets/widget_settings_sheet.dart';

void main() {
  group('WidgetSettingsSheet', () {
    testWidgets('shows widget name in title', (tester) async {
      Map<String, dynamic>? savedSettings;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showWidgetSettingsSheet(
                  context: context,
                  config: const DashboardWidgetConfig(
                    id: 'monthly_trend',
                    name: '월별 추이',
                    icon: 'show_chart',
                    order: 8,
                  ),
                  onSave: (s) => savedSettings = s,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('월별 추이 설정'), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
      expect(savedSettings, isNull); // Not saved yet
    });

    testWidgets('shows controls for monthly_trend widget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showWidgetSettingsSheet(
                  context: context,
                  config: const DashboardWidgetConfig(
                    id: 'monthly_trend',
                    name: '월별 추이',
                    icon: 'show_chart',
                    order: 8,
                  ),
                  onSave: (_) {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should show period dropdown and checkbox items
      expect(find.text('기간'), findsOneWidget);
      expect(find.text('표시 항목'), findsOneWidget);
      expect(find.text('수입'), findsOneWidget);
      expect(find.text('지출'), findsOneWidget);
      expect(find.text('잔액'), findsOneWidget);
    });

    testWidgets('shows controls for category_breakdown widget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showWidgetSettingsSheet(
                  context: context,
                  config: const DashboardWidgetConfig(
                    id: 'category_breakdown',
                    name: '카테고리별 현황',
                    icon: 'donut_large',
                    order: 9,
                  ),
                  onSave: (_) {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('표시 유형'), findsOneWidget);
      expect(find.text('표시 개수'), findsOneWidget);
    });

    testWidgets('shows controls for recent_transactions widget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showWidgetSettingsSheet(
                  context: context,
                  config: const DashboardWidgetConfig(
                    id: 'recent_transactions',
                    name: '최근 거래',
                    icon: 'receipt_long',
                    order: 2,
                  ),
                  onSave: (_) {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('표시 건수'), findsOneWidget);
    });

    testWidgets('save button triggers onSave callback', (tester) async {
      Map<String, dynamic>? savedSettings;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showWidgetSettingsSheet(
                  context: context,
                  config: const DashboardWidgetConfig(
                    id: 'recent_transactions',
                    name: '최근 거래',
                    icon: 'receipt_long',
                    order: 2,
                  ),
                  onSave: (s) => savedSettings = s,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(savedSettings, isNotNull);
      expect(savedSettings!['count'], 5); // default value
    });

    testWidgets('close button dismisses sheet', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showWidgetSettingsSheet(
                  context: context,
                  config: const DashboardWidgetConfig(
                    id: 'recent_transactions',
                    name: '최근 거래',
                    icon: 'receipt_long',
                    order: 2,
                  ),
                  onSave: (_) {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('최근 거래 설정'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('최근 거래 설정'), findsNothing);
    });

    testWidgets('shows no-settings message for unknown widget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showWidgetSettingsSheet(
                  context: context,
                  config: const DashboardWidgetConfig(
                    id: 'unknown_widget',
                    name: '알 수 없는 위젯',
                    icon: 'star',
                    order: 99,
                  ),
                  onSave: (_) {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('설정 가능한 항목이 없습니다.'), findsOneWidget);
    });
  });
}
