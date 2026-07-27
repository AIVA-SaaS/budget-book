import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/transaction/data/models/transaction_model.dart';
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_filter.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';

abstract class TransactionRemoteDataSource {
  /// 필터는 [TransactionFilter] VO 로만 받는다 (필드 나열 금지 — 전파 누락 방지).
  Future<PageResponse<TransactionModel>> getTransactions({
    int? year,
    int? month,
    TransactionFilter filter = TransactionFilter.empty,
    int page = 0,
    int size = 20,
  });
  Future<TransactionModel> getTransaction(String id);
  Future<TransactionModel> createTransaction(Map<String, dynamic> data);
  Future<TransactionModel> updateTransaction(
      String id, Map<String, dynamic> data);
  Future<void> deleteTransaction(String id);
  Future<List<SuggestionGroup>> getSuggestions(String query, {String? type});
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final ApiClient apiClient;

  TransactionRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<PageResponse<TransactionModel>> getTransactions({
    int? year,
    int? month,
    TransactionFilter filter = TransactionFilter.empty,
    int page = 0,
    int size = 20,
  }) async {
    // S2 구조적 수정: 개별 필드 인라인 조립 제거, TransactionFilter.toQueryParams() 로 중앙화.
    // 2026-07-27: VO 를 파라미터로 직접 받아 재조립 단계까지 제거 (재조립 = 누락 기회).
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      ...filter.toQueryParams(),
    };
    if (year != null) queryParams['year'] = year;
    if (month != null) queryParams['month'] = month;

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
  Future<List<SuggestionGroup>> getSuggestions(String query, {String? type}) async {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.transactions}/suggestions',
      queryParameters: {
        'q': query,
        'limit': 5,
        if (type != null) 'type': type,
      },
    );
    final list = response.data['data'] as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      final patterns = (map['patterns'] as List<dynamic>).map((p) {
        final pm = p as Map<String, dynamic>;
        return SuggestionPattern(
          categoryId: pm['categoryId'] as String?,
          categoryName: pm['categoryName'] as String?,
          // 회차 12 follow-up — BE 응답에 categoryGroupName 추가됨
          categoryGroupName: pm['categoryGroupName'] as String?,
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
