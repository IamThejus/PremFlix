import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/auth_session.dart';
import '../models/media_item.dart';
import '../models/playback.dart';
import '../services/device_identity_service.dart';
import '../services/session_controller.dart';

/// Stream resolution and playback reporting against Jellyfin.
///
/// Resolution posts a deliberately permissive device profile: mpv (via
/// media_kit) plays virtually every container and codec, so the server
/// direct-plays whenever it can and only transcodes when forced (e.g.
/// bitrate limits set server-side). Progress reports keep resume state
/// in sync across every Jellyfin client the user owns.
class PlaybackRepository {
  PlaybackRepository({
    required Dio api,
    required AuthSession session,
    required DeviceIdentityService identity,
  })  : _api = api,
        _session = session,
        _identity = identity;

  final Dio _api;
  final AuthSession _session;
  final DeviceIdentityService _identity;

  /// Uncapped ceiling used for [QualityOption.auto].
  static const int _uncappedBitrate = 140000000;

  /// "Play anything" profile: empty container strings mean *all*, with
  /// an HLS h264 fallback for transcodes (forced or quality-capped).
  static Map<String, dynamic> _deviceProfile(int maxBitrate) => {
        'MaxStreamingBitrate': maxBitrate,
        'DirectPlayProfiles': [
          {'Container': '', 'Type': 'Video'},
          {'Container': '', 'Type': 'Audio'},
        ],
        'TranscodingProfiles': [
          {
            'Container': 'ts',
            'Type': 'Video',
            'VideoCodec': 'h264',
            'AudioCodec': 'aac,mp3',
            'Context': 'Streaming',
            'Protocol': 'hls',
          },
        ],
        'SubtitleProfiles': [
          {'Format': 'subrip', 'Method': 'Embed'},
          {'Format': 'ass', 'Method': 'Embed'},
          {'Format': 'ssa', 'Method': 'Embed'},
          {'Format': 'pgssub', 'Method': 'Embed'},
          {'Format': 'vtt', 'Method': 'Embed'},
        ],
      };

  /// Resolves the playable stream for [itemId].
  ///
  /// A non-auto [quality] disables direct play so the server must
  /// transcode within the bitrate cap — that's how Jellyfin implements
  /// quality selection; the server chooses the resolution that fits.
  Future<PlaybackSource> resolveStream(
    String itemId, {
    Duration startPosition = Duration.zero,
    QualityOption quality = QualityOption.auto,
  }) async {
    final capped = quality.maxBitrate != null;
    final maxBitrate = quality.maxBitrate ?? _uncappedBitrate;
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/Items/$itemId/PlaybackInfo',
        queryParameters: {
          'UserId': _session.userId,
          'StartTimeTicks': '${durationToTicks(startPosition)}',
          'AutoOpenLiveStream': 'true',
          'MaxStreamingBitrate': '$maxBitrate',
          if (capped) 'EnableDirectPlay': 'false',
          if (capped) 'EnableDirectStream': 'false',
        },
        data: {'DeviceProfile': _deviceProfile(maxBitrate)},
      );

      final body = response.data ?? const {};
      final sources = (body['MediaSources'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
      if (sources.isEmpty) {
        throw const ApiException(
          ApiErrorKind.notFound,
          'The server offered no playable stream for this title.',
        );
      }

      final source = sources.first;
      final playSessionId = body['PlaySessionId'] as String? ?? '';
      final mediaSourceId = source['Id'] as String? ?? itemId;
      final transcodingUrl = source['TranscodingUrl'] as String?;
      final directPlayable = (source['SupportsDirectPlay'] as bool? ?? false) ||
          (source['SupportsDirectStream'] as bool? ?? false);

      if (directPlayable || transcodingUrl == null) {
        // Static stream of the original file. The api_key query param is
        // how Jellyfin authenticates media URLs handed to native players
        // that don't attach headers.
        final url = '${_session.serverUrl}/Videos/$itemId/stream'
            '?static=true'
            '&mediaSourceId=$mediaSourceId'
            '&deviceId=${_identity.deviceId}'
            '&api_key=${_session.accessToken}'
            '&playSessionId=$playSessionId';
        return PlaybackSource(
          url: url,
          playSessionId: playSessionId,
          mediaSourceId: mediaSourceId,
          isTranscoding: false,
        );
      }

      return PlaybackSource(
        url: '${_session.serverUrl}$transcodingUrl',
        playSessionId: playSessionId,
        mediaSourceId: mediaSourceId,
        isTranscoding: true,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Intro window from the Intro Skipper plugin; null when the plugin is
  /// absent or the episode has no detected intro.
  Future<IntroTimestamps?> introTimestamps(String itemId) async {
    try {
      final response = await _api
          .get<Map<String, dynamic>>('/Episode/$itemId/IntroTimestamps/v1');
      final data = response.data;
      return data == null ? null : IntroTimestamps.fromJson(data);
    } on DioException {
      return null;
    }
  }

  /// The episode following [episode] in its series, or null at the end.
  Future<MediaItem?> nextEpisode(MediaItem episode) async {
    final seriesId = episode.seriesId;
    if (!episode.isEpisode || seriesId == null) return null;
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/Shows/$seriesId/Episodes',
        queryParameters: {
          'UserId': _session.userId,
          'StartItemId': episode.id,
          'Limit': '2',
        },
      );
      final items = PagedItems.fromJson(response.data ?? const {}).items;
      return items.length > 1 ? items[1] : null;
    } on DioException {
      return null;
    }
  }

  /// For a series Play button: the episode in progress, else the first
  /// unwatched, else the very first episode.
  Future<MediaItem?> seriesPlayTarget(String seriesId) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/Shows/$seriesId/Episodes',
        queryParameters: {'UserId': _session.userId},
      );
      final episodes = PagedItems.fromJson(response.data ?? const {}).items;
      if (episodes.isEmpty) return null;
      for (final episode in episodes) {
        if (episode.userData?.inProgress ?? false) return episode;
      }
      for (final episode in episodes) {
        if (!(episode.userData?.played ?? false)) return episode;
      }
      return episodes.first;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  // ---------------------------------------------------------------------
  // Progress reporting — always best-effort: a dropped report must never
  // interrupt playback, so failures are swallowed.
  // ---------------------------------------------------------------------

  Future<void> reportStart(PlaybackSource source, String itemId) =>
      _report('/Sessions/Playing', {
        'ItemId': itemId,
        'PlaySessionId': source.playSessionId,
        'MediaSourceId': source.mediaSourceId,
        'CanSeek': true,
        'PlayMethod': source.isTranscoding ? 'Transcode' : 'DirectPlay',
      });

  Future<void> reportProgress(
    PlaybackSource source,
    String itemId, {
    required Duration position,
    required bool isPaused,
  }) =>
      _report('/Sessions/Playing/Progress', {
        'ItemId': itemId,
        'PlaySessionId': source.playSessionId,
        'MediaSourceId': source.mediaSourceId,
        'PositionTicks': durationToTicks(position),
        'IsPaused': isPaused,
        'CanSeek': true,
        'PlayMethod': source.isTranscoding ? 'Transcode' : 'DirectPlay',
      });

  Future<void> reportStopped(
    PlaybackSource source,
    String itemId, {
    required Duration position,
  }) =>
      _report('/Sessions/Playing/Stopped', {
        'ItemId': itemId,
        'PlaySessionId': source.playSessionId,
        'MediaSourceId': source.mediaSourceId,
        'PositionTicks': durationToTicks(position),
      });

  Future<void> _report(String path, Map<String, dynamic> body) async {
    try {
      await _api.post<void>(path, data: body);
    } on DioException {
      // Best-effort by design.
    }
  }
}

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) {
    throw StateError('playbackRepositoryProvider read without a session');
  }
  return PlaybackRepository(
    api: ref.watch(apiClientProvider),
    session: session,
    identity: ref.watch(deviceIdentityProvider),
  );
});
