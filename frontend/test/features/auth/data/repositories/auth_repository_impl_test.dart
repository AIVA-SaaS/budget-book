import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:budget_book/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:budget_book/features/auth/data/models/user_model.dart';
import 'package:budget_book/features/auth/data/models/auth_token_model.dart';
import 'package:budget_book/features/auth/domain/entities/user.dart';
import 'package:budget_book/features/auth/domain/entities/auth_token.dart';
import 'package:budget_book/core/error/failure.dart';

// Manual mock with proper null-safe default return values
class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {
  @override
  Future<AuthTokenModel> refreshToken(String refreshToken) =>
      super.noSuchMethod(
        Invocation.method(#refreshToken, [refreshToken]),
        returnValue: Future.value(const AuthTokenModel(
          accessToken: '',
          refreshToken: '',
          expiresIn: 0,
        )),
      ) as Future<AuthTokenModel>;

  @override
  Future<UserModel> getCurrentUser() =>
      super.noSuchMethod(
        Invocation.method(#getCurrentUser, []),
        returnValue: Future.value(UserModel(
          id: '',
          email: '',
          nickname: '',
          provider: '',
          role: '',
          createdAt: DateTime(2024),
        )),
      ) as Future<UserModel>;

  @override
  Future<void> logout(String refreshToken) =>
      super.noSuchMethod(
        Invocation.method(#logout, [refreshToken]),
        returnValue: Future.value(),
      ) as Future<void>;
}

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockRemoteDataSource;

  // Test fixtures
  final tCreatedAt = DateTime.parse('2024-01-15T10:30:00.000Z');
  final tUserModel = UserModel(
    id: '123e4567-e89b-12d3-a456-426614174000',
    email: 'test@example.com',
    nickname: 'TestUser',
    profileImageUrl: null,
    provider: 'GOOGLE',
    role: 'USER',
    createdAt: tCreatedAt,
  );
  final User tUser = tUserModel;

  const tAuthTokenModel = AuthTokenModel(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    expiresIn: 3600,
  );
  const AuthToken tAuthToken = tAuthTokenModel;

  const tRefreshToken = 'current-refresh-token';

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(remoteDataSource: mockRemoteDataSource);
  });

  group('AuthRepositoryImpl', () {
    group('refreshToken', () {
      test('returns Right(AuthToken) when datasource succeeds', () async {
        // arrange
        when(mockRemoteDataSource.refreshToken(tRefreshToken))
            .thenAnswer((_) async => tAuthTokenModel);

        // act
        final result = await repository.refreshToken(tRefreshToken);

        // assert
        expect(result, equals(const Right<Failure, AuthToken>(tAuthToken)));
        verify(mockRemoteDataSource.refreshToken(tRefreshToken)).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });

      test('returns Left(ServerFailure) with API error message when datasource throws DioException', () async {
        // arrange
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
            statusCode: 401,
            data: {
              'error': {'message': 'Token expired'},
            },
          ),
        );
        when(mockRemoteDataSource.refreshToken(tRefreshToken))
            .thenAnswer((_) async => throw dioException);

        // act
        final result = await repository.refreshToken(tRefreshToken);

        // assert
        expect(result, equals(const Left<Failure, AuthToken>(ServerFailure('Token expired'))));
        verify(mockRemoteDataSource.refreshToken(tRefreshToken)).called(1);
      });

      test('returns Left(ServerFailure) with default message when DioException has no error message', () async {
        // arrange
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
            statusCode: 500,
            data: null,
          ),
        );
        when(mockRemoteDataSource.refreshToken(tRefreshToken))
            .thenAnswer((_) async => throw dioException);

        // act
        final result = await repository.refreshToken(tRefreshToken);

        // assert
        expect(result, equals(const Left<Failure, AuthToken>(ServerFailure('Token refresh failed'))));
      });
    });

    group('getCurrentUser', () {
      test('returns Right(User) when datasource succeeds', () async {
        // arrange
        when(mockRemoteDataSource.getCurrentUser())
            .thenAnswer((_) async => tUserModel);

        // act
        final result = await repository.getCurrentUser();

        // assert
        expect(result, equals(Right<Failure, User>(tUser)));
        verify(mockRemoteDataSource.getCurrentUser()).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });

      test('returns Left(ServerFailure) with API error message when datasource throws DioException', () async {
        // arrange
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/me'),
            statusCode: 401,
            data: {
              'error': {'message': 'Invalid token'},
            },
          ),
        );
        when(mockRemoteDataSource.getCurrentUser())
            .thenAnswer((_) async => throw dioException);

        // act
        final result = await repository.getCurrentUser();

        // assert
        expect(result, equals(const Left<Failure, User>(ServerFailure('Invalid token'))));
        verify(mockRemoteDataSource.getCurrentUser()).called(1);
      });

      test('returns Left(ServerFailure) with default message when DioException has no error message', () async {
        // arrange
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/me'),
            statusCode: 500,
            data: null,
          ),
        );
        when(mockRemoteDataSource.getCurrentUser())
            .thenAnswer((_) async => throw dioException);

        // act
        final result = await repository.getCurrentUser();

        // assert
        expect(result, equals(const Left<Failure, User>(ServerFailure('Failed to get user'))));
      });
    });

    group('logout', () {
      test('returns Right(null) when datasource succeeds', () async {
        // arrange
        when(mockRemoteDataSource.logout(tRefreshToken))
            .thenAnswer((_) async {});

        // act
        final result = await repository.logout(tRefreshToken);

        // assert
        expect(result, equals(const Right<Failure, void>(null)));
        verify(mockRemoteDataSource.logout(tRefreshToken)).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });

      test('returns Left(ServerFailure) with API error message when datasource throws DioException', () async {
        // arrange
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/logout'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/logout'),
            statusCode: 500,
            data: {
              'error': {'message': 'Logout failed on server'},
            },
          ),
        );
        when(mockRemoteDataSource.logout(tRefreshToken))
            .thenAnswer((_) async => throw dioException);

        // act
        final result = await repository.logout(tRefreshToken);

        // assert
        expect(result, equals(const Left<Failure, void>(ServerFailure('Logout failed on server'))));
        verify(mockRemoteDataSource.logout(tRefreshToken)).called(1);
      });

      test('returns Left(ServerFailure) with default message when DioException has no error message', () async {
        // arrange
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/logout'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/logout'),
            statusCode: 500,
            data: null,
          ),
        );
        when(mockRemoteDataSource.logout(tRefreshToken))
            .thenAnswer((_) async => throw dioException);

        // act
        final result = await repository.logout(tRefreshToken);

        // assert
        expect(result, equals(const Left<Failure, void>(ServerFailure('Logout failed'))));
      });
    });
  });
}
