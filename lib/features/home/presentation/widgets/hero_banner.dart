import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/image_url_builder.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/accent_button.dart';
import '../../../../core/widgets/ghost_button.dart';
import '../../../../core/widgets/jellyfin_image.dart';
import '../../../../core/widgets/shimmer.dart';
import '../controllers/home_providers.dart';

/// The featured banner at the top of home.
///
/// Cycles through backdrop-worthy titles every eight seconds with a slow
/// cross-fade; the active backdrop plays a subtle Ken Burns zoom so the
/// banner never feels static. The next item's backdrop is prefetched
/// right after each switch, making every transition instant. The bottom
/// gradient fades into the page background, so the banner melts into the
/// rows below instead of ending at a hard edge.
class HeroBanner extends ConsumerStatefulWidget {
  const HeroBanner({
    super.key,
    required this.height,
    this.onPlay,
    this.onInfo,
  });

  final double height;
  final void Function(MediaItem item)? onPlay;
  final void Function(MediaItem item)? onInfo;

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> {
  static const Duration _cycleInterval = Duration(seconds: 8);

  Timer? _cycleTimer;
  int _index = 0;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  void _ensureCycling(List<MediaItem> items) {
    if (items.length < 2 || (_cycleTimer?.isActive ?? false)) return;
    _cycleTimer = Timer.periodic(_cycleInterval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % items.length);
      _prefetchNext(items);
    });
  }

  /// Warms the image cache for the upcoming backdrop so the cross-fade
  /// never reveals a loading frame.
  void _prefetchNext(List<MediaItem> items) {
    final next = items[(_index + 1) % items.length];
    final url = ref.read(imageUrlBuilderProvider).backdrop(next);
    if (url != null) {
      unawaited(
        precacheImage(CachedNetworkImageProvider(url), context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(heroItemsProvider);

    return SizedBox(
      height: widget.height,
      child: itemsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const Shimmer(
          child: SkeletonBox(borderRadius: 0),
        ),
        error: (error, stackTrace) =>
            const ColoredBox(color: AppColors.background),
        data: (items) {
          if (items.isEmpty) {
            return const ColoredBox(color: AppColors.background);
          }
          _ensureCycling(items);
          final item = items[_index % items.length];

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _HeroSlide(
              key: ValueKey(item.id),
              item: item,
              onPlay: widget.onPlay,
              onInfo: widget.onInfo,
              indicator: items.length < 2
                  ? null
                  : _CycleIndicator(
                      count: items.length,
                      active: _index % items.length,
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// One fully-composed hero frame: backdrop, scrims, and content block.
class _HeroSlide extends ConsumerWidget {
  const _HeroSlide({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onInfo,
    required this.indicator,
  });

  final MediaItem item;
  final void Function(MediaItem item)? onPlay;
  final void Function(MediaItem item)? onInfo;
  final Widget? indicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(imageUrlBuilderProvider);
    final theme = Theme.of(context);
    final inset = context.pageInset;
    final compact = context.isCompact;

    final meta = <String>[
      if (item.year != null) '${item.year}',
      if (item.runtime != null) formatRuntime(item.runtime!),
      ...item.genres.take(3),
    ];

    final logoUrl = images.logo(item);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Ken Burns: slow zoom from 105% → 112% over the slide's life.
        // Clipped, because Transform paints outside the hero's bounds
        // otherwise — the scaled backdrop would draw a stray strip of
        // artwork over the content below the banner.
        ClipRect(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.05, end: 1.12),
            duration: const Duration(seconds: 9),
            curve: Curves.linear,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: JellyfinImage(
              url: images.backdrop(item, maxWidth: 1920),
              fallbackIcon: Icons.theaters_outlined,
            ),
          ),
        ),
        // Bottom scrim: melts into the page background.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.45, 0.82, 1],
              colors: [
                Colors.transparent,
                Color(0xB30A0A0A),
                AppColors.background,
              ],
            ),
          ),
        ),
        // Side scrim: legibility for the text block.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0, 0.65],
              colors: [Color(0x99000000), Colors.transparent],
            ),
          ),
        ),
        Positioned(
          left: inset,
          right: inset,
          bottom: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compact ? double.infinity : 560,
                  maxHeight: 110,
                ),
                child: logoUrl != null
                    ? Align(
                        alignment: Alignment.bottomLeft,
                        child: JellyfinImage(
                          url: logoUrl,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: compact
                            ? theme.textTheme.displayMedium
                            : theme.textTheme.displayLarge,
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                meta.join('   ·   '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              if (!compact && (item.overview?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    item.overview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: AccentButton(
                      label: 'Play',
                      icon: Icons.play_arrow_rounded,
                      onPressed:
                          onPlay == null ? null : () => onPlay!(item),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GhostButton(
                    label: 'More Info',
                    icon: Icons.info_outline_rounded,
                    onPressed: onInfo == null ? null : () => onInfo!(item),
                  ),
                  if (indicator != null) ...[
                    const Spacer(),
                    indicator!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Minimal cycle position indicator: small bars, active one accent-tinted
/// and wider.
class _CycleIndicator extends StatelessWidget {
  const _CycleIndicator({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(left: 5),
            width: index == active ? 18 : 7,
            height: 3.5,
            decoration: BoxDecoration(
              color: index == active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
