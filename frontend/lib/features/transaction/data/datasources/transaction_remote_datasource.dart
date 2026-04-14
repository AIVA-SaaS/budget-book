import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';

abstract class TransactionRemoteDataSource {
  Future<PageResponse<TransactionModel>> getTransactions({
    int? year,
    int? month,
    String? type,
    String? categoryId,
    String? keyword,
    String? paymentMethodId,
    String? pocketId,
    int? amountMin,
    int? amountMax,
    String? dateFrom,
    String? dateTo,
    int page = 0,
    int size = 20,
  });
  Future<TransactionModel> getTransaction(String id);
  Future<TransactionModel> createTransaction(Map<String, dynamic> data);
  Future<TransactionModel> updateTransaction(
      String id, Map<String, dynamic> data);
  Future<void> deleteTransaction(String id);
  Future<List<SuggestionGroup>> getSuggestions(String query);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final ApiClient apiClient;

  TransactionRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<PageResponse<TransactionModel>> getTransactions({
    int? year,
    int? month,
    String? type,
    String? categoryId,
    String? keyword,
    String? paymentMethodId,
    String? pocketId,
    int? amountMin,
    int? amountMax,
    String? dateFrom,
    String? dateTo,
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (year != null) queryParams['year'] = year;
    if (month != null) queryParams['month'] = month;
    if (type != null) queryParams['type'] = type;
    if (categoryId != null) queryParams['categoryId'] = categoryId;
    if (keyword != null && keyword.isNotEmpty) queryParams['keyword'] = keyword;
    if (paymentMethodId != null) queryParams['paymentMethodId'] = paymentMethodId;
    if (pocketId != null) queryParams['pocketId'] = pocketId;
    if (amountMin != null) queryParams['amountMin'] = amountMin;
    if (amountMax != null) queryParams['amountMax'] = amountMax;
    if (dateFrom != null) queryParams['dateFrom'] = dateFrom;
    if (dateTo != null) queryParams['dateTo'] = dateTo;

    final response = await apiClient.dio.get(
      ApiEndpoints.transactions,
      queryParameters: queryParams,
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final content = (data['content'] as List<dynamic>)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PageResponse<TransactionModel>(
      content: content,
      page: data['page'] as int,
      size: data['size'] as int,
      totalElements: data['totalElements'] as int,
      totalPages: data['totalPages'] as int,
      first: data['first'] as bool,
      last: data['last'] as bool,
    );
  }

  @override
  Future<TransactionModel> getTransaction(String id) async {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.transactions}/$id',
    );
    return TransactionModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<TransactionModel> createTransaction(
      Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.transactions,
      data: data,
    );
    return TransactionModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<TransactionModel> updateTransaction(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.transactions}/$id',
      data: data,
    );
    return TransactionModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.transactions}/$id');
  }

  @override
  Future<List<SuggestionGroup>> getSuggestions(String query) async {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.transactions}/suggestions',
      queryParameters: {'q': query, 'limit': 5},
    );
    final list = response.data['data'] as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final patterns = (map['patterns'] as List<dynamic>).map((p) {
        final pm = p as Map<String, dynamic>;
        return SuggestionPattern(
          categoryId: pm['categoryId'] as String?,
          categoryName: pm['categoryName'] as String?,
          categoryIcon: pm['categoryIcon'] as String?,
          categoryColor: pm['categoryColor'] as String?,
          paymentMethodId: pm['paymentMethodId'] as String?,
          paymentMethodName: pm['paymentMethodName'] as String?,
          count: pm['count'] as int,
        );
      }).toList();
      return SuggestionGroup(
        description: map['description'] as String,
        patterns: patterns,
      );
    }).toList();
  }
}
