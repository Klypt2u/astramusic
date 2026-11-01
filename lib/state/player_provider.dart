import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media.dart';
import '../services/audio_handler.dart';

/// UI-facing playback state. Wraps the background [AstraAudioHandler] and
/// fans its streams out into a [ChangeNotifier] for widgets.
class PlayerProvider extends ChangeNotifier {
  PlayerProvider(this._handler) {
    _handler.initialize();
    _handler.playerStateStream.listen(_onPlayerState);
    _subPos = _handler.positionStream.listen(_onPosition);
  }

  final AstraAudioHandler _handler;
  StreamSubscription<Duration>? _subPos;

  // Cheap snapshots refreshed on every relevant event.
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  LoopMode _loopMode = LoopMode.off;
  bool _shuffle = false;
  List<Track> _queue = const [];
  int _index = 0;
  String _queueTitle = '';

  // Getters used across the UI.
  List<Track> get queue => _queue;
  int get currentIndex => _index;
  Track? get currentTrack => _queue.isEmpty ? null : _queue[_index.clamp(0, _queue.length - 1)];
  String get queueTitle => _queueTitle;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  bool get hasTrack => _queue.isNotEmpty;
  Duration get position => _position;
  Duration get duration => _duration;
  LoopMode get repeatMode => _loopMode;
  bool get shuffleEnabled => _shuffle;

  String get repeatLabel => switch (_loopMode) {
        LoopMode.off => 'off',
        LoopMode.one => 'one',
        LoopMode.all => 'all',
      };

  // -------------------------------------------------------------------------
  // Actions (thin pass-through)
  // -------------------------------------------------------------------------

  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String title = 'Queue',
  }) async {
    await _handler.playTracks(tracks, startIndex: startIndex, title: title);
    _syncAll();
  }

  Future<void> togglePause() => _handler.togglePause().then((_) => _syncCheapState());
  Future<void> next() => _handler.skipToNext().then((_) => _syncAll());
  Future<void> previous() => _handler.skipToPrevious().then((_) => _syncAll());
  Future<void> jumpTo(int i) => _handler.jumpTo(i).then((_) => _syncAll());
  Future<void> seekTo(Duration d) => _handler.seek(d).then((_) => _syncCheapState());
  Future<void> cycleRepeatMode() =>
      _handler.cycleRepeatMode().then((_) => _syncCheapState());
  Future<void> toggleShuffle() =>
      _handler.toggleShuffle().then((_) => _syncAll());

  Future<void> stop() => _handler.stopPlayback();

  // -------------------------------------------------------------------------
  // Stream → state sync
  // -------------------------------------------------------------------------

  void _onPlayerState(PlayerState state) {
    _playing = state.playing;
    if (state.processingState == ProcessingState.ready ||
        state.processingState == ProcessingState.completed) {
      _duration = _handler.duration;
    }
    _syncCheapState();
  }

  void _onPosition(Duration pos) {
    _position = pos;
    _notifyThrottled();
  }

  void _syncCheapState() {
    _playing = _handler.isPlaying;
    _loading = _handler.isLoading;
    _loopMode = _handler.loopMode;
    _shuffle = _handler.shuffleEnabled;
    _queue = _handler.queue;
    _index = _handler.currentIndex;
    _queueTitle = _handler.queueTitle;
    _duration = _handler.duration;
    notifyListeners();
  }

  void _syncAll() {
    _syncCheapState();
    _position = _handler.position;
    notifyListeners();
  }

  /// Position ticks arrive too frequently to re-render the entire widget tree;
  /// notify on a coarse 250ms grid, except when duration jumps (track change).
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= 250) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subPos?.cancel();
    super.dispose();
  }
}
