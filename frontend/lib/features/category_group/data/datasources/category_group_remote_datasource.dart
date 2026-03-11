import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/category_group/data/models/category_group_model.dart';

abstract class CategoryGroupRemoteDataSource {
  Future<List<CategoryGroupModel>> getCategoryGroups();
  Future<CategoryGroupModel> createCategoryGroup(Map<String, dynamic> data);
  Future<CategoryGroupModel> updateCategoryGroup(
      String id, Map<String, dynamic> data);
  Future<void> deleteCategoryGroup(String id);
}

class CategoryGroupRemoteDataSourceImpl
    implements CategoryGroupRemoteDataSource {
  final ApiClient apiClient;

  CategoryGroupRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<CategoryGroupModel>> getCategoryGroups() async {
    final response = await apiClient.dio.get(ApiEndpoints.categoryGroups);
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((e) => CategoryGroupModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CategoryGroupModel> createCategoryGroup(
      Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.categoryGroups,
      data: data,
    );
    return CategoryGroupModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<CategoryGroupModel> updateCategoryGroup(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.categoryGroups}/$id',
      data: data,
    );
    return CategoryGroupModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteCategoryGroup(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.categoryGroups}/$id');
  }
}
