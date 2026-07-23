import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'preferences_service.dart';

/// Identifies this installation to Jellyfin.
///
/// Jellyfin issues access tokens *per device*, keyed by the `DeviceId`
/// sent in the `Authorization: MediaBrowser ...` header. The id is
/// generated once and persisted so re-logins reuse the same server-side
/// device entry instead of piling up ghosts in the server dashboard.
class DeviceIdentityService {
  const DeviceIdentityService({
    required this.deviceId,
    required this.deviceName,
    required this.appVersion,
  });

  static const String clientName = 'PremFlix';
  static const String _deviceIdKey = 'device_id';

  final String deviceId;
  final String deviceName;
  final String appVersion;

  /// Gathers device name and app version, generating (and persisting)
  /// the stable device id on first launch. Called once at bootstrap.
  static Future<DeviceIdentityService> initialize(
    PreferencesService preferences,
  ) async {
    var deviceId = preferences.getString(_deviceIdKey);
    if (deviceId == null) {
      final random = Random.secure();
      deviceId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await preferences.setString(_deviceIdKey, deviceId);
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final deviceName = await _resolveDeviceName();

    return DeviceIdentityService(
      deviceId: deviceId,
      deviceName: deviceName,
      appVersion: packageInfo.version,
    );
  }

  static Future<String> _resolveDeviceName() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return info.model;
    }
    if (Platform.isLinux) {
      final info = await plugin.linuxInfo;
      return info.prettyName;
    }
    if (Platform.isWindows) {
      final info = await plugin.windowsInfo;
      return info.computerName;
    }
    if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      return info.computerName;
    }
    return 'Unknown Device';
  }

  /// Builds the `Authorization` header value in Jellyfin's MediaBrowser
  /// scheme. Sent without [token] for `AuthenticateByName` (the server
  /// requires client identity to issue a token) and with it afterwards.
  String authorizationHeader({String? token}) {
    // Header values are quoted; strip quotes from free-form strings like
    // the device name so a `"` in a hostname can't break the header.
    String sanitize(String value) => value.replaceAll('"', '');
    final buffer = StringBuffer(
      'MediaBrowser Client="$clientName", '
      'Device="${sanitize(deviceName)}", '
      'DeviceId="$deviceId", '
      'Version="$appVersion"',
    );
    if (token != null) {
      buffer.write(', Token="$token"');
    }
    return buffer.toString();
  }
}

/// Overridden at bootstrap with the initialized instance.
final deviceIdentityProvider = Provider<DeviceIdentityService>(
  (ref) => throw UnimplementedError(
    'deviceIdentityProvider must be overridden at bootstrap',
  ),
);
