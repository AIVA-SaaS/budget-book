import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import '../../../../core/theme/bb_scale.dart';

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
  bool _callbackDispatched = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  void _handleCallback() {
    final accessToken = widget.accessToken;
    final refreshToken = widget.refreshToken;

    if (accessToken != null && refreshToken != null) {
      _callbackDispatched = true;
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
        } else if (state is AuthUnauthenticated && !_callbackDispatched) {
          // Only redirect to login if we didn't dispatch a callback.
          // AuthCheckRequested may emit AuthUnauthenticated before
          // AuthCallbackReceived is processed — ignore that.
          context.go('/login');
        }
      },
      // ★`gapV` 는 토큰을 읽으므로 const 트리에서 나와야 한다.
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                context.bbSpace.gapV(BbSpaceToken.block),
                Text(
                  '로그인 처리 중...',
                  style: TextStyle(fontSize: context.bbType.title),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
