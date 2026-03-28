import 'package:equatable/equatable.dart';

class Favorites extends Equatable {
  final List<String> categoryIds;
  final List<String> paymentMethodIds;

  const Favorites({
    this.categoryIds = const [],
    this.paymentMethodIds = const [],
  });

  /// Returns true if the given category ID is in the favorites list.
  bool isCategoryFavorite(String categoryId) =>
      categoryIds.contains(categoryId);

  /// Returns true if the given payment method ID is in the favorites list.
  bool isPaymentMethodFavorite(String paymentMethodId) =>
      paymentMethodIds.contains(paymentMethodId);

  static const empty = Favorites();

  @override
  List<Object?> get props => [categoryIds, paymentMethodIds];
}
