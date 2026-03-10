import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/presentation/pages/login_page.dart';
import 'package:budget_book/features/auth/domain/entities/user.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());
  });

  Widget buildTestWidget() {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginPage(),
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

  group('LoginPage', () {
    testWidgets('renders app title', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Budget Book'), findsOneWidget);
    });

    testWidgets('renders subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('부부 공유 가계부'), findsOneWidget);
    });

    testWidgets('renders wallet icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
          find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    });

    testWidgets('renders Google login button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Google(으)로 로그인'), findsOneWidget);
    });

    testWidgets('renders Kakao login button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('카카오(으)로 로그인'), findsOneWidget);
    });

    testWidgets('renders footer text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('소셜 계정으로 간편하게 시작하세요'), findsOneWidget);
    });

    testWidgets('shows snackbar on AuthError state', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthError('로그인에 실패했습니다'),
        ]),
        initialState: const AuthUnauthenticated(),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('로그인에 실패했습니다'), findsOneWidget);
    });

    testWidgets('navigates to /home on AuthAuthenticated state',
        (tester) async {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        nickname: 'TestUser',
        provider: 'GOOGLE',
        role: 'USER',
        coupleId: 'couple-id',
        createdAt: DateTime(2024),
      );

      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([AuthAuthenticated(user)]),
        initialState: const AuthUnauthenticated(),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}
