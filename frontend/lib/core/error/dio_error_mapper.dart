import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';

/// Maps [DioException] to [ServerFailure]. Shared across all repositories.
Failure mapDioError(DioException e, String defaultMessage) {
  final errorData = e.response?.data?['error'];
  return ServerFailure(
    errorData?['message'] as String? ?? defaultMessage,
    errorData?['code'] as String?,
    e.response?.statusCode,
  );
}
