import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/domain/entities/user.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  final userWithCouple = User(
    id: 'test-id',
    email: 'test@example.com',
    nickname: 'TestUser',
    provider: 'GOOGLE',
    role: 'USER',
    coupleId: 'couple-123',
    createdAt: DateTime(2024),
  );

  final userWithoutCouple = User(
    id: 'test-id',
    email: 'test@example.com',
    nickname: 'TestUser',
    provider: 'GOOGLE',
    role: 'USER',
    coupleId: null,
    createdAt: DateTime(2024),
  );

  setUp(() {
    mockAuthBloc = MockAuthBloc();
  });

  final adminUser = User(
    id: 'admin-id',
    email: 'admin@example.com',
    nickname: 'Admin',
    provider: 'GOOGLE',
    role: 'ADMIN',
    coupleId: 'couple-123',
    createdAt: DateTime(2024),
  );

  // Build a test app with the same redirect logic as app_router.dart
  // but with simple page builders that don't require DI (getIt).
  Widget buildTestApp({String initialLocation = '/login'}) {
    final router = GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) {
        final authState = context.read<AuthBloc>().state;
        final isAuthenticated = authState is AuthAuthenticated;
        final isOnLoginPage = state.matchedLocation == '/login';
        final isOnCallbackPage = state.matchedLocation == '/auth/callback';
        final isOnCouplePage = state.matchedLocation == '/couple';
        final isOnAdminPage = state.matchedLocation.startsWith('/admin');

        if (isOnCallbackPage) return null;

        if (authState is AuthAuthenticated && isOnLoginPage) {
          return authState.user.coupleId != null ? '/home' : '/couple';
        }

        if (authState is AuthAuthenticated) {
          // Admin guard
          if (isOnAdminPage && authState.user.role != 'ADMIN') {
            return '/home';
          }
          if (authState.user.coupleId == null &&
              !isOnCouplePage &&
              !isOnAdminPage) {
            return '/couple';
          }
          return null;
        }

        if (!isAuthenticated && !isOnLoginPage) {
          if (authState is AuthInitial || authState is AuthLoading) return null;
          return '/login';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: '/auth/callback',
          builder: (_, __) => const Scaffold(body: Text('Callback')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/couple',
          builder: (_, __) => const Scaffold(body: Text('Couple')),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, __) => const Scaffold(body: Text('Admin')),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (_, __) => const Scaffold(body: Text('Admin Users')),
        ),
        GoRoute(
          path: '/admin/announcements',
          builder: (_, __) =>
              const Scaffold(body: Text('Admin Announcements')),
        ),
      ],
    );

    return BlocProvider<AuthBloc>.value(
      value: mockAuthBloc,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('AppRouter redirect', () {
    testWidgets(
        'redirects authenticated user with coupleId from /login to /home',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(userWithCouple));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets(
        'redirects authenticated user without coupleId from /login to /couple',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(userWithoutCouple));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Couple'), findsOneWidget);
    });

    testWidgets(
        'redirects authenticated user without coupleId from /home to /couple',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(userWithoutCouple));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/home'));
      await tester.pumpAndSettle();

      expect(find.text('Couple'), findsOneWidget);
    });

    testWidgets('allows authenticated user without coupleId on /couple',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(userWithoutCouple));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/couple'));
      await tester.pumpAndSettle();

      expect(find.text('Couple'), findsOneWidget);
    });

    testWidgets('allows authenticated user with coupleId on /home',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(userWithCouple));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/home'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('redirects unauthenticated user to /login',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(const AuthUnauthenticated());
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/home'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('allows callback page regardless of auth state',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(const AuthUnauthenticated());
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/auth/callback'));
      await tester.pumpAndSettle();

      expect(find.text('Callback'), findsOneWidget);
    });

    testWidgets('allows initial auth state to stay without redirect',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(const AuthInitial());
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/home'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('redirects non-admin user from /admin to /home',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(userWithCouple));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/admin'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('redirects non-admin user from /admin/users to /home',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(userWithCouple));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/admin/users'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('allows admin user to access /admin', (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(adminUser));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/admin'));
      await tester.pumpAndSettle();

      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('allows admin user to access /admin/users', (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(adminUser));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester
          .pumpWidget(buildTestApp(initialLocation: '/admin/users'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Users'), findsOneWidget);
    });

    testWidgets('allows admin user to access /admin/announcements',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(AuthAuthenticated(adminUser));
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
          buildTestApp(initialLocation: '/admin/announcements'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Announcements'), findsOneWidget);
    });

    testWidgets('redirects unauthenticated user from /admin to /login',
        (tester) async {
      when(() => mockAuthBloc.state)
          .thenReturn(const AuthUnauthenticated());
      when(() => mockAuthBloc.stream)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestApp(initialLocation: '/admin'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });
  });
}
