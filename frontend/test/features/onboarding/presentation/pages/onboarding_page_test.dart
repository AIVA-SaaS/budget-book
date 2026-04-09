import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:budget_book/core/router/app_router.dart' show kOnboardingCompleted;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingPage', () {
    testWidgets('renders step 1 - welcome', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingPage(),
        ),
      );

      expect(find.text('환영합니다'), findsOneWidget);
      expect(
        find.text('Budget Book으로 똑똑하게 가계부를 관리하세요'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
    });

    testWidgets('shows 3 dot indicators', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingPage(),
        ),
      );

      // 3 dot indicators rendered as AnimatedContainer
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('can swipe to step 2 - couple', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingPage(),
        ),
      );

      // Swipe left to go to step 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('파트너와 함께'), findsOneWidget);
      expect(
        find.text('파트너와 연결하면 수입/지출을 공유하고\n함께 예산을 관리할 수 있어요'),
        findsOneWidget,
      );
      expect(find.text('파트너 연결하기'), findsOneWidget);
      expect(find.text('혼자 사용할게요'), findsOneWidget);
    });

    testWidgets('나중에 button advances to next page', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingPage(),
        ),
      );

      // Go to step 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Tap 혼자 사용할게요
      await tester.tap(find.text('혼자 사용할게요'));
      await tester.pumpAndSettle();

      // Should be on step 3
      expect(find.text('준비 완료!'), findsOneWidget);
      expect(find.text('시작하기'), findsOneWidget);
    });

    testWidgets('can swipe to step 3 - start', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingPage(),
        ),
      );

      // Swipe through to step 3
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('준비 완료!'), findsOneWidget);
      expect(find.text('첫 거래를 기록해보세요'), findsOneWidget);
      expect(find.text('시작하기'), findsOneWidget);
    });

    testWidgets('시작하기 saves completion flag', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const OnboardingPage(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      // Navigate to step 3
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Tap 시작하기
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      // Verify the flag was saved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kOnboardingCompleted), isTrue);
    });
  });
}
