import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Thin wrapper around the Hive `preferences` box.
///
/// Centralizing box access here means feature code never touches Hive
/// directly, keys live in one place, and the storage backend could be
/// swapped without touching any feature.
class PreferencesService {
  PreferencesService(this._box);

  static const String boxName = 'preferences';

  static const String accentKey = 'accent_preset';
  static const String searchHistoryKey = 'search_history';
  static const String playbackQualityKey = 'playback_quality';

  final Box<dynamic> _box;

  /// Opens the backing box. Called once during app bootstrap, before
  /// `runApp`, so every read afterwards is synchronous.
  static Future<PreferencesService> open() async =>
      PreferencesService(await Hive.openBox<dynamic>(boxName));

  String? getString(String key) => _box.get(key) as String?;

  Future<void> setString(String key, String value) => _box.put(key, value);

  List<String> getStringList(String key) =>
      (_box.get(key) as List?)?.cast<String>() ?? const [];

  Future<void> setStringList(String key, List<String> value) =>
      _box.put(key, value);

  Future<void> remove(String key) => _box.delete(key);
}

/// Overridden in `main` with the opened instance; throwing by default
/// makes a missed bootstrap override fail loudly instead of silently.
final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => throw UnimplementedError(
    'preferencesServiceProvider must be overridden at bootstrap',
  ),
);
