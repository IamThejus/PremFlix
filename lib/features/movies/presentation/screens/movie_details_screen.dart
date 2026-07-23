import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/providers/library_providers.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/router/route_args.dart';
import '../../../../core/widgets/cast_rail.dart';
import '../../../../core/widgets/details_view.dart';
import '../../../../core/widgets/poster_rail.dart';

/// Detail page for movies and collections.
///
/// Thin composition over [DetailsView]: cast, then the context rail —
/// "More Like This" for a movie, "In This Collection" for a box set
/// (whose members matter more than lookalikes).
class MovieDetailsScreen extends ConsumerWidget {
  const MovieDetailsScreen({
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
      onPlay: (item) => openPlayer(context, item),
      sectionsBuilder: (item) => [
        CastRail(people: item.people),
        if (item.kind == MediaKind.boxSet)
          PosterRail(
            title: 'In This Collection',
            items: ref.watch(collectionItemsProvider(itemId)),
            heroContext: 'collection-$itemId',
            onItemTap: (tapped, heroTag) =>
                openMediaDetails(context, tapped, heroTag: heroTag),
          )
        else
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
