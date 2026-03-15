import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/statistics/domain/entities/payment_method_statistics.dart';
import 'package:budget_book/features/statistics/presentation/widgets/payment_method_stats_tab.dart';

void main() {
  Widget createTestWidget({
    List<PaymentMethodStatistics> stats = const [],
    bool isLoading = false,
    String? error,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PaymentMethodStatsTab(
          stats: stats,
          isLoading: isLoading,
          error: error,
        ),
      ),
    );
  }

  group('PaymentMethodStatsTab', () {
    testWidgets('shows loading indicator when loading', (tester) async {
      await tester.pumpWidget(createTestWidget(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when error occurs', (tester) async {
      await tester.pumpWidget(
        createTestWidget(error: '결제수단별 통계를 불러오지 못했습니다'),
      );
      expect(find.text('결제수단별 통계를 불러오지 못했습니다'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows empty state when no stats', (tester) async {
      await tester.pumpWidget(createTestWidget(stats: const []));
      expect(find.text('결제수단별 통계가 없습니다'), findsOneWidget);
    });

    testWidgets('shows payment method list with amounts', (tester) async {
      const stats = [
        PaymentMethodStatistics(
          paymentMethodId: 'pm-1',
          paymentMethodName: '신한카드',
          paymentMethodType: 'CREDIT_CARD',
          totalAmount: 1500000,
          transactionCount: 20,
          percentage: 65.2,
        ),
        PaymentMethodStatistics(
          paymentMethodId: 'pm-2',
          paymentMethodName: '현금',
          paymentMethodType: 'CASH',
          totalAmount: 800000,
          transactionCount: 15,
          percentage: 34.8,
        ),
      ];

      await tester.pumpWidget(createTestWidget(stats: stats));

      expect(find.text('신한카드'), findsOneWidget);
      expect(find.text('현금'), findsOneWidget);
      expect(find.text('20건'), findsOneWidget);
      expect(find.text('15건'), findsOneWidget);
      expect(find.text('1,500,000원'), findsOneWidget);
      expect(find.text('800,000원'), findsOneWidget);
      expect(find.text('65.2%'), findsOneWidget);
      expect(find.text('34.8%'), findsOneWidget);
    });
  });
}
