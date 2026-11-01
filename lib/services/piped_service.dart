import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_constants.dart';
import 'yt_music_service.dart';

/// ---------------------------------------------------------------------------
/// PipedService — fallback stream resolver backed by public Piped and
/// Invidious community instances. Used when the InnerTube iOS player client
/// cannot return a direct URL (rate limiting, region restriction, drift).
///
/// Public instances are community-run and rotate; Astra tries several in
/// order and short-circuits on the first success, blacklisting dead ones
/// for the rest of the session.
/// ---------------------------------------------------------------------------
abstract class StreamResolver {
  Future<AstraStream> resolve(String videoId);
}

class PipedService implements StreamResolver {
  PipedService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Set<String> _deadInstances = {};

  static const Duration _timeout = Duration(seconds: 10);

  @override
  Future<AstraStream> resolve(String videoId) async {
    final failures = <String>[];

    for (final instance in kPipedInstances) {
      if (_deadInstances.contains(instance)) continue;
      try {
        return await _resolvePiped(instance, videoId);
      } catch (e) {
        failures.add('piped($instance): $e');
        _deadInstances.add(instance);
      }
    }

    for (final instance in kInvidiousInstances) {
      if (_deadInstances.contains(instance)) continue;
      try {
        return await _resolveInvidious(instance, videoId);
      } catch (e) {
        failures.add('invidious($instance): $e');
        _deadInstances.add(instance);
      }
    }

    throw YtMusicException(
        'All fallback instances failed for $videoId (${failures.join(' | ')})');
  }

  Future<AstraStream> _resolvePiped(String instance, String videoId) async {
    final uri = Uri.parse('$instance/streams/$videoId');
    final res =
        await _client.get(uri, headers: {'accept': 'application/json'})
        .timeout(_timeout, onTimeout: () => throw 'timeout');
    if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if ((data['error'] ?? '') != '') throw data['error'].toString();

    AstraStream? best;
    int bestBitrate = 0;
    final streams = (data['audioStreams'] as List<dynamic>? ?? []);
    for (final raw in streams) {
      if (raw is! Map) continue;
      final url = raw['url'] as String?;
      if (url == null) continue;
      final bitrate = (raw['bitrate'] as num?)?.toInt() ?? 0;
      final mime = (raw['mimeType'] ?? 'audio/mp4').toString();
      if (bitrate > bestBitrate) {
        bestBitrate = bitrate;
        best = AstraStream(
          url: url,
          mimeType:
              mime.startsWith('audio') ? mime.split(';').first : 'audio/mp4',
          bitrateKbps: bitrate ~/ 1000,
        );
      }
    }
    if (best == null) throw 'no audioStreams in response';
    return best;
  }

  Future<AstraStream> _resolveInvidious(String instance, String videoId) async {
    final uri = Uri.parse(
        '$instance/api/v1/videos/$videoId?fields=adaptiveFormats,title');
    final res =
        await _client.get(uri, headers: {'accept': 'application/json'})
        .timeout(_timeout, onTimeout: () => throw 'timeout');
    if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    AstraStream? best;
    int bestBitrate = 0;
    final formats = (data['adaptiveFormats'] as List<dynamic>? ?? []);
    for (final raw in formats) {
      if (raw is! Map) continue;
      final url = raw['url'] as String?;
      if (url == null) continue;
      final mime = (raw['type'] ?? '').toString();
      if (!mime.startsWith('audio')) continue;
      final bitrate = (raw['bitrate'] as num?)?.toInt() ?? 0;
      if (bitrate > bestBitrate) {
        bestBitrate = bitrate;
        best = AstraStream(
          url: url,
          mimeType: mime.split(';').first,
          bitrateKbps: bitrate ~/ 1000,
        );
      }
    }
    if (best == null) throw 'no audio formats in response';
    return best;
  }
}
