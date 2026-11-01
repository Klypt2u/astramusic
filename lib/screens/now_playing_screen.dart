import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/library_provider.dart';
import '../state/player_provider.dart';
import '../widgets/mini_player.dart';

/// Immersive full-screen player. Surface tint is extracted live from the
/// album artwork with PaletteGenerator (Lyra's dynamic color accents).
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      opaque: true,
      backgroundColor: AstraTheme.background,
    );
  }

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  Color _tint = AstraTheme.accentStatic;
  String? _lastArtUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshPalette();
  }

  Future<void> _refreshPalette() async {
    final player = context.read<PlayerProvider>();
    final artUrl = player.currentTrack?.artUrl;
    if (artUrl == null || artUrl == _lastArtUrl) return;
    _lastArtUrl = artUrl;

    try {
      final image = NetworkImage(artUrl);
      final palette = await PaletteGenerator.fromImageProvider(
        image,
        size: const Size(64, 64),
        maximumColorCount: 24,
      );
      if (!mounted) return;
      final dominant = palette.dominantColor?.color;
      if (dominant == null) return;
      setState(() {
        // Keep the gradient dark so white text stays readable.
        _tint = Color.lerp(dominant, AstraTheme.background, 0.55)!;
      });
    } catch (_) {
      // Palette extraction is cosmetic — keep the static accent on failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    // Re-tint when the track auto-advances while this screen is open.
    if (player.currentTrack?.artUrl != _lastArtUrl) {
      _refreshPalette();
    }
    final track = player.currentTrack;
    if (track == null) {
      return const Scaffold(
        backgroundColor: AstraTheme.background,
        body: Center(child: Text('Nothing playing')),
      );
    }
    final library = context.watch<LibraryProvider>();
    final isFavorite = library.isFavorite(track.id);

    return Scaffold(
      backgroundColor: AstraTheme.background,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _tint,
              AstraTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 30),
                    ),
                    const Spacer(),
                    Text(
                      player.queueTitle.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.2,
                        color: AstraTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Spacer(),
              // Artwork
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AstraTheme.radiusL),
                    child: Image.network(
                      track.artUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AstraTheme.surfaceHigh,
                        child: const Icon(Icons.album_rounded,
                            size: 80, color: AstraTheme.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Meta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artistLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AstraTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context
                          .read<LibraryProvider>()
                          .toggleFavorite(track),
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? AstraTheme.accentStatic
                            : AstraTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Slider
              const SizedBox(height: 12),
              _PositionSlider(player: player),
              // Transport controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: player.shuffleEnabled
                          ? null
                          : () => context.read<PlayerProvider>().toggleShuffle(),
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: player.shuffleEnabled
                            ? AstraTheme.accentStatic
                            : AstraTheme.textSecondary,
                      ),
                      tooltip: 'Shuffle',
                    ),
                    IconButton(
                      onPressed: () => context.read<PlayerProvider>().previous(),
                      icon: const Icon(Icons.skip_previous_rounded, size: 40),
                    ),
                    PlayPauseControl(isPlaying: player.isPlaying),
                    IconButton(
                      onPressed: () => context.read<PlayerProvider>().next(),
                      icon: const Icon(Icons.skip_next_rounded, size: 40),
                    ),
                    IconButton(
                      onPressed: () =>
                          context.read<PlayerProvider>().cycleRepeatMode(),
                      icon: Icon(
                        switch (player.repeatMode) {
                          LoopMode.off => Icons.repeat_rounded,
                          LoopMode.one => Icons.repeat_one_rounded,
                          LoopMode.all => Icons.repeat_rounded,
                        },
                        color: player.repeatMode == LoopMode.off
                            ? AstraTheme.textSecondary
                            : AstraTheme.accentStatic,
                      ),
                      tooltip: 'Repeat',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Queue
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _showQueue,
                      icon: const Icon(Icons.queue_music_rounded, size: 20),
                      label: Text(
                        'Queue · ${player.queue.length}',
                        style: const TextStyle(color: AstraTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueue() {
    final player = context.read<PlayerProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              color: AstraTheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Playing from “${player.queueTitle}”',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: player.queue.length,
                      itemBuilder: (context, i) {
                        final track = player.queue[i];
                        final isCurrent = i == player.currentIndex;
                        return ListTile(
                          selected: isCurrent,
                          leading: SizedBox(
                            width: 38,
                            child: Text(
                              (i + 1).toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isCurrent
                                    ? AstraTheme.accentStatic
                                    : AstraTheme.textSecondary,
                              ),
                            ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artistLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: AstraTheme.textSecondary),
                          ),
                          trailing: const SizedBox(width: 48),
                          onTap: () {
                            context.read<PlayerProvider>().jumpTo(i);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Live position slider with time labels. Subscribes to the position stream
/// locally so drag interactions don't fight ChangeNotifier rebuilds.
class _PositionSlider extends StatelessWidget {
  const _PositionSlider({required this.player});

  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final position = player.position;
    final duration = player.duration;
    final hasDuration = duration.inMilliseconds > 0;

    return Column(
      children: [
        SliderTheme(
          data: Theme.of(context).sliderTheme,
          child: Slider(
            value: hasDuration && position <= duration
                ? position.inMilliseconds.toDouble()
                : 0,
            max: hasDuration ? duration.inMilliseconds.toDouble() : 1,
            onChanged: hasDuration
                ? (value) => context
                    .read<PlayerProvider>()
                    .seekTo(Duration(milliseconds: value.toInt()))
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: const TextStyle(
                    color: AstraTheme.textSecondary, fontSize: 12),
              ),
              Text(
                hasDuration ? _fmt(duration) : '--:--',
                style: const TextStyle(
                    color: AstraTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final mm = (m % 60).toString().padLeft(2, '0');
      return '${d.inHours}:$mm:$s';
    }
    return '$m:$s';
  }
}
