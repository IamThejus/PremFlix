import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

/// Persists the [AuthSession] in platform secure storage
/// (Keystore on Android, libsecret on Linux, DPAPI on Windows,
/// Keychain on macOS).
///
/// Credentials never touch Hive or shared preferences — this service is
/// the only place the access token is written to disk.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _sessionKey = 'premflix_session';

  final FlutterSecureStorage _storage;

  /// The stored session, or null when signed out / never signed in /
  /// the stored payload could not be decoded.
  Future<AuthSession?> readSession() async =>
      AuthSession.tryDecode(await _storage.read(key: _sessionKey));

  Future<void> writeSession(AuthSession session) =>
      _storage.write(key: _sessionKey, value: session.encode());

  Future<void> clearSession() => _storage.delete(key: _sessionKey);
}

final secureStorageProvider =
    Provider<SecureStorageService>((ref) => SecureStorageService());
