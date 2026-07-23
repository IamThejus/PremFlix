import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/repositories/library_repository.dart';
import '../../../../core/services/preferences_service.dart';

/// Search results grouped for the categorized results view.
class SearchResults {
  const SearchResults({
    this.movies = const [],
    this.series = const [],
    this.episodes = const [],
  });

  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<MediaItem> episodes;

  bool get isEmpty => movies.isEmpty && series.isEmpty && episodes.isEmpty;

  factory SearchResults.group(List<MediaItem> items) => SearchResults(
        movies: items.where((i) => i.kind == MediaKind.movie).toList(),
        series: items.where((i) => i.kind == MediaKind.series).toList(),
        episodes: items.where((i) => i.kind == MediaKind.episode).toList(),
      );
}

/// Debounced real-time search.
///
/// Each keystroke calls [query]; the actual request fires 350 ms after
/// typing pauses. Stale responses are discarded by generation counting —
/// a slow response for "bat" can never overwrite results for "batman".
class SearchController extends AsyncNotifier<SearchResults> {
  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _debounceTimer;
  int _generation = 0;
  String _lastQuery = '';

  @override
  Future<SearchResults> build() async {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const SearchResults();
  }

  void query(String input) {
    final term = input.trim();
    if (term == _lastQuery) return;
    _lastQuery = term;
    _debounceTimer?.cancel();

    if (term.isEmpty) {
      _generation++;
      _setInFlight(false);
      state = const AsyncData(SearchResults());
      return;
    }

    // Previous results stay visible while the new request runs; the
    // screen shows a thin progress bar via [searchInFlightProvider]
    // instead of blanking the page into skeletons on every keystroke.
    _setInFlight(true);
    _debounceTimer = Timer(_debounce, () => _run(term));
  }

  Future<void> _run(String term) async {
    final generation = ++_generation;
    try {
      final items =
          await ref.read(libraryRepositoryProvider).search(term);
      if (generation != _generation) return;
      _setInFlight(false);
      state = AsyncData(SearchResults.group(items));
    } on Object catch (error, stackTrace) {
      if (generation != _generation) return;
      _setInFlight(false);
      state = AsyncError(error, stackTrace);
    }
  }

  void _setInFlight(bool value) =>
      ref.read(searchInFlightProvider.notifier).set(value);
}

/// True while a query is debouncing or awaiting the server — drives the
/// search bar's progress indicator without disturbing shown results.
class SearchInFlight extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final searchInFlightProvider =
    NotifierProvider<SearchInFlight, bool>(SearchInFlight.new);

final searchControllerProvider =
    AsyncNotifierProvider.autoDispose<SearchController, SearchResults>(
  SearchController.new,
);

/// Recent search terms, newest first, persisted across launches.
class RecentSearches extends Notifier<List<String>> {
  static const int _maxEntries = 10;

  @override
  List<String> build() => ref
      .watch(preferencesServiceProvider)
      .getStringList(PreferencesService.searchHistoryKey);

  Future<void> add(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final updated = [
      trimmed,
      ...state.where((entry) => entry.toLowerCase() != trimmed.toLowerCase()),
    ].take(_maxEntries).toList();
    state = updated;
    await ref
        .read(preferencesServiceProvider)
        .setStringList(PreferencesService.searchHistoryKey, updated);
  }

  Future<void> remove(String term) async {
    final updated = state.where((entry) => entry != term).toList();
    state = updated;
    await ref
        .read(preferencesServiceProvider)
        .setStringList(PreferencesService.searchHistoryKey, updated);
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);
