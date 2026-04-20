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
        // Spring `@RequestParam List<UUID>` 호환: `?k=a&k=b` 형식.
        // 기본값 multiCompatible(`?k[]=a&k[]=b`) 는 Spring 이 파싱하지 못함.
        // PR-C3 에서 복수 필터(categoryIds 등) 전달 위해 ListFormat.multi 로 통일.
        listFormat: ListFormat.multi,
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
