/// Domain models for Jellyfin library items.
///
/// One unified [MediaItem] covers movies, series, seasons, episodes, and
/// collections — Jellyfin's `BaseItemDto` is likewise unified, and a
/// single model keeps rows heterogeneous (a Continue Watching row mixes
/// movies and episodes) without casting. Parsing is defensive: any field
/// the server omits degrades to null/empty instead of throwing, because
/// real-world servers differ wildly in configured metadata.
library;

/// The kind of library item, mapped from `BaseItemDto.Type`.
enum MediaKind {
  movie('Movie'),
  series('Series'),
  season('Season'),
  episode('Episode'),
  boxSet('BoxSet'),
  person('Person'),
  other('');

  const MediaKind(this.wireName);

  /// The value Jellyfin uses in `Type` and `IncludeItemTypes`.
  final String wireName;

  static MediaKind fromWire(String? type) => MediaKind.values.firstWhere(
        (kind) => kind.wireName == type,
        orElse: () => MediaKind.other,
      );
}

/// Per-user state attached to an item (`UserItemDataDto`).
class UserItemData {
  const UserItemData({
    required this.isFavorite,
    required this.played,
    required this.playbackPosition,
    required this.playedPercentage,
    required this.unplayedItemCount,
  });

  final bool isFavorite;
  final bool played;

  /// Where playback left off; [Duration.zero] when never started.
  final Duration playbackPosition;

  /// Server-computed 0–100 progress, when available.
  final double? playedPercentage;

  /// For series/seasons: how many episodes remain unwatched.
  final int? unplayedItemCount;

  bool get inProgress => playbackPosition > Duration.zero && !played;

  factory UserItemData.fromJson(Map<String, dynamic> json) => UserItemData(
        isFavorite: json['IsFavorite'] as bool? ?? false,
        played: json['Played'] as bool? ?? false,
        playbackPosition: ticksToDuration(json['PlaybackPositionTicks']),
        playedPercentage: (json['PlayedPercentage'] as num?)?.toDouble(),
        unplayedItemCount: json['UnplayedItemCount'] as int?,
      );

  UserItemData copyWith({bool? isFavorite, bool? played}) => UserItemData(
        isFavorite: isFavorite ?? this.isFavorite,
        played: played ?? this.played,
        playbackPosition: playbackPosition,
        playedPercentage: playedPercentage,
        unplayedItemCount: unplayedItemCount,
      );

  Map<String, dynamic> toJson() => {
        'IsFavorite': isFavorite,
        'Played': played,
        'PlaybackPositionTicks': playbackPosition.inMicroseconds * 10,
        'PlayedPercentage': playedPercentage,
        'UnplayedItemCount': unplayedItemCount,
      };
}

/// A cast or crew member (`BaseItemPerson`).
class MediaPerson {
  const MediaPerson({
    required this.id,
    required this.name,
    required this.role,
    required this.type,
    required this.primaryImageTag,
  });

  final String id;
  final String name;

  /// Character name for actors, job for crew; may be empty.
  final String role;

  /// "Actor", "Director", "Writer", ...
  final String type;
  final String? primaryImageTag;

  factory MediaPerson.fromJson(Map<String, dynamic> json) => MediaPerson(
        id: json['Id'] as String? ?? '',
        name: json['Name'] as String? ?? '',
        role: json['Role'] as String? ?? '',
        type: json['Type'] as String? ?? '',
        primaryImageTag: json['PrimaryImageTag'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Role': role,
        'Type': type,
        'PrimaryImageTag': primaryImageTag,
      };
}

/// A Jellyfin library item: movie, series, season, episode, or collection.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.name,
    required this.kind,
    this.overview,
    this.taglines = const [],
    this.year,
    this.runtime,
    this.genres = const [],
    this.communityRating,
    this.officialRating,
    this.imageTags = const {},
    this.backdropImageTags = const [],
    this.seriesId,
    this.seriesName,
    this.seriesPrimaryImageTag,
    this.parentBackdropItemId,
    this.parentBackdropImageTags = const [],
    this.seasonId,
    this.indexNumber,
    this.parentIndexNumber,
    this.childCount,
    this.people = const [],
    this.userData,
  });

  final String id;
  final String name;
  final MediaKind kind;
  final String? overview;
  final List<String> taglines;
  final int? year;
  final Duration? runtime;
  final List<String> genres;

  /// Community rating on a 0–10 scale (e.g. 7.8).
  final double? communityRating;

  /// Parental rating ("PG-13", "TV-MA").
  final String? officialRating;

  /// Image tags by type: Primary, Logo, Thumb, Banner...
  final Map<String, String> imageTags;
  final List<String> backdropImageTags;

  // Episode/season ancestry — lets episode cards show series artwork.
  final String? seriesId;
  final String? seriesName;
  final String? seriesPrimaryImageTag;
  final String? parentBackdropItemId;
  final List<String> parentBackdropImageTags;
  final String? seasonId;

  /// Episode number (or season number on a season item).
  final int? indexNumber;

  /// Season number on an episode item.
  final int? parentIndexNumber;

  /// Number of children (episodes in a season, items in a collection).
  final int? childCount;
  final List<MediaPerson> people;
  final UserItemData? userData;

  bool get isEpisode => kind == MediaKind.episode;

  /// 0.0–1.0 resume progress for progress bars; null when not started.
  double? get progress {
    final data = userData;
    if (data == null || !data.inProgress) return null;
    final pct = data.playedPercentage;
    if (pct != null) return (pct / 100).clamp(0.0, 1.0);
    final total = runtime;
    if (total == null || total == Duration.zero) return null;
    return (data.playbackPosition.inSeconds / total.inSeconds)
        .clamp(0.0, 1.0);
  }

  /// "S2 · E5" style label for episodes; empty otherwise.
  String get episodeLabel {
    if (!isEpisode) return '';
    final season = parentIndexNumber;
    final episode = indexNumber;
    return [
      if (season != null) 'S$season',
      if (episode != null) 'E$episode',
    ].join(' · ');
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['Id'] as String? ?? '',
        name: json['Name'] as String? ?? '',
        kind: MediaKind.fromWire(json['Type'] as String?),
        overview: json['Overview'] as String?,
        taglines: _stringList(json['Taglines']),
        year: json['ProductionYear'] as int?,
        runtime: json['RunTimeTicks'] == null
            ? null
            : ticksToDuration(json['RunTimeTicks']),
        genres: _stringList(json['Genres']),
        communityRating: (json['CommunityRating'] as num?)?.toDouble(),
        officialRating: json['OfficialRating'] as String?,
        imageTags: (json['ImageTags'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
        backdropImageTags: _stringList(json['BackdropImageTags']),
        seriesId: json['SeriesId'] as String?,
        seriesName: json['SeriesName'] as String?,
        seriesPrimaryImageTag: json['SeriesPrimaryImageTag'] as String?,
        parentBackdropItemId: json['ParentBackdropItemId'] as String?,
        parentBackdropImageTags: _stringList(json['ParentBackdropImageTags']),
        seasonId: json['SeasonId'] as String?,
        indexNumber: json['IndexNumber'] as int?,
        parentIndexNumber: json['ParentIndexNumber'] as int?,
        childCount: json['ChildCount'] as int?,
        people: (json['People'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(MediaPerson.fromJson)
                .toList() ??
            const [],
        userData: json['UserData'] is Map<String, dynamic>
            ? UserItemData.fromJson(json['UserData'] as Map<String, dynamic>)
            : null,
      );

  /// Round-trips through the same shape as the wire format so cached
  /// items reuse [MediaItem.fromJson] — one parser, no drift.
  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Type': kind.wireName,
        'Overview': overview,
        'Taglines': taglines,
        'ProductionYear': year,
        'RunTimeTicks':
            runtime == null ? null : runtime!.inMicroseconds * 10,
        'Genres': genres,
        'CommunityRating': communityRating,
        'OfficialRating': officialRating,
        'ImageTags': imageTags,
        'BackdropImageTags': backdropImageTags,
        'SeriesId': seriesId,
        'SeriesName': seriesName,
        'SeriesPrimaryImageTag': seriesPrimaryImageTag,
        'ParentBackdropItemId': parentBackdropItemId,
        'ParentBackdropImageTags': parentBackdropImageTags,
        'SeasonId': seasonId,
        'IndexNumber': indexNumber,
        'ParentIndexNumber': parentIndexNumber,
        'ChildCount': childCount,
        'People': people.map((person) => person.toJson()).toList(),
        'UserData': userData?.toJson(),
      };

  static List<String> _stringList(Object? value) =>
      (value as List?)?.map((element) => element.toString()).toList() ??
      const [];
}

/// One page of a larger query (`BaseItemDtoQueryResult`).
class PagedItems {
  const PagedItems({
    required this.items,
    required this.totalCount,
    required this.startIndex,
  });

  final List<MediaItem> items;
  final int totalCount;
  final int startIndex;

  bool get hasMore => startIndex + items.length < totalCount;

  factory PagedItems.fromJson(Map<String, dynamic> json) => PagedItems(
        items: (json['Items'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(MediaItem.fromJson)
                .toList() ??
            const [],
        totalCount: json['TotalRecordCount'] as int? ?? 0,
        startIndex: json['StartIndex'] as int? ?? 0,
      );
}

/// Converts Jellyfin ticks (100-nanosecond units) to a [Duration].
Duration ticksToDuration(Object? ticks) => Duration(
      microseconds: ((ticks as num?) ?? 0) ~/ 10,
    );

/// Converts a [Duration] to Jellyfin ticks.
int durationToTicks(Duration duration) => duration.inMicroseconds * 10;
