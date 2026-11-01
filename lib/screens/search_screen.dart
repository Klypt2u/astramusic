import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/media.dart';
import '../services/yt_music_service.dart';
import '../widgets/album_card.dart';
import '../widgets/shelf.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _SearchFilter { all, songs, albums, artists, playlists }

extension _SearchFilterX on _SearchFilter {
  String get apiKey => switch (this) {
        _SearchFilter.all => 'all',
        _SearchFilter.songs => 'songs',
        _SearchFilter.albums => 'albums',
        _SearchFilter.artists => 'artists',
        _SearchFilter.playlists => 'playlists',
      };

  String get label => switch (this) {
        _SearchFilter.all => 'All',
        _SearchFilter.songs => 'Songs',
        _SearchFilter.albums => 'Albums',
        _SearchFilter.artists => 'Artists',
        _SearchFilter.playlists => 'Playlists',
      };
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final YtMusicService _service = YtMusicService();
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  Timer? _debounce;

  SearchResults? _results;
  String? _continuation;
  String? _error;
  bool _loading = false;
  bool _loadingMore = false;
  _SearchFilter _filter = _SearchFilter.all;
  List<String> _suggestions = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _suggestions = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    // Suggestions fire almost instantly; results debounce 350ms.
    _fetchSuggestions(query);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final suggestions = await _service.searchSuggestions(query);
    if (!mounted || _queryController.text.trim() != query) return;
    setState(() => _suggestions = suggestions);
  }

  Future<void> _search(String query, {_SearchFilter? filter}) async {
    final f = filter ?? _filter;
    if (filter != null) setState(() => _filter = filter);
    setState(() {
      _loading = true;
      _error = null;
      _results = null;
      _continuation = null;
    });
    try {
      final res = await _service.search(query, filter: f.apiKey);
      if (!mounted || _queryController.text.trim() != query) return;
      setState(() {
        _results = res;
        _continuation = res.continuation;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _continuation == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final more =
          await _service.searchMore(_continuation!, _filter.apiKey);
      if (!mounted) return;
      setState(() {
        // Append for track-only filters; bubbles/duplicates are filtered
        // already by the service.
        _results = SearchResults(
          tracks: [...?_results?.tracks, ...more.tracks],
          collections: [...?_results?.collections, ...more.collections],
          continuation: more.continuation,
        );
        _continuation = more.continuation;
      });
    } catch (_) {
      // Pagination is best-effort; keep what we have.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AstraTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                controller: _queryController,
                focusNode: _queryFocus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(_queryController.text.trim()),
                style: const TextStyle(color: AstraTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Songs, albums, artists…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AstraTheme.textSecondary),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AstraTheme.textSecondary),
                          onPressed: () {
                            _queryController.clear();
                            _queryFocus.requestFocus();
                          },
                        ),
                ),
              ),
            ),
            // Filter chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final f in _SearchFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        selectedColor: AstraTheme.accentStatic,
                        backgroundColor: AstraTheme.surface,
                        labelStyle: TextStyle(
                          color: _filter == f
                              ? Colors.white
                              : AstraTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide.none,
                        showCheckmark: false,
                        onSelected: (_) {
                          if (_queryController.text.trim().isEmpty) return;
                          _search(_queryController.text.trim(), filter: f);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _body(colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _body(ColorScheme colorScheme) {
    if (_queryController.text.trim().isEmpty) {
      return _idleState();
    }
    if (_loading) return _loadingState();
    if (_error != null) {
      return _CenterNote(
        icon: Icons.wifi_off_rounded,
        text: 'Search failed — check your connection and try again.',
        actionLabel: 'Retry',
        onAction: () => _search(_queryController.text.trim()),
      );
    }
    final results = _results;
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty) {
      return const _CenterNote(
        icon: Icons.search_off_rounded,
        text: 'No results found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount:
          results.tracks.length + results.collections.length + 1,
      itemBuilder: (context, i) {
        // Track rows in "All"/"Songs"/"Videos" were parsed to tracks.
        if (i < results.tracks.length) {
          return TrackTile(track: results.tracks[i]);
        }
        if (i - results.tracks.length < results.collections.length) {
          final c = results.collections[i - results.tracks.length];
          return AlbumCard(collection: c);
        }
        // Pagination row.
        if (i == results.tracks.length + results.collections.length) {
          if (_continuation == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AstraTheme.accentStatic,
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _loadMore,
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _idleState() {
    // Suggestion surface while the field has focus & cached text history.
    if (_suggestions.isEmpty) {
      return const _CenterNote(
        icon: Icons.explore_rounded,
        text: 'Search across songs, albums, artists and playlists.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _suggestions.length,
      itemBuilder: (context, i) {
        final suggestion = _suggestions[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.north_west_rounded,
              size: 18, color: AstraTheme.textSecondary),
          title: Text(suggestion,
              style: const TextStyle(color: AstraTheme.textPrimary)),
          onTap: () {
            _queryController.value = TextEditingValue(
              text: suggestion,
              selection:
                  TextSelection.collapsed(offset: suggestion.length),
            );
            _search(suggestion);
          },
        );
      },
    );
  }

  Widget _loadingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: const [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                ShimmerBox(width: 52, height: 52, radius: 10),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 14),
                      SizedBox(height: 8),
                      ShimmerBox(width: 120, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CenterNote extends StatelessWidget {
  const _CenterNote({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AstraTheme.textSecondary, size: 34),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AstraTheme.textSecondary),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
