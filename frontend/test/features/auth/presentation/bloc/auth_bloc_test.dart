import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/auth/domain/repositories/auth_repository.dart';
import 'package:budget_book/features/auth/domain/entities/user.dart';
import 'package:budget_book/features/auth/domain/entities/auth_token.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
import 'package:budget_book/core/error/failure.dart';

// Manual mocks with proper null-safe default return values
class MockAuthRepository extends Mock implements AuthRepository {
  @override
  Future<Either<Failure, AuthToken>> refreshToken(String refreshToken) =>
      super.noSuchMethod(
        Invocation.method(#refreshToken, [refreshToken]),
        returnValue: Future.value(
          const Right<Failure, AuthToken>(AuthToken(
            accessToken: '',
            refreshToken: '',
            expiresIn: 0,
          )),
        ),
      ) as Future<Either<Failure, AuthToken>>;

  @override
  Future<Either<Failure, User>> getCurrentUser() =>
      super.noSuchMethod(
        Invocation.method(#getCurrentUser, []),
        returnValue: Future.value(
          Right<Failure, User>(User(
            id: '',
            email: '',
            nickname: '',
            provider: '',
            role: '',
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, User>>;

  @override
  Future<Either<Failure, void>> logout(String refreshToken) =>
      super.noSuchMethod(
        Invocation.method(#logout, [refreshToken]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;
}

class MockSecureStorageService extends Mock implements SecureStorageService {
  @override
  Future<String?> getAccessToken() =>
      super.noSuchMethod(
        Invocation.method(#getAccessToken, []),
        returnValue: Future.value(null),
      ) as Future<String?>;

  @override
  Future<String?> getRefreshToken() =>
      super.noSuchMethod(
        Invocation.method(#getRefreshToken, []),
        returnValue: Future.value(null),
      ) as Future<String?>;

  @override
  Future<void> saveAccessToken(String token) =>
      super.noSuchMethod(
        Invocation.method(#saveAccessToken, [token]),
        returnValue: Future.value(),
      ) as Future<void>;

  @override
  Future<void> saveRefreshToken(String token) =>
      super.noSuchMethod(
        Invocation.method(#saveRefreshToken, [token]),
        returnValue: Future.value(),
      ) as Future<void>;

  @override
  Future<void> clearTokens() =>
      super.noSuchMethod(
        Invocation.method(#clearTokens, []),
        returnValue: Future.value(),
      ) as Future<void>;
}

void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockAuthRepository;
  late MockSecureStorageService mockStorageService;

  // Test fixtures
  final tCreatedAt = DateTime.parse('2024-01-15T10:30:00.000Z');
  final tUser = User(
    id: '123e4567-e89b-12d3-a456-426614174000',
    email: 'test@example.com',
    nickname: 'TestUser',
    profileImageUrl: null,
    provider: 'GOOGLE',
    role: 'USER',
    createdAt: tCreatedAt,
  );

  const tAuthToken = AuthToken(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    expiresIn: 3600,
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockStorageService = MockSecureStorageService();
    authBloc = AuthBloc(
      authRepository: mockAuthRepository,
      storageService: mockStorageService,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, const AuthInitial());
    });

    group('AuthCheckRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthUnauthenticated] when no token is stored',
        build: () {
          when(mockStorageService.getAccessToken())
              .thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => [
          const AuthLoading(),
          const AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(mockStorageService.getAccessToken()).called(1);
          verifyNever(mockAuthRepository.getCurrentUser());
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthAuthenticated] when token exists and user fetch succeeds',
        build: () {
          when(mockStorageService.getAccessToken())
              .thenAnswer((_) async => 'stored-access-token');
          when(mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => Right(tUser));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => [
          const AuthLoading(),
          AuthAuthenticated(tUser),
        ],
        verify: (_) {
          verify(mockStorageService.getAccessToken()).called(1);
          verify(mockAuthRepository.getCurrentUser()).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthUnauthenticated] and triggers token refresh when user fetch fails',
        build: () {
          when(mockStorageService.getAccessToken())
              .thenAnswer((_) async => 'stored-access-token');
          when(mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => const Left(ServerFailure('Unauthorized')));
          // Token refresh path: no refresh token stored -> unauthenticated
          when(mockStorageService.getRefreshToken())
              .thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const AuthLoading(),
          // The bloc adds AuthTokenRefreshRequested internally,
          // which finds no refresh token and emits AuthUnauthenticated
          const AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(mockStorageService.getAccessToken()).called(1);
          verify(mockAuthRepository.getCurrentUser()).called(1);
        },
      );
    });

    group('AuthCallbackReceived', () {
      blocTest<AuthBloc, AuthState>(
        'saves tokens, fetches user, emits [AuthLoading, AuthAuthenticated]',
        build: () {
          when(mockStorageService.saveAccessToken('new-access-token'))
              .thenAnswer((_) async {});
          when(mockStorageService.saveRefreshToken('new-refresh-token'))
              .thenAnswer((_) async {});
          when(mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => Right(tUser));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthCallbackReceived(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
        )),
        expect: () => [
          const AuthLoading(),
          AuthAuthenticated(tUser),
        ],
        verify: (_) {
          verify(mockStorageService.saveAccessToken('new-access-token'))
              .called(1);
          verify(mockStorageService.saveRefreshToken('new-refresh-token'))
              .called(1);
          verify(mockAuthRepository.getCurrentUser()).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthError] when user fetch fails after callback',
        build: () {
          when(mockStorageService.saveAccessToken('new-access-token'))
              .thenAnswer((_) async {});
          when(mockStorageService.saveRefreshToken('new-refresh-token'))
              .thenAnswer((_) async {});
          when(mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async =>
                  const Left(ServerFailure('Failed to get user')));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthCallbackReceived(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
        )),
        expect: () => [
          const AuthLoading(),
          const AuthError('Failed to get user'),
        ],
        verify: (_) {
          verify(mockStorageService.saveAccessToken('new-access-token'))
              .called(1);
          verify(mockStorageService.saveRefreshToken('new-refresh-token'))
              .called(1);
          verify(mockAuthRepository.getCurrentUser()).called(1);
        },
      );
    });

    group('AuthLogoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'calls logout with refresh token, clears tokens, emits [AuthUnauthenticated]',
        build: () {
          when(mockStorageService.getRefreshToken())
              .thenAnswer((_) async => 'stored-refresh-token');
          when(mockAuthRepository.logout('stored-refresh-token'))
              .thenAnswer((_) async => const Right(null));
          when(mockStorageService.clearTokens())
              .thenAnswer((_) async {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLogoutRequested()),
        expect: () => [
          const AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(mockStorageService.getRefreshToken()).called(1);
          verify(mockAuthRepository.logout('stored-refresh-token')).called(1);
          verify(mockStorageService.clearTokens()).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'skips logout API call when no refresh token, clears tokens, emits [AuthUnauthenticated]',
        build: () {
          when(mockStorageService.getRefreshToken())
              .thenAnswer((_) async => null);
          when(mockStorageService.clearTokens())
              .thenAnswer((_) async {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLogoutRequested()),
        expect: () => [
          const AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(mockStorageService.getRefreshToken()).called(1);
          verifyNever(mockAuthRepository.logout('any-token'));
          verify(mockStorageService.clearTokens()).called(1);
        },
      );
    });

    group('AuthTokenRefreshRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthUnauthenticated] when no refresh token stored',
        build: () {
          when(mockStorageService.getRefreshToken())
              .thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthTokenRefreshRequested()),
        expect: () => [
          const AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(mockStorageService.getRefreshToken()).called(1);
          verifyNever(mockAuthRepository.refreshToken('any-token'));
        },
      );

      blocTest<AuthBloc, AuthState>(
        'refreshes token, saves new tokens, fetches user, emits [AuthAuthenticated]',
        build: () {
          when(mockStorageService.getRefreshToken())
              .thenAnswer((_) async => 'old-refresh-token');
          when(mockAuthRepository.refreshToken('old-refresh-token'))
              .thenAnswer((_) async => const Right(tAuthToken));
          when(mockStorageService.saveAccessToken(tAuthToken.accessToken))
              .thenAnswer((_) async {});
          when(mockStorageService.saveRefreshToken(tAuthToken.refreshToken))
              .thenAnswer((_) async {});
          when(mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => Right(tUser));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthTokenRefreshRequested()),
        expect: () => [
          AuthAuthenticated(tUser),
        ],
        verify: (_) {
          verify(mockStorageService.getRefreshToken()).called(1);
          verify(mockAuthRepository.refreshToken('old-refresh-token'))
              .called(1);
          verify(mockStorageService.saveAccessToken(tAuthToken.accessToken))
              .called(1);
          verify(mockStorageService.saveRefreshToken(tAuthToken.refreshToken))
              .called(1);
          verify(mockAuthRepository.getCurrentUser()).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'clears tokens and emits [AuthUnauthenticated] when refresh fails',
        build: () {
          when(mockStorageService.getRefreshToken())
              .thenAnswer((_) async => 'old-refresh-token');
          when(mockAuthRepository.refreshToken('old-refresh-token'))
              .thenAnswer((_) async =>
                  const Left(ServerFailure('Token expired')));
          when(mockStorageService.clearTokens())
              .thenAnswer((_) async {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthTokenRefreshRequested()),
        expect: () => [
          const AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(mockStorageService.getRefreshToken()).called(1);
          verify(mockAuthRepository.refreshToken('old-refresh-token'))
              .called(1);
          verify(mockStorageService.clearTokens()).called(1);
          verifyNever(mockAuthRepository.getCurrentUser());
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthError] when refresh succeeds but user fetch fails',
        build: () {
          when(mockStorageService.getRefreshToken())
              .thenAnswer((_) async => 'old-refresh-token');
          when(mockAuthRepository.refreshToken('old-refresh-token'))
              .thenAnswer((_) async => const Right(tAuthToken));
          when(mockStorageService.saveAccessToken(tAuthToken.accessToken))
              .thenAnswer((_) async {});
          when(mockStorageService.saveRefreshToken(tAuthToken.refreshToken))
              .thenAnswer((_) async {});
          when(mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async =>
                  const Left(ServerFailure('Failed to get user')));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthTokenRefreshRequested()),
        expect: () => [
          const AuthError('Failed to get user'),
        ],
        verify: (_) {
          verify(mockAuthRepository.refreshToken('old-refresh-token'))
              .called(1);
          verify(mockAuthRepository.getCurrentUser()).called(1);
        },
      );
    });
  });
}
