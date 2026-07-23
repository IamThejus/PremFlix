import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import 'horizontal_media_rail.dart';

/// Generic poster rail driven by an [AsyncValue] — used for "More Like
/// This", collection contents, and search categories.
///
/// A thin adapter over [HorizontalMediaRail] that keeps the historical
/// non-null `heroTag` callback contract its call sites rely on.
class PosterRail extends StatelessWidget {
  const PosterRail({
    super.key,
    required this.title,
    required this.items,
    required this.heroContext,
    this.onItemTap,
  });

  final String title;
  final AsyncValue<List<MediaItem>> items;

  /// Namespaces hero tags so this rail never collides with another
  /// surface showing the same item.
  final String heroContext;
  final void Function(MediaItem item, String heroTag)? onItemTap;

  @override
  Widget build(BuildContext context) {
    return HorizontalMediaRail(
      title: title,
      items: items,
      heroContext: heroContext,
      onItemTap: onItemTap == null
          ? null
          // Poster rails always produce a hero tag; unwrap the nullable.
          : (item, heroTag) => onItemTap!(item, heroTag!),
    );
  }
}
