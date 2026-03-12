import 'dart:async';
import 'package:dio/dio.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:get_it/get_it.dart';

/// Global key for showing snackbars from non-widget code (e.g., interceptors).
/// Must be assigned to the ScaffoldMessenger in the MaterialApp.
import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;
  final List<_RetryRequest> _pendingRequests = [];

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
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Don't try to refresh if the failing request is the refresh endpoint itself
    final requestPath = err.requestOptions.path;
    if (requestPath == ApiEndpoints.authRefresh) {
      _handleRefreshFailure();
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      // Another refresh is already in progress; queue this request
      final completer = Completer<Response>();
      _pendingRequests.add(_RetryRequest(
        requestOptions: err.requestOptions,
        completer: completer,
      ));
      try {
        final response = await completer.future;
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
      return;
    }

    _isRefreshing = true;

    try {
      final storage = GetIt.I<SecureStorageService>();
      final refreshToken = await storage.getRefreshToken();

      if (refreshToken == null) {
        await storage.clearTokens();
        _handleRefreshFailure();
        _rejectPendingRequests(err);
        handler.next(err);
        return;
      }

      // Create a new Dio instance to avoid interceptor loop
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await refreshDio.post(
        ApiEndpoints.authRefresh,
        data: {'refreshToken': refreshToken},
      );

      final newAccessToken =
          response.data['data']['accessToken'] as String;
      final newRefreshToken =
          response.data['data']['refreshToken'] as String;

      await storage.saveAccessToken(newAccessToken);
      await storage.saveRefreshToken(newRefreshToken);

      // Retry the original request with new token
      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryDio = Dio(BaseOptions(
        baseUrl: requestOptions.baseUrl,
        headers: requestOptions.headers,
      ));

      final retryResponse = await retryDio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
        ),
      );

      // Resolve pending requests with new token
      _resolvePendingRequests(newAccessToken);

      handler.resolve(retryResponse);
    } on DioException {
      final storage = GetIt.I<SecureStorageService>();
      await storage.clearTokens();
      _handleRefreshFailure();
      _rejectPendingRequests(err);
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Handles token refresh failure: dispatches logout event to AuthBloc
  /// and shows a session-expired snackbar to the user.
  void _handleRefreshFailure() {
    // Dispatch logout event to AuthBloc so the app navigates to login
    try {
      final authBloc = GetIt.I<AuthBloc>();
      authBloc.add(const AuthSessionExpired());
    } catch (_) {
      // AuthBloc may not be registered yet during startup
    }

    // Show a snackbar notification to the user
    try {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('세션이 만료되었습니다. 다시 로그인해주세요.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      // ScaffoldMessenger may not be available yet
    }
  }

  void _resolvePendingRequests(String newAccessToken) {
    for (final pending in _pendingRequests) {
      final options = pending.requestOptions;
      options.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryDio = Dio(BaseOptions(
        baseUrl: options.baseUrl,
        headers: options.headers,
      ));

      retryDio
          .request(
            options.path,
            data: options.data,
            queryParameters: options.queryParameters,
            options: Options(
              method: options.method,
              headers: options.headers,
            ),
          )
          .then((response) => pending.completer.complete(response))
          .catchError((error) => pending.completer.completeError(error));
    }
    _pendingRequests.clear();
  }

  void _rejectPendingRequests(DioException error) {
    for (final pending in _pendingRequests) {
      pending.completer.completeError(error);
    }
    _pendingRequests.clear();
  }
}

class _RetryRequest {
  final RequestOptions requestOptions;
  final Completer<Response> completer;

  _RetryRequest({
    required this.requestOptions,
    required this.completer,
  });
}
