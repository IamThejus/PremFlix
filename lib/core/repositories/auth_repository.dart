import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/auth_session.dart';
import '../services/device_identity_service.dart';

/// Handles authentication against a Jellyfin server.
///
/// This is the one place that knows the `AuthenticateByName` wire format.
/// It uses short-lived Dio instances rather than [apiClientProvider]
/// because both calls happen *outside* an established session: login has
/// no token yet, and logout runs while the session is being torn down.
class AuthRepository {
  AuthRepository(this._identity);

  final DeviceIdentityService _identity;

  /// Signs into the server at [serverUrl] with username/password.
  ///
  /// The user's per-device token is issued by the server in response —
  /// PremFlix never uses an admin API key. Throws [ApiException] with a
  /// classified kind on failure.
  Future<AuthSession> authenticate({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final normalizedUrl = normalizeServerUrl(serverUrl);
    final dio = Dio(jellyfinBaseOptions(normalizedUrl));

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
        options: Options(
          headers: {
            // Client identity without a token — required by Jellyfin to
            // issue one.
            'Authorization': _identity.authorizationHeader(),
          },
        ),
      );

      final body = response.data;
      final user = body?['User'] as Map<String, dynamic>?;
      final accessToken = body?['AccessToken'] as String?;
      if (user == null || accessToken == null) {
        throw const ApiException(
          ApiErrorKind.unknown,
          'The server sent an unexpected login response. '
          'Is this a Jellyfin server?',
        );
      }

      return AuthSession(
        serverUrl: normalizedUrl,
        userId: user['Id'] as String,
        userName: user['Name'] as String? ?? username,
        accessToken: accessToken,
        userImageTag: user['PrimaryImageTag'] as String?,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } finally {
      dio.close();
    }
  }

  /// Best-effort server-side logout: asks Jellyfin to revoke the device
  /// token. Failures are swallowed — the device forgets its credentials
  /// regardless (see `SessionController.clear`), and an unreachable
  /// server must never trap the user in a signed-in state.
  Future<void> logout(AuthSession session) async {
    final dio = Dio(jellyfinBaseOptions(session.serverUrl));
    try {
      await dio.post<void>(
        '/Sessions/Logout',
        options: Options(
          headers: {
            'Authorization':
                _identity.authorizationHeader(token: session.accessToken),
          },
        ),
      );
    } on DioException {
      // Intentionally ignored — local sign-out proceeds either way.
    } finally {
      dio.close();
    }
  }

  /// Normalizes user input into a base URL Jellyfin accepts:
  /// trims whitespace, defaults to `http://` when no scheme is given
  /// (the common case for LAN servers), and strips trailing slashes.
  static String normalizeServerUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) {
      throw const ApiException(
        ApiErrorKind.unreachable,
        'Enter your server address.',
      );
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw const ApiException(
        ApiErrorKind.unreachable,
        "That doesn't look like a valid server address.",
      );
    }
    return url;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(deviceIdentityProvider)),
);
