import 'package:dio/dio.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/network/api_interceptor.dart';
import 'package:budget_book/core/network/retry_interceptor.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(RetryInterceptor(
      dio: dio,
      maxRetries: 2,
      baseDelay: const Duration(seconds: 1),
    ));
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
}
