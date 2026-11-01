import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/media.dart';
import '../screens/collection_screen.dart';
import '../screens/now_playing_screen.dart';
import '../state/library_provider.dart';
import '../state/player_provider.dart';
import 'media_art.dart';

/// A track row: artwork, title/artist meta, favorite heart + overflow menu.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.onRemove,
    this.subtitle,
  });

  final Track track;
  final VoidCallback? onRemove;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final isCurrent = player.currentTrack?.id == track.id;
    final isFavorite = library.isFavorite(track.id);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _play(context, player),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          MediaArt(url: track.artUrl, size: 52, radius: AstraTheme.radiusS),
          if (isCurrent && player.isPlaying)
            const Opacity(
              opacity: 0.85,
              child: Icon(
                Icons.graphic_eq_rounded,
                color: AstraTheme.textPrimary,
                size: 30,
              ),
            ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: isCurrent ? AstraTheme.accentStatic : null,
            ),
      ),
      subtitle: Text(
        subtitle ?? track.artistLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.isExplicit)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: _ExplicitBadge(),
            ),
          IconButton(
            onPressed: () =>
                context.read<LibraryProvider>().toggleFavorite(track),
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 20,
              color:
                  isFavorite ? AstraTheme.accentStatic : AstraTheme.textSecondary,
            ),
          ),
          _TrackMenu(track: track, onRemove: onRemove),
        ],
      ),
    );
  }

  void _play(BuildContext context, PlayerProvider player) {
    player.playTracks([track], startIndex: 0, title: track.title).then(
          (_) => Navigator.of(context).push(NowPlayingScreen.route()),
        );
  }
}

class _TrackMenu extends StatelessWidget {
  const _TrackMenu({required this.track, this.onRemove});

  final Track track;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 20, color: AstraTheme.textSecondary),
      color: AstraTheme.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        final library = context.read<LibraryProvider>();
        switch (value) {
          case 'add_to_playlist':
            final playlist = await _choosePlaylist(context, library);
            if (playlist != null) {
              library.addToPlaylist(playlist.id, track);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to "${playlist.name}"')),
                );
              }
            }
          case 'go_to_album':
            openCollection(context, _albumCollection());
          case 'remove':
            onRemove?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add_to_playlist',
          child: Row(children: [
            Icon(Icons.playlist_add_rounded, size: 18),
            SizedBox(width: 10),
            Text('Add to playlist'),
          ]),
        ),
        if (track.albumBrowseId != null)
          const PopupMenuItem(
            value: 'go_to_album',
            child: Row(children: [
              Icon(Icons.album_rounded, size: 18),
              SizedBox(width: 10),
              Text('Go to album'),
            ]),
          ),
        if (onRemove != null)
          const PopupMenuItem(
            value: 'remove',
            child: Row(children: [
              Icon(Icons.delete_rounded, size: 18),
              SizedBox(width: 10),
              Text('Remove from list'),
            ]),
          ),
      ],
    );
  }

  Collection _albumCollection() => Collection(
        type: CollectionType.album,
        id: track.albumBrowseId!,
        title: track.albumName ?? 'Album',
        subtitle: track.artistLabel,
        imageUrl: track.artUrl,
      );

  Future<UserPlaylist?> _choosePlaylist(
      BuildContext context, LibraryProvider library) async {
    if (library.playlists.isEmpty) {
      final name = await _promptNewPlaylist(context);
      if (name == null) return null;
      library.createPlaylist(name);
      // Newly created playlists are appended at the end of the list.
      return library.playlists.lastOrNull;
    }
    return showModalBottomSheet<UserPlaylist>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('New playlist'),
                onTap: () async {
                  final name = await _promptNewPlaylist(context);
                  if (name != null) {
                    library.createPlaylist(name);
                    if (context.mounted) {
                      Navigator.pop(context, library.playlists.lastOrNull);
                    }
                  }
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: library.playlists.length,
                  itemBuilder: (context, i) {
                    final p = library.playlists[i];
                    return ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(p.name),
                      subtitle: Text('${p.tracks.length} tracks'),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<String?> _promptNewPlaylist(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (value) => Navigator.pop(context, value),
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
}

class _ExplicitBadge extends StatelessWidget {
  const _ExplicitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AstraTheme.textSecondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'E',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AstraTheme.textSecondary,
        ),
      ),
    );
  }
}
