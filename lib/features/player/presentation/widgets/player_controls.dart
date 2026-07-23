import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/models/playback.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../controllers/player_session.dart';

/// Custom playback controls overlaid on the video.
///
/// Auto-hides after 3.5 s of inactivity (any pointer movement, tap, or
/// key press revives them). Layout:
///  * top — back, title/subtitle, transcoding badge
///  * center — replay-10 / play-pause / forward-10
///  * bottom — seek bar (with buffered range), timestamps, audio &
///    subtitle menus, next-episode, fullscreen (desktop)
///  * floating — Skip Intro pill during the intro window
///
/// Keyboard/remote: space toggles, ←/→ seek 10 s, F fullscreen, Esc back.
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.session,
    required this.title,
    this.subtitle,
    this.intro,
    this.isTranscoding = false,
    this.quality = QualityOption.auto,
    this.onQualityChanged,
    this.onNextEpisode,
    required this.onBack,
  });

  final PlayerSession session;
  final String title;
  final String? subtitle;
  final IntroTimestamps? intro;
  final bool isTranscoding;

  /// Active quality ceiling, shown checked in the quality menu.
  final QualityOption quality;

  /// Non-null enables the quality menu (hidden for offline playback).
  final ValueChanged<QualityOption>? onQualityChanged;

  /// Non-null enables the Next Episode button.
  final VoidCallback? onNextEpisode;
  final VoidCallback onBack;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  static const Duration _hideDelay = Duration(milliseconds: 3500);

  bool _visible = true;
  bool _fullscreen = false;
  Timer? _hideTimer;

  /// While the user drags the seek bar we preview the drag position
  /// instead of the live position, and only seek on release.
  double? _dragValue;

  Player get _player => widget.session.player;

  bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && _player.state.playing) {
        setState(() => _visible = false);
      }
    });
  }

  void _revive() {
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  void _togglePlay() {
    _player.playOrPause();
    _revive();
  }

  Future<void> _toggleFullscreen() async {
    if (!_isDesktop) return;
    _fullscreen = !_fullscreen;
    await windowManager.setFullScreen(_fullscreen);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          widget.session.seekRelative(const Duration(seconds: -10));
          _revive();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          widget.session.seekRelative(const Duration(seconds: 10));
          _revive();
        },
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): widget.onBack,
      },
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          onHover: (_) => _revive(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Tap toggles visibility; when controls are up, tapping
              // empty space is the universal "hide them" gesture.
              _visible ? setState(() => _visible = false) : _revive();
            },
            onDoubleTap: _togglePlay,
            child: Stack(
              children: [
                // Free-floating buffering spinner — only while controls
                // are hidden. With controls up, the ring wraps the
                // play/pause button instead, so the two never misalign
                // (the transport row is not at exact screen center).
                Center(
                  child: StreamBuilder<bool>(
                    stream: _player.stream.buffering,
                    initialData: _player.state.buffering,
                    builder: (context, snapshot) =>
                        (snapshot.data ?? false) && !_visible
                            ? const SizedBox(
                                width: 54,
                                height: 54,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white70,
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
                _SkipIntroButton(
                  session: widget.session,
                  intro: widget.intro,
                  onSkipped: _revive,
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _visible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_visible,
                    child: _buildOverlay(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.22, 0.75, 1],
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xE6000000),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ---- Top bar -------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 26),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (widget.isTranscoding)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('TRANSCODE',
                          style: theme.textTheme.labelSmall),
                    ),
                ],
              ),
            ),
            const Spacer(),
            // ---- Center transport ---------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlIcon(
                  icon: Icons.replay_10_rounded,
                  size: 40,
                  onPressed: () {
                    widget.session
                        .seekRelative(const Duration(seconds: -10));
                    _revive();
                  },
                ),
                const SizedBox(width: 36),
                StreamBuilder<bool>(
                  stream: _player.stream.buffering,
                  initialData: _player.state.buffering,
                  builder: (context, bufferingSnapshot) {
                    final buffering = bufferingSnapshot.data ?? false;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ring hugs the button, so buffering reads as a
                        // state of the transport — always concentric.
                        if (buffering)
                          const SizedBox(
                            width: 88,
                            height: 88,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white70,
                            ),
                          ),
                        StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          initialData: _player.state.playing,
                          builder: (context, snapshot) {
                            final playing = snapshot.data ?? true;
                            return _ControlIcon(
                              icon: playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 64,
                              onPressed: _togglePlay,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 36),
                _ControlIcon(
                  icon: Icons.forward_10_rounded,
                  size: 40,
                  onPressed: () {
                    widget.session
                        .seekRelative(const Duration(seconds: 10));
                    _revive();
                  },
                ),
              ],
            ),
            const Spacer(),
            // ---- Bottom bar ---------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: StreamBuilder<Duration>(
                stream: _player.stream.position,
                initialData: _player.state.position,
                builder: (context, snapshot) {
                  final duration = _player.state.duration;
                  final position = snapshot.data ?? Duration.zero;
                  final total = duration.inMilliseconds.toDouble();
                  final value = _dragValue ??
                      position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble();
                  final buffered = _player.state.buffer.inMilliseconds
                      .clamp(0, duration.inMilliseconds)
                      .toDouble();

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3.5,
                          activeTrackColor: context.accent,
                          secondaryActiveTrackColor:
                              Colors.white.withValues(alpha: 0.35),
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.15),
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayColor:
                              context.accent.withValues(alpha: 0.25),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                        ),
                        child: Slider(
                          max: total > 0 ? total : 1,
                          value: value.clamp(0, total > 0 ? total : 1),
                          secondaryTrackValue:
                              buffered.clamp(0, total > 0 ? total : 1),
                          onChangeStart: (_) => _hideTimer?.cancel(),
                          onChanged: (next) =>
                              setState(() => _dragValue = next),
                          onChangeEnd: (next) {
                            setState(() => _dragValue = null);
                            widget.session.seek(
                                Duration(milliseconds: next.round()));
                            _scheduleHide();
                          },
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Text(
                              '${formatTimestamp(position)}  /  '
                              '${formatTimestamp(duration)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            _TrackMenu(
                              icon: Icons.audiotrack_rounded,
                              tooltip: 'Audio',
                              session: widget.session,
                              subtitles: false,
                              onOpened: () => _hideTimer?.cancel(),
                              onClosed: _scheduleHide,
                            ),
                            _TrackMenu(
                              icon: Icons.subtitles_rounded,
                              tooltip: 'Subtitles',
                              session: widget.session,
                              subtitles: true,
                              onOpened: () => _hideTimer?.cancel(),
                              onClosed: _scheduleHide,
                            ),
                            if (widget.onQualityChanged != null)
                              _QualityMenu(
                                active: widget.quality,
                                onSelected: widget.onQualityChanged!,
                                onOpened: () => _hideTimer?.cancel(),
                                onClosed: _scheduleHide,
                              ),
                            if (widget.onNextEpisode != null)
                              _ControlIcon(
                                icon: Icons.skip_next_rounded,
                                size: 28,
                                tooltip: 'Next episode',
                                onPressed: widget.onNextEpisode!,
                              ),
                            if (_isDesktop)
                              _ControlIcon(
                                icon: _fullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                size: 28,
                                tooltip: 'Fullscreen (F)',
                                onPressed: _toggleFullscreen,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon button with hover scale — larger targets than stock IconButton.
class _ControlIcon extends StatefulWidget {
  const _ControlIcon({
    required this.icon,
    required this.size,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  State<_ControlIcon> createState() => _ControlIconState();
}

class _ControlIconState extends State<_ControlIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _hovered ? 1.15 : 1,
          duration: const Duration(milliseconds: 140),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(widget.icon, size: widget.size, color: Colors.white),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      child = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 600),
        child: child,
      );
    }
    return child;
  }
}

/// Audio or subtitle track picker.
class _TrackMenu extends StatelessWidget {
  const _TrackMenu({
    required this.icon,
    required this.tooltip,
    required this.session,
    required this.subtitles,
    required this.onOpened,
    required this.onClosed,
  });

  final IconData icon;
  final String tooltip;
  final PlayerSession session;
  final bool subtitles;
  final VoidCallback onOpened;
  final VoidCallback onClosed;

  String _label(String? title, String? language, String id) {
    if (title != null && title.isNotEmpty) return title;
    if (language != null && language.isNotEmpty) return language;
    return 'Track $id';
  }

  @override
  Widget build(BuildContext context) {
    final player = session.player;

    return MenuAnchor(
      onOpen: onOpened,
      onClose: onClosed,
      style: MenuStyle(
        backgroundColor:
            const WidgetStatePropertyAll(Color(0xF2171717)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      menuChildren: [
        if (subtitles) ...[
          _trackItem(
            context,
            label: 'Off',
            selected: player.state.track.subtitle == SubtitleTrack.no(),
            onTap: () => player.setSubtitleTrack(SubtitleTrack.no()),
          ),
          for (final track in player.state.tracks.subtitle
              .where((track) => track.id != 'auto' && track.id != 'no'))
            _trackItem(
              context,
              label: _label(track.title, track.language, track.id),
              selected: player.state.track.subtitle.id == track.id,
              onTap: () => player.setSubtitleTrack(track),
            ),
        ] else
          for (final track in player.state.tracks.audio
              .where((track) => track.id != 'auto' && track.id != 'no'))
            _trackItem(
              context,
              label: _label(track.title, track.language, track.id),
              selected: player.state.track.audio.id == track.id,
              onTap: () => player.setAudioTrack(track),
            ),
      ],
      builder: (context, controller, child) => _ControlIcon(
        icon: icon,
        size: 26,
        tooltip: tooltip,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _trackItem(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return MenuItemButton(
      leadingIcon: Icon(
        selected ? Icons.check_rounded : null,
        size: 18,
        color: context.accent,
      ),
      onPressed: onTap,
      child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

/// Quality (bitrate ceiling) picker.
class _QualityMenu extends StatelessWidget {
  const _QualityMenu({
    required this.active,
    required this.onSelected,
    required this.onOpened,
    required this.onClosed,
  });

  final QualityOption active;
  final ValueChanged<QualityOption> onSelected;
  final VoidCallback onOpened;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      onOpen: onOpened,
      onClose: onClosed,
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xF2171717)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      menuChildren: [
        for (final option in QualityOption.values)
          MenuItemButton(
            leadingIcon: Icon(
              option == active ? Icons.check_rounded : null,
              size: 18,
              color: context.accent,
            ),
            onPressed: () => onSelected(option),
            child: Text(
              option.label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
      ],
      builder: (context, controller, child) => _ControlIcon(
        icon: Icons.tune_rounded,
        size: 26,
        tooltip: 'Quality · ${active.label}',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// "Skip Intro" pill, visible only inside the intro window.
class _SkipIntroButton extends StatelessWidget {
  const _SkipIntroButton({
    required this.session,
    required this.intro,
    required this.onSkipped,
  });

  final PlayerSession session;
  final IntroTimestamps? intro;
  final VoidCallback onSkipped;

  @override
  Widget build(BuildContext context) {
    final window = intro;
    if (window == null) return const SizedBox.shrink();

    return StreamBuilder<Duration>(
      stream: session.player.stream.position,
      initialData: session.player.state.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final visible = window.contains(position);
        return Positioned(
          right: 24,
          bottom: 110,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            offset: visible ? Offset.zero : const Offset(0, 0.6),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: visible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !visible,
                child: GestureDetector(
                  onTap: () {
                    session.seek(window.introEnd);
                    onSkipped();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fast_forward_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Skip Intro',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
