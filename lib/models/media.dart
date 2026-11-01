import '../core/api_constants.dart';

/// A single artist credit on a track. [id] is the artist browse ID when
/// the API exposes it (empty string otherwise).
class TrackArtist {
  const TrackArtist({required this.name, this.id = ''});

  final String name;
  final String id;

  factory TrackArtist.fromJson(Map<String, dynamic> json) => TrackArtist(
        name: (json['name'] ?? '') as String,
        id: (json['id'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'id': id};
}

/// A playable track. `id` is the YouTube videoId.
class Track {
  const Track({
    required this.id,
    required this.title,
    this.artists = const [],
    this.albumName,
    this.albumBrowseId,
    this.durationSeconds,
    this.imageUrl,
    this.isExplicit = false,
  });

  /// YouTube videoId — unique and stable across the app.
  final String id;
  final String title;
  final List<TrackArtist> artists;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationSeconds;
  final String? imageUrl;
  final bool isExplicit;

  String get artistLabel =>
      artists.isEmpty ? 'Unknown artist' : artists.map((a) => a.name).join(', ');

  /// Best known artwork, falling back to the always-available YT thumbnail.
  String get artUrl =>
      (imageUrl != null && imageUrl!.isNotEmpty)
          ? imageUrl!
          : ytThumb(id);

  Duration get duration => Duration(seconds: durationSeconds ?? 0);

  String get durationLabel {
    final d = duration;
    if (d.inSeconds == 0) return '--:--';
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final mm = (m % 60).toString().padLeft(2, '0');
      return '${d.inHours}:$mm:$s';
    }
    return '$m:$s';
  }

  Track copyWith({
    String? id,
    String? title,
    List<TrackArtist>? artists,
    String? albumName,
    String? albumBrowseId,
    int? durationSeconds,
    String? imageUrl,
    bool? isExplicit,
  }) =>
      Track(
        id: id ?? this.id,
        title: title ?? this.title,
        artists: artists ?? this.artists,
        albumName: albumName ?? this.albumName,
        albumBrowseId: albumBrowseId ?? this.albumBrowseId,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        imageUrl: imageUrl ?? this.imageUrl,
        isExplicit: isExplicit ?? this.isExplicit,
      );

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        title: (json['title'] ?? '') as String,
        artists: ((json['artists'] as List?) ?? [])
            .whereType<Map>()
            .map((a) => TrackArtist.fromJson(Map<String, dynamic>.from(a)))
            .toList(),
        albumName: json['albumName'] as String?,
        albumBrowseId: json['albumBrowseId'] as String?,
        durationSeconds: json['durationSeconds'] as int?,
        imageUrl: json['imageUrl'] as String?,
        isExplicit: (json['isExplicit'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artists': artists.map((a) => a.toJson()).toList(),
        'albumName': albumName,
        'albumBrowseId': albumBrowseId,
        'durationSeconds': durationSeconds,
        'imageUrl': imageUrl,
        'isExplicit': isExplicit,
      };
}

/// A browsable collection: album, artist, or YT playlist/radio.
enum CollectionType { album, artist, playlist }

class Collection {
  const Collection({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.trackCount,
  });

  final CollectionType type;
  final String id; // browseId (MPREb… / UC… / VL…) or playlist id
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final int? trackCount;

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        type: CollectionType
            .values[(json['typeOrdinal'] ?? 0) as int],
        id: (json['id'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        subtitle: json['subtitle'] as String?,
        imageUrl: json['imageUrl'] as String?,
        trackCount: json['trackCount'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'typeOrdinal': type.index,
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'trackCount': trackCount,
      };
}

/// Everything needed to render one horizontal "shelf" of the Home page.
class MediaSection {
  const MediaSection({
    required this.title,
    this.tracks = const [],
    this.collections = const [],
  });

  final String title;
  final List<Track> tracks;
  final List<Collection> collections;
}

/// Result bundle for the Search tab.
class SearchResults {
  const SearchResults({
    this.tracks = const [],
    this.collections = const [],
    this.continuation,
  });

  final List<Track> tracks;
  final List<Collection> collections;

  /// InnerTube continuation token for the next page (null ⇒ no more pages).
  final String? continuation;

  bool get isEmpty => tracks.isEmpty && collections.isEmpty;
}

/// A user-authored playlist stored locally on the device (SharedPreferences).
class UserPlaylist {
  UserPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.tracks = const [],
  });

  final String id; // local UUID
  final String name;
  final DateTime createdAt;
  final List<Track> tracks;

  UserPlaylist copyWith({String? name, List<Track>? tracks}) => UserPlaylist(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        tracks: tracks ?? this.tracks,
      );

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        tracks: ((json['tracks'] as List?) ?? [])
            .whereType<Map>()
            .map((t) => Track.fromJson(Map<String, dynamic>.from(t)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}
