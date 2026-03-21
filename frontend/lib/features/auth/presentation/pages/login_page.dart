import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:budget_book/core/utils/web_navigation_stub.dart'
    if (dart.library.js_interop) 'package:budget_book/core/utils/web_navigation_web.dart'
    as web_nav;
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/presentation/widgets/social_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isWakingServer = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, authState) {
      // Show loading splash while checking existing auth token
      if (authState is AuthInitial || authState is AuthLoading) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Budget Book',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      }

      return Scaffold(
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
                    // Server wake-up status
                    if (_isWakingServer) ...[
                      _buildWakeUpIndicator(),
                      const SizedBox(height: 24),
                    ],
                    // Google login button
                    SocialLoginButton(
                      providerName: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      backgroundColor: Colors.white,
                      textColor: Colors.black87,
                      iconColor: Colors.red,
                      onPressed: _isWakingServer
                          ? () {}
                          : () => _wakeAndLaunchOAuth(
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
                      onPressed: _isWakingServer
                          ? () {}
                          : () => _wakeAndLaunchOAuth(
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
      );
      },
    );
  }

  Widget _buildWakeUpIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _wakeAndLaunchOAuth(String oauthUrl) async {
    setState(() {
      _isWakingServer = true;
      _statusMessage = '서버 연결 중...';
    });

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));

    try {
      // Quick health check first
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}/actuator/health',
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _isWakingServer = false);
          _launchOAuth(oauthUrl);
        }
        return;
      }
    } on DioException {
      // Server is likely sleeping - start wake-up polling
    }

    if (!mounted) return;
    setState(() => _statusMessage = '서버를 깨우고 있습니다...');

    // Poll with retries (max 90 seconds)
    for (int i = 0; i < 18; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      if (i >= 6) {
        setState(() => _statusMessage = '거의 다 됐습니다... 잠시만 기다려주세요');
      }

      try {
        final response = await dio.get(
          '${ApiEndpoints.baseUrl}/actuator/health',
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            setState(() => _isWakingServer = false);
            _launchOAuth(oauthUrl);
          }
          return;
        }
      } on DioException {
        // Still waking up, continue polling
      }
    }

    // Timeout - let user try anyway
    if (mounted) {
      setState(() => _isWakingServer = false);
      _launchOAuth(oauthUrl);
    }
  }

  void _launchOAuth(String url) {
    if (kIsWeb) {
      web_nav.setWindowLocation(url);
    } else {
      final uri = Uri.parse(url);
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
