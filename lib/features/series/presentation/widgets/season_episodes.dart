import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/image_url_builder.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/providers/library_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/jellyfin_image.dart';
import '../../../../core/widgets/shimmer.dart';

/// Season picker + episode list for a series detail page.
///
/// Seasons render as a horizontal chip strip; the selected season's
/// episodes list below with still, number, overview, runtime, watched
/// state, and resume progress. Episode data loads per season on demand
/// — a 20-season series never fetches everything up front.
class SeasonEpisodes extends ConsumerStatefulWidget {
  const SeasonEpisodes({
    super.key,
    required this.seriesId,
    this.onEpisodeTap,
  });

  final String seriesId;
  final void Function(MediaItem episode)? onEpisodeTap;

  @override
  ConsumerState<SeasonEpisodes> createState() => _SeasonEpisodesState();
}

class _SeasonEpisodesState extends ConsumerState<SeasonEpisodes> {
  String? _selectedSeasonId;

  @override
  Widget build(BuildContext context) {
    final seasonsAsync = ref.watch(seasonsProvider(widget.seriesId));
    final inset = context.pageInset;
    final theme = Theme.of(context);

    return seasonsAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: const Shimmer(
          child: Row(
            children: [
              SkeletonBox(width: 110, height: 38, borderRadius: 19),
              SizedBox(width: 10),
              SkeletonBox(width: 110, height: 38, borderRadius: 19),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (seasons) {
        if (seasons.isEmpty) return const SizedBox.shrink();
        final selectedId = _selectedSeasonId ?? seasons.first.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: inset, right: inset, bottom: 14),
              child: Text('Episodes', style: theme.textTheme.headlineMedium),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: inset),
                itemCount: seasons.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final season = seasons[index];
                  return _SeasonChip(
                    label: season.name,
                    selected: season.id == selectedId,
                    onTap: () =>
                        setState(() => _selectedSeasonId = season.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _EpisodeList(
              seriesId: widget.seriesId,
              seasonId: selectedId,
              onEpisodeTap: widget.onEpisodeTap,
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }
}

class _SeasonChip extends StatefulWidget {
  const _SeasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;

    return FocusableActionDetector(
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected
                ? accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: _hovered ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? accent
                  : _focused
                      ? Colors.white
                      : AppColors.border,
              width: widget.selected || _focused ? 1.4 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  fontSize: 14,
                  color: widget.selected ? Colors.white : AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeList extends ConsumerWidget {
  const _EpisodeList({
    required this.seriesId,
    required this.seasonId,
    required this.onEpisodeTap,
  });

  final String seriesId;
  final String seasonId;
  final void Function(MediaItem episode)? onEpisodeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = ref.watch(
      episodesProvider((seriesId: seriesId, seasonId: seasonId)),
    );
    final inset = context.pageInset;

    return episodesAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Shimmer(
          child: Column(
            children: [
              for (var index = 0; index < 4; index++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SkeletonBox(width: 150, height: 84, borderRadius: 10),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(
                                width: 180, height: 14, borderRadius: 7),
                            SizedBox(height: 8),
                            SkeletonBox(
                                width: 240, height: 12, borderRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (episodes) => Column(
        children: [
          for (final episode in episodes)
            _EpisodeTile(
              episode: episode,
              onTap: onEpisodeTap == null
                  ? null
                  : () => onEpisodeTap!(episode),
            ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends ConsumerStatefulWidget {
  const _EpisodeTile({required this.episode, required this.onTap});

  final MediaItem episode;
  final VoidCallback? onTap;

  @override
  ConsumerState<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends ConsumerState<_EpisodeTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final images = ref.watch(imageUrlBuilderProvider);
    final theme = Theme.of(context);
    final inset = context.pageInset;
    final watched = episode.userData?.played ?? false;

    final title = [
      if (episode.indexNumber != null) '${episode.indexNumber}.',
      episode.name,
    ].join(' ');

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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: inset - 10, vertical: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hovered || _focused
                ? AppColors.cardHighlight
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 150,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        JellyfinImage(
                          url: images.backdrop(episode, maxWidth: 400),
                        ),
                        // Resume affordance appears on hover/focus.
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: _hovered || _focused ? 1 : 0,
                          child: const ColoredBox(
                            color: Color(0x66000000),
                            child: Icon(Icons.play_arrow_rounded, size: 34),
                          ),
                        ),
                        if (episode.progress != null)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              height: 3.5,
                              child: ColoredBox(
                                color:
                                    Colors.black.withValues(alpha: 0.5),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: episode.progress!
                                        .clamp(0.02, 1.0),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: context.accentGradient,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium!
                                .copyWith(fontSize: 15),
                          ),
                        ),
                        if (watched)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                    if (episode.runtime != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        formatRuntime(episode.runtime!),
                        style: theme.textTheme.bodySmall!
                            .copyWith(fontSize: 12),
                      ),
                    ],
                    if (episode.overview?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(
                        episode.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
