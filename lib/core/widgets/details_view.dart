import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_exception.dart';
import '../api/image_url_builder.dart';
import '../models/media_item.dart';
import '../providers/library_providers.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/accent_button.dart';
import '../widgets/entrance_reveal.dart';
import '../widgets/jellyfin_image.dart';
import '../widgets/shimmer.dart';
import '../widgets/user_data_buttons.dart';

/// Shared chassis for movie, series, and collection detail pages.
///
/// Renders the cinematic top (full-bleed backdrop melting into the
/// canvas, poster with optional hero flight, title/logo, meta, genres,
/// action row, overview) and lets each screen inject its own sections
/// below via [sectionsBuilder] (series adds seasons/episodes; every
/// screen adds its rails).
///
/// Paints in layers of freshness: if the navigation carried a [preview]
/// item, the page renders instantly from row data and quietly upgrades
/// in place when the full record (cast, taglines) arrives — the hero
/// flight lands on real content, never a spinner.
class DetailsView extends ConsumerWidget {
  const DetailsView({
    super.key,
    required this.itemId,
    this.preview,
    this.heroTag,
    this.onPlay,
    this.sectionsBuilder,
  });

  final String itemId;
  final MediaItem? preview;
  final String? heroTag;

  /// Invoked with the freshest item when Play/Resume is pressed.
  final void Function(MediaItem item)? onPlay;

  /// Extra content below the overview (season browsers, rails).
  final List<Widget> Function(MediaItem item)? sectionsBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(itemDetailsProvider(itemId));
    final item = detailsAsync.value ?? preview;

    if (item == null) {
      // Deep link with no preview: full-page skeleton or error.
      return Scaffold(
        body: detailsAsync.hasError
            ? _ErrorState(
                error: detailsAsync.error,
                onRetry: () => ref.invalidate(itemDetailsProvider(itemId)),
              )
            : const _PageSkeleton(),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _DetailsHeader(
                  item: item,
                  heroTag: heroTag,
                  onPlay: onPlay == null ? null : () => onPlay!(item),
                ),
              ),
              if (item.overview?.isNotEmpty ?? false)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pageInset,
                      8,
                      context.pageInset,
                      34,
                    ),
                    child: EntranceReveal(
                      delay: const Duration(milliseconds: 120),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.taglines.isNotEmpty) ...[
                              Text(
                                item.taglines.first,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              item.overview!,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (sectionsBuilder != null)
                ...sectionsBuilder!(item)
                    .map((section) => SliverToBoxAdapter(child: section)),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
          const _FrostedBackButton(),
        ],
      ),
    );
  }
}

/// Backdrop + poster + title block + actions, overlapped so the poster
/// straddles the backdrop's bottom edge.
class _DetailsHeader extends ConsumerWidget {
  const _DetailsHeader({
    required this.item,
    required this.heroTag,
    required this.onPlay,
  });

  final MediaItem item;
  final String? heroTag;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(imageUrlBuilderProvider);
    final theme = Theme.of(context);
    final inset = context.pageInset;
    final compact = context.isCompact;

    final backdropHeight = compact
        ? 260.0
        : (MediaQuery.sizeOf(context).height * 0.45).clamp(300.0, 520.0);
    final posterWidth = compact ? 120.0 : 180.0;
    final overlap = compact ? 60.0 : 90.0;

    final meta = <InlineSpan>[
      if (item.year != null) TextSpan(text: '${item.year}'),
      if (item.runtime != null)
        TextSpan(text: formatRuntime(item.runtime!)),
      if (item.communityRating != null)
        TextSpan(
          children: [
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 3),
                child:
                    Icon(Icons.star_rounded, size: 15, color: Colors.amber),
              ),
            ),
            TextSpan(text: formatRating(item.communityRating!)),
          ],
        ),
    ];

    final resume = item.userData?.inProgress ?? false;
    final playLabel = resume && item.runtime != null
        ? 'Resume · ${formatRemaining(item.runtime!, item.userData!.playbackPosition)}'
        : (resume ? 'Resume' : 'Play');

    Widget poster = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: JellyfinImage(url: images.poster(item, maxWidth: 500)),
      ),
    );
    if (heroTag != null) {
      poster = Hero(tag: heroTag!, child: poster);
    }

    return Stack(
      children: [
        // Backdrop with scrims that melt into the canvas.
        SizedBox(
          height: backdropHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              JellyfinImage(
                url: images.backdrop(item, maxWidth: 1920),
                fallbackIcon: Icons.theaters_outlined,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1],
                    colors: [Color(0x330A0A0A), AppColors.background],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Content block overlapping the backdrop's lower edge.
        Padding(
          padding: EdgeInsets.fromLTRB(
            inset,
            backdropHeight - overlap - (compact ? 40 : 80),
            inset,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: posterWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: poster,
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EntranceReveal(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: compact
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.displayMedium,
                          ),
                        ),
                        const SizedBox(height: 10),
                        EntranceReveal(
                          delay: const Duration(milliseconds: 60),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    for (var index = 0;
                                        index < meta.length;
                                        index++) ...[
                                      if (index > 0)
                                        const TextSpan(text: '   ·   '),
                                      meta[index],
                                    ],
                                  ],
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                              if (item.officialRating != null)
                                _RatingChip(label: item.officialRating!),
                            ],
                          ),
                        ),
                        if (item.genres.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          EntranceReveal(
                            delay: const Duration(milliseconds: 120),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final genre in item.genres.take(5))
                                  _GenreChip(label: genre),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              EntranceReveal(
                delay: const Duration(milliseconds: 180),
                child: Row(
                  children: [
                    SizedBox(
                      width: resume ? 230 : 170,
                      child: AccentButton(
                        label: playLabel,
                        icon: Icons.play_arrow_rounded,
                        onPressed: onPlay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FavoriteButton(
                      itemId: item.id,
                      initialValue: item.userData?.isFavorite ?? false,
                    ),
                    const SizedBox(width: 12),
                    WatchedButton(
                      itemId: item.id,
                      initialValue: item.userData?.played ?? false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textTertiary),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall!
            .copyWith(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

/// Frosted circular back button floating over the backdrop.
class _FrostedBackButton extends StatelessWidget {
  const _FrostedBackButton();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.black.withValues(alpha: 0.35),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.pop(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_rounded, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-page skeleton for deep links (no preview item to paint from).
class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    final inset = context.pageInset;

    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            width: double.infinity,
            height: 300,
            borderRadius: 0,
          ),
          Padding(
            padding: EdgeInsets.all(inset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 150, height: 225, borderRadius: 14),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        width: MediaQuery.sizeOf(context).width * 0.3,
                        height: 32,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 14),
                      const SkeletonBox(
                          width: 200, height: 14, borderRadius: 7),
                      const SizedBox(height: 10),
                      const SkeletonBox(
                          width: 260, height: 14, borderRadius: 7),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail fetch failed with nothing to show — explain and offer retry.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Something went wrong loading this title.';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          SizedBox(
            width: 160,
            child: AccentButton(label: 'Try Again', onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}
