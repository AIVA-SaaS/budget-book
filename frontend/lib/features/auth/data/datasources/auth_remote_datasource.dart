import 'package:dio/dio.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/features/auth/data/models/user_model.dart';
import 'package:budget_book/features/auth/data/models/auth_token_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthTokenModel> refreshToken(String refreshToken);
  Future<UserModel> getCurrentUser();
  Future<UserModel> updateProfile({
    String? nickname,
    String? profileImageUrl,
    bool clearProfileImage = false,
  });
  Future<void> logout(String refreshToken);
  Future<UserModel> uploadProfileImage(List<int> imageBytes, String fileName);
  Future<void> deleteProfileImage();
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
  Future<UserModel> updateProfile({
    String? nickname,
    String? profileImageUrl,
    bool clearProfileImage = false,
  }) async {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (profileImageUrl != null) data['profileImageUrl'] = profileImageUrl;
    if (clearProfileImage) data['clearProfileImage'] = true;

    final response = await apiClient.dio.patch(
      ApiEndpoints.authMe,
      data: data,
    );
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

  @override
  Future<UserModel> uploadProfileImage(
      List<int> imageBytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
    });
    final response = await apiClient.dio.post(
      ApiEndpoints.authProfileImage,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return UserModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteProfileImage() async {
    await apiClient.dio.delete(ApiEndpoints.authProfileImage);
  }
}
