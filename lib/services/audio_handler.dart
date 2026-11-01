import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media.dart';
import 'yt_music_service.dart';

/// ---------------------------------------------------------------------------
/// AstraAudioHandler — the background audio service.
///
/// Owns a just_audio [AudioPlayer] and a logical queue of [Track]s. When a
/// track finishes it resolves + loads the next source itself, so playback
/// continues while the app is minimized. Lock-screen / notification controls
/// come from the [MediaItem] tags set here; the `audio` UIBackgroundMode is
/// configured in ios/Runner/Info.plist (see docs/BUILD_IPA_GUIDE.md).
///
/// YouTube stream URLs expire after a few hours, so each source is resolved
/// fresh immediately before it plays (see [_loadAndPlay]).
/// ---------------------------------------------------------------------------
class AstraAudioHandler extends BaseAudioHandler {
  AstraAudioHandler(this._musicService);

  final YtMusicService _musicService;

  final AudioPlayer player = AudioPlayer();

  /// Human label of the current queue (e.g. album name), shown on lock screen.
  String queueTitle = '';

  List<Track> _queue = const [];
  final List<Track> _unshuffledQueue = [];
  bool _shuffled = false;

  /// Index of the source currently loaded in the player, or -1 for none.
  int _loadedIndex = -1;
  int _activeIndex = 0;

  bool _loading = false;

  // Convenience streams / getters for the UI (exposed via PlayerProvider).
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<Duration> get positionStream => player.positionStream;
  Duration get position => player.position;
  Duration get bufferedPosition => player.bufferedPosition;
  Duration get duration => player.duration ?? Duration.zero;
  bool get isPlaying => player.playing;
  bool get isLoading => _loading;

  List<Track> get queue => List.unmodifiable(_queue);

  int get currentIndex => _activeIndex;

  Track? get currentTrack =>
      _queue.isEmpty ? null : _queue[_activeIndex.clamp(0, _queue.length - 1)];

  LoopMode get loopMode => player.loopMode;
  bool get shuffleEnabled => _shuffled;

  // -------------------------------------------------------------------------
  // Public control surface
  // -------------------------------------------------------------------------

  /// Starts playing [tracks] at [startIndex], replacing any existing queue.
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String title = 'Queue',
  }) async {
    if (tracks.isEmpty) return;
    queueTitle = title;

    _unshuffledQueue
      ..clear()
      ..addAll(tracks);
    _queue = List.of(tracks);
    _shuffled = false;
    final start = startIndex.clamp(0, tracks.length - 1);

    // New queues always start orderly; the user can re-enable shuffle.
    if (player.loopMode != LoopMode.off) {
      await player.setLoopMode(LoopMode.off);
    }
    await _loadAndPlay(start);
  }

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;
    if (_loadedIndex != _activeIndex) {
      await _loadAndPlay(_activeIndex);
    } else {
      await player.play();
    }
  }

  @override
  Future<void> pause() async {
    await player.pause();
  }

  Future<void> togglePause() => isPlaying ? pause() : play();

  @override
  Future<void> skipToNext() => _advance();

  @override
  Future<void> skipToPrevious() async {
    if (player.position.inMilliseconds > 3000) {
      await player.seek(Duration.zero);
      return;
    }
    if (_activeIndex > 0) {
      await _loadAndPlay(_activeIndex - 1);
    } else {
      await player.seek(Duration.zero);
    }
  }

  Future<void> jumpTo(int queueIndex) async {
    if (queueIndex < 0 || queueIndex >= _queue.length) return;
    await _loadAndPlay(queueIndex);
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  /// none → one → all → none
  Future<void> cycleRepeatMode() async {
    final next = switch (player.loopMode) {
      LoopMode.off => LoopMode.one,
      LoopMode.one => LoopMode.all,
      LoopMode.all => LoopMode.off,
    };
    await player.setLoopMode(next);
  }

  Future<void> toggleShuffle() async {
    _shuffled = !_shuffled;
    if (_queue.length <= 1) {
      // Nothing to reorder, but keep the flag so future queues start shuffled.
      _publishShuffleFlag();
      return;
    }

    final currentId = currentTrack?.id;
    if (_shuffled) {
      _unshuffledQueue
        ..clear()
        ..addAll(_queue);
      _queue = _shuffleCopy(_queue, keepFirstId: currentId);
    } else if (_unshuffledQueue.isNotEmpty) {
      _queue = List.of(_unshuffledQueue);
    }
    final target = _queue.indexWhere((t) => t.id == currentId);
    if (target >= 0) {
      await _loadAndPlay(target);
    }
    _publishShuffleFlag();
  }

  void _publishShuffleFlag() {
    playbackState.add(playbackState.value.copyWith(
      shuffleMode: _shuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  Future<void> stopPlayback() async {
    await player.stop();
    _loadedIndex = -1;
  }

  Future<void> dispose() async {
    await player.dispose();
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  Future<void> _loadAndPlay(int index) async {
    if (_queue.isEmpty) return;
    final i = index.clamp(0, _queue.length - 1);
    final track = _queue[i];

    _activeIndex = i;
    _loading = true;
    _publishState(loading: true);
    _setMediaItem(track);

    try {
      final stream = await _musicService.getStreamUrl(track);
      final source = AudioSource.uri(
        stream.uri,
        tag: _mediaItemFor(track),
      );
      await player.setAudioSource(source);
      _loadedIndex = i;
      _activeIndex = i;
      _publishState(loading: false);
      await player.play();
    } catch (e) {
      _publishState(loading: false);
      if (e is YtMusicException) {
        // Unresolvable stream (deleted video, all resolvers down): walk
        // FORWARD only, so a fully-unplayable queue terminates instead of
        // wrapping around forever.
        final next = i + 1;
        if (next < _queue.length) {
          _activeIndex = next;
          await _loadAndPlay(next);
        } else {
          _loadedIndex = -1;
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> _advance() async {
    if (_queue.isEmpty) return;
    final next = _activeIndex + 1;
    if (next >= _queue.length) {
      // Queue finished (repeat-all would have restarted via loop below, but
      // with manual queueing we stop at the end).
      await player.seek(Duration.zero);
      await player.stop();
      _loadedIndex = -1;
      _publishState(ended: true);
      return;
    }
    await _loadAndPlay(next);
  }

  MediaItem _mediaItemFor(Track track) => MediaItem(
        id: track.id,
        album: track.albumName ?? queueTitle,
        title: track.title,
        artist: track.artistLabel,
        artUri: Uri.tryParse(track.artUrl),
        duration: track.duration,
      );

  void _setMediaItem(Track track) {
    mediaItem.add(_mediaItemFor(track));
    queue.add(_queue.map(_mediaItemFor).toList());
  }

  void _publishState({bool loading = false, bool ended = false}) {
    playbackState.add(playbackState.value.copyWith(
      controls: isPlaying || !loading
          ? [
              MediaControl.skipToPrevious(androidIcon: 'drawable/audio_skip_previous'),
              isPlaying
                  ? MediaControl.pause(androidIcon: 'drawable/audio_pause')
                  : MediaControl.play(androidIcon: 'drawable/audio_play'),
              MediaControl.skipToNext(androidIcon: 'drawable/audio_skip_next'),
            ]
          : const [],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      processingState: _processingState(loading, ended),
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: _queue.isEmpty ? null : _activeIndex,
    ));
  }

  AudioProcessingState _processingState(bool loading, bool ended) {
    if (ended) return AudioProcessingState.completed;
    if (loading) return AudioProcessingState.loading;
    return AudioProcessingState.ready;
  }

  /// Wire just_audio → audio_service & queue progression. Call once at startup.
  void initialize() {
    player.playerStateStream.listen(_onPlayerState);
    player.playbackEventStream.listen(
      (_) => _publishState(),
      onError: (Object e) => _publishState(),
    );
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      if (player.loopMode == LoopMode.one) {
        player.seek(Duration.zero).then((_) => player.play());
        return;
      }
      _advance();
    } else {
      _publishState();
    }
  }

  static List<Track> _shuffleCopy(List<Track> source, {String? keepFirstId}) {
    final list = List.of(source);
    Track? pinned;
    if (keepFirstId != null) {
      final idx = list.indexWhere((t) => t.id == keepFirstId);
      if (idx >= 0) {
        pinned = list.removeAt(idx);
      }
    }
    list.shuffle();
    if (pinned != null) list.insert(0, pinned);
    return list;
  }
}
