import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import 'media_cache_service.dart';
import 'secure_storage_service.dart';

/// Single source of truth for the authenticated session.
///
/// State meanings:
///  * `AsyncLoading`      — restoring credentials at boot (splash screen).
///  * `AsyncData(null)`   — signed out → router sends the user to login.
///  * `AsyncData(session)`— signed in → router allows the app shell.
///
/// Lives in `core` (not the auth feature) because core infrastructure —
/// the Dio client and the router guards — must read it, and core never
/// imports feature code.
class SessionController extends AsyncNotifier<AuthSession?> {
  /// Minimum time the boot ident (splash) stays on screen — matched to
  /// the `LogoReveal` settle point (2.8 s of its 3 s timeline), so the
  /// router's fade to home/login plays as the ident's fade-out.
  /// Credential restore is nearly instant; without this floor the splash
  /// would flash for a single frame and read as a glitch.
  static const Duration _bootIdentDuration = Duration(milliseconds: 2800);

  @override
  Future<AuthSession?> build() async {
    final (session, _) = await (
      ref.watch(secureStorageProvider).readSession(),
      Future<void>.delayed(_bootIdentDuration),
    ).wait;
    return session;
  }

  /// Adopts a freshly authenticated [session]: persists it and flips the
  /// app into the signed-in state (the router reacts immediately).
  Future<void> establish(AuthSession session) async {
    await ref.read(secureStorageProvider).writeSession(session);
    state = AsyncData(session);
  }

  /// Drops the session locally and wipes the media cache, so the next
  /// account on this device starts clean. Server-side logout is the
  /// repository's job; this only guarantees the device forgets.
  Future<void> clear() async {
    await ref.read(secureStorageProvider).clearSession();
    await ref.read(mediaCacheProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, AuthSession?>(
  SessionController.new,
);
