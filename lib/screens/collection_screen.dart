import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/media.dart';
import '../state/library_provider.dart';
import '../state/player_provider.dart';
import '../widgets/media_art.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';

/// Opens the appropriate detail screen for a server-backed collection
/// (album / artist / YouTube playlist).
void openCollection(BuildContext context, Collection collection) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CollectionScreen(collection: collection),
    ),
  );
}

/// Detail page for a remote album, artist, or playlist.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.collection});

  final Collection collection;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final YtMusicService _service;
  CollectionDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = YtMusicService();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _error = null);
    try {
      final detail =
          await _service.getCollectionDetails(widget.collection);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = _detail?.collection ?? widget.collection;

    return Scaffold(
      backgroundColor: AstraTheme.background,
      body: SafeArea(
        bottom: false,
        child: _error != null
            ? _ErrorPane(message: _error!, onRetry: _fetch)
            : _detail == null
                ? const _LoadingPane()
                : _DetailBody(detail: _detail!, base: collection),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.base});

  final CollectionDetail detail;
  final Collection base;

  @override
  Widget build(BuildContext context) {
    final tracks = detail.tracks;
    final showRelated =
        detail.relatedCollections.isNotEmpty && tracks.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: AstraTheme.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: MediaArt(
                    url: base.imageUrl ?? '',
                    size: MediaQuery.of(context).size.width *
                        (detail.collection.type == CollectionType.artist
                            ? 0.42
                            : 0.55),
                    radius: detail.collection.type == CollectionType.artist
                        ? 999
                        : AstraTheme.radiusL,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  detail.collection.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  detail.collection.subtitle ?? base.subtitle ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AstraTheme.textPrimary,
                          foregroundColor: AstraTheme.background,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                        onPressed: tracks.isEmpty
                            ? null
                            : () async {
                                await context.read<PlayerProvider>().playTracks(
                                      tracks,
                                      title: detail.collection.title,
                                    );
                                if (context.mounted) {
                                  Navigator.of(context)
                                      .push(NowPlayingScreen.route());
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Shuffle'),
                      onPressed: tracks.isEmpty
                          ? null
                          : () async {
                              final provider =
                                  context.read<PlayerProvider>();
                              await provider.playTracks(
                                (tracks.toList()..shuffle()),
                                title: detail.collection.title,
                              );
                              await provider.toggleShuffle();
                              if (context.mounted) {
                                Navigator.of(context)
                                    .push(NowPlayingScreen.route());
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (tracks.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: AstraTheme.pagePadding,
              child: Text(
                'No playable tracks found on this page — YouTube Music may not expose them for this item.',
                style: TextStyle(color: AstraTheme.textSecondary),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => TrackTile(track: tracks[i]),
                childCount: tracks.length,
              ),
            ),
          ),
        if (showRelated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('More like this',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 170,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: detail.relatedCollections.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final c = detail.relatedCollections[i];
                        return GestureDetector(
                          onTap: () => openCollection(context, c),
                          child: SizedBox(
                            width: 132,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MediaArt(
                                    url: c.imageUrl ?? '', size: 132),
                                const SizedBox(height: 8),
                                Text(c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }
}

// =============================================================================
// Local (device-owned) screens
// =============================================================================

/// Local liked-songs screen with play/shuffle from the favorites list.
class LocalFavoritesScreen extends StatelessWidget {
  LocalFavoritesScreen();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final tracks = library.favorites;
    return _LocalListScreen(
      title: 'Liked songs',
      subtitle: '${tracks.length} tracks · synced on this device',
      imageUrl: tracks.isNotEmpty ? tracks.first.artUrl : null,
      tracks: tracks,
      onRemove: (track) => library.toggleFavorite(track),
    );
  }
}

/// Local user playlist with track management.
class LocalPlaylistScreen extends StatelessWidget {
  const LocalPlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final playlist = library.playlistById(playlistId);
    if (playlist == null) {
      return const Scaffold(
        backgroundColor: AstraTheme.background,
        body: Center(child: Text('Playlist not found')),
      );
    }
    return _LocalListScreen(
      title: playlist.name,
      subtitle: '${playlist.tracks.length} tracks · made by you',
      imageUrl: playlist.tracks.isNotEmpty ? playlist.tracks.first.artUrl : null,
      tracks: playlist.tracks,
      onRemove: (track) => library.removeFromPlaylist(playlist.id, track.id),
    );
  }
}

/// Shared list layout for local collections (favorites + playlists).
class _LocalListScreen extends StatelessWidget {
  const _LocalListScreen({
    required this.title,
    required this.subtitle,
    required this.tracks,
    this.imageUrl,
    this.onRemove,
  });

  final String title;
  final String subtitle;
  final List<Track> tracks;
  final String? imageUrl;
  final ValueChanged<Track>? onRemove;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AstraTheme.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: AstraTheme.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MediaArt(
                          url: imageUrl ?? '',
                          size: 92,
                          radius: AstraTheme.radiusM,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 4),
                              Text(subtitle,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AstraTheme.textPrimary,
                              foregroundColor: AstraTheme.background,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play'),
                            onPressed: tracks.isEmpty
                                ? null
                                : () async {
                                    await context
                                        .read<PlayerProvider>()
                                        .playTracks(tracks, title: title);
                                    if (context.mounted) {
                                      Navigator.of(context)
                                          .push(NowPlayingScreen.route());
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: tracks.isEmpty
                              ? null
                              : () async {
                                  final shuffled = tracks.toList();
                                  shuffled.shuffle();
                                  await context
                                      .read<PlayerProvider>()
                                      .playTracks(shuffled, title: title);
                                  if (context.mounted) {
                                    Navigator.of(context)
                                        .push(NowPlayingScreen.route());
                                  }
                                },
                          child: const Icon(Icons.shuffle_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (tracks.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'Nothing here yet.\nTap the ♥ on any track to add it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AstraTheme.textSecondary),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => TrackTile(
                      track: tracks[i],
                      onRemove: onRemove == null
                          ? null
                          : () => onRemove!(tracks[i]),
                    ),
                    childCount: tracks.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Loading / error panes
// =============================================================================

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AstraTheme.accentStatic),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AstraTheme.errorTint, size: 34),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AstraTheme.textSecondary,
                    fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
