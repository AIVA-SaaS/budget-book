import 'package:dio/dio.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
import 'package:get_it/get_it.dart';

class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = GetIt.I<SecureStorageService>();
    final token = await storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // TODO: Implement token refresh logic
    }
    handler.next(err);
  }
}
