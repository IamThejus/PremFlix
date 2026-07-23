import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_identity_service.dart';
import '../services/session_controller.dart';
import 'interceptors.dart';

/// Base options shared by every Dio instance the app creates.
///
/// Jellyfin can be slow to wake spinning disks, so receive is generous
/// while connect stays tight (an unreachable server should fail fast).
BaseOptions jellyfinBaseOptions(String serverUrl) => BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      // Treat only transport-level failures as exceptions here; status
      // handling is centralized in ApiException.fromDio.
      validateStatus: (status) => status != null && status < 400,
    );

/// The session-scoped Dio used by all repositories after login.
///
/// Watches the session, so signing into a different server (or out) tears
/// the old client down and builds a fresh one — no stale base URLs or
/// tokens can leak between sessions. Reading this without an active
/// session is a programming error and fails loudly.
final apiClientProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) {
    throw StateError('apiClientProvider read without an active session');
  }

  final identity = ref.watch(deviceIdentityProvider);
  final dio = Dio(jellyfinBaseOptions(session.serverUrl));

  dio.interceptors.addAll([
    AuthInterceptor(
      headerValue: identity.authorizationHeader(token: session.accessToken),
      onUnauthorized: () =>
          ref.read(sessionControllerProvider.notifier).clear(),
    ),
    RetryInterceptor(dio),
  ]);

  ref.onDispose(dio.close);
  return dio;
});
