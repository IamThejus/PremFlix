import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/media_item.dart';
import '../services/media_cache_service.dart';
import '../services/session_controller.dart';

/// Read access to the Jellyfin library: home rows, item details,
/// seasons/episodes, collections, similar titles, and paged browsing.
///
/// Caching strategy (row queries): serve fresh cache when younger than
/// [_rowTtl]; otherwise hit the network and update the cache; if the
/// network fails with a transport-level error, fall back to stale cache
/// so the app keeps working offline. Controllers can force `refresh` to
/// bypass the freshness check (pull-to-refresh, returning from playback)
/// — a failed refresh still degrades to cache.
class LibraryRepository {
  LibraryRepository({
    required Dio api,
    required String userId,
    required MediaCacheService cache,
  })  : _api = api,
        _userId = userId,
        _cache = cache;

  final Dio _api;
  final String _userId;
  final MediaCacheService _cache;

  static const Duration _rowTtl = Duration(minutes: 5);

  /// Extra fields the default responses omit but the UI needs.
  static const String _listFields =
      'Overview,Genres,PrimaryImageAspectRatio,ParentId';

  // ---------------------------------------------------------------------
  // Home rows
  // ---------------------------------------------------------------------

  /// In-progress movies and episodes, most recent first.
  Future<List<MediaItem>> resumeItems({bool refresh = false}) => _cachedList(
        'resume',
        refresh: refresh,
        fetch: () async {
          final data = await _get('/Users/$_userId/Items/Resume', {
            'Limit': '12',
            'MediaTypes': 'Video',
            'Fields': _listFields,
          });
          return PagedItems.fromJson(data).items;
        },
      );

  /// Next episodes to watch across all shows.
  Future<List<MediaItem>> nextUp({bool refresh = false}) => _cachedList(
        'nextup',
        refresh: refresh,
        fetch: () async {
          final data = await _get('/Shows/NextUp', {
            'UserId': _userId,
            'Limit': '16',
            'Fields': _listFields,
          });
          return PagedItems.fromJson(data).items;
        },
      );

  /// Latest additions of [kind] (movie or series).
  Future<List<MediaItem>> latest(
    MediaKind kind, {
    bool refresh = false,
  }) =>
      _cachedList(
        'latest_${kind.wireName}',
        refresh: refresh,
        fetch: () async {
          // `/Items/Latest` returns a bare array, not a paged envelope.
          final response = await _api.get<List<dynamic>>(
            '/Users/$_userId/Items/Latest',
            queryParameters: {
              'IncludeItemTypes': kind.wireName,
              'Limit': '16',
              'Fields': _listFields,
            },
          );
          return (response.data ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(MediaItem.fromJson)
              .toList();
        },
      );

  /// Most-played items on the server — the "Trending" row.
  Future<List<MediaItem>> trending({bool refresh = false}) => _cachedList(
        'trending',
        refresh: refresh,
        fetch: () async => (await _pagedItems({
          'IncludeItemTypes': 'Movie,Series',
          'SortBy': 'PlayCount',
          'SortOrder': 'Descending',
          'Limit': '16',
        }))
            .items,
      );

  /// Most-played items of a single [kind] — "Trending Movies" / "Trending
  /// Shows" on the dedicated catalog pages.
  Future<List<MediaItem>> trendingByType(
    MediaKind kind, {
    bool refresh = false,
  }) =>
      _cachedList(
        'trending_${kind.wireName}',
        refresh: refresh,
        fetch: () async => (await _pagedItems({
          'IncludeItemTypes': kind.wireName,
          'SortBy': 'PlayCount',
          'SortOrder': 'Descending',
          'Limit': '20',
        }))
            .items,
      );

  /// Highest community-rated titles of [kind] — the "Popular" row.
  Future<List<MediaItem>> popular(
    MediaKind kind, {
    bool refresh = false,
  }) =>
      _cachedList(
        'popular_${kind.wireName}',
        refresh: refresh,
        fetch: () async => (await _pagedItems({
          'IncludeItemTypes': kind.wireName,
          'SortBy': 'CommunityRating',
          'SortOrder': 'Descending',
          'Limit': '20',
        }))
            .items,
      );

  /// Titles of [kind] tagged with [genre] — a genre row on a catalog page.
  /// Genres absent from the server yield an empty list, so the row simply
  /// collapses (rows never error on a missing genre).
  Future<List<MediaItem>> byGenre(
    MediaKind kind,
    String genre, {
    bool refresh = false,
  }) =>
      _cachedList(
        'genre_${kind.wireName}_$genre',
        refresh: refresh,
        fetch: () async => (await _pagedItems({
          'IncludeItemTypes': kind.wireName,
          'Genres': genre,
          'SortBy': 'SortName',
          'Limit': '24',
        }))
            .items,
      );

  /// The user's favorite movies and shows.
  Future<List<MediaItem>> favorites({bool refresh = false}) => _cachedList(
        'favorites',
        refresh: refresh,
        fetch: () async => (await _pagedItems({
          'IncludeItemTypes': 'Movie,Series',
          'Filters': 'IsFavorite',
          'SortBy': 'SortName',
          'Limit': '24',
        }))
            .items,
      );

  /// Library collections (box sets).
  Future<List<MediaItem>> collections({bool refresh = false}) => _cachedList(
        'collections',
        refresh: refresh,
        fetch: () async => (await _pagedItems({
          'IncludeItemTypes': 'BoxSet',
          'SortBy': 'SortName',
          'Limit': '24',
        }))
            .items,
      );

  /// A random backdrop-worthy title for the hero banner.
  Future<List<MediaItem>> heroCandidates({bool refresh = false}) =>
      _cachedList(
        'hero',
        refresh: refresh,
        fetch: () async => (await _pagedItems({
          'IncludeItemTypes': 'Movie,Series',
          'SortBy': 'Random',
          'Limit': '8',
          'ImageTypes': 'Backdrop',
          'Fields': '$_listFields,Taglines',
        }))
            .items,
      );

  // ---------------------------------------------------------------------
  // Browsing & details
  // ---------------------------------------------------------------------

  /// Paged browse of the library, sorted and filtered.
  ///
  /// Uncached: paged grids have their own scroll-position state, and
  /// callers paginate faster than any TTL would help.
  Future<PagedItems> browse({
    required MediaKind kind,
    String sortBy = 'SortName',
    String sortOrder = 'Ascending',
    String? genre,
    int startIndex = 0,
    int limit = 60,
  }) =>
      _pagedItems({
        'IncludeItemTypes': kind.wireName,
        'SortBy': sortBy,
        'SortOrder': sortOrder,
        'Genres': ?genre,
        'StartIndex': '$startIndex',
        'Limit': '$limit',
      });

  /// Full detail record for one item, including cast.
  Future<MediaItem> item(String itemId) async =>
      MediaItem.fromJson(await _get('/Users/$_userId/Items/$itemId', {}));

  /// Titles similar to [itemId] — the "More Like This" rail.
  Future<List<MediaItem>> similar(String itemId, {int limit = 12}) async {
    final data = await _get('/Items/$itemId/Similar', {
      'UserId': _userId,
      'Limit': '$limit',
      'Fields': _listFields,
    });
    return PagedItems.fromJson(data).items;
  }

  /// Seasons of a series, in order.
  Future<List<MediaItem>> seasons(String seriesId) async {
    final data = await _get('/Shows/$seriesId/Seasons', {
      'UserId': _userId,
      'Fields': _listFields,
    });
    return PagedItems.fromJson(data).items;
  }

  /// Episodes of one season.
  Future<List<MediaItem>> episodes(String seriesId, String seasonId) async {
    final data = await _get('/Shows/$seriesId/Episodes', {
      'UserId': _userId,
      'SeasonId': seasonId,
      'Fields': '$_listFields,Overview',
    });
    return PagedItems.fromJson(data).items;
  }

  /// Full-text search across movies, series, and episodes.
  ///
  /// Uncached: queries change with every keystroke and results must
  /// always be live. Relevance ordering comes from the server.
  Future<List<MediaItem>> search(String term, {int limit = 60}) async =>
      (await _pagedItems({
        'SearchTerm': term,
        'IncludeItemTypes': 'Movie,Series,Episode',
        'Limit': '$limit',
      }))
          .items;

  /// Items inside a collection.
  Future<List<MediaItem>> collectionItems(String collectionId) async =>
      (await _pagedItems({
        'ParentId': collectionId,
        'SortBy': 'SortName',
      }))
          .items;

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>(path, queryParameters: query);
      return response.data ?? const {};
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PagedItems> _pagedItems(Map<String, String?> query) async {
    final data = await _get('/Users/$_userId/Items', {
      'Recursive': 'true',
      'Fields': _listFields,
      for (final MapEntry(:key, :value) in query.entries) key: ?value,
    });
    return PagedItems.fromJson(data);
  }

  Future<List<MediaItem>> _cachedList(
    String key, {
    required bool refresh,
    required Future<List<MediaItem>> Function() fetch,
  }) async {
    final cacheKey = '${_userId}_$key';
    final cached = _cache.peekList(cacheKey);

    final fresh = cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _rowTtl;
    if (fresh && !refresh) return cached.items;

    try {
      final items = await fetch();
      await _cache.putList(cacheKey, items);
      return items;
    } on ApiException catch (error) {
      // Offline / flaky network: stale data beats an error screen.
      final transient = error.kind == ApiErrorKind.unreachable ||
          error.kind == ApiErrorKind.timeout;
      if (transient && cached != null) return cached.items;
      rethrow;
    }
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) {
    throw StateError('libraryRepositoryProvider read without a session');
  }
  return LibraryRepository(
    api: ref.watch(apiClientProvider),
    userId: session.userId,
    cache: ref.watch(mediaCacheProvider),
  );
});
