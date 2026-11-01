import 'package:flutter/foundation.dart';

import '../models/media.dart';
import '../services/library_storage.dart';

/// Local, device-only library: favorites ("Liked songs") and custom playlists.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._storage);

  final LibraryStorage _storage;

  final List<Track> _favorites = [];
  final List<UserPlaylist> _playlists = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<Track> get favorites => List.unmodifiable(_favorites);
  List<UserPlaylist> get playlists => List.unmodifiable(_playlists);

  Future<void> load() async {
    if (_loaded) return;
    final snapshot = await _storage.load();
    _favorites
      ..clear()
      ..addAll(snapshot.favorites);
    _playlists
      ..clear()
      ..addAll(snapshot.playlists);
    _loaded = true;
    notifyListeners();
  }

  bool isFavorite(String videoId) =>
      _favorites.any((t) => t.id == videoId);

  void toggleFavorite(Track track) {
    final existing = _favorites.indexWhere((t) => t.id == track.id);
    if (existing >= 0) {
      _favorites.removeAt(existing);
    } else {
      _favorites.insert(0, track);
    }
    _persist();
  }

  void createPlaylist(String name) {
    _playlists.add(UserPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'New playlist' : name.trim(),
      createdAt: DateTime.now(),
    ));
    _persist();
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p.id == playlistId);
    _persist();
  }

  void renamePlaylist(String playlistId, String name) {
    if (name.trim().isEmpty) return;
    final p = _playlists.indexWhere((x) => x.id == playlistId);
    if (p < 0) return;
    _playlists[p] = _playlists[p].copyWith(name: name.trim());
    _persist();
  }

  void addToPlaylist(String playlistId, Track track) {
    final p = _playlists.firstWhere((x) => x.id == playlistId);
    if (p.tracks.any((t) => t.id == track.id)) return;
    final idx = _playlists.indexWhere((x) => x.id == playlistId);
    _playlists[idx] = p.copyWith(tracks: [...p.tracks, track]);
    _persist();
  }

  void removeFromPlaylist(String playlistId, String videoId) {
    final idx = _playlists.indexWhere((x) => x.id == playlistId);
    if (idx < 0) return;
    final p = _playlists[idx];
    _playlists[idx] = p.copyWith(
        tracks: p.tracks.where((t) => t.id != videoId).toList());
    _persist();
  }

  UserPlaylist? playlistById(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } on StateError {
      return null;
    }
  }

  void _persist() {
    _storage.save(LibrarySnapshot(
      favorites: List.of(_favorites),
      playlists: List.of(_playlists),
    ));
    notifyListeners();
  }
}
