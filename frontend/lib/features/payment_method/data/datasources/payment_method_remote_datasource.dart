import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/payment_method/data/models/payment_method_model.dart';
import 'package:budget_book/features/payment_method/data/models/card_pending_model.dart';
import 'package:budget_book/features/payment_method/data/models/card_settlement_summary_model.dart';

abstract class PaymentMethodRemoteDataSource {
  Future<List<PaymentMethodModel>> getPaymentMethods();
  Future<PaymentMethodModel> createPaymentMethod(Map<String, dynamic> data);
  Future<PaymentMethodModel> updatePaymentMethod(
      String id, Map<String, dynamic> data);
  Future<void> deletePaymentMethod(String id);
  Future<List<CardPendingModel>> getCardPending(int year, int month);
  Future<CardSettlementSummaryModel> getCardSettlementSummary();
  Future<void> reorderPaymentMethods(List<String> orderedIds);
}

class PaymentMethodRemoteDataSourceImpl
    implements PaymentMethodRemoteDataSource {
  final ApiClient apiClient;

  PaymentMethodRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final response = await apiClient.dio.get(ApiEndpoints.paymentMethods);
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((e) => PaymentMethodModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PaymentMethodModel> createPaymentMethod(
      Map<String, dynamic> data) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.paymentMethods,
      data: data,
    );
    return PaymentMethodModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<PaymentMethodModel> updatePaymentMethod(
      String id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put(
      '${ApiEndpoints.paymentMethods}/$id',
      data: data,
    );
    return PaymentMethodModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deletePaymentMethod(String id) async {
    await apiClient.dio.delete('${ApiEndpoints.paymentMethods}/$id');
  }

  @override
  Future<List<CardPendingModel>> getCardPending(int year, int month) async {
    final response = await apiClient.dio.get(
      ApiEndpoints.paymentMethodsCardPending,
      queryParameters: {'year': year, 'month': month},
    );
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((e) => CardPendingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CardSettlementSummaryModel> getCardSettlementSummary() async {
    final response = await apiClient.dio.get(
      ApiEndpoints.paymentMethodsCardSettlementSummary,
    );
    return CardSettlementSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> reorderPaymentMethods(List<String> orderedIds) async {
    await apiClient.dio.put(
      ApiEndpoints.paymentMethodsReorder,
      data: {'orderedIds': orderedIds},
    );
  }
}
