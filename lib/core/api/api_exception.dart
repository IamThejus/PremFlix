import 'package:dio/dio.dart';

/// Classified failure categories the UI can branch on.
enum ApiErrorKind {
  /// Could not reach the server at all (DNS, refused, no network).
  unreachable,

  /// The server accepted the connection but took too long.
  timeout,

  /// 401 — bad credentials or a revoked/expired token.
  unauthorized,

  /// 403 — the user is not allowed to perform this action.
  forbidden,

  /// 404 — the resource does not exist on this server.
  notFound,

  /// Any 5xx from the server.
  server,

  /// Anything else (malformed response, cancelled, unknown).
  unknown,
}

/// Typed error surfaced by the API layer.
///
/// Repositories catch [DioException] and rethrow this, so nothing above
/// the repository layer ever imports Dio. [message] is user-presentable
/// default copy; screens with more context (e.g. the login form mapping
/// `unauthorized` to "wrong password") can branch on [kind] instead.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          ApiErrorKind.timeout,
          'The server took too long to respond.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          ApiErrorKind.unreachable,
          "Can't reach the server. Check the address and your network.",
        );
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        return switch (status) {
          401 => ApiException(
              ApiErrorKind.unauthorized,
              'Your session has expired. Please sign in again.',
              statusCode: status,
            ),
          403 => ApiException(
              ApiErrorKind.forbidden,
              "You don't have permission to do that.",
              statusCode: status,
            ),
          404 => ApiException(
              ApiErrorKind.notFound,
              'The server could not find that item.',
              statusCode: status,
            ),
          >= 500 => ApiException(
              ApiErrorKind.server,
              'The server ran into a problem ($status). Try again shortly.',
              statusCode: status,
            ),
          _ => ApiException(
              ApiErrorKind.unknown,
              'Unexpected server response ($status).',
              statusCode: status,
            ),
        };
      case DioExceptionType.badCertificate:
        return const ApiException(
          ApiErrorKind.unreachable,
          "The server's security certificate is not trusted.",
        );
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const ApiException(
          ApiErrorKind.unknown,
          'Something went wrong. Please try again.',
        );
    }
  }

  @override
  String toString() => 'ApiException(${kind.name}, $statusCode): $message';
}
