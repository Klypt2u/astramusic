import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/media.dart';

/// JSON persistence for favorites + user playlists in SharedPreferences.
/// For a fully offline personal library this is the right size — no
/// database needed on iOS for a few hundred entries.
class LibraryStorage {
  static const _key = 'astra.library.v1';

  /// Reads the library snapshot, tolerating corrupt data (fresh library).
  Future<LibrarySnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return LibrarySnapshot.empty();

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final favorites = ((data['favorites'] as List?) ?? [])
          .whereType<Map>()
          .map((t) => Track.fromJson(Map<String, dynamic>.from(t)))
          .toList();
      final playlists = ((data['playlists'] as List?) ?? [])
          .whereType<Map>()
          .map((p) => UserPlaylist.fromJson(Map<String, dynamic>.from(p)))
          .toList();
      return LibrarySnapshot(favorites: favorites, playlists: playlists);
    } catch (_) {
      return LibrarySnapshot.empty();
    }
  }

  Future<void> save(LibrarySnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      'favorites': snapshot.favorites.map((t) => t.toJson()).toList(),
      'playlists': snapshot.playlists.map((p) => p.toJson()).toList(),
    });
    await prefs.setString(_key, encoded);
  }
}

class LibrarySnapshot {
  const LibrarySnapshot({required this.favorites, required this.playlists});

  const LibrarySnapshot.empty()
      : favorites = const [],
        playlists = const [];

  final List<Track> favorites;
  final List<UserPlaylist> playlists;
}
