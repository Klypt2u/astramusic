import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/media.dart';
import '../state/library_provider.dart';
import '../widgets/media_art.dart';
import 'collection_screen.dart';

/// Library tab: liked songs + custom playlists, stored locally on-device.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      backgroundColor: AstraTheme.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AstraTheme.accentStatic,
          onRefresh: () async => library.load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text(
                'Library',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 20),
              _LikedSongsCard(count: library.favorites.length),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Your playlists',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _createPlaylist(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (library.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No playlists yet.\nTap “New” to make your first one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AstraTheme.textSecondary),
                    ),
                  ),
                )
              else
                ..._playlistRows(context, library),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playlistRows(BuildContext context, LibraryProvider library) {
    return Column(
      children: [
        for (final playlist in library.playlists)
          ListTile(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AstraTheme.radiusM),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LocalPlaylistScreen(playlistId: playlist.id),
              ),
            ),
            leading: playlist.tracks.isEmpty
                ? Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AstraTheme.surfaceHigh,
                      borderRadius:
                          BorderRadius.circular(AstraTheme.radiusS),
                    ),
                    child: const Icon(Icons.queue_music_rounded,
                        color: AstraTheme.textSecondary),
                  )
                : MediaArt(
                    url: playlist.tracks.first.artUrl,
                    size: 52,
                    radius: AstraTheme.radiusS,
                  ),
            title: Text(playlist.name,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text('${playlist.tracks.length} tracks'),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AstraTheme.textSecondary),
          ),
      ],
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. Late night drive'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null) context.read<LibraryProvider>().createPlaylist(name);
  }
}

/// Hero card for liked/favorite songs.
class _LikedSongsCard extends StatelessWidget {
  const _LikedSongsCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocalFavoritesScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B6CFF), Color(0xFF5A3DE8)],
          ),
          borderRadius: BorderRadius.circular(AstraTheme.radiusL),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liked songs',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    count == 1 ? '1 track' : '$count tracks',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
