import 'package:budget_book/features/preference/domain/entities/favorites.dart';

class FavoritesModel extends Favorites {
  const FavoritesModel({
    super.categoryIds,
    super.paymentMethodIds,
  });

  factory FavoritesModel.fromJson(Map<String, dynamic> json) {
    return FavoritesModel(
      categoryIds: (json['categoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      paymentMethodIds: (json['paymentMethodIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
