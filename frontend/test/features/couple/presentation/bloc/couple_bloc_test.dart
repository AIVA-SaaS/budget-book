import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';
import 'package:budget_book/features/couple/domain/repositories/couple_repository.dart';
import 'package:budget_book/features/couple/domain/entities/couple.dart';
import 'package:budget_book/features/couple/domain/entities/invitation.dart';
import 'package:budget_book/features/couple/domain/entities/user_summary.dart';
import 'package:budget_book/core/error/failure.dart';

class MockCoupleRepository extends Mock implements CoupleRepository {
  @override
  Future<Either<Failure, Couple>> getMyCouple() =>
      super.noSuchMethod(
        Invocation.method(#getMyCouple, []),
        returnValue: Future.value(
          Right<Failure, Couple>(Couple(
            id: '',
            partner: const UserSummary(id: '', nickname: ''),
            status: 'ACTIVE',
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, Couple>>;

  @override
  Future<Either<Failure, Invitation>> createInvitation() =>
      super.noSuchMethod(
        Invocation.method(#createInvitation, []),
        returnValue: Future.value(
          Right<Failure, Invitation>(Invitation(
            code: '',
            expiresAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, Invitation>>;

  @override
  Future<Either<Failure, Couple>> acceptInvitation(String code) =>
      super.noSuchMethod(
        Invocation.method(#acceptInvitation, [code]),
        returnValue: Future.value(
          Right<Failure, Couple>(Couple(
            id: '',
            partner: const UserSummary(id: '', nickname: ''),
            status: 'ACTIVE',
            createdAt: DateTime(2024),
          )),
        ),
      ) as Future<Either<Failure, Couple>>;

  @override
  Future<Either<Failure, void>> dissolveCouple() =>
      super.noSuchMethod(
        Invocation.method(#dissolveCouple, []),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;
}

void main() {
  late CoupleBloc coupleBloc;
  late MockCoupleRepository mockRepository;

  const tPartner = UserSummary(
    id: 'partner-id',
    nickname: '홍길동',
    profileImageUrl: 'https://example.com/photo.jpg',
  );

  final tCouple = Couple(
    id: 'couple-id',
    partner: tPartner,
    status: 'ACTIVE',
    createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
  );

  final tInvitation = Invitation(
    code: 'A3F9K2BX',
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
  );

  setUp(() {
    mockRepository = MockCoupleRepository();
    coupleBloc = CoupleBloc(coupleRepository: mockRepository);
  });

  tearDown(() {
    coupleBloc.close();
  });

  group('CoupleBloc', () {
    test('initial state is CoupleInitial', () {
      expect(coupleBloc.state, const CoupleInitial());
    });

    group('LoadCouple', () {
      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleLinked] when couple exists',
        build: () {
          when(mockRepository.getMyCouple())
              .thenAnswer((_) async => Right(tCouple));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const LoadCouple()),
        expect: () => [
          const CoupleLoading(),
          CoupleLinked(tCouple),
        ],
      );

      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleNotLinked] when couple not found by code',
        build: () {
          when(mockRepository.getMyCouple()).thenAnswer((_) async =>
              const Left(ServerFailure(
                  'User is not currently in a couple.',
                  'COUPLE_NOT_FOUND',
                  404)));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const LoadCouple()),
        expect: () => [
          const CoupleLoading(),
          const CoupleNotLinked(),
        ],
      );

      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleNotLinked] when couple not found by status 404',
        build: () {
          when(mockRepository.getMyCouple()).thenAnswer((_) async =>
              const Left(ServerFailure(
                  'Not found', null, 404)));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const LoadCouple()),
        expect: () => [
          const CoupleLoading(),
          const CoupleNotLinked(),
        ],
      );

      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleError] on other failures',
        build: () {
          when(mockRepository.getMyCouple()).thenAnswer(
              (_) async => const Left(ServerFailure('Server error')));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const LoadCouple()),
        expect: () => [
          const CoupleLoading(),
          const CoupleError('Server error'),
        ],
      );
    });

    group('GenerateInvitation', () {
      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleInvitationPending] on success',
        build: () {
          when(mockRepository.createInvitation())
              .thenAnswer((_) async => Right(tInvitation));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const GenerateInvitation()),
        expect: () => [
          const CoupleLoading(),
          CoupleInvitationPending(tInvitation),
        ],
      );

      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleError] when already in couple',
        build: () {
          when(mockRepository.createInvitation()).thenAnswer((_) async =>
              const Left(
                  ServerFailure('User is already in an active couple.')));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const GenerateInvitation()),
        expect: () => [
          const CoupleLoading(),
          const CoupleError('User is already in an active couple.'),
        ],
      );
    });

    group('AcceptInvitation', () {
      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleLinked] on success',
        build: () {
          when(mockRepository.acceptInvitation('A3F9K2BX'))
              .thenAnswer((_) async => Right(tCouple));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const AcceptInvitation('A3F9K2BX')),
        expect: () => [
          const CoupleLoading(),
          CoupleLinked(tCouple),
        ],
      );

      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleError] when code not found',
        build: () {
          when(mockRepository.acceptInvitation('INVALID1')).thenAnswer(
              (_) async => const Left(
                  ServerFailure('Invitation code does not exist')));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const AcceptInvitation('INVALID1')),
        expect: () => [
          const CoupleLoading(),
          const CoupleError('Invitation code does not exist'),
        ],
      );

      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleError] when self invitation',
        build: () {
          when(mockRepository.acceptInvitation('A3F9K2BX')).thenAnswer(
              (_) async => const Left(
                  ServerFailure('User cannot accept their own invitation')));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const AcceptInvitation('A3F9K2BX')),
        expect: () => [
          const CoupleLoading(),
          const CoupleError('User cannot accept their own invitation'),
        ],
      );
    });

    group('DissolveCouple', () {
      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleNotLinked] on success',
        build: () {
          when(mockRepository.dissolveCouple())
              .thenAnswer((_) async => const Right(null));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const DissolveCouple()),
        expect: () => [
          const CoupleLoading(),
          const CoupleNotLinked(),
        ],
      );

      blocTest<CoupleBloc, CoupleState>(
        'emits [CoupleLoading, CoupleError] on failure',
        build: () {
          when(mockRepository.dissolveCouple()).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to dissolve couple')));
          return coupleBloc;
        },
        act: (bloc) => bloc.add(const DissolveCouple()),
        expect: () => [
          const CoupleLoading(),
          const CoupleError('Failed to dissolve couple'),
        ],
      );
    });
  });
}
