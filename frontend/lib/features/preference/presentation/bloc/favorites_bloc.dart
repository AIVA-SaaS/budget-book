import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/preference/domain/entities/favorites.dart';
import 'package:budget_book/features/preference/domain/repositories/preference_repository.dart';
import 'favorites_event.dart';
import 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final PreferenceRepository preferenceRepository;

  FavoritesBloc({required this.preferenceRepository})
      : super(const FavoritesInitial()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<UpdateFavorites>(_onUpdateFavorites);
    on<ToggleFavorite>(_onToggleFavorite);
  }

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      // 회차 12 follow-up — race fix.
      if (state is! FavoritesLoaded) {
        emit(const FavoritesLoading());
      }
      final result = await preferenceRepository.getFavorites();
      result.fold(
        (failure) {
          if (state is FavoritesLoaded) {
            // keep — operationError 가 없으므로 상태 유지만
          } else {
            emit(FavoritesError(failure.message));
          }
        },
        (favorites) => emit(FavoritesLoaded(favorites)),
      );
    } catch (_) {
      if (state is! FavoritesLoaded) {
        emit(const FavoritesError('즐겨찾기를 불러오지 못했습니다'));
      }
    }
  }

  Future<void> _onUpdateFavorites(
    UpdateFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final current = _currentFavorites;
      final result = await preferenceRepository.updateFavorites(
        categoryIds: event.categoryIds,
        paymentMethodIds: event.paymentMethodIds,
      );
      result.fold(
        (failure) => emit(FavoritesLoaded(current)),
        (favorites) => emit(FavoritesLoaded(favorites)),
      );
    } catch (_) {
      emit(FavoritesLoaded(_currentFavorites));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      // Optimistic update: toggle locally first for instant UI feedback
      final current = _currentFavorites;
      final optimistic = _toggleLocal(current, event.type, event.itemId);
      emit(FavoritesLoaded(optimistic));

      final result = await preferenceRepository.toggleFavorite(
        type: event.type,
        itemId: event.itemId,
      );
      result.fold(
        // Revert on failure
        (failure) => emit(FavoritesLoaded(current)),
        (favorites) => emit(FavoritesLoaded(favorites)),
      );
    } catch (_) {
      // Keep the current state on unexpected errors
    }
  }

  Favorites get _currentFavorites =>
      state is FavoritesLoaded
          ? (state as FavoritesLoaded).favorites
          : Favorites.empty;

  /// Locally toggles an item for optimistic UI.
  Favorites _toggleLocal(Favorites current, String type, String itemId) {
    if (type == 'CATEGORY') {
      final ids = List<String>.from(current.categoryIds);
      if (ids.contains(itemId)) {
        ids.remove(itemId);
      } else {
        ids.add(itemId);
      }
      return Favorites(
        categoryIds: ids,
        paymentMethodIds: current.paymentMethodIds,
      );
    } else {
      final ids = List<String>.from(current.paymentMethodIds);
      if (ids.contains(itemId)) {
        ids.remove(itemId);
      } else {
        ids.add(itemId);
      }
      return Favorites(
        categoryIds: current.categoryIds,
        paymentMethodIds: ids,
      );
    }
  }
}
