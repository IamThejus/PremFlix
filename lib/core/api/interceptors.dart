import 'dart:async';

import 'package:dio/dio.dart';

/// Attaches the Jellyfin `Authorization: MediaBrowser ...` header to every
/// request and reacts to token revocation.
///
/// When the server answers 401 (token deleted from the dashboard, password
/// changed, session expired) [onUnauthorized] is invoked — the session
/// controller clears stored credentials, which routes the app back to the
/// login screen. This makes remote sign-out "just work" from any screen.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.headerValue,
    required this.onUnauthorized,
  });

  /// Pre-built MediaBrowser header (client identity + token).
  final String headerValue;

  /// Called once when the server rejects our token.
  final Future<void> Function() onUnauthorized;

  bool _handling401 = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = headerValue;
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 && !_handling401) {
      // Guard so a burst of parallel requests failing together triggers
      // a single sign-out, not one per request.
      _handling401 = true;
      unawaited(onUnauthorized());
    }
    handler.next(err);
  }
}

/// Retries failed **idempotent** requests (GETs) on transient transport
/// errors — connection reset, timeout — with a short linear backoff.
///
/// Mutating requests (playback progress POSTs, favorite toggles) are never
/// retried here: a retry after an ambiguous failure could apply them twice.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2});

  static const String _attemptKey = 'premflix_retry_attempt';

  final Dio _dio;
  final int maxRetries;

  bool _isTransient(DioException err) => switch (err.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        _ => false,
      };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (options.method != 'GET' ||
        !_isTransient(err) ||
        attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    options.extra[_attemptKey] = attempt + 1;
    await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
