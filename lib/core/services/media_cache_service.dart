import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/media_item.dart';

/// Hive-backed cache for library query results.
///
/// Entries are stored as JSON in the *wire format*, so cached items are
/// decoded by the exact same [MediaItem.fromJson] parser as network
/// responses — one parser, zero drift between cold-start and live data.
///
/// Two roles:
///  * **Instant paint** — [peekList] gives the home screen data on the
///    first frame after a cold start.
///  * **Offline fallback** — repositories serve stale entries when the
///    server is unreachable.
///
/// Keys are prefixed with the user id by the repositories, so switching
/// accounts on the same device never shows another user's rows.
class MediaCacheService {
  MediaCacheService(this._box);

  static const String boxName = 'media_cache';

  final Box<String> _box;

  static Future<MediaCacheService> open() async =>
      MediaCacheService(await Hive.openBox<String>(boxName));

  /// Cached list plus its age, or null when never cached / corrupt.
  ({List<MediaItem> items, DateTime fetchedAt})? peekList(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      return (
        items: (envelope['items'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MediaItem.fromJson)
            .toList(),
        fetchedAt: DateTime.parse(envelope['fetchedAt'] as String),
      );
    } on Object {
      // Corrupt/legacy entry: drop it and treat as a miss.
      _box.delete(key);
      return null;
    }
  }

  Future<void> putList(String key, List<MediaItem> items) => _box.put(
        key,
        jsonEncode({
          'fetchedAt': DateTime.now().toIso8601String(),
          'items': items.map((item) => item.toJson()).toList(),
        }),
      );

  /// Wipes everything — used on sign-out so the next account starts clean.
  Future<void> clear() => _box.clear();
}

/// Overridden at bootstrap with the opened instance.
final mediaCacheProvider = Provider<MediaCacheService>(
  (ref) => throw UnimplementedError(
    'mediaCacheProvider must be overridden at bootstrap',
  ),
);
