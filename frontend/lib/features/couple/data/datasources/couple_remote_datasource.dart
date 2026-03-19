import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/couple/data/models/couple_model.dart';
import 'package:budget_book/features/couple/data/models/invitation_model.dart';
import 'package:budget_book/features/couple/data/models/invitation_status_model.dart';

abstract class CoupleRemoteDataSource {
  Future<CoupleModel> getMyCouple();
  Future<InvitationModel> createInvitation();
  Future<CoupleModel> acceptInvitation(String code);
  Future<void> dissolveCouple();
  Future<InvitationStatusModel> getMyInvitation();
}

class CoupleRemoteDataSourceImpl implements CoupleRemoteDataSource {
  final ApiClient apiClient;

  CoupleRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<CoupleModel> getMyCouple() async {
    final response = await apiClient.dio.get(ApiEndpoints.coupleMe);
    return CoupleModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<InvitationModel> createInvitation() async {
    final response = await apiClient.dio.post(ApiEndpoints.coupleInvitations);
    return InvitationModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<CoupleModel> acceptInvitation(String code) async {
    final response = await apiClient.dio.post(
      '${ApiEndpoints.coupleInvitations}/$code/accept',
    );
    return CoupleModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> dissolveCouple() async {
    await apiClient.dio.delete(ApiEndpoints.coupleMe);
  }

  @override
  Future<InvitationStatusModel> getMyInvitation() async {
    final response = await apiClient.dio.get(ApiEndpoints.coupleMyInvitation);
    return InvitationStatusModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
