import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../repositories/library_repository.dart';

/// Detail-page providers over [LibraryRepository].
///
/// All are `autoDispose`: detail pages come and go, and holding every
/// visited item's cast list and similar rail alive for the whole session
/// would grow without bound. Revisits refetch — cheap single-item calls
/// on a local server.

/// Bumped after playback ends (and other user-data mutations that other
/// screens must see). Providers that show resume/watched state watch it,
/// so finishing an episode updates Continue Watching, detail pages, and
/// episode lists without any feature importing another feature.
class RefreshTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final libraryRefreshTickProvider =
    NotifierProvider<RefreshTick, int>(RefreshTick.new);

/// Full record for one item (overview, cast, taglines).
final itemDetailsProvider = FutureProvider.autoDispose
    .family<MediaItem, String>((ref, itemId) {
  ref.watch(libraryRefreshTickProvider);
  return ref.watch(libraryRepositoryProvider).item(itemId);
});

/// "More Like This" rail for an item.
final similarItemsProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>(
  (ref, itemId) => ref.watch(libraryRepositoryProvider).similar(itemId),
);

/// Seasons of a series, in order.
final seasonsProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>(
  (ref, seriesId) => ref.watch(libraryRepositoryProvider).seasons(seriesId),
);

/// Episodes of one season; keyed by (seriesId, seasonId). Watches the
/// refresh tick so watched/progress state updates after playback.
final episodesProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, ({String seriesId, String seasonId})>((ref, key) {
  ref.watch(libraryRefreshTickProvider);
  return ref
      .watch(libraryRepositoryProvider)
      .episodes(key.seriesId, key.seasonId);
});

/// Items inside a collection (box set).
final collectionItemsProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>(
  (ref, collectionId) =>
      ref.watch(libraryRepositoryProvider).collectionItems(collectionId),
);
