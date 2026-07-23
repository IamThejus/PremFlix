import '../models/media_item.dart';

/// Extra payload passed to detail routes via `state.extra`.
///
/// Both fields are optional because detail pages must also work from
/// deep links, where no originating card exists:
///  * [preview] — the already-loaded row item, letting the page paint
///    instantly while the full record (cast, taglines) loads behind it.
///  * [heroTag] — tag of the tapped poster, so the shared-element flight
///    lands on the detail page's poster. Null skips the hero.
class MediaDetailsArgs {
  const MediaDetailsArgs({this.preview, this.heroTag});

  final MediaItem? preview;
  final String? heroTag;

  /// Safely extracts args from `state.extra`, tolerating null or foreign
  /// values (deep links pass nothing).
  static MediaDetailsArgs from(Object? extra) =>
      extra is MediaDetailsArgs ? extra : const MediaDetailsArgs();
}

/// Extra payload for the login route.
///
/// When a server was chosen on the discovery screen, [serverUrl] (and its
/// friendly [serverName]) are pre-filled and the address field is hidden —
/// the user only enters credentials. With no server (manual entry, or
/// "Use another server"), both are null and the editable address field is
/// shown, so manual and remote-server setup keep working exactly as before.
class LoginArgs {
  const LoginArgs({this.serverUrl, this.serverName});

  final String? serverUrl;
  final String? serverName;

  bool get hasServer => serverUrl != null;

  static LoginArgs from(Object? extra) =>
      extra is LoginArgs ? extra : const LoginArgs();
}

/// Extra payload for the player route.
///
/// [item] spares the player a details fetch and carries the resume
/// position. Null on deep links: the player then loads the item by
/// route id.
class PlayerArgs {
  const PlayerArgs({this.item});

  final MediaItem? item;

  static PlayerArgs from(Object? extra) =>
      extra is PlayerArgs ? extra : const PlayerArgs();
}
