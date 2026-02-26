import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/presentation/widgets/social_login_button.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // App icon
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    // App title
                    Text(
                      'Budget Book',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      '부부 공유 가계부',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: 60),
                    // Google login button
                    SocialLoginButton(
                      providerName: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      backgroundColor: Colors.white,
                      textColor: Colors.black87,
                      iconColor: Colors.red,
                      onPressed: () => _launchOAuth(
                        '${ApiEndpoints.baseUrl}${ApiEndpoints.authGoogle}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Kakao login button
                    SocialLoginButton(
                      providerName: '카카오',
                      icon: Icons.chat_bubble_rounded,
                      backgroundColor: const Color(0xFFFEE500),
                      textColor: const Color(0xFF3C1E1E),
                      iconColor: const Color(0xFF3C1E1E),
                      onPressed: () => _launchOAuth(
                        '${ApiEndpoints.baseUrl}${ApiEndpoints.authKakao}',
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Footer text
                    Text(
                      '소셜 계정으로 간편하게 시작하세요',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchOAuth(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
