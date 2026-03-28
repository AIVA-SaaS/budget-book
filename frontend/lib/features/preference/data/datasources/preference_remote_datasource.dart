import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/preference/data/models/favorites_model.dart';

abstract class PreferenceRemoteDataSource {
  Future<FavoritesModel> getFavorites();
  Future<FavoritesModel> updateFavorites(Map<String, dynamic> data);
  Future<FavoritesModel> toggleFavorite(Map<String, dynamic> data);
}

class PreferenceRemoteDataSourceImpl implements PreferenceRemoteDataSource {
  final ApiClient apiClient;

  PreferenceRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<FavoritesModel> getFavorites() async {
    final response = await apiClient.dio.get(
      ApiEndpoints.preferencesFavorites,
    );
    return FavoritesModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<FavoritesModel> updateFavorites(Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      ApiEndpoints.preferencesFavorites,
      data: data,
    );
    return FavoritesModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<FavoritesModel> toggleFavorite(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.preferencesFavoritesToggle,
      data: data,
    );
    return FavoritesModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
