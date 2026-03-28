import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/preference/domain/entities/favorites.dart';

abstract class PreferenceRepository {
  /// Fetches the current favorites for the authenticated user's couple.
  Future<Either<Failure, Favorites>> getFavorites();

  /// Replaces the entire favorites list (bulk update).
  Future<Either<Failure, Favorites>> updateFavorites({
    required List<String> categoryIds,
    required List<String> paymentMethodIds,
  });

  /// Toggles a single item in the favorites list.
  /// [type] must be 'CATEGORY' or 'PAYMENT_METHOD'.
  Future<Either<Failure, Favorites>> toggleFavorite({
    required String type,
    required String itemId,
  });
}
