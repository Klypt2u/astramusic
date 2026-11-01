import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../screens/now_playing_screen.dart';
import '../state/player_provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(NowPlayingScreen.route()),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AstraTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(AstraTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AstraTheme.radiusS),
              child: Image.network(
                track.artUrl,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 42,
                  height: 42,
                  color: AstraTheme.surface,
                  child: const Icon(Icons.music_note_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
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
            IconButton(
              onPressed: () => context.read<PlayerProvider>().previous(),
              icon: const Icon(Icons.skip_previous_rounded,
                  color: AstraTheme.textPrimary),
            ),
            _PlayPauseButton(isPlaying: player.isPlaying),
            IconButton(
              onPressed: () => context.read<PlayerProvider>().next(),
              icon: const Icon(Icons.skip_next_rounded,
                  color: AstraTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated play/pause icon shared by the mini player and the full screen.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, this.size = 48});

  final bool isPlaying;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.read<PlayerProvider>().togglePause(),
      iconSize: size,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          key: ValueKey(isPlaying),
          color: AstraTheme.textPrimary,
          size: size,
        ),
      ),
    );
  }
}

/// Raw play/pause icon button used on the Now Playing screen too.
class PlayPauseControl extends StatelessWidget {
  const PlayPauseControl({
    super.key,
    required this.isPlaying,
    this.size = 64,
  });

  final bool isPlaying;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => context.read<PlayerProvider>().togglePause(),
      style: FilledButton.styleFrom(
        backgroundColor: AstraTheme.textPrimary,
        foregroundColor: AstraTheme.background,
        shape: const CircleBorder(),
        fixedSize: Size(size, size),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          key: ValueKey(isPlaying),
          size: size * 0.6,
        ),
      ),
    );
  }
}
