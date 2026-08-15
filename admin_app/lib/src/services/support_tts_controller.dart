import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_scope.dart';

/// Serves the support assistant's spoken replies (Sarvam TTS over the outlet
/// WebSocket) as one progressive MP3 stream.
///
/// The backend relays Sarvam's raw audio frames as `support_audio` events
/// (`data: {messageId, audio}` base64 MP3) and finishes with
/// `support_audio_done`. Sarvam cuts its frames at arbitrary byte boundaries,
/// so single frames are not decodable standalone; feeding them into a single
/// progressive stream source lets ExoPlayer decode the whole message
/// while playback still starts after only a short initial buffer.
///
/// The mute state is persisted locally and pushed to the server as a
/// `support_tts_mute` WebSocket message so the server skips streaming audio
/// while muted.
// ignore: experimental_member_use
class _TtsStreamAudioSource extends ja.StreamAudioSource {
  _TtsStreamAudioSource(this.stream);

  final Stream<List<int>> stream;

  @override
  // ignore: experimental_member_use
  Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
    // ignore: experimental_member_use
    return ja.StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: start,
      rangeRequestsSupported: false,
      stream: stream,
      contentType: 'audio/mpeg',
    );
  }
}

class SupportTtsController extends ChangeNotifier {
  SupportTtsController._() {
    _player.playingStream.listen((playing) {
      if (_playing == playing) return;
      _playing = playing;
      notifyListeners();
    });
  }

  static final SupportTtsController instance = SupportTtsController._();

  static const _mutedKey = 'support_tts_muted';

  final ja.AudioPlayer _player = ja.AudioPlayer();
  StreamController<Uint8List>? _audioStream;
  bool _sessionActive = false;
  bool _playing = false;
  bool _muted = false;
  bool _loaded = false;
  BuildContext? _hostContext;

  bool get muted => _muted;
  bool get speaking => _playing;

  /// Wires a long-lived host context (the shell) so mute state can be pushed
  /// over the outlet WebSocket. Loads the persisted mute setting on first use.
  Future<void> attachHost(BuildContext context) async {
    _hostContext = context;
    await loadMuteState();
    syncMuteState();
  }

  /// Loads the persisted mute setting (once; idempotent afterwards).
  Future<void> loadMuteState() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_mutedKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Pushes the current mute state to the server over the outlet WebSocket.
  void syncMuteState() {
    final host = _hostContext;
    if (host == null || !host.mounted) return;
    final app = AppScope.read(host);
    unawaited(app.cloudRealtimeService.sendMessage(<String, Object?>{
      'type': 'support_tts_mute',
      'data': <String, Object?>{'muted': _muted},
    }));
  }

  /// Persists the mute setting and syncs it to the server.
  Future<void> setMuted(bool muted) async {
    if (_muted == muted) return;
    _muted = muted;
    if (_muted) {
      _endSession();
      unawaited(_player.stop());
    }
    notifyListeners();
    syncMuteState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, muted);
    } catch (_) {}
  }

  /// Feeds one base64 MP3 fragment received from the backend into the
  /// progressive stream for the current message.
  void handleAudioChunk(String base64Audio) {
    if (_muted || base64Audio.isEmpty) return;
    Uint8List bytes;
    try {
      bytes = base64Decode(base64Audio);
    } catch (_) {
      return;
    }
    if (!_sessionActive) {
      _startSession();
    }
    _audioStream?.add(bytes);
  }

  /// Marks the current spoken message as finished; the stream ends and the
  /// remaining buffered audio plays out.
  void handleAudioDone() {
    if (!_sessionActive) return;
    _endSession();
  }

  void _startSession() {
    if (_sessionActive) return;
    _sessionActive = true;
    final controller = StreamController<Uint8List>();
    _audioStream = controller;
    unawaited(_playSession(controller));
  }

  Future<void> _playSession(StreamController<Uint8List> controller) async {
    try {
      await _player.setAudioSource(_TtsStreamAudioSource(controller.stream));
      await _player.play();
    } catch (_) {
      if (_audioStream == controller) _audioStream = null;
      _sessionActive = false;
      unawaited(controller.close());
    }
  }

  void _endSession() {
    _sessionActive = false;
    final stream = _audioStream;
    _audioStream = null;
    unawaited(stream?.close());
  }

  void stop() {
    _endSession();
    unawaited(_player.stop());
  }

  @visibleForTesting
  void resetForTest() {
    _endSession();
    _muted = false;
    _loaded = false;
    _hostContext = null;
  }

  @override
  void dispose() {
    _endSession();
    unawaited(_player.dispose());
    _hostContext = null;
    super.dispose();
  }
}