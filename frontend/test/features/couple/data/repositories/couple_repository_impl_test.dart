import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/features/couple/data/repositories/couple_repository_impl.dart';
import 'package:budget_book/features/couple/data/datasources/couple_remote_datasource.dart';
import 'package:budget_book/features/couple/data/models/couple_model.dart';
import 'package:budget_book/features/couple/data/models/invitation_model.dart';
import 'package:budget_book/features/couple/data/models/invitation_status_model.dart';
import 'package:budget_book/features/couple/data/models/user_summary_model.dart';
import 'package:budget_book/features/couple/domain/entities/couple.dart';
import 'package:budget_book/features/couple/domain/entities/invitation.dart';
import 'package:budget_book/core/error/failure.dart';

class MockCoupleRemoteDataSource extends Mock
    implements CoupleRemoteDataSource {
  @override
  Future<CoupleModel> getMyCouple() => super.noSuchMethod(
        Invocation.method(#getMyCouple, []),
        returnValue: Future.value(CoupleModel(
          id: '',
          partner: const UserSummaryModel(id: '', nickname: ''),
          status: 'ACTIVE',
          createdAt: DateTime(2024),
        )),
      ) as Future<CoupleModel>;

  @override
  Future<InvitationModel> createInvitation() => super.noSuchMethod(
        Invocation.method(#createInvitation, []),
        returnValue: Future.value(InvitationModel(
          code: '',
          expiresAt: DateTime(2024),
        )),
      ) as Future<InvitationModel>;

  @override
  Future<CoupleModel> acceptInvitation(String code) => super.noSuchMethod(
        Invocation.method(#acceptInvitation, [code]),
        returnValue: Future.value(CoupleModel(
          id: '',
          partner: const UserSummaryModel(id: '', nickname: ''),
          status: 'ACTIVE',
          createdAt: DateTime(2024),
        )),
      ) as Future<CoupleModel>;

  @override
  Future<void> dissolveCouple() => super.noSuchMethod(
        Invocation.method(#dissolveCouple, []),
        returnValue: Future.value(),
      ) as Future<void>;

  @override
  Future<InvitationStatusModel> getMyInvitation() => super.noSuchMethod(
        Invocation.method(#getMyInvitation, []),
        returnValue: Future.value(InvitationStatusModel(
          code: '',
          expiresAt: DateTime(2024),
          status: 'PENDING',
        )),
      ) as Future<InvitationStatusModel>;
}

void main() {
  late CoupleRepositoryImpl repository;
  late MockCoupleRemoteDataSource mockDataSource;

  final tCoupleModel = CoupleModel(
    id: 'couple-id',
    partner: const UserSummaryModel(
      id: 'partner-id',
      nickname: '홍길동',
      profileImageUrl: 'https://example.com/photo.jpg',
    ),
    status: 'ACTIVE',
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tInvitationModel = InvitationModel(
    code: 'A3F9K2BX',
    expiresAt: DateTime.parse('2024-01-02T12:00:00Z'),
  );

  setUp(() {
    mockDataSource = MockCoupleRemoteDataSource();
    repository = CoupleRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('CoupleRepositoryImpl', () {
    group('getMyCouple', () {
      test('returns Right(Couple) when datasource succeeds', () async {
        when(mockDataSource.getMyCouple())
            .thenAnswer((_) async => tCoupleModel);

        final result = await repository.getMyCouple();

        expect(result, equals(Right<Failure, Couple>(tCoupleModel)));
        verify(mockDataSource.getMyCouple()).called(1);
      });

      test('returns Left(ServerFailure) on DioException', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/couples/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/couples/me'),
            statusCode: 404,
            data: {
              'error': {
                'message': 'User is not currently in a couple.'
              },
            },
          ),
        );
        when(mockDataSource.getMyCouple())
            .thenAnswer((_) async => throw dioException);

        final result = await repository.getMyCouple();

        expect(
          result,
          equals(const Left<Failure, Couple>(
              ServerFailure('User is not currently in a couple.', null, 404))),
        );
      });
    });

    group('createInvitation', () {
      test('returns Right(Invitation) when datasource succeeds', () async {
        when(mockDataSource.createInvitation())
            .thenAnswer((_) async => tInvitationModel);

        final result = await repository.createInvitation();

        expect(
            result, equals(Right<Failure, Invitation>(tInvitationModel)));
        verify(mockDataSource.createInvitation()).called(1);
      });

      test('returns Left(ServerFailure) on DioException', () async {
        final dioException = DioException(
          requestOptions:
              RequestOptions(path: '/api/v1/couples/invitations'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/api/v1/couples/invitations'),
            statusCode: 409,
            data: {
              'error': {
                'message': 'User is already in an active couple.'
              },
            },
          ),
        );
        when(mockDataSource.createInvitation())
            .thenAnswer((_) async => throw dioException);

        final result = await repository.createInvitation();

        expect(
          result,
          equals(const Left<Failure, Invitation>(
              ServerFailure('User is already in an active couple.', null, 409))),
        );
      });
    });

    group('acceptInvitation', () {
      test('returns Right(Couple) when datasource succeeds', () async {
        when(mockDataSource.acceptInvitation('A3F9K2BX'))
            .thenAnswer((_) async => tCoupleModel);

        final result = await repository.acceptInvitation('A3F9K2BX');

        expect(result, equals(Right<Failure, Couple>(tCoupleModel)));
        verify(mockDataSource.acceptInvitation('A3F9K2BX')).called(1);
      });

      test('returns Left(ServerFailure) on expired invitation', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(
              path: '/api/v1/couples/invitations/EXPIRED1/accept'),
          response: Response(
            requestOptions: RequestOptions(
                path: '/api/v1/couples/invitations/EXPIRED1/accept'),
            statusCode: 410,
            data: {
              'error': {'message': 'Invitation code has expired'},
            },
          ),
        );
        when(mockDataSource.acceptInvitation('EXPIRED1'))
            .thenAnswer((_) async => throw dioException);

        final result = await repository.acceptInvitation('EXPIRED1');

        expect(
          result,
          equals(const Left<Failure, Couple>(
              ServerFailure('Invitation code has expired', null, 410))),
        );
      });
    });

    group('getMyInvitation', () {
      final tInvitationStatusModel = InvitationStatusModel(
        code: 'A3F9K2BX',
        expiresAt: DateTime.parse('2024-01-02T12:00:00Z'),
        status: 'PENDING',
      );

      test('returns Right(Invitation) when datasource succeeds', () async {
        when(mockDataSource.getMyInvitation())
            .thenAnswer((_) async => tInvitationStatusModel);

        final result = await repository.getMyInvitation();

        expect(
            result, equals(Right<Failure, Invitation>(tInvitationStatusModel)));
        verify(mockDataSource.getMyInvitation()).called(1);
      });

      test('returns Left(ServerFailure) on DioException 404', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(
              path: '/api/v1/couples/invitations/me'),
          response: Response(
            requestOptions: RequestOptions(
                path: '/api/v1/couples/invitations/me'),
            statusCode: 404,
            data: {
              'error': {
                'message': 'No invitation found',
              },
            },
          ),
        );
        when(mockDataSource.getMyInvitation())
            .thenAnswer((_) async => throw dioException);

        final result = await repository.getMyInvitation();

        expect(
          result,
          equals(const Left<Failure, Invitation>(
              ServerFailure('No invitation found', null, 404))),
        );
      });
    });

    group('dissolveCouple', () {
      test('returns Right(null) when datasource succeeds', () async {
        when(mockDataSource.dissolveCouple()).thenAnswer((_) async {});

        final result = await repository.dissolveCouple();

        expect(result, equals(const Right<Failure, void>(null)));
        verify(mockDataSource.dissolveCouple()).called(1);
      });

      test('returns Left(ServerFailure) on DioException', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/api/v1/couples/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/couples/me'),
            statusCode: 404,
            data: null,
          ),
        );
        when(mockDataSource.dissolveCouple())
            .thenAnswer((_) async => throw dioException);

        final result = await repository.dissolveCouple();

        expect(
          result,
          equals(const Left<Failure, void>(
              ServerFailure('Failed to dissolve couple', null, 404))),
        );
      });
    });
  });
}
