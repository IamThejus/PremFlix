import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/library_providers.dart';
import '../../../../core/repositories/playback_repository.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/router/route_args.dart';
import '../../../../core/widgets/cast_rail.dart';
import '../../../../core/widgets/details_view.dart';
import '../../../../core/widgets/poster_rail.dart';
import '../widgets/season_episodes.dart';

/// Detail page for series: the shared chassis plus the season/episode
/// browser between overview and cast.
class SeriesDetailsScreen extends ConsumerWidget {
  const SeriesDetailsScreen({
    super.key,
    required this.itemId,
    required this.args,
  });

  final String itemId;
  final MediaDetailsArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DetailsView(
      itemId: itemId,
      preview: args.preview,
      heroTag: args.heroTag,
      // Play on a series resolves to the right episode: the one in
      // progress, else the first unwatched, else episode one.
      onPlay: (item) async {
        final target = await ref
            .read(playbackRepositoryProvider)
            .seriesPlayTarget(itemId);
        if (target != null && context.mounted) {
          openPlayer(context, target);
        }
      },
      sectionsBuilder: (item) => [
        SeasonEpisodes(
          seriesId: itemId,
          onEpisodeTap: (episode) => openPlayer(context, episode),
        ),
        const SizedBox(height: 16),
        CastRail(people: item.people),
        PosterRail(
          title: 'More Like This',
          items: ref.watch(similarItemsProvider(itemId)),
          heroContext: 'similar-$itemId',
          onItemTap: (tapped, heroTag) =>
              openMediaDetails(context, tapped, heroTag: heroTag),
        ),
      ],
    );
  }
}
