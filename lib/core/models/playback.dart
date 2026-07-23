/// Models for stream resolution and playback session state.
library;

import 'media_item.dart';

/// Playback quality ceiling selectable in the player.
///
/// Jellyfin models quality as a **bitrate cap**: any cap forces a
/// transcode and the server picks the resolution that fits the budget.
/// [auto] means no cap — the original file direct-plays whenever the
/// server allows it.
enum QualityOption {
  auto('Auto (Original)', null),
  p1080High('1080p · 20 Mbps', 20000000),
  p1080('1080p · 10 Mbps', 10000000),
  p720High('720p · 8 Mbps', 8000000),
  p720('720p · 4 Mbps', 4000000),
  p480('480p · 2.5 Mbps', 2500000),
  p360('360p · 1 Mbps', 1000000);

  const QualityOption(this.label, this.maxBitrate);

  final String label;

  /// Bits per second, or null for uncapped/direct.
  final int? maxBitrate;

  /// Looks up a persisted choice, defaulting to [auto] for unknown
  /// values (e.g. a preset removed in a future release).
  static QualityOption fromName(String? name) =>
      QualityOption.values.firstWhere(
        (option) => option.name == name,
        orElse: () => QualityOption.auto,
      );
}

/// A resolved, playable stream for one item.
class PlaybackSource {
  const PlaybackSource({
    required this.url,
    required this.playSessionId,
    required this.mediaSourceId,
    required this.isTranscoding,
  });

  /// Absolute URL the player opens (direct stream or HLS transcode).
  final String url;

  /// Server-issued session id; must accompany every progress report so
  /// the server ties reports (and transcode lifetime) to this playback.
  final String playSessionId;
  final String mediaSourceId;

  /// True when the server is transcoding rather than serving the
  /// original file — shown in the player as a small badge.
  final bool isTranscoding;
}

/// Intro window for an episode, provided by the Intro Skipper plugin.
///
/// [showSkipAt]–[hideSkipAt] bound when the Skip Intro button is
/// visible; skipping seeks to [introEnd].
class IntroTimestamps {
  const IntroTimestamps({
    required this.introStart,
    required this.introEnd,
    required this.showSkipAt,
    required this.hideSkipAt,
  });

  final Duration introStart;
  final Duration introEnd;
  final Duration showSkipAt;
  final Duration hideSkipAt;

  bool contains(Duration position) =>
      position >= showSkipAt && position <= hideSkipAt;

  factory IntroTimestamps.fromJson(Map<String, dynamic> json) {
    Duration seconds(Object? value) => Duration(
          milliseconds: (((value as num?) ?? 0) * 1000).round(),
        );
    return IntroTimestamps(
      introStart: seconds(json['IntroStart']),
      introEnd: seconds(json['IntroEnd']),
      showSkipAt: seconds(json['ShowSkipPromptAt']),
      hideSkipAt: seconds(json['HideSkipPromptAt']),
    );
  }
}

/// Everything the player screen needs to start: the item, its stream,
/// where to resume, and (for episodes) intro/next-episode context.
class PlaybackLaunch {
  const PlaybackLaunch({
    required this.item,
    required this.source,
    required this.startPosition,
    this.intro,
    this.nextEpisode,
  });

  final MediaItem item;
  final PlaybackSource source;
  final Duration startPosition;
  final IntroTimestamps? intro;
  final MediaItem? nextEpisode;
}
