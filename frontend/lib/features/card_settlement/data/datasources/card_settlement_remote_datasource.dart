import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/card_settlement/data/models/settlement_transaction_model.dart';

abstract class CardSettlementRemoteDataSource {
  Future<SettlementTransactionsResponseModel> getSettlementTransactions({
    required String paymentMethodId,
    required int year,
    required int month,
  });
}

class CardSettlementRemoteDataSourceImpl
    implements CardSettlementRemoteDataSource {
  final ApiClient apiClient;

  CardSettlementRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<SettlementTransactionsResponseModel> getSettlementTransactions({
    required String paymentMethodId,
    required int year,
    required int month,
  }) async {
    final response = await apiClient.dio.get(
      '${ApiEndpoints.transactions}/settlement',
      queryParameters: {
        'paymentMethodId': paymentMethodId,
        'year': year,
        'month': month,
      },
    );

    return SettlementTransactionsResponseModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
