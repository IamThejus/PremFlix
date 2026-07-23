import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/catalog_providers.dart';
import '../router/navigation.dart';
import 'horizontal_media_rail.dart';

/// Renders a catalog page (Movies / TV Shows) as a vertical stack of
/// horizontal rails — one per [CatalogSection]. Each rail watches its own
/// provider, so sections stream in independently and empty ones (e.g. a
/// genre the server doesn't have) simply don't appear.
///
/// [topInset] leaves room for the shell's floating navigation bar, since
/// these pages have no full-bleed hero to sit behind it.
class CatalogSectionsView extends StatelessWidget {
  const CatalogSectionsView({
    super.key,
    required this.sections,
    required this.topInset,
  });

  final List<CatalogSection> sections;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topInset + 8)),
        for (final section in sections)
          SliverToBoxAdapter(child: _CatalogRail(section: section)),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }
}

/// A single catalog rail: watches the section's provider and delegates to
/// the shared [HorizontalMediaRail].
class _CatalogRail extends ConsumerWidget {
  const _CatalogRail({required this.section});

  final CatalogSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HorizontalMediaRail(
      title: section.title,
      items: ref.watch(catalogRowProvider(section.key)),
      heroContext: section.heroContext,
      wide: section.wide,
      onItemTap: (item, heroTag) =>
          openMediaDetails(context, item, heroTag: heroTag),
    );
  }
}
