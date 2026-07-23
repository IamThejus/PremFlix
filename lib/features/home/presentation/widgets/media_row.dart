import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/widgets/horizontal_media_rail.dart';
import '../controllers/home_providers.dart';

/// One home-screen row. Watches its [HomeRowKind] provider and delegates
/// rendering to the shared [HorizontalMediaRail], so every row loads,
/// animates, and fails independently while sharing one implementation.
class MediaRow extends ConsumerWidget {
  const MediaRow({super.key, required this.kind, this.onItemTap});

  final HomeRowKind kind;

  /// [heroTag] is non-null only for poster cards; forward it for the
  /// shared-element flight into the detail page.
  final void Function(MediaItem item, String? heroTag)? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HorizontalMediaRail(
      title: kind.title,
      items: ref.watch(homeRowProvider(kind)),
      heroContext: kind.name,
      wide: kind.wide,
      onItemTap: onItemTap,
    );
  }
}
