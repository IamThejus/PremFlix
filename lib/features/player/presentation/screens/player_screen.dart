import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/models/playback.dart';
import '../../../../core/providers/library_providers.dart';
import '../../../../core/repositories/playback_repository.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/route_args.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/accent_button.dart';
import '../controllers/player_session.dart';
import '../widgets/player_controls.dart';

/// Full-screen video player.
///
/// Launch sequence: load the item (skipped when the navigation carried
/// it), resolve the stream via PlaybackInfo, fetch intro window and next
/// episode in parallel for episodes, open the player at the resume
/// point, and report the session start. On exit the session reports
/// stopped and the library refresh tick bumps, so Continue Watching and
/// detail pages reflect the session.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.itemId, required this.args});

  final String itemId;
  final PlayerArgs args;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  PlayerSession? _session;
  MediaItem? _item;
  PlaybackSource? _source;
  MediaItem? _nextEpisode;
  IntroTimestamps? _intro;
  String? _error;
  StreamSubscription<bool>? _completedSub;
  QualityOption _quality = QualityOption.auto;

  @override
  void initState() {
    super.initState();
    _quality = QualityOption.fromName(
      ref
          .read(preferencesServiceProvider)
          .getString(PreferencesService.playbackQualityKey),
    );
    _enterImmersive();
    unawaited(_launch());
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    // Report + release before ref becomes invalid; fire-and-forget so
    // dispose never blocks the navigation animation.
    final session = _session;
    if (session != null) unawaited(session.shutdown());
    ref.read(libraryRefreshTickProvider.notifier).bump();
    _exitImmersive();
    super.dispose();
  }

  void _enterImmersive() {
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _exitImmersive() {
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  Future<void> _launch() async {
    try {
      final playback = ref.read(playbackRepositoryProvider);
      final MediaItem item = widget.args.item ??
          (await ref.read(itemDetailsProvider(widget.itemId).future));
      _item = item;

      final resumeFrom = (item.userData?.inProgress ?? false)
          ? item.userData!.playbackPosition
          : Duration.zero;

      if (item.isEpisode) {
        // Parallel, both optional — neither may delay first frame long.
        final (intro, next) = await (
          playback.introTimestamps(widget.itemId),
          playback.nextEpisode(item),
        ).wait;
        _intro = intro;
        _nextEpisode = next;
      }

      await _startStream(resumeFrom: resumeFrom);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Playback failed to start.');
      }
    }
  }

  /// Resolves a stream at the active [_quality] and starts a session at
  /// [resumeFrom]. Used for both the initial launch and quality swaps.
  Future<void> _startStream({required Duration resumeFrom}) async {
    final playback = ref.read(playbackRepositoryProvider);
    final source = await playback.resolveStream(
      widget.itemId,
      startPosition: resumeFrom,
      quality: _quality,
    );
    _source = source;

    final session = PlayerSession(
      mediaUrl: source.url,
      resumeFrom: resumeFrom,
      reporter: PlaybackReporter(
        repository: playback,
        source: source,
        itemId: widget.itemId,
      ),
    );
    await session.init();
    _attachCompletion(session);
    if (!mounted) {
      await session.shutdown();
      return;
    }
    setState(() => _session = session);
  }

  /// Swaps the stream at the current position. The old session reports
  /// stopped (its PlaySessionId dies with it — the server tears down any
  /// transcode), and the new one resumes where playback was.
  Future<void> _changeQuality(QualityOption quality) async {
    final current = _session;
    if (quality == _quality || current == null) return;

    setState(() {
      _quality = quality;
      _session = null; // Spinner while the new stream spins up.
    });
    unawaited(
      ref.read(preferencesServiceProvider).setString(
            PreferencesService.playbackQualityKey,
            quality.name,
          ),
    );

    final position = current.player.state.position;
    await _completedSub?.cancel();
    await current.shutdown();

    try {
      await _startStream(resumeFrom: position);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Playback failed to start.');
      }
    }
  }

  void _attachCompletion(PlayerSession session) {
    _completedSub = session.player.stream.completed.listen((completed) {
      if (completed && mounted) {
        _nextEpisode != null ? _playNext() : context.pop();
      }
    });
  }

  /// Swaps this screen for the next episode's player. pushReplacement
  /// keeps the back stack clean: back from episode 5 returns to the
  /// series page, not through episodes 4, 3, 2...
  void _playNext() {
    final next = _nextEpisode;
    if (next == null) return;
    context.pushReplacementNamed(
      AppRoutes.player,
      pathParameters: {'id': next.id},
      extra: PlayerArgs(item: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final item = _item;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? _PlaybackError(message: _error!, onBack: () => context.pop())
          : session == null
              ? const Center(
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white70,
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(
                      controller: session.controller,
                      controls: NoVideoControls,
                      fill: Colors.black,
                    ),
                    PlayerControls(
                      session: session,
                      title: item?.isEpisode ?? false
                          ? (item!.seriesName ?? item.name)
                          : item?.name ?? 'Now Playing',
                      subtitle: item?.isEpisode ?? false
                          ? [item!.episodeLabel, item.name]
                              .where((part) => part.isNotEmpty)
                              .join('  ')
                          : null,
                      intro: _intro,
                      isTranscoding: _source?.isTranscoding ?? false,
                      quality: _quality,
                      onQualityChanged: _changeQuality,
                      onNextEpisode:
                          _nextEpisode == null ? null : _playNext,
                      onBack: () => context.pop(),
                    ),
                  ],
                ),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_disabled_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          SizedBox(
            width: 160,
            child: AccentButton(label: 'Go Back', onPressed: onBack),
          ),
        ],
      ),
    );
  }
}
