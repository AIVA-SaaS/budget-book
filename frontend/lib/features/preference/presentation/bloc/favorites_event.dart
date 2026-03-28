import 'package:equatable/equatable.dart';

sealed class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class LoadFavorites extends FavoritesEvent {
  const LoadFavorites();
}

class UpdateFavorites extends FavoritesEvent {
  final List<String> categoryIds;
  final List<String> paymentMethodIds;

  const UpdateFavorites({
    required this.categoryIds,
    required this.paymentMethodIds,
  });

  @override
  List<Object?> get props => [categoryIds, paymentMethodIds];
}

class ToggleFavorite extends FavoritesEvent {
  /// 'CATEGORY' or 'PAYMENT_METHOD'
  final String type;
  final String itemId;

  const ToggleFavorite({required this.type, required this.itemId});

  @override
  List<Object?> get props => [type, itemId];
}
