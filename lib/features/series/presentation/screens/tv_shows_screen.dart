import 'package:flutter/material.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/providers/catalog_providers.dart';
import '../../../../core/widgets/catalog_sections_view.dart';
import '../../../shell/presentation/nav_metrics.dart';

/// The dedicated TV Shows catalog page.
///
/// Series-only rows: in-progress episodes and next-up (16:9 episode
/// cards), then trending / recently added / popular series and a run of
/// genre rails. Fed entirely by the shared [catalogRowProvider].
class TvShowsScreen extends StatelessWidget {
  const TvShowsScreen({super.key});

  static const _kind = MediaKind.series;

  static const List<(String, String)> _genres = [
    ('Anime', 'Anime'),
    ('Drama', 'Drama'),
    ('Comedy', 'Comedy'),
    ('Crime', 'Crime'),
    ('Documentary', 'Documentary'),
  ];

  List<CatalogSection> get _sections => [
        const CatalogSection(
          'Continue Watching',
          (type: 'resume', kind: _kind, genre: null),
          wide: true,
        ),
        const CatalogSection(
          'Next Episode',
          (type: 'nextup', kind: _kind, genre: null),
          wide: true,
        ),
        const CatalogSection(
          'Trending Shows',
          (type: 'trending', kind: _kind, genre: null),
        ),
        const CatalogSection(
          'Recently Added',
          (type: 'recent', kind: _kind, genre: null),
        ),
        const CatalogSection(
          'Popular Series',
          (type: 'popular', kind: _kind, genre: null),
        ),
        for (final (title, genre) in _genres)
          CatalogSection(title, (type: 'genre', kind: _kind, genre: genre)),
      ];

  @override
  Widget build(BuildContext context) {
    return CatalogSectionsView(
      sections: _sections,
      topInset: premFlixContentTopInset(context),
    );
  }
}
