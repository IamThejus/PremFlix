import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/widgets/continue_watching_card.dart';
import '../models/media_item.dart';
import '../utils/responsive.dart';
import 'entrance_reveal.dart';
import 'media_card.dart';
import 'shimmer.dart';

/// The canonical horizontal media rail: a titled, edge-to-edge scrolling
/// row of cards driven by an [AsyncValue].
///
/// This is the single implementation behind every rail in the app — the
/// home rows, the "More Like This" details rail, and the genre rows on
/// the Movies/TV catalog pages all delegate here, so card sizing, focus
/// behavior, skeletons, empty-collapse, and entrance animation stay
/// identical everywhere.
///
/// States:
///  * loading — shimmering skeletons in the row's card geometry
///  * empty / error — collapses to nothing (a half-broken server or a
///    missing genre still yields a clean page)
///  * data — cards slide in with a staggered entrance reveal
///
/// [wide] switches between 16:9 episode cards (Continue Watching / Next
/// Up) and 2:3 posters. On TV the cards and the gaps grow, matching the
/// living-room viewing distance.
class HorizontalMediaRail extends StatelessWidget {
  const HorizontalMediaRail({
    super.key,
    required this.title,
    required this.items,
    required this.heroContext,
    this.wide = false,
    this.onItemTap,
  });

  final String title;
  final AsyncValue<List<MediaItem>> items;

  /// Namespaces hero tags so the same item in two rails never collides.
  final String heroContext;

  /// 16:9 episode stills instead of 2:3 posters.
  final bool wide;

  /// [heroTag] is non-null only for poster cards (wide cards carry no
  /// Hero); forward it to detail navigation for the shared-element flight.
  final void Function(MediaItem item, String? heroTag)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final inset = context.pageInset;
    final tv = context.isTv;
    final baseWidth = context.posterWidth * (tv ? 1.12 : 1.0);
    final cardWidth = wide ? baseWidth * 1.9 : baseWidth;
    // Poster cards: 2:3 art + two text lines. Wide cards: 16:9 art only.
    final rowHeight = wide ? cardWidth * 9 / 16 : cardWidth * 3 / 2 + 52;
    final gap = tv ? 20.0 : 14.0;

    return items.when(
      skipLoadingOnRefresh: true,
      loading: () => _RailScaffold(
        title: title,
        height: rowHeight,
        child: Shimmer(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: inset),
            itemCount: 8,
            separatorBuilder: (context, index) => SizedBox(width: gap),
            itemBuilder: (context, index) => wide
                ? ContinueWatchingCardSkeleton(width: cardWidth)
                : MediaCardSkeleton(width: cardWidth),
          ),
        ),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (loaded) {
        if (loaded.isEmpty) return const SizedBox.shrink();
        return EntranceReveal(
          child: _RailScaffold(
            title: title,
            height: rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: inset),
              itemCount: loaded.length,
              separatorBuilder: (context, index) => SizedBox(width: gap),
              itemBuilder: (context, index) {
                final item = loaded[index];
                return wide
                    ? ContinueWatchingCard(
                        item: item,
                        width: cardWidth,
                        onTap: onItemTap == null
                            ? null
                            : () => onItemTap!(item, null),
                      )
                    : MediaCard(
                        item: item,
                        width: cardWidth,
                        heroContext: heroContext,
                        onTap: onItemTap == null
                            ? null
                            : () => onItemTap!(
                                item, 'poster-$heroContext-${item.id}'),
                      );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Shared header + fixed-height body used by both the skeleton and data
/// states, so the layout never jumps when content arrives.
class _RailScaffold extends StatelessWidget {
  const _RailScaffold({
    required this.title,
    required this.height,
    required this.child,
  });

  final String title;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: context.pageInset,
              right: context.pageInset,
              bottom: 14,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}
