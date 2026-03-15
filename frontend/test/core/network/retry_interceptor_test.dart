import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/network/retry_interceptor.dart';

/// A test-friendly error handler that captures whether next() or resolve() was called.
class _TestErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;
  bool resolveCalled = false;
  final Completer<void> _completer = Completer<void>();

  Future<void> get done => _completer.future;

  @override
  void next(DioException err) {
    nextCalled = true;
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  void resolve(Response response) {
    resolveCalled = true;
    if (!_completer.isCompleted) _completer.complete();
  }
}

void main() {
  group('RetryInterceptor', () {
    late Dio dio;
    late RetryInterceptor interceptor;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      interceptor = RetryInterceptor(
        dio: dio,
        maxRetries: 2,
        baseDelay: const Duration(milliseconds: 10), // fast for tests
      );
    });

    test('should be created with default values', () {
      final defaultInterceptor = RetryInterceptor(dio: dio);
      expect(defaultInterceptor.maxRetries, 2);
      expect(defaultInterceptor.baseDelay, const Duration(seconds: 1));
    });

    test('constructor accepts custom parameters', () {
      final customInterceptor = RetryInterceptor(
        dio: dio,
        maxRetries: 5,
        baseDelay: const Duration(seconds: 3),
      );

      expect(customInterceptor.maxRetries, 5);
      expect(customInterceptor.baseDelay, const Duration(seconds: 3));
    });

    group('does not retry on client errors', () {
      for (final statusCode in [400, 401, 403, 404, 422]) {
        test('does not retry on $statusCode', () async {
          final requestOptions = RequestOptions(path: '/test');
          final err = DioException(
            type: DioExceptionType.badResponse,
            requestOptions: requestOptions,
            response: Response(
              statusCode: statusCode,
              requestOptions: requestOptions,
            ),
          );

          final handler = _TestErrorHandler();
          interceptor.onError(err, handler);
          await handler.done;

          expect(handler.nextCalled, isTrue,
              reason: 'Should call next (no retry) for $statusCode');
          expect(handler.resolveCalled, isFalse);
          // retry count should not be set (no retry attempted)
          expect(requestOptions.extra['retry_interceptor_count'], isNull);
        });
      }
    });

    test('does not retry on cancel', () async {
      final requestOptions = RequestOptions(path: '/test');
      final err = DioException(
        type: DioExceptionType.cancel,
        requestOptions: requestOptions,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(err, handler);
      await handler.done;

      expect(handler.nextCalled, isTrue);
      expect(requestOptions.extra['retry_interceptor_count'], isNull);
    });

    test('does not retry when maxRetries is already reached', () async {
      final requestOptions = RequestOptions(path: '/test');
      // Simulate that we already retried 2 times
      requestOptions.extra['retry_interceptor_count'] = 2;

      final err = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: requestOptions,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(err, handler);
      await handler.done;

      expect(handler.nextCalled, isTrue,
          reason: 'Should give up after maxRetries');
      // retry count should remain at 2, not increment
      expect(requestOptions.extra['retry_interceptor_count'], 2);
    });

    test('does not retry on badCertificate', () async {
      final requestOptions = RequestOptions(path: '/test');
      final err = DioException(
        type: DioExceptionType.badCertificate,
        requestOptions: requestOptions,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(err, handler);
      await handler.done;

      expect(handler.nextCalled, isTrue);
      expect(requestOptions.extra['retry_interceptor_count'], isNull);
    });
  });
}
