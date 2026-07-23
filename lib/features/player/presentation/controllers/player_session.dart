import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/models/playback.dart';
import '../../../../core/repositories/playback_repository.dart';

/// Reports playback state to Jellyfin for one session.
///
/// Kept separate from [PlayerSession] so offline playback simply passes
/// no reporter — the player then never touches the network.
class PlaybackReporter {
  PlaybackReporter({
    required this.repository,
    required this.source,
    required this.itemId,
  });

  final PlaybackRepository repository;
  final PlaybackSource source;
  final String itemId;

  Future<void> start() => repository.reportStart(source, itemId);

  Future<void> progress(Duration position, {required bool isPaused}) =>
      repository.reportProgress(
        source,
        itemId,
        position: position,
        isPaused: isPaused,
      );

  Future<void> stopped(Duration position) =>
      repository.reportStopped(source, itemId, position: position);
}

/// Owns the media_kit [Player] and its Jellyfin reporting lifecycle.
///
/// The player is a highly imperative native resource with a 1:1 lifetime
/// to the screen, so it lives in a plain class owned by the screen state
/// rather than a Riverpod provider — Riverpod supplies the repositories,
/// not the resource.
///
/// Responsibilities:
///  * open the stream and seek to the resume point once the duration is
///    known (seeking before mpv reports a duration is silently dropped)
///  * report progress every ten seconds, on pause/resume, and on seek
///  * report stopped exactly once at teardown with the final position
class PlayerSession {
  PlayerSession({
    required this.mediaUrl,
    this.resumeFrom = Duration.zero,
    this.reporter,
  }) : player = Player(
          configuration: const PlayerConfiguration(title: 'PremFlix'),
        ) {
    controller = VideoController(player);
  }

  static const Duration _reportInterval = Duration(seconds: 10);

  final String mediaUrl;
  final Duration resumeFrom;
  final PlaybackReporter? reporter;

  final Player player;
  late final VideoController controller;

  Timer? _reportTimer;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  bool _resumed = false;
  bool _stopped = false;

  Future<void> init() async {
    if (resumeFrom > Duration.zero) {
      _durationSub = player.stream.duration.listen((duration) {
        if (!_resumed && duration > resumeFrom) {
          _resumed = true;
          player.seek(resumeFrom);
        }
      });
    }
    // Pause/resume flips are reported immediately so other clients see
    // the paused state without waiting out the interval.
    _playingSub = player.stream.playing.listen((_) => reportNow());

    await player.open(Media(mediaUrl));
    await reporter?.start();
    _reportTimer = Timer.periodic(_reportInterval, (_) => reportNow());
  }

  Future<void> reportNow() async {
    if (_stopped) return;
    await reporter?.progress(
      player.state.position,
      isPaused: !player.state.playing,
    );
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
    await reportNow();
  }

  Future<void> seekRelative(Duration offset) {
    final target = player.state.position + offset;
    final duration = player.state.duration;
    return seek(
      target < Duration.zero
          ? Duration.zero
          : (duration > Duration.zero && target > duration ? duration : target),
    );
  }

  /// Reports the final position and releases the native player. Safe to
  /// call once; the screen calls it from `dispose`.
  Future<void> shutdown() async {
    if (_stopped) return;
    _stopped = true;
    _reportTimer?.cancel();
    await _durationSub?.cancel();
    await _playingSub?.cancel();
    final position = player.state.position;
    await reporter?.stopped(position);
    await player.dispose();
  }
}
