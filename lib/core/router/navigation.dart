import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/media_item.dart';
import 'app_router.dart';
import 'route_args.dart';

/// Routes a tapped [item] to the right detail page.
///
/// Centralized because every surface (home rows, hero banner, similar
/// rails, search results) shares the same rules:
///  * movies & collections → movie details
///  * series → series details
///  * episodes → their parent series' details (the episode row there is
///    the natural resume surface)
/// The tapped item rides along as the instant-paint preview; episodes
/// pass no preview since the target page shows the *series*.
void openMediaDetails(
  BuildContext context,
  MediaItem item, {
  String? heroTag,
}) {
  switch (item.kind) {
    case MediaKind.movie || MediaKind.boxSet:
      context.pushNamed(
        AppRoutes.movieDetails,
        pathParameters: {'id': item.id},
        extra: MediaDetailsArgs(preview: item, heroTag: heroTag),
      );
    case MediaKind.series:
      context.pushNamed(
        AppRoutes.seriesDetails,
        pathParameters: {'id': item.id},
        extra: MediaDetailsArgs(preview: item, heroTag: heroTag),
      );
    case MediaKind.episode:
      final seriesId = item.seriesId;
      if (seriesId == null) return;
      context.pushNamed(
        AppRoutes.seriesDetails,
        pathParameters: {'id': seriesId},
        extra: const MediaDetailsArgs(),
      );
    case MediaKind.season || MediaKind.person || MediaKind.other:
      // No dedicated page for these kinds; taps are inert by design.
      break;
  }
}

/// Opens the player for a playable [item] (movie or episode). Non-video
/// kinds fall back to their detail page — a Play press must always do
/// something sensible.
void openPlayer(BuildContext context, MediaItem item) {
  if (item.kind != MediaKind.movie && item.kind != MediaKind.episode) {
    openMediaDetails(context, item);
    return;
  }
  context.pushNamed(
    AppRoutes.player,
    pathParameters: {'id': item.id},
    extra: PlayerArgs(item: item),
  );
}
