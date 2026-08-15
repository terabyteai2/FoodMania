import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_scope.dart';

/// Plays the support assistant's spoken replies (Sarvam TTS over the outlet
/// WebSocket) as a sequential queue of MP3 chunks.
///
/// The backend relays Sarvam's audio frames as `support_audio` events
/// (`data: {messageId, audio}` base64 MP3) and finishes with
/// `support_audio_done`. Chunks are queued and played one at a time with
/// [BytesSource]; the mute state is persisted locally and pushed to the
/// server as a `support_tts_mute` WebSocket message so the server skips
/// streaming audio while muted.
class SupportTtsController extends ChangeNotifier {
  SupportTtsController._();

  static final SupportTtsController instance = SupportTtsController._();

  static const _mutedKey = 'support_tts_muted';

  AudioPlayer? _player;
  final List<Uint8List> _queue = <Uint8List>[];
  bool _playing = false;
  bool _muted = false;
  bool _loaded = false;
  bool _donePending = false;
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
      _queue.clear();
    }
    notifyListeners();
    syncMuteState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, muted);
    } catch (_) {}
  }

  /// Enqueues one base64 MP3 chunk received from the backend.
  void handleAudioChunk(String base64Audio) {
    if (_muted || base64Audio.isEmpty) return;
    try {
      _queue.add(base64Decode(base64Audio));
    } catch (_) {
      return;
    }
    if (!_playing) unawaited(_pump());
  }

  /// Marks the current spoken message as finished. The currently playing
  /// chunk is allowed to finish; anything still queued is dropped.
  void handleAudioDone() {
    if (!_playing) return;
    _donePending = true;
  }

  Future<void> _pump() async {
    if (_playing) return;
    _playing = true;
    _donePending = false;
    notifyListeners();
    try {
      final player = _player ??= AudioPlayer();
      while (_queue.isNotEmpty) {
        if (_muted) {
          _queue.clear();
          break;
        }
        final chunk = _queue.removeAt(0);
        final completer = Completer<void>();
        final subscription = player.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        try {
          await player.stop();
          await player.play(BytesSource(chunk));
          await completer.future.timeout(const Duration(seconds: 45));
        } catch (_) {
        } finally {
          await subscription.cancel();
        }
        if (_donePending) {
          _queue.clear();
          break;
        }
      }
    } catch (_) {
      _queue.clear();
    } finally {
      _playing = false;
      _donePending = false;
      notifyListeners();
    }
  }

  void stop() {
    _queue.clear();
    if (_playing) {
      _donePending = true;
    }
  }

  @visibleForTesting
  void resetForTest() {
    _queue.clear();
    _playing = false;
    _muted = false;
    _loaded = false;
    _donePending = false;
    _hostContext = null;
  }

  @override
  void dispose() {
    _queue.clear();
    _player?.dispose();
    _player = null;
    _hostContext = null;
    super.dispose();
  }
}