import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';

/// A Dio interceptor that retries failed requests with exponential backoff.
///
/// Retry policy:
/// - Retries on network errors (connectionTimeout, sendTimeout, receiveTimeout,
///   connectionError, unknown with no response).
/// - Retries on 5xx server errors.
/// - Does NOT retry on 4xx client errors.
/// - Max [maxRetries] attempts with exponential backoff starting at
///   [baseDelay] (1s, 2s, 4s, ...).
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(seconds: 1),
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final retryCount = _getRetryCount(err.requestOptions);
    if (retryCount >= maxRetries) {
      handler.next(err);
      return;
    }

    // Exponential backoff: baseDelay * 2^retryCount
    final delay = baseDelay * pow(2, retryCount).toInt();
    await Future<void>.delayed(delay);

    // Increment retry count
    final options = err.requestOptions;
    _setRetryCount(options, retryCount + 1);

    try {
      final response = await dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    // Retry on timeout and network errors
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        // Retry on 5xx server errors, not on 4xx client errors
        final statusCode = err.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return true;
        }
        return false;
      case DioExceptionType.unknown:
        // Retry on unknown errors that have no response (likely network issues)
        return err.response == null;
      default:
        return false;
    }
  }

  static const _retryCountKey = 'retry_interceptor_count';

  int _getRetryCount(RequestOptions options) {
    return (options.extra[_retryCountKey] as int?) ?? 0;
  }

  void _setRetryCount(RequestOptions options, int count) {
    options.extra[_retryCountKey] = count;
  }
}
