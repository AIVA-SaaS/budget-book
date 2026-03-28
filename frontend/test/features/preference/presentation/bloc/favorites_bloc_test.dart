import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_event.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_state.dart';
import 'package:budget_book/features/preference/domain/repositories/preference_repository.dart';
import 'package:budget_book/features/preference/domain/entities/favorites.dart';
import 'package:budget_book/core/error/failure.dart';

class MockPreferenceRepository extends Mock implements PreferenceRepository {
  @override
  Future<Either<Failure, Favorites>> getFavorites() =>
      super.noSuchMethod(
        Invocation.method(#getFavorites, []),
        returnValue: Future.value(
          const Right<Failure, Favorites>(Favorites.empty),
        ),
      ) as Future<Either<Failure, Favorites>>;

  @override
  Future<Either<Failure, Favorites>> updateFavorites({
    required List<String> categoryIds,
    required List<String> paymentMethodIds,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateFavorites, [], {
          #categoryIds: categoryIds,
          #paymentMethodIds: paymentMethodIds,
        }),
        returnValue: Future.value(
          const Right<Failure, Favorites>(Favorites.empty),
        ),
      ) as Future<Either<Failure, Favorites>>;

  @override
  Future<Either<Failure, Favorites>> toggleFavorite({
    required String type,
    required String itemId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFavorite, [], {
          #type: type,
          #itemId: itemId,
        }),
        returnValue: Future.value(
          const Right<Failure, Favorites>(Favorites.empty),
        ),
      ) as Future<Either<Failure, Favorites>>;
}

void main() {
  late MockPreferenceRepository mockRepository;

  setUp(() {
    mockRepository = MockPreferenceRepository();
  });

  const testFavorites = Favorites(
    categoryIds: ['cat-1', 'cat-2'],
    paymentMethodIds: ['pm-1'],
  );

  group('FavoritesBloc', () {
    test('initial state is FavoritesInitial', () {
      final bloc = FavoritesBloc(preferenceRepository: mockRepository);
      expect(bloc.state, const FavoritesInitial());
      bloc.close();
    });

    blocTest<FavoritesBloc, FavoritesState>(
      'emits [FavoritesLoading, FavoritesLoaded] when LoadFavorites succeeds',
      build: () {
        when(mockRepository.getFavorites())
            .thenAnswer((_) async => const Right(testFavorites));
        return FavoritesBloc(preferenceRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadFavorites()),
      expect: () => [
        const FavoritesLoading(),
        const FavoritesLoaded(testFavorites),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'emits [FavoritesLoading, FavoritesError] when LoadFavorites fails',
      build: () {
        when(mockRepository.getFavorites())
            .thenAnswer((_) async => const Left(ServerFailure('Network error')));
        return FavoritesBloc(preferenceRepository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadFavorites()),
      expect: () => [
        const FavoritesLoading(),
        const FavoritesError('Network error'),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'emits updated FavoritesLoaded when UpdateFavorites succeeds',
      build: () {
        when(mockRepository.updateFavorites(
          categoryIds: ['cat-3'],
          paymentMethodIds: ['pm-2'],
        )).thenAnswer((_) async => const Right(Favorites(
              categoryIds: ['cat-3'],
              paymentMethodIds: ['pm-2'],
            )));
        return FavoritesBloc(preferenceRepository: mockRepository);
      },
      seed: () => const FavoritesLoaded(testFavorites),
      act: (bloc) => bloc.add(const UpdateFavorites(
        categoryIds: ['cat-3'],
        paymentMethodIds: ['pm-2'],
      )),
      expect: () => [
        const FavoritesLoaded(Favorites(
          categoryIds: ['cat-3'],
          paymentMethodIds: ['pm-2'],
        )),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'ToggleFavorite optimistically updates then confirms with server response',
      build: () {
        when(mockRepository.toggleFavorite(
          type: 'CATEGORY',
          itemId: 'cat-3',
        )).thenAnswer((_) async => const Right(Favorites(
              categoryIds: ['cat-1', 'cat-2', 'cat-3'],
              paymentMethodIds: ['pm-1'],
            )));
        return FavoritesBloc(preferenceRepository: mockRepository);
      },
      seed: () => const FavoritesLoaded(testFavorites),
      act: (bloc) => bloc.add(const ToggleFavorite(
        type: 'CATEGORY',
        itemId: 'cat-3',
      )),
      expect: () => [
        // Optimistic update + server confirms same result (deduplicated by Equatable)
        const FavoritesLoaded(Favorites(
          categoryIds: ['cat-1', 'cat-2', 'cat-3'],
          paymentMethodIds: ['pm-1'],
        )),
      ],
      verify: (_) {
        verify(mockRepository.toggleFavorite(
          type: 'CATEGORY',
          itemId: 'cat-3',
        )).called(1);
      },
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'ToggleFavorite reverts on server failure',
      build: () {
        when(mockRepository.toggleFavorite(
          type: 'CATEGORY',
          itemId: 'cat-3',
        )).thenAnswer((_) async => const Left(ServerFailure('Error')));
        return FavoritesBloc(preferenceRepository: mockRepository);
      },
      seed: () => const FavoritesLoaded(testFavorites),
      act: (bloc) => bloc.add(const ToggleFavorite(
        type: 'CATEGORY',
        itemId: 'cat-3',
      )),
      expect: () => [
        // Optimistic: cat-3 added
        const FavoritesLoaded(Favorites(
          categoryIds: ['cat-1', 'cat-2', 'cat-3'],
          paymentMethodIds: ['pm-1'],
        )),
        // Reverted to original
        const FavoritesLoaded(testFavorites),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'ToggleFavorite removes existing favorite (PAYMENT_METHOD)',
      build: () {
        when(mockRepository.toggleFavorite(
          type: 'PAYMENT_METHOD',
          itemId: 'pm-1',
        )).thenAnswer((_) async => const Right(Favorites(
              categoryIds: ['cat-1', 'cat-2'],
              paymentMethodIds: [],
            )));
        return FavoritesBloc(preferenceRepository: mockRepository);
      },
      seed: () => const FavoritesLoaded(testFavorites),
      act: (bloc) => bloc.add(const ToggleFavorite(
        type: 'PAYMENT_METHOD',
        itemId: 'pm-1',
      )),
      expect: () => [
        // Optimistic removal + server confirms (deduplicated by Equatable)
        const FavoritesLoaded(Favorites(
          categoryIds: ['cat-1', 'cat-2'],
          paymentMethodIds: [],
        )),
      ],
      verify: (_) {
        verify(mockRepository.toggleFavorite(
          type: 'PAYMENT_METHOD',
          itemId: 'pm-1',
        )).called(1);
      },
    );
  });

  group('Favorites entity', () {
    test('isCategoryFavorite returns correct values', () {
      expect(testFavorites.isCategoryFavorite('cat-1'), isTrue);
      expect(testFavorites.isCategoryFavorite('cat-999'), isFalse);
    });

    test('isPaymentMethodFavorite returns correct values', () {
      expect(testFavorites.isPaymentMethodFavorite('pm-1'), isTrue);
      expect(testFavorites.isPaymentMethodFavorite('pm-999'), isFalse);
    });

    test('empty favorites has no items', () {
      expect(Favorites.empty.categoryIds, isEmpty);
      expect(Favorites.empty.paymentMethodIds, isEmpty);
    });
  });
}
