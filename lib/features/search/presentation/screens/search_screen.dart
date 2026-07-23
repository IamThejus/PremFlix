import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/entrance_reveal.dart';
import '../../../../core/widgets/poster_rail.dart';
import '../../../shell/presentation/nav_metrics.dart';
import '../controllers/search_controller.dart';

/// Real-time library search.
///
/// The field autofocuses and searches as you type (debounced in the
/// controller). Results render as category rails — Movies, TV Shows,
/// Episodes — reusing the same poster cards as home, so tapping through
/// to details keeps the hero flight. With no query, recent searches
/// appear as tappable chips; a term is saved to history when the user
/// opens one of its results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.embedded = false});

  /// True when hosted as a shell tab (no back button; content insets
  /// under the floating top nav on larger screens).
  final bool embedded;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _fieldController = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  @override
  void dispose() {
    _fieldController.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _openResult(MediaItem item, String? heroTag) {
    // A result tap is the strongest signal a query was useful — that's
    // the moment it earns a history slot.
    ref.read(recentSearchesProvider.notifier).add(_fieldController.text);
    openMediaDetails(context, item, heroTag: heroTag);
  }

  void _applyRecent(String term) {
    _fieldController.text = term;
    _fieldController.selection =
        TextSelection.collapsed(offset: term.length);
    ref.read(searchControllerProvider.notifier).query(term);
    _fieldFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchControllerProvider);
    final inFlight = ref.watch(searchInFlightProvider);
    final hasQuery = _fieldController.text.trim().isNotEmpty;

    // As a tab on larger screens the floating top nav overlays the top,
    // so the field insets beneath it; on phones the tab has no top bar.
    final useBottomNav = context.isCompact && !context.isTv;
    final topInset =
        widget.embedded && !useBottomNav ? kPremFlixNavBarHeight : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchBar(
              controller: _fieldController,
              focusNode: _fieldFocus,
              inFlight: inFlight,
              showBack: !widget.embedded,
              topInset: topInset,
              onChanged: (value) {
                ref.read(searchControllerProvider.notifier).query(value);
                // Rebuild for the clear button / empty-state switch.
                setState(() {});
              },
              onClear: () {
                _fieldController.clear();
                ref.read(searchControllerProvider.notifier).query('');
                setState(() {});
                _fieldFocus.requestFocus();
              },
              onBack: () => context.pop(),
            ),
            Expanded(
              child: !hasQuery
                  ? _RecentSearches(onSelected: _applyRecent)
                  : resultsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => _Message(
                        icon: Icons.cloud_off_rounded,
                        text: 'Search failed. Check your connection.',
                      ),
                      data: (results) => results.isEmpty && !inFlight
                          ? _Message(
                              icon: Icons.search_off_rounded,
                              text:
                                  'Nothing found for "${_fieldController.text.trim()}"',
                            )
                          : ListView(
                              padding: const EdgeInsets.only(top: 20),
                              children: [
                                PosterRail(
                                  title: 'Movies',
                                  items: AsyncData(results.movies),
                                  heroContext: 'search-movies',
                                  onItemTap: _openResult,
                                ),
                                PosterRail(
                                  title: 'TV Shows',
                                  items: AsyncData(results.series),
                                  heroContext: 'search-series',
                                  onItemTap: _openResult,
                                ),
                                PosterRail(
                                  title: 'Episodes',
                                  items: AsyncData(results.episodes),
                                  heroContext: 'search-episodes',
                                  onItemTap: _openResult,
                                ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search input with back button, clear button, and a hairline progress
/// bar that runs while a query is in flight.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.inFlight,
    required this.showBack,
    required this.topInset,
    required this.onChanged,
    required this.onClear,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool inFlight;
  final bool showBack;
  final double topInset;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(height: topInset),
        Padding(
          padding: EdgeInsets.fromLTRB(
            showBack ? context.pageInset - 8 : context.pageInset,
            10,
            context.pageInset,
            10,
          ),
          child: Row(
            children: [
              if (showBack) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodyLarge,
                  cursorColor: context.accent,
                  decoration: InputDecoration(
                    hintText: 'Search movies, shows, episodes…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: AppColors.textTertiary,
                    ),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClear,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Hairline activity indicator; keeps results steady while the
        // next query runs.
        SizedBox(
          height: 2,
          child: inFlight
              ? LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: context.accent,
                  minHeight: 2,
                )
              : const SizedBox.expand(),
        ),
      ],
    );
  }
}

/// Recent search chips shown before any query is typed.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) {
      return _Message(
        icon: Icons.search_rounded,
        text: 'Search your library',
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pageInset,
        24,
        context.pageInset,
        24,
      ),
      children: [
        Text(
          'Recent Searches',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        EntranceReveal(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final term in recents)
                _RecentChip(
                  term: term,
                  onTap: () => onSelected(term),
                  onRemove: () => ref
                      .read(recentSearchesProvider.notifier)
                      .remove(term),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8, right: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(term, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.textTertiary),
          const SizedBox(height: 14),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
