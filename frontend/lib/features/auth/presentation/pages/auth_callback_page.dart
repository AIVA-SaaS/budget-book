import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';

class AuthCallbackPage extends StatefulWidget {
  final String? accessToken;
  final String? refreshToken;

  const AuthCallbackPage({
    super.key,
    this.accessToken,
    this.refreshToken,
  });

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  void _handleCallback() {
    final accessToken = widget.accessToken;
    final refreshToken = widget.refreshToken;

    if (accessToken != null && refreshToken != null) {
      context.read<AuthBloc>().add(
            AuthCallbackReceived(
              accessToken: accessToken,
              refreshToken: refreshToken,
            ),
          );
    } else {
      // Missing tokens, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/login');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthError) {
          context.go('/login');
        } else if (state is AuthUnauthenticated) {
          context.go('/login');
        }
      },
      child: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                '로그인 처리 중...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
