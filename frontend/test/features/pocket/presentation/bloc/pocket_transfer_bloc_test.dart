import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_event.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_transfer_state.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_transfer_repository.dart';
import 'package:budget_book/features/pocket/domain/entities/pocket_transfer.dart';
import 'package:budget_book/core/error/failure.dart';

class MockPocketTransferRepository extends Mock
    implements PocketTransferRepository {
  @override
  Future<Either<Failure, List<PocketTransfer>>> getPocketTransfers({
    String? fromPocketId,
    String? toPocketId,
    String? startDate,
    String? endDate,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPocketTransfers, [], {
          #fromPocketId: fromPocketId,
          #toPocketId: toPocketId,
          #startDate: startDate,
          #endDate: endDate,
        }),
        returnValue: Future.value(
          const Right<Failure, List<PocketTransfer>>([]),
        ),
      ) as Future<Either<Failure, List<PocketTransfer>>>;

  @override
  Future<Either<Failure, PocketTransfer>> createPocketTransfer({
    required String fromPocketId,
    required String toPocketId,
    required int amount,
    String? description,
    required String transferDate,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createPocketTransfer, [], {
          #fromPocketId: fromPocketId,
          #toPocketId: toPocketId,
          #amount: amount,
          #description: description,
          #transferDate: transferDate,
        }),
        returnValue: Future.value(
          const Right<Failure, PocketTransfer>(PocketTransfer(
            id: '',
            fromPocket: PocketRef(id: '', name: ''),
            toPocket: PocketRef(id: '', name: ''),
            amount: 0,
            transferDate: '',
            authorId: '',
          )),
        ),
      ) as Future<Either<Failure, PocketTransfer>>;
}

void main() {
  late PocketTransferBloc bloc;
  late MockPocketTransferRepository mockRepository;

  const tTransfer = PocketTransfer(
    id: 'transfer-1',
    fromPocket: PocketRef(id: 'pocket-1', name: '생활비'),
    toPocket: PocketRef(id: 'pocket-2', name: '저축'),
    amount: 100000,
    description: '이월 저축',
    transferDate: '2026-03-12',
    authorId: 'user-1',
  );

  const tTransfer2 = PocketTransfer(
    id: 'transfer-2',
    fromPocket: PocketRef(id: 'pocket-2', name: '저축'),
    toPocket: PocketRef(id: 'pocket-1', name: '생활비'),
    amount: 50000,
    transferDate: '2026-03-13',
    authorId: 'user-1',
  );

  final tTransfers = [tTransfer];

  setUp(() {
    mockRepository = MockPocketTransferRepository();
    bloc = PocketTransferBloc(pocketTransferRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('PocketTransferBloc', () {
    test('initial state is PocketTransferInitial', () {
      expect(bloc.state, const PocketTransferInitial());
    });

    group('LoadPocketTransfers', () {
      blocTest<PocketTransferBloc, PocketTransferState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getPocketTransfers())
              .thenAnswer((_) async => Right(tTransfers));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPocketTransfers()),
        expect: () => [
          const PocketTransferLoading(),
          PocketTransferLoaded(tTransfers),
        ],
      );

      blocTest<PocketTransferBloc, PocketTransferState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getPocketTransfers()).thenAnswer((_) async =>
              const Left(ServerFailure('Failed to load pocket transfers')));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPocketTransfers()),
        expect: () => [
          const PocketTransferLoading(),
          const PocketTransferError('Failed to load pocket transfers'),
        ],
      );
    });

    group('CreatePocketTransfer', () {
      blocTest<PocketTransferBloc, PocketTransferState>(
        'emits [Loaded] with new transfer prepended',
        build: () {
          when(mockRepository.createPocketTransfer(
            fromPocketId: 'pocket-2',
            toPocketId: 'pocket-1',
            amount: 50000,
            description: null,
            transferDate: '2026-03-13',
          )).thenAnswer((_) async => const Right(tTransfer2));
          return bloc;
        },
        seed: () => PocketTransferLoaded(tTransfers),
        act: (bloc) => bloc.add(const CreatePocketTransfer(
          fromPocketId: 'pocket-2',
          toPocketId: 'pocket-1',
          amount: 50000,
          transferDate: '2026-03-13',
        )),
        expect: () => [
          PocketTransferLoaded([tTransfer2, ...tTransfers]),
        ],
      );

      blocTest<PocketTransferBloc, PocketTransferState>(
        'emits [Loaded with operationError] on failure',
        build: () {
          when(mockRepository.createPocketTransfer(
            fromPocketId: 'pocket-1',
            toPocketId: 'pocket-1',
            amount: 50000,
            description: null,
            transferDate: '2026-03-13',
          )).thenAnswer((_) async =>
              const Left(ServerFailure('Cannot transfer to same pocket')));
          return bloc;
        },
        seed: () => PocketTransferLoaded(tTransfers),
        act: (bloc) => bloc.add(const CreatePocketTransfer(
          fromPocketId: 'pocket-1',
          toPocketId: 'pocket-1',
          amount: 50000,
          transferDate: '2026-03-13',
        )),
        expect: () => [
          PocketTransferLoaded(tTransfers,
              operationError: 'Cannot transfer to same pocket'),
        ],
      );
    });
  });
}
