import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/providers/library_providers.dart';
import '../../../../core/repositories/library_repository.dart';

/// The rows on the home screen, in display order.
///
/// Each row is an independent [FutureProvider] (via [homeRowProvider]),
/// so rows stream onto the screen as their requests land instead of the
/// slowest request gating the whole page. Rows that error or come back
/// empty simply don't render — a half-broken server still yields a
/// working home screen.
enum HomeRowKind {
  continueWatching('Continue Watching', wide: true),
  nextUp('Next Up', wide: true),
  trending('Trending Now'),
  newMovies('New Movies'),
  newShows('New Shows'),
  collections('Collections'),
  favorites('Favorites');

  const HomeRowKind(this.title, {this.wide = false});

  /// Section header shown above the row.
  final String title;

  /// Wide 16:9 cards (episode stills) instead of 2:3 posters.
  final bool wide;
}

/// Backdrop-worthy items for the hero banner.
final heroItemsProvider = FutureProvider<List<MediaItem>>(
  (ref) => ref.watch(libraryRepositoryProvider).heroCandidates(),
);

/// One home row's items. Repository-level caching makes re-reads after
/// invalidation instant when data hasn't changed.
final homeRowProvider =
    FutureProvider.family<List<MediaItem>, HomeRowKind>((ref, kind) {
  final library = ref.watch(libraryRepositoryProvider);
  // Resume-sensitive rows re-fetch (bypassing the cache TTL) when
  // playback ends, so Continue Watching reflects the session just ended.
  final tick = ref.watch(libraryRefreshTickProvider);
  final bypassTtl = tick > 0;
  return switch (kind) {
    HomeRowKind.continueWatching => library.resumeItems(refresh: bypassTtl),
    HomeRowKind.nextUp => library.nextUp(refresh: bypassTtl),
    HomeRowKind.trending => library.trending(),
    HomeRowKind.newMovies => library.latest(MediaKind.movie),
    HomeRowKind.newShows => library.latest(MediaKind.series),
    HomeRowKind.collections => library.collections(),
    HomeRowKind.favorites => library.favorites(),
  };
});

/// Forces every home section past the cache TTL: refetches all rows from
/// the network (updating the cache), then invalidates the providers so
/// the UI re-reads the now-fresh cache. Used by pull-to-refresh; rows
/// keep showing current data while the refresh is in flight, and a
/// failed refresh quietly leaves cached content in place.
Future<void> refreshHome(Ref ref) async {
  final library = ref.read(libraryRepositoryProvider);
  await Future.wait([
    library.heroCandidates(refresh: true),
    library.resumeItems(refresh: true),
    library.nextUp(refresh: true),
    library.trending(refresh: true),
    library.latest(MediaKind.movie, refresh: true),
    library.latest(MediaKind.series, refresh: true),
    library.collections(refresh: true),
    library.favorites(refresh: true),
  ].map(_swallowErrors));
  ref
    ..invalidate(heroItemsProvider)
    ..invalidate(homeRowProvider);
}

/// A pull-to-refresh where one row 404s must not blow up the gesture.
Future<void> _swallowErrors(Future<Object?> future) async {
  try {
    await future;
  } on Object {
    // Row keeps its cached content; the provider will surface the same
    // data it already shows.
  }
}

/// Riverpod-callable wrapper for [refreshHome] so widgets can invoke it
/// through `ref.read(homeRefresherProvider)()`.
final homeRefresherProvider = Provider<Future<void> Function()>(
  (ref) => () => refreshHome(ref),
);
