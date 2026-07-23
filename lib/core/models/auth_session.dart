import 'dart:convert';

/// An authenticated Jellyfin session.
///
/// Immutable value object produced by `AuthRepository.authenticate` and
/// persisted (as JSON, in secure storage) between launches. Everything the
/// API client needs to talk to the server on the user's behalf lives here.
class AuthSession {
  const AuthSession({
    required this.serverUrl,
    required this.userId,
    required this.userName,
    required this.accessToken,
    this.userImageTag,
  });

  /// Normalized base URL of the Jellyfin server, without trailing slash
  /// (e.g. `http://192.168.1.20:8096`).
  final String serverUrl;

  /// The Jellyfin user id all `/Users/{id}/...` calls are scoped to.
  final String userId;

  /// Display name, shown in the app bar avatar.
  final String userName;

  /// Per-device access token issued by `AuthenticateByName`.
  final String accessToken;

  /// Image tag of the user's profile picture, if one is set. Used to
  /// build the avatar URL and bust caches when the picture changes.
  final String? userImageTag;

  /// URL of the user's profile image, or null when none is set.
  String? get userImageUrl => userImageTag == null
      ? null
      : '$serverUrl/Users/$userId/Images/Primary?tag=$userImageTag';

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'userId': userId,
        'userName': userName,
        'accessToken': accessToken,
        'userImageTag': userImageTag,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        serverUrl: json['serverUrl'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        accessToken: json['accessToken'] as String,
        userImageTag: json['userImageTag'] as String?,
      );

  String encode() => jsonEncode(toJson());

  /// Decodes a session persisted by [encode]. Returns null when the stored
  /// value is corrupt (e.g. schema changed between releases) so a bad
  /// payload degrades to "signed out" instead of crashing the boot.
  static AuthSession? tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
