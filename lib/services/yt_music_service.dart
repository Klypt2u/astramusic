import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_constants.dart';
import '../models/media.dart';
import 'piped_service.dart';

/// ---------------------------------------------------------------------------
/// YtMusicService — a minimal InnerTube (YouTube Music) client.
///
/// Wraps:
///   •  /youtubei/v1/search         — songs/videos, albums, artists, playlists
///   •  /youtubei/v1/browse         — home feed, charts, album/artist/playlist pages
///   •  /youtubei/v1/player         — direct audio stream URLs (iOS client)
///   •  /youtubei/v1/music/get_search_suggestions
///
/// Stream resolution first tries the InnerTube "IOS" client (whose responses
/// contain plain, unscrambled URLs — no signature deciphering needed), then
/// falls back to public Piped/Invidious instances via [PipedService].
/// No paid or user API keys are used anywhere.
/// ---------------------------------------------------------------------------
class YtMusicService {
  YtMusicService({StreamResolver? streamResolver})
      : _streamResolver = streamResolver ?? PipedService();

  final StreamResolver _streamResolver;

  static const Duration _timeout = Duration(seconds: 15);

  // -------------------------------------------------------------------------
  // Low-level plumbing
  // -------------------------------------------------------------------------

  Map<String, String> get _musicHeaders => {
        'Content-Type': 'application/json',
        'User-Agent': kMusicUserAgent,
        'X-Youtube-Client-Name': '67',
        'X-Youtube-Client-Version': kMusicClientVersion,
        'X-Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
        'Origin': 'https://music.youtube.com',
      };

  Map<String, String> get _iosHeaders => {
        'Content-Type': 'application/json',
        'User-Agent': kIosUserAgent,
        'X-Youtube-Client-Name': '5',
        'X-Youtube-Client-Version': kIosClientVersion,
      };

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    bool iosClient = false,
    bool withContext = true,
  }) async {
    final base = iosClient ? kYoutubeApiBase : kMusicApiBase;
    final key = iosClient ? kIosInnertubeApiKey : kMusicInnertubeApiKey;
    final uri = Uri.parse('$base/$endpoint?prettyPrint=false&key=$key');
    final headers = iosClient ? _iosHeaders : _musicHeaders;
    final payload = withContext
        ? {
            ...body,
            'context': iosClient ? iosPlayerContext : musicContext,
          }
        : body;

    final res = await http
        .post(uri, headers: headers, body: jsonEncode(payload))
        .timeout(_timeout, onTimeout: () => throw TimeoutException(endpoint));
    if (res.statusCode != 200) {
      throw YtMusicException(
          'InnerTube $endpoint failed: HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Generic deep navigation into loosely-typed InnerTube JSON.
  static dynamic nav(dynamic data, List<Object> path) {
    dynamic current = data;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else if (current is List && key is int && key < current.length) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  static List<Map<String, dynamic>> _objList(dynamic data) {
    if (data is! List) return [];
    return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  static String _runsText(dynamic runs) {
    if (runs is! List) return '';
    return runs.whereType<Map>().map((r) => (r['text'] ?? '') as String).join('');
  }

  static List<String> _subtitleTokens(dynamic runs) {
    final joined = _runsText(runs);
    return joined
        .split(' • ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? _bestThumb(dynamic container) {
    final thumbs = nav(container ?? const {}, const ['thumbnails']);
    if (thumbs is! List || thumbs.isEmpty) return null;
    Map<String, dynamic>? best;
    int bestArea = 0;
    for (final t in thumbs) {
      if (t is! Map) continue;
      final w = (t['width'] as num?)?.toInt() ?? 0;
      final h = (t['height'] as num?)?.toInt() ?? 0;
      if (w * h > bestArea) {
        bestArea = w * h;
        best = Map<String, dynamic>.from(t);
      }
    }
    var url = best?['url'] as String?;
    if (url != null && url.startsWith('//')) url = 'https:$url';
    return url;
  }

  /// "4:15" / "1:02:31" duration parser; returns null for non-durations.
  static int? parseDuration(String? text) {
    if (text == null) return null;
    final match =
        RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2)) ?? 0;
    final seconds = int.tryParse(match.group(3)) ?? 0;
    return hours * 3600 + minutes * 60 + seconds;
  }

  static bool _isYear(String token) =>
      RegExp(r'^\d{4}$').hasMatch(token) || token.contains(' views');

  // -------------------------------------------------------------------------
  // Search
  // -------------------------------------------------------------------------

  Future<SearchResults> search(
    String query, {
    String filter = 'all', // all | songs | videos | albums | artists | playlists
  }) async {
    final params = kSearchFilterParams[filter];
    final data = await _post('search', {
      'query': query,
      if (params != null) 'params': params,
    });

    final results = <Track>[];
    final collections = <Collection>[];
    String? continuation;

    final items = _extractSearchItems(data);
    for (final item in items) {
      if (nav(item, ['continuationItemRenderer', 'continuationEndpoint',
              'continuationCommand', 'token'])
          is String) {
        continuation = nav(item, ['continuationItemRenderer',
                'continuationEndpoint', 'continuationCommand', 'token'])
            as String;
      }
      final responsive = item['musicResponsiveListItemRenderer'];
      if (responsive is! Map) continue;
      final parsed = _parseResponsiveListItem(
          Map<String, dynamic>.from(responsive), filter);
      _appendParsed(results, collections, parsed);
    }

    // Optional "Top result" card for unfiltered searches.
    if (filter == 'all') {
      final cards = _collectMaps(data['contents'] ?? data, 'musicCardShelfRenderer');
      if (cards.isNotEmpty) {
        final parsed = _parseCardShelf(cards.first);
        _appendParsed(results, collections, parsed);
      }
    }

    return SearchResults(
      tracks: results,
      collections: collections,
      continuation: continuation,
    );
  }

  /// Next page for the same search. Empty results ⇒ no more pages.
  Future<SearchResults> searchMore(String continuation, String filter) async {
    final data = await _post('search', {'continuation': continuation});
    final actions = _objList(data['onResponseReceivedActions']);
    for (final action in actions) {
      final items = _objList(
          nav(action, ['appendContinuationItemsAction', 'continuationItems']));
      final results = <Track>[];
      final collections = <Collection>[];
      String? nextToken;
      for (final item in items) {
        if (nav(item, ['continuationItemRenderer', 'continuationEndpoint',
                'continuationCommand', 'token'])
            is String) {
          nextToken = nav(item, ['continuationItemRenderer',
                  'continuationEndpoint', 'continuationCommand', 'token'])
              as String;
        }
        final responsive = item['musicResponsiveListItemRenderer'];
        if (responsive is! Map) continue;
        final parsed = _parseResponsiveListItem(
            Map<String, dynamic>.from(responsive), filter);
        _appendParsed(results, collections, parsed);
      }
      return SearchResults(
        tracks: results,
        collections: collections,
        continuation: nextToken,
      );
    }
    return const SearchResults();
  }

  List<Map<String, dynamic>> _extractSearchItems(Map<String, dynamic> data) {
    final items = <Map<String, dynamic>>[];
    final shelves = _collectMaps(data['contents'] ?? data, 'musicShelfRenderer');
    for (final shelf in shelves) {
      items.addAll(_objList(shelf['contents']));
    }
    return items;
  }

  void _appendParsed(
      List<Track> tracks, List<Collection> collections, Object? parsed) {
    if (parsed is Track) {
      if (tracks.every((t) => t.id != parsed.id)) tracks.add(parsed);
    } else if (parsed is Collection) {
      if (collections.every((c) => c.id != parsed.id)) collections.add(parsed);
    }
  }

  /// Parse one musicResponsiveListItemRenderer into either a [Track] or a
  /// [Collection] depending on available navigation data.
  Object? _parseResponsiveListItem(
      Map<String, dynamic> item, String filter) {
    final policy = item['musicItemRendererDisplayPolicy'];
    if (policy == 'MUSIC_ITEM_RENDERER_DISPLAY_POLICY_GREY_OUT') return null;

    final flexColumns = _objList(item['flexColumns']);
    final titleText = flexColumns.isNotEmpty
        ? _runsText(nav(flexColumns.first,
            ['musicResponsiveListItemFlexColumnRenderer', 'text', 'runs']))
        : '';
    if (titleText.isEmpty) return null;

    final subtitleRuns = flexColumns.length > 1
        ? _subtitleTokens(nav(flexColumns[1],
            ['musicResponsiveListItemFlexColumnRenderer', 'text', 'runs']))
        : <String>[];

    String? duration;
    for (final col in _objList(item['fixedColumns'])) {
      final txt = _runsText(nav(col,
          ['musicResponsiveListItemFixedColumnRenderer', 'text', 'runs']));
      duration ??= parseDuration(txt) != null ? txt : null;
    }

    final browseId =
        nav(item, ['navigationEndpoint', 'browseEndpoint', 'browseId'])
            as String?;
    final videoId =
        (nav(item, ['playlistItemData', 'videoId']) as String?) ??
            (nav(item, [
              'flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer',
              'text', 'runs', 0, 'navigationEndpoint', 'watchEndpoint',
              'videoId'
            ]) as String?);
    final thumbs = _bestThumb(item['thumbnail']);
    final explicit = (item['badges'] as List? ?? []).any((b) =>
        nav(b, ['musicInlineBadgeRenderer', 'icon', 'iconType']) ==
        'MUSIC_EXPLICIT_BADGE');

    String? resolveType() {
      if (filter == 'songs' || filter == 'videos') return 'song';
      if (filter == 'albums') return 'album';
      if (filter == 'artists') return 'artist';
      if (filter == 'playlists') return 'playlist';
      if (browseId != null) {
        for (final entry in kBrowseIdPrefixTypes.entries) {
          if (browseId.startsWith(entry.key)) return entry.value;
        }
      }
      return videoId != null ? 'song' : null;
    }

    switch (resolveType()) {
      case 'song':
        if (videoId == null) return null;
        final content = subtitleRuns.where((s) => !_isYear(s)).toList();
        final artistNames = content.length > 1 ? [content.first] : <String>[];
        final albumName = content.length > 1 ? content[1] : null;
        return Track(
          id: videoId,
          title: titleText,
          artists: artistNames.map(TrackArtist.new).toList(),
          albumName: albumName,
          durationSeconds: parseDuration(duration),
          imageUrl: thumbs,
          isExplicit: explicit,
        );
      case 'album':
      case 'artist':
      case 'playlist':
        if (browseId == null) return null;
        return _parseResponsiveCollection(browseId, titleText, subtitleRuns, thumbs);
      default:
        return null;
    }
  }

  Collection _parseResponsiveCollection(
      String browseId, String title, List<String> subtitleRuns, String? thumbs) {
    final type = kBrowseIdPrefixTypes.entries
        .firstWhere(
          (e) => browseId.startsWith(e.key),
          orElse: () => const MapEntry('', 'album'),
        )
        .value;
    final isAlbum = type == 'album';
    final artistRun = isAlbum && subtitleRuns.length >= 2
        ? subtitleRuns.last
        : (subtitleRuns.isNotEmpty ? subtitleRuns.first : '');
    final detail = subtitleRuns.where((s) => s != artistRun).join(' • ');
    final collectionType = type == 'artist'
        ? CollectionType.artist
        : type == 'playlist'
            ? CollectionType.playlist
            : CollectionType.album;
    return Collection(
      type: collectionType,
      id: browseId,
      title: title,
      subtitle: artistRun.isEmpty ? detail : artistRun,
      imageUrl: thumbs,
    );
  }

  /// Parse the "Top result" card of an unfiltered search.
  Object? _parseCardShelf(Map<String, dynamic> card) {
    final title = _runsText(nav(card, ['title', 'runs']));
    if (title.isEmpty) return null;
    final subtitleRuns =
        _subtitleTokens(nav(card, ['subtitle', 'runs']));
    final videoId = nav(card, ['onTap', 'watchEndpoint', 'videoId']) as String?;
    final browseId = nav(card, [
      'title', 'runs', 0, 'navigationEndpoint', 'browseEndpoint', 'browseId'
    ]) as String?;
    final thumbs =
        _bestThumb(nav(card, ['thumbnail', 'musicThumbnailRenderer']));
    final explicit =
        subtitleRuns.any((s) => s.toLowerCase() == 'explicit');

    if (videoId != null) {
      final content = subtitleRuns
          .where((s) => s != 'Song' && s != 'Video' && !_isYear(s))
          .toList();
      return Track(
        id: videoId,
        title: title,
        artists: [
          if (content.isNotEmpty) TrackArtist(name: content.first),
        ],
        albumName: content.length > 1 ? content[1] : null,
        durationSeconds: _firstDuration(subtitleRuns),
        imageUrl: thumbs,
        isExplicit: explicit,
      );
    }
    if (browseId != null) {
      return _parseResponsiveCollection(browseId, title, subtitleRuns, thumbs);
    }
    return null;
  }

  static int? _firstDuration(List<String> tokens) {
    for (final t in tokens) {
      final d = parseDuration(t);
      if (d != null) return d;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Search suggestions
  // -------------------------------------------------------------------------

  Future<List<String>> searchSuggestions(String input) async {
    if (input.trim().isEmpty) return [];
    try {
      final data = await _post('music/get_search_suggestions', {
        'input': input,
      });
      final entries = _objList(nav(
          data, ['contents', 0, 'searchSuggestionsSectionRenderer', 'contents']));
      return [
        for (final e in entries)
          if (nav(e, ['searchSuggestionRenderer', 'navigationEndpoint',
                  'searchEndpoint', 'query'])
              is String)
            nav(e, ['searchSuggestionRenderer', 'navigationEndpoint',
                    'searchEndpoint', 'query'])!
                as String,
      ];
    } catch (_) {
      return []; // Suggestions are decorative — never block the search box.
    }
  }

  // -------------------------------------------------------------------------
  // Browse: home feed & charts
  // -------------------------------------------------------------------------

  Future<List<MediaSection>> homeSections() async {
    final data = await _post('browse', {'browseId': kBrowseHome});
    return _parseCarouselShelves(data) ?? [];
  }

  Future<List<MediaSection>> chartSections() async {
    final data = await _post('browse', {'browseId': kBrowseCharts});
    return _parseCarouselShelves(data) ?? [];
  }

  /// Flattens a browse response into one [MediaSection] per carousel shelf.
  List<MediaSection>? _parseCarouselShelves(Map<String, dynamic> data) {
    final root = _collectMaps(data['contents'] ?? data, 'sectionListRenderer');
    final sectionContents =
        (root.isNotEmpty ? root.first['contents'] : null) as List<dynamic>? ?? [];

    final sections = <MediaSection>[];
    for (final rawSection in sectionContents.whereType<Map>()) {
      final carousel = rawSection['musicCarouselShelfRenderer'] ??
          rawSection['musicShelfRenderer'];
      if (carousel is! Map) continue;
      final shelf = Map<String, dynamic>.from(carousel);

      final headerTitle =
          _runsText(nav(shelf, [
                'header', 'musicCarouselShelfHeaderRenderer', 'title', 'runs'
              ])).isNotEmpty
              ? _runsText(nav(shelf, [
                  'header', 'musicCarouselShelfHeaderRenderer', 'title', 'runs'
                ]))
              : _runsText(shelf['title']);
      final title = headerTitle.isEmpty ? 'More of what you like' : headerTitle;

      final tracks = <Track>[];
      final collections = <Collection>[];
      for (final raw in _objList(shelf['contents'])) {
        final twoRow = raw['musicTwoRowItemRenderer'];
        final responsive = raw['musicResponsiveListItemRenderer'];
        if (twoRow is Map) {
          final parsed =
              _parseTwoRowItem(Map<String, dynamic>.from(twoRow));
          _appendParsed(tracks, collections, parsed);
        } else if (responsive is Map) {
          final parsed = _parseResponsiveListItem(
              Map<String, dynamic>.from(responsive), 'all');
          _appendParsed(tracks, collections, parsed);
        }
      }
      if (tracks.isNotEmpty || collections.isNotEmpty) {
        sections.add(
            MediaSection(title: title, tracks: tracks, collections: collections));
      }
    }
    return sections;
  }

  /// Parse a home-feed two-row card (album / artist / playlist / song).
  Object? _parseTwoRowItem(Map<String, dynamic> item) {
    final title = _runsText(nav(item, ['title', 'runs']));
    if (title.isEmpty) return null;

    final subtitleRuns = _subtitleTokens(nav(item, ['subtitle', 'runs']));

    final browseId =
        nav(item, ['navigationEndpoint', 'browseEndpoint', 'browseId'])
            as String?;
    final videoId = (nav(item, ['navigationEndpoint', 'watchEndpoint', 'videoId'])
            as String?) ??
        (nav(item, [
          'thumbnailOverlay', 'musicItemThumbnailOverlayRenderer', 'content',
          'musicPlayButtonRenderer', 'playNavigationEndpoint', 'watchEndpoint',
          'videoId'
        ]) as String?);

    final thumbs = _bestThumb(item['thumbnailRenderer']);

    if (videoId != null) {
      return Track(
        id: videoId,
        title: title,
        artists: [
          if (subtitleRuns.isNotEmpty) TrackArtist(name: subtitleRuns.first),
        ],
        albumName: subtitleRuns.length > 1 ? subtitleRuns[1] : null,
        imageUrl: thumbs,
      );
    }
    if (browseId == null) return null;
    return _parseResponsiveCollection(browseId, title, subtitleRuns, thumbs);
  }

  // -------------------------------------------------------------------------
  // Browse: album / artist / playlist detail pages
  // -------------------------------------------------------------------------

  /// Full detail bundle for an album, artist, or playlist collection page:
  /// header info + main track list + related collection shelves.
  Future<CollectionDetail> getCollectionDetails(Collection collection) async {
    final data = await _post('browse', {'browseId': collection.id});

    final tracks = <Track>[];
    final related = <Collection>[];

    // Header — several renderer shapes across album/artist/playlist pages.
    final header = _firstMap([
      data['header'],
      ..._collectMaps(data['contents'] ?? data, 'musicResponsiveHeaderRenderer'),
      ..._collectMaps(data['contents'] ?? data, 'musicDetailHeaderRenderer'),
      ..._collectMaps(data['contents'] ?? data, 'musicImmersiveHeaderRenderer'),
    ]);

    String? headerTitle = collection.title;
    String? headerSubtitle = collection.subtitle;
    String? headerThumb = collection.imageUrl;

    if (header != null) {
      final title = _runsText(nav(header, ['title', 'runs']));
      if (title.isNotEmpty) headerTitle = title;
      final subtitle = _objList(nav(header, ['subtitle', 'runs']))
          .map((r) => (r['text'] ?? '') as String)
          .join(' • ');
      if (subtitle.isNotEmpty) headerSubtitle = subtitle;
      headerThumb = _firstNonNull([
        headerThumb,
        _bestThumb(nav(header, ['thumb', 'musicThumbnailRenderer'])),
        _bestThumb(nav(header, ['foregroundHeader', 'musicThumbnailRenderer'])),
      ]);
    }

    headerThumb = _firstNonNull([
        headerThumb,
        _bestThumb(nav(data, [
          'header', 'musicResponsiveHeaderRenderer', 'thumb',
          'musicThumbnailRenderer'
        ])),
      ]);

    // Track shelves. Artist "Top songs" shelves classify rendered rows as
    // songs thanks to the videos filter hint; album/playlist pages carry
    // playlistItemData.videoId which our parser reads.
    final shelves = _collectMaps(data['contents'] ?? data, 'musicShelfRenderer');
    for (final shelf in shelves) {
      for (final raw in _objList(shelf['contents'])) {
        final responsive = raw['musicResponsiveListItemRenderer'];
        if (responsive is! Map) continue;
        final hint = shelf['title'] is Map && _runsText(nav(shelf, ['title', 'runs']))
                .toLowerCase()
                .contains('song')
            ? 'videos'
            : 'all';
        final parsed = _parseResponsiveListItem(
            Map<String, dynamic>.from(responsive), hint);
        if (parsed is Track) {
          if (tracks.every((t) => t.id != parsed.id)) tracks.add(parsed);
        }
      }
    }

    // Related carousels (artist albums/singles, "more" shelves).
    final carousels =
        _collectMaps(data['contents'] ?? data, 'musicCarouselShelfRenderer');
    for (final carousel in carousels) {
      final headerTitle = _runsText(nav(carousel, [
            'header', 'musicCarouselShelfHeaderRenderer', 'title', 'runs'
          ]));
      if (headerTitle.toLowerCase() == 'singles' && collection.type != CollectionType.artist) {
        continue;
      }
      for (final raw in _objList(carousel['contents'])) {
        final twoRow = raw['musicTwoRowItemRenderer'];
        if (twoRow is! Map) continue;
        final parsed = _parseTwoRowItem(Map<String, dynamic>.from(twoRow));
        if (parsed is Collection && related.every((c) => c.id != parsed.id)) {
          related.add(parsed);
        }
      }
    }

    return CollectionDetail(
      collection: Collection(
        type: collection.type,
        id: collection.id,
        title: headerTitle ?? collection.title,
        subtitle: headerSubtitle ?? collection.subtitle,
        imageUrl: headerThumb ?? collection.imageUrl,
        trackCount: tracks.length,
      ),
      tracks: tracks,
      relatedCollections: related,
    );
  }

  // -------------------------------------------------------------------------
  // Stream resolution
  // -------------------------------------------------------------------------

  /// Resolves the best direct audio URL for a track.
  /// Try 1: InnerTube iOS player client → direct unscrambled URLs.
  /// Try 2: public Piped instances (with Invidious as last resort).
  Future<AstraStream> getStreamUrl(Track track) async {
    YtMusicException innerTubeError;
    try {
      return await _innertubeStream(track.id);
    } catch (e) {
      innerTubeError =
          e is YtMusicException ? e : YtMusicException(e.toString());
    }
    try {
      return await _streamResolver.resolve(track.id);
    } catch (e) {
      throw YtMusicException(
          'Stream resolution failed for "${track.title}": '
          'innerTube(${innerTubeError.message}); fallback($e)');
    }
  }

  Future<AstraStream> _innertubeStream(String videoId) async {
    final data = await _post('player', {
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    }, iosClient: true);

    final playability = data['playabilityStatus'] as Map?;
    if (playability?['status'] != 'OK') {
      throw YtMusicException(playability?['reason'] ?? 'Unplayable video');
    }

    final streamingData = (data['streamingData'] as Map?) ?? const {};
    final formats = [
      ..._objList(streamingData['adaptiveFormats']),
      ..._objList(streamingData['formats']),
    ];

    AstraStream? best;
    int bestBitrate = 0;
    for (final f in formats) {
      final url = f['url'] as String?;
      if (url == null) continue;
      final mime = (f['mimeType'] ?? '').toString();
      if (!mime.startsWith('audio')) continue;
      final bitrate = ((f['averageBitrate'] ?? 0) as num).toInt();
      if (bitrate > bestBitrate) {
        bestBitrate = bitrate;
        best = AstraStream(
          url: url.startsWith('//') ? 'https:$url' : url,
          mimeType: mime.split(';').first,
          bitrateKbps: bitrate ~/ 1000,
        );
      }
    }
    if (best == null) throw YtMusicException('No audio formats returned');
    return best;
  }
}

// =============================================================================
// Supporting types
// =============================================================================

/// A resolved, playable stream.
class AstraStream {
  const AstraStream({
    required this.url,
    required this.mimeType,
    required this.bitrateKbps,
  });
  final String url;
  final String mimeType;
  final int bitrateKbps;

  Uri get uri => Uri.parse(url);
}

class YtMusicException implements Exception {
  const YtMusicException(this.message);
  final String message;

  @override
  String toString() => 'YtMusicException: $message';
}

/// Aggregate detail bundle for an album / artist / playlist page.
class CollectionDetail {
  const CollectionDetail({
    required this.collection,
    this.tracks = const [],
    this.relatedCollections = const [],
  });
  final Collection collection;
  final List<Track> tracks;
  final List<Collection> relatedCollections;
}

// =============================================================================
// Tiny JSON helpers
// =============================================================================

/// Recursively collect all child maps under [key] from a JSON subtree.
List<Map<String, dynamic>> _collectMaps(dynamic data, String key) {
  final out = <Map<String, dynamic>>[];
  void rec(dynamic node) {
    if (node is Map) {
      if (node[key] is Map) {
        out.add(Map<String, dynamic>.from(node[key]));
      }
      for (final v in node.values) {
        rec(v);
      }
    } else if (node is List) {
      for (final v in node) {
        rec(v);
      }
    }
  }

  rec(data);
  return out;
}

Map<String, dynamic>? _firstMap(List<dynamic> candidates) {
  for (final c in candidates) {
    if (c is Map && c.isNotEmpty) return Map<String, dynamic>.from(c);
  }
  return null;
}

dynamic _firstNonNull(List<dynamic> candidates) {
  for (final c in candidates) {
    if (c != null) return c;
  }
  return null;
}
