import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/media.dart';
import '../services/yt_music_service.dart';
import '../state/player_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/media_art.dart';
import '../widgets/shelf.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';

/// Home tab: content lanes assembled from the personalized (FEmusic_home)
/// feed and the charts endpoint, fetched in parallel with graceful fallbacks.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final YtMusicService _service = YtMusicService();

  List<MediaSection>? _homeShelves;
  List<MediaSection>? _chartShelves;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);

    List<MediaSection> home;
    List<MediaSection> charts;
    try {
      home = await _service.homeSections();
    } catch (_) {
      home = const [];
    }
    try {
      charts = await _service.chartSections();
    } catch (_) {
      charts = const [];
    }

    if (!mounted) return;
    setState(() {
      _homeShelves = home;
      _chartShelves = charts;
      if (home.isEmpty && charts.isEmpty) {
        _error = 'Could not reach YouTube Music. Check your connection.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AstraTheme.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AstraTheme.accentStatic,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              pinned: false,
              floating: true,
              backgroundColor: AstraTheme.background,
              title: Text(
                'Astra',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your music, unfiltered. No ads. Ever.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AstraTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 22),
                  ],
                ),
              ),
            ),
            ..._contentSlivers(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers() {
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: AstraTheme.pagePadding,
            child: _ErrorCard(message: _error!, onRetry: _refresh),
          ),
        ),
      ];
    }

    final loadingStill = _homeShelves == null && _chartShelves == null;
    if (loadingStill) {
      return const [
        SliverToBoxAdapter(
          child: Column(
            children: [
              PlaceholderShelf(titlePlaceholderCount: 4),
              SizedBox(height: 30),
              PlaceholderShelf(titlePlaceholderCount: 4),
            ],
          ),
        ),
      ];
    }

    final sections = <MediaSection>[
      ...?_chartShelves,
      ...?_homeShelves,
    ];

    if (sections.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: AstraTheme.pagePadding,
            child: Text(
              'Nothing here yet — try a search to get started.',
              style: TextStyle(color: AstraTheme.textSecondary),
            ),
          ),
        ),
      ];
    }

    return [
      for (final section in sections)
        SliverToBoxAdapter(
          child: _SectionWidget(section: section),
        ),
    ];
  }
}

/// Renders one shelf: artwork row for albums/artists, song cards for charts,
/// or plain tiles for small lists.
class _SectionWidget extends StatelessWidget {
  const _SectionWidget({required this.section});

  final MediaSection section;

  @override
  Widget build(BuildContext context) {
    final title = section.title.trim().isEmpty
        ? 'For you'
        : section.title.trim();

    if (section.collections.length >= 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArtworkShelf(
            title: title,
            children: [
              for (final c in section.collections.take(12))
                c.type == CollectionType.artist
                    ? ArtistCard(collection: c)
                    : AlbumCard(collection: c)
            ],
          ),
          const SizedBox(height: 30),
        ],
      );
    }

    if (section.tracks.length >= 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArtworkShelf(
            title: title,
            children: [
              for (final t in section.tracks.take(12)) _SongCard(track: t),
            ],
          ),
          const SizedBox(height: 30),
        ],
      );
    }

    if (section.tracks.isEmpty && section.collections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: AstraTheme.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title),
          for (final t in section.tracks.take(8)) TrackTile(track: t),
          for (final c in section.collections.take(8)) AlbumCard(collection: c),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Square card for a single song; tap = play + open Now Playing.
class _SongCard extends StatelessWidget {
  const _SongCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await context
            .read<PlayerProvider>()
            .playTracks([track], title: track.artistLabel);
        if (context.mounted) {
          Navigator.of(context).push(NowPlayingScreen.route());
        }
      },
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaArt(url: track.artUrl, size: 148, radius: AstraTheme.radiusM),
            const SizedBox(height: 10),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              track.artistLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AstraTheme.surface,
        borderRadius: BorderRadius.circular(AstraTheme.radiusL),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AstraTheme.errorTint),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AstraTheme.textPrimary),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
