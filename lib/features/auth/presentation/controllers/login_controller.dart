import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/repositories/auth_repository.dart';
import '../../../../core/services/session_controller.dart';

/// Drives the login form's submission lifecycle.
///
/// State is an `AsyncValue<void>`: `data` = idle, `loading` = submitting,
/// `error` = last attempt failed (the screen renders the message inline).
/// On success there is no state to set here — establishing the session
/// flips [sessionControllerProvider], and the router redirects to home.
class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    // Ignore duplicate submits (double-tap, Enter while loading).
    if (state.isLoading) return;

    state = const AsyncLoading();
    try {
      final session = await ref.read(authRepositoryProvider).authenticate(
            serverUrl: serverUrl,
            username: username,
            password: password,
          );
      await ref.read(sessionControllerProvider.notifier).establish(session);
      state = const AsyncData(null);
    } on ApiException catch (error, stackTrace) {
      // In the login context a 401 means wrong credentials, not an
      // expired session — reword before surfacing.
      final message = error.kind == ApiErrorKind.unauthorized
          ? 'Wrong username or password.'
          : error.message;
      state = AsyncError(ApiException(error.kind, message), stackTrace);
    }
  }
}

final loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(
  LoginController.new,
);
