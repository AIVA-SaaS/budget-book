import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/auth/data/models/user_model.dart';
import 'package:budget_book/features/auth/data/models/auth_token_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthTokenModel> refreshToken(String refreshToken);
  Future<UserModel> getCurrentUser();
  Future<void> logout(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AuthTokenModel> refreshToken(String refreshToken) async {
    final response = await apiClient.dio.post(
      ApiEndpoints.authRefresh,
      data: {'refreshToken': refreshToken},
    );
    return AuthTokenModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await apiClient.dio.get(ApiEndpoints.authMe);
    return UserModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    await apiClient.dio.post(
      ApiEndpoints.authLogout,
      data: {'refreshToken': refreshToken},
    );
  }
}
