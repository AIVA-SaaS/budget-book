import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/presentation/pages/auth_callback_page.dart';
import 'package:budget_book/features/auth/domain/entities/user.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(const AuthCheckRequested());
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
  });

  Widget buildTestWidget({String? accessToken, String? refreshToken}) {
    final router = GoRouter(
      initialLocation: '/auth/callback',
      routes: [
        GoRoute(
          path: '/auth/callback',
          builder: (_, __) => AuthCallbackPage(
            accessToken: accessToken,
            refreshToken: refreshToken,
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    return BlocProvider<AuthBloc>.value(
      value: mockAuthBloc,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('AuthCallbackPage', () {
    testWidgets('shows loading indicator and processing text', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('로그인 처리 중...'), findsOneWidget);
    });

    testWidgets('dispatches AuthCallbackReceived when tokens are provided',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
      ));

      verify(() => mockAuthBloc.add(
            const AuthCallbackReceived(
              accessToken: 'test-access-token',
              refreshToken: 'test-refresh-token',
            ),
          )).called(1);
    });

    testWidgets('redirects to /login when tokens are missing',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('redirects to /login when only accessToken is missing',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(refreshToken: 'test-refresh'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('redirects to /login when only refreshToken is missing',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(accessToken: 'test-access'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('navigates to /home on AuthAuthenticated', (tester) async {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        nickname: 'Test',
        provider: 'GOOGLE',
        role: 'USER',
        createdAt: DateTime(2024),
      );

      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([AuthAuthenticated(user)]),
        initialState: const AuthLoading(),
      );

      await tester.pumpWidget(buildTestWidget(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('navigates to /login on AuthError', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthError('Login failed'),
        ]),
        initialState: const AuthLoading(),
      );

      await tester.pumpWidget(buildTestWidget(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets(
        'ignores AuthUnauthenticated when callback tokens are provided',
        (tester) async {
      // When tokens are provided, AuthUnauthenticated from AuthCheckRequested
      // should NOT redirect — the callback is still being processed.
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthUnauthenticated(),
        ]),
        initialState: const AuthLoading(),
      );

      await tester.pumpWidget(buildTestWidget(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
      ));
      // Use pump() instead of pumpAndSettle() because the page stays
      // on the callback screen with a CircularProgressIndicator that
      // never settles.
      await tester.pump();
      await tester.pump();

      // Should stay on callback page, not redirect to login
      expect(find.text('로그인 처리 중...'), findsOneWidget);
    });

    testWidgets(
        'navigates to /login on AuthUnauthenticated when no tokens provided',
        (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthUnauthenticated(),
        ]),
        initialState: const AuthLoading(),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });
  });
}
