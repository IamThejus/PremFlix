import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/image_url_builder.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'jellyfin_image.dart';
import 'shimmer.dart';

/// Standard 2:3 poster card used in rows, grids, and search results.
///
/// Feedback model (shared across pointer, touch, and d-pad):
///  * hover/focus — lifts to 105% with an accent glow; focus additionally
///    draws a white ring, which is the TV focus indicator.
///  * press — settles back to 100% for a tactile dip.
///
/// The poster carries a `Hero` tag (`poster-<id>`) so detail pages can
/// play the shared-element transition from wherever the card was.
class MediaCard extends ConsumerStatefulWidget {
  const MediaCard({
    super.key,
    required this.item,
    required this.width,
    this.onTap,
    this.heroContext = '',
  });

  final MediaItem item;
  final double width;
  final VoidCallback? onTap;

  /// Disambiguates hero tags when the same item appears in several rows
  /// (an item can be both "Trending" and a "Favorite").
  final String heroContext;

  @override
  ConsumerState<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<MediaCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _lifted => (_hovered || _focused) && !_pressed;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final images = ref.watch(imageUrlBuilderProvider);
    final theme = Theme.of(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    final caption = item.isEpisode
        ? [item.seriesName, item.episodeLabel]
            .whereType<String>()
            .where((part) => part.isNotEmpty)
            .join(' · ')
        : item.year?.toString() ?? '';

    return FocusableActionDetector(
      enabled: widget.onTap != null,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap?.call(),
        ),
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          // Larger lift on TV — the focus indicator must read across a
          // living room, per the D-pad focus spec.
          scale: _lifted ? (context.isTv ? 1.08 : 1.05) : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'poster-${widget.heroContext}-${item.id}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _focused
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (_lifted)
                          BoxShadow(
                            color:
                                context.accent.withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            JellyfinImage(
                              url: images.poster(item),
                              memCacheWidth:
                                  (widget.width * devicePixelRatio).round(),
                            ),
                            if (item.progress != null)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: _ProgressBar(value: item.progress!),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium!.copyWith(fontSize: 14),
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin accent progress bar pinned to the bottom edge of artwork.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.02, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: context.accentGradient),
        ),
      ),
    );
  }
}

/// Skeleton matching [MediaCard]'s geometry, shown while a row loads.
class MediaCardSkeleton extends StatelessWidget {
  const MediaCardSkeleton({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(aspectRatio: 2 / 3, child: SkeletonBox()),
          const SizedBox(height: 8),
          SkeletonBox(width: width * 0.7, height: 12, borderRadius: 6),
          const SizedBox(height: 6),
          SkeletonBox(width: width * 0.4, height: 10, borderRadius: 5),
        ],
      ),
    );
  }
}
