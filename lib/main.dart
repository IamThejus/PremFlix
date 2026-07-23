import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/services/device_identity_service.dart';
import 'core/services/media_cache_service.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/app_theme.dart';

/// App bootstrap.
///
/// Everything that must be ready before the first frame happens here:
/// Hive (so theme/preferences reads are synchronous), media_kit's native
/// libraries, and system chrome. Services initialized here are injected
/// via provider overrides — features receive fully-constructed
/// dependencies and never deal with async initialization themselves.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Native libmpv bindings for the video player.
  MediaKit.ensureInitialized();

  // Desktop window: sane minimum size, branded title, and the manager
  // the player's fullscreen toggle relies on.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('PremFlix');
    await windowManager.setMinimumSize(const Size(480, 360));
  }

  // Transparent status bar over the dark canvas.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);

  await Hive.initFlutter();
  final preferences = await PreferencesService.open();
  final deviceIdentity = await DeviceIdentityService.initialize(preferences);
  final mediaCache = await MediaCacheService.open();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferences),
        deviceIdentityProvider.overrideWithValue(deviceIdentity),
        mediaCacheProvider.overrideWithValue(mediaCache),
      ],
      child: const PremFlixApp(),
    ),
  );
}
