import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/auth/presentation/widgets/social_login_button.dart';

void main() {
  group('SocialLoginButton', () {
    testWidgets('renders provider name with Korean suffix', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButton(
              providerName: 'Google',
              icon: Icons.g_mobiledata_rounded,
              backgroundColor: Colors.white,
              textColor: Colors.black87,
              iconColor: Colors.red,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Google(으)로 로그인'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButton(
              providerName: 'Google',
              icon: Icons.g_mobiledata_rounded,
              backgroundColor: Colors.white,
              textColor: Colors.black87,
              iconColor: Colors.red,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.g_mobiledata_rounded), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButton(
              providerName: 'Google',
              icon: Icons.g_mobiledata_rounded,
              backgroundColor: Colors.white,
              textColor: Colors.black87,
              iconColor: Colors.red,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });

    testWidgets('has correct dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButton(
              providerName: 'Google',
              icon: Icons.g_mobiledata_rounded,
              backgroundColor: Colors.white,
              textColor: Colors.black87,
              iconColor: Colors.red,
              onPressed: () {},
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 52);
      expect(sizedBox.width, double.infinity);
    });

    testWidgets('renders Korean provider name correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButton(
              providerName: '카카오',
              icon: Icons.chat_bubble_rounded,
              backgroundColor: const Color(0xFFFEE500),
              textColor: const Color(0xFF3C1E1E),
              iconColor: const Color(0xFF3C1E1E),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('카카오(으)로 로그인'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
    });
  });
}
