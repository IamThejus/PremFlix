import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/image_url_builder.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/jellyfin_image.dart';
import '../../../../core/widgets/shimmer.dart';

/// Wide 16:9 card for Continue Watching / Next Up rows.
///
/// Shows the episode still (or movie backdrop) with a bottom gradient,
/// title, episode label, and an accent resume bar. A play glyph fades in
/// over the artwork on hover/focus — the card's whole promise is "tap to
/// resume", so the affordance appears exactly when the user considers it.
class ContinueWatchingCard extends ConsumerStatefulWidget {
  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.width,
    this.onTap,
  });

  final MediaItem item;
  final double width;
  final VoidCallback? onTap;

  @override
  ConsumerState<ContinueWatchingCard> createState() =>
      _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
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

    final subtitle = item.isEpisode
        ? [item.episodeLabel, item.name]
            .where((part) => part.isNotEmpty)
            .join('  ')
        : item.year?.toString() ?? '';
    final title = item.isEpisode ? (item.seriesName ?? item.name) : item.name;

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
          scale: _lifted ? 1.04 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                if (_lifted)
                  BoxShadow(
                    color: context.accent.withValues(alpha: 0.3),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    JellyfinImage(
                      url: images.backdrop(item, maxWidth: 640),
                      memCacheWidth:
                          (widget.width * devicePixelRatio).round(),
                    ),
                    // Legibility gradient behind the text block.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 1],
                          colors: [Colors.transparent, Color(0xD9000000)],
                        ),
                      ),
                    ),
                    // Resume affordance on hover/focus.
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _lifted ? 1 : 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                            border: Border.all(color: Colors.white70),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium!
                                .copyWith(fontSize: 15),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          if (item.progress != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 4,
                                child: ColoredBox(
                                  color: Colors.white
                                      .withValues(alpha: 0.25),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: item.progress!
                                          .clamp(0.02, 1.0),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient:
                                              context.accentGradient,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton matching [ContinueWatchingCard]'s geometry.
class ContinueWatchingCardSkeleton extends StatelessWidget {
  const ContinueWatchingCardSkeleton({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: const AspectRatio(
        aspectRatio: 16 / 9,
        child: SkeletonBox(borderRadius: 14),
      ),
    );
  }
}
