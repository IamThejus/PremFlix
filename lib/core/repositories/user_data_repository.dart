import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/media_item.dart';
import '../services/session_controller.dart';

/// Mutates per-user item state: favorites and watched status.
///
/// Each call returns the [UserItemData] the server responds with, so
/// controllers can update UI state from the authoritative result instead
/// of guessing — important because marking a series played, for example,
/// cascades to its episodes server-side.
class UserDataRepository {
  UserDataRepository({required Dio api, required String userId})
      : _api = api,
        _userId = userId;

  final Dio _api;
  final String _userId;

  /// Sets or clears the favorite flag on [itemId].
  Future<UserItemData> setFavorite(String itemId, bool favorite) =>
      _mutate('/Users/$_userId/FavoriteItems/$itemId', add: favorite);

  /// Marks [itemId] fully played, or clears playback history entirely.
  Future<UserItemData> setPlayed(String itemId, bool played) =>
      _mutate('/Users/$_userId/PlayedItems/$itemId', add: played);

  Future<UserItemData> _mutate(String path, {required bool add}) async {
    try {
      final response = add
          ? await _api.post<Map<String, dynamic>>(path)
          : await _api.delete<Map<String, dynamic>>(path);
      return UserItemData.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final userDataRepositoryProvider = Provider<UserDataRepository>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null) {
    throw StateError('userDataRepositoryProvider read without a session');
  }
  return UserDataRepository(
    api: ref.watch(apiClientProvider),
    userId: session.userId,
  );
});
