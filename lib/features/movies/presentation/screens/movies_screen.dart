import 'package:flutter/material.dart';

import '../../../../core/models/media_item.dart';
import '../../../../core/providers/catalog_providers.dart';
import '../../../../core/widgets/catalog_sections_view.dart';
import '../../../shell/presentation/nav_metrics.dart';

/// The dedicated Movies catalog page.
///
/// Movie-only rows: in-progress movies, trending, recently added, then a
/// run of genre rails. Genres absent from the server collapse to nothing,
/// so the page adapts to whatever libraries exist. All rows are fed by
/// the shared [catalogRowProvider] — this screen is pure composition.
class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  static const _kind = MediaKind.movie;

  /// (display title, Jellyfin genre) — titles diverge from genre strings
  /// where the library name differs (e.g. "Sci-Fi" → "Science Fiction").
  static const List<(String, String)> _genres = [
    ('Action', 'Action'),
    ('Comedy', 'Comedy'),
    ('Sci-Fi', 'Science Fiction'),
    ('Drama', 'Drama'),
    ('Animation', 'Animation'),
    ('Family', 'Family'),
    ('Horror', 'Horror'),
    ('Documentaries', 'Documentary'),
  ];

  List<CatalogSection> get _sections => [
        const CatalogSection(
          'Continue Watching',
          (type: 'resume', kind: _kind, genre: null),
        ),
        const CatalogSection(
          'Trending Movies',
          (type: 'trending', kind: _kind, genre: null),
        ),
        const CatalogSection(
          'Recently Added',
          (type: 'recent', kind: _kind, genre: null),
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
