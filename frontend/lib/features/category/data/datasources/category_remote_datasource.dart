import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/category/data/models/category_model.dart';

abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> getCategories({String? type});
  Future<CategoryModel> createCategory(Map<String, dynamic> data);
  Future<CategoryModel> updateCategory(String id, Map<String, dynamic> data);
  Future<void> deleteCategory(String id);
}

class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final ApiClient apiClient;

  CategoryRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<CategoryModel>> getCategories({String? type}) async {
    final queryParams = <String, dynamic>{};
    if (type != null) queryParams['type'] = type;

    final response = await apiClient.dio.get(
      ApiEndpoints.categories,
      queryParameters: queryParams,
    );
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CategoryModel> createCategory(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.categories,
      data: data,
    );
    return CategoryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<CategoryModel> updateCategory(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.categories}/$id',
      data: data,
    );
    return CategoryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.categories}/$id');
  }
}
