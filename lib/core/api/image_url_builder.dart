import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../services/session_controller.dart';

/// Builds Jellyfin image URLs for [MediaItem]s.
///
/// Lives outside the models so they stay pure data (no server URL baked
/// in — cached items survive a server address change). Every URL carries
/// the image `tag`, which doubles as a cache-buster: when artwork changes
/// server-side the tag changes, and CachedNetworkImage fetches fresh.
/// `maxWidth` + `quality` let the server downscale, so a poster row never
/// pulls multi-megabyte originals.
class ImageUrlBuilder {
  const ImageUrlBuilder(this._serverUrl);

  final String _serverUrl;

  String _url(
    String itemId,
    String type, {
    String? tag,
    int? maxWidth,
    int index = 0,
  }) {
    final query = <String, String>{
      'tag': ?tag,
      if (maxWidth != null) 'maxWidth': '$maxWidth',
      'quality': '90',
    };
    final queryString = query.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    final indexSegment = type == 'Backdrop' ? '/$index' : '';
    return '$_serverUrl/Items/$itemId/Images/$type$indexSegment?$queryString';
  }

  /// Poster artwork. Episodes fall back to their series poster so
  /// vertical rows stay uniform (episode primaries are 16:9 stills).
  String? poster(MediaItem item, {int maxWidth = 400}) {
    final tag = item.imageTags['Primary'];
    if (tag != null && !item.isEpisode) {
      return _url(item.id, 'Primary', tag: tag, maxWidth: maxWidth);
    }
    if (item.seriesId != null && item.seriesPrimaryImageTag != null) {
      return _url(
        item.seriesId!,
        'Primary',
        tag: item.seriesPrimaryImageTag,
        maxWidth: maxWidth,
      );
    }
    if (tag != null) {
      return _url(item.id, 'Primary', tag: tag, maxWidth: maxWidth);
    }
    return null;
  }

  /// Wide artwork for hero banners and continue-watching cards. Episodes
  /// prefer their own still, then the series backdrop.
  String? backdrop(MediaItem item, {int maxWidth = 1280}) {
    if (item.isEpisode) {
      final still = item.imageTags['Primary'];
      if (still != null) {
        return _url(item.id, 'Primary', tag: still, maxWidth: maxWidth);
      }
    }
    if (item.backdropImageTags.isNotEmpty) {
      return _url(
        item.id,
        'Backdrop',
        tag: item.backdropImageTags.first,
        maxWidth: maxWidth,
      );
    }
    if (item.parentBackdropItemId != null &&
        item.parentBackdropImageTags.isNotEmpty) {
      return _url(
        item.parentBackdropItemId!,
        'Backdrop',
        tag: item.parentBackdropImageTags.first,
        maxWidth: maxWidth,
      );
    }
    final thumb = item.imageTags['Thumb'];
    if (thumb != null) {
      return _url(item.id, 'Thumb', tag: thumb, maxWidth: maxWidth);
    }
    return null;
  }

  /// Transparent title-treatment logo, when the library has one.
  String? logo(MediaItem item, {int maxWidth = 500}) {
    final tag = item.imageTags['Logo'];
    if (tag == null) return null;
    return _url(item.id, 'Logo', tag: tag, maxWidth: maxWidth);
  }

  /// Headshot for a cast member.
  String? personImage(MediaPerson person, {int maxWidth = 200}) {
    if (person.primaryImageTag == null || person.id.isEmpty) return null;
    return _url(
      person.id,
      'Primary',
      tag: person.primaryImageTag,
      maxWidth: maxWidth,
    );
  }
}

/// Session-scoped builder; requires an active session like the API client.
final imageUrlBuilderProvider = Provider<ImageUrlBuilder>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) {
    throw StateError('imageUrlBuilderProvider read without an active session');
  }
  return ImageUrlBuilder(session.serverUrl);
});
