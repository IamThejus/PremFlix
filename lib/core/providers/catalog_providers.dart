import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../repositories/library_repository.dart';
import 'library_providers.dart';

/// Identifies one catalog row. A record (value-equality built in) so it
/// works directly as a [FutureProvider.family] key without a hand-written
/// `==`/`hashCode`.
///
/// [type] is one of: `trending`, `recent`, `popular`, `resume`, `nextup`,
/// `genre`. [genre] is only meaningful when `type == 'genre'`.
typedef CatalogRowKey = ({String type, MediaKind kind, String? genre});

/// One catalog row's items, resolved from the shared [LibraryRepository]
/// (and therefore its cache). The Movies and TV pages are both built
/// entirely from this one family — no per-page provider duplication.
///
/// Only the resume-sensitive rows watch [libraryRefreshTickProvider], so
/// finishing playback refreshes Continue Watching / Next Up without
/// re-fetching every genre row.
final catalogRowProvider =
    FutureProvider.family<List<MediaItem>, CatalogRowKey>((ref, key) async {
  final repo = ref.watch(libraryRepositoryProvider);
  switch (key.type) {
    case 'trending':
      return repo.trendingByType(key.kind);
    case 'recent':
      return repo.latest(key.kind);
    case 'popular':
      return repo.popular(key.kind);
    case 'genre':
      return repo.byGenre(key.kind, key.genre ?? '');
    case 'resume':
      final bypass = ref.watch(libraryRefreshTickProvider) > 0;
      final all = await repo.resumeItems(refresh: bypass);
      return all.where((item) {
        // The Movies page wants in-progress movies; the TV page wants
        // in-progress episodes (and any series-level resume).
        if (key.kind == MediaKind.movie) return item.kind == MediaKind.movie;
        return item.isEpisode || item.kind == MediaKind.series;
      }).toList();
    case 'nextup':
      final bypass = ref.watch(libraryRefreshTickProvider) > 0;
      return repo.nextUp(refresh: bypass);
    default:
      return const <MediaItem>[];
  }
});

/// A titled row on a catalog page: what to show ([key]) and how ([wide]).
class CatalogSection {
  const CatalogSection(this.title, this.key, {this.wide = false});

  final String title;
  final CatalogRowKey key;

  /// 16:9 episode cards (Continue Watching / Next Up) vs. 2:3 posters.
  final bool wide;

  /// Unique hero-tag namespace so an item appearing in two rows on the
  /// same page never produces duplicate [Hero] tags.
  String get heroContext =>
      'cat-${key.type}-${key.kind.name}-${key.genre ?? ''}';
}
