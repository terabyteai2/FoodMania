import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;

import '../app_scope.dart';

/// Mic seam over the platform recorder so tests can inject a fake.
abstract class SupportMicRecorder {
  /// True when the mic permission is granted (prompts the user if needed).
  Future<bool> hasPermission();

  /// Starts recording 16 kHz mono WAV to a temp file; returns the file path.
  Future<String> start({required int sampleRate});

  /// Stops recording and returns the recorded file path (or null).
  Future<String?> stop();

  /// Stops recording and discards the clip.
  Future<void> cancel();
}

class _RecordMicRecorder implements SupportMicRecorder {
  // Constructed lazily: the record package's constructor fires a platform
  // channel call, which must not happen in unit tests (or before use).
  rec.AudioRecorder? _recorder;

  rec.AudioRecorder get _impl => _recorder ??= rec.AudioRecorder();
  String? _path;

  @override
  Future<bool> hasPermission() => _impl.hasPermission();

  @override
  Future<String> start({required int sampleRate}) async {
    final dir = await getTemporaryDirectory();
    _path =
        '${dir.path}/support_stt_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _impl.start(
      rec.RecordConfig(
        encoder: rec.AudioEncoder.wav,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
      path: _path!,
    );
    return _path!;
  }

  @override
  Future<String?> stop() => _impl.stop();

  @override
  Future<void> cancel() => _impl.cancel();
}

/// Serves the support assistant's voice input (Sarvam STT over the outlet
/// WebSocket) as push-to-talk.
///
/// Hold the mic icon to record a 16 kHz mono WAV clip; on release the clip is
/// base64-shipped as a `support_stt` WebSocket message. The backend
/// transcribes it with Sarvam and posts the transcript as a regular
/// support-chat message (which triggers the assistant's reply + spoken TTS).
/// The server acks with `support_stt_result` (`{status: ok|empty|error}`);
/// until then the UI keeps the "sending" state (bounded by a timeout).
///
/// Very short holds (< [minHold]) are discarded as accidental; [maxHold]
/// caps a clip at 30s (the Sarvam sync-REST limit).
class SupportSttController extends ChangeNotifier {
  SupportSttController._();

  static final SupportSttController instance = SupportSttController._();

  static const int sampleRate = 16000;
  static const Duration minHold = Duration(milliseconds: 800);
  static const Duration maxHold = Duration(seconds: 30);
  static const Duration _ackTimeout = Duration(seconds: 20);

  SupportMicRecorder? _recorderOverride;
  final SupportMicRecorder _defaultRecorder = _RecordMicRecorder();

  SupportMicRecorder get _mic => _recorderOverride ?? _defaultRecorder;

  bool _recording = false;
  bool _sending = false;
  String? _path;
  DateTime? _startedAt;
  Timer? _maxHoldTimer;
  Timer? _ackTimer;
  String? _lastError;
  BuildContext? _hostContext;
  bool _disposed = false;

  /// Test hook: intercepts the WS send (receives the raw recorded bytes).
  @visibleForTesting
  Future<void> Function(Uint8List bytes)? onSendClip;

  /// Test hook: overrides the accidental-tap guard.
  @visibleForTesting
  Duration minHoldOverride = minHold;

  /// Test hook: swaps in a fake mic recorder.
  @visibleForTesting
  void attachRecorderForTest(SupportMicRecorder recorder) {
    _recorderOverride = recorder;
  }

  bool get isRecording => _recording;
  bool get isSending => _sending;

  /// Error key (`permission_denied | start_failed | empty | send_failed |
  /// offline | stt_failed`); null when the last attempt was clean.
  String? get lastError => _lastError;

  /// Mic capture is only wired where the recorder works: Android/iOS/macOS.
  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS;
  }

  /// Wires a long-lived host context (the shell) so clips can be sent over
  /// the outlet WebSocket.
  void attachHost(BuildContext context) {
    _hostContext = context;
  }

  /// Starts a push-to-talk recording. No-op while already recording/sending.
  Future<void> start() async {
    if (_recording || _sending || _disposed) return;
    _lastError = null;
    try {
      if (!await _mic.hasPermission()) {
        _lastError = 'permission_denied';
        notifyListeners();
        return;
      }
      _path = await _mic.start(sampleRate: sampleRate);
      _startedAt = DateTime.now();
      _recording = true;
      notifyListeners();
      _maxHoldTimer = Timer(maxHold, () => unawaited(stopAndSend()));
    } catch (_) {
      _lastError = 'start_failed';
      _path = null;
      notifyListeners();
    }
  }

  /// Stops recording and sends the clip for transcription. Holds shorter
  /// than [minHold] are discarded as accidental taps.
  Future<void> stopAndSend() async {
    if (!_recording) return;
    _maxHoldTimer?.cancel();
    _maxHoldTimer = null;
    _recording = false;
    final wasShort = _startedAt != null &&
        DateTime.now().difference(_startedAt!) < minHoldOverride;
    _startedAt = null;
    final path = _path;
    _path = null;
    if (wasShort) {
      try {
        await _mic.cancel();
      } catch (_) {}
      notifyListeners();
      return;
    }
    _sending = true;
    notifyListeners();
    try {
      final recorded = await _mic.stop();
      final bytes = recorded == null ? null : await _readBytes(recorded);
      if (bytes == null || bytes.isEmpty) {
        _lastError = 'empty';
      } else {
        await _sendClip(bytes);
        _ackTimer = Timer(_ackTimeout, _onAckTimeout);
      }
    } catch (_) {
      _lastError = 'send_failed';
    } finally {
      _cleanupFile(path);
      if (_lastError != null) {
        _sending = false;
      }
      notifyListeners();
    }
  }

  /// Cancels an in-progress recording without sending anything.
  Future<void> cancel() async {
    if (!_recording) return;
    _maxHoldTimer?.cancel();
    _maxHoldTimer = null;
    _recording = false;
    _startedAt = null;
    final path = _path;
    _path = null;
    try {
      await _mic.cancel();
    } catch (_) {}
    _cleanupFile(path);
    notifyListeners();
  }

  /// Handles the server's `support_stt_result` ack.
  void handleResult(String status) {
    _ackTimer?.cancel();
    _ackTimer = null;
    if (status == 'ok') {
      _sending = false;
      _lastError = null;
    } else if (status == 'empty') {
      _sending = false;
      _lastError = 'empty';
    } else {
      _sending = false;
      _lastError = 'stt_failed';
    }
    notifyListeners();
  }

  void _onAckTimeout() {
    _ackTimer = null;
    if (!_sending) return;
    _sending = false;
    _lastError = 'stt_failed';
    notifyListeners();
  }

  Future<void> _sendClip(Uint8List bytes) async {
    final hook = onSendClip;
    if (hook != null) {
      await hook(bytes);
      return;
    }
    final host = _hostContext;
    if (host == null || !host.mounted) return;
    final app = AppScope.read(host);
    final sent = await app.cloudRealtimeService.sendMessage(<String, Object?>{
      'type': 'support_stt',
      'data': <String, Object?>{
        'audio': base64Encode(bytes),
        'senderName': app.accountDisplayName,
      },
    });
    if (!sent) _lastError = 'offline';
  }

  Future<Uint8List?> _readBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  void _cleanupFile(String? path) {
    if (path == null) return;
    try {
      File(path).delete().ignore();
    } catch (_) {}
  }

  /// Resets all state (tests only).
  @visibleForTesting
  void resetForTest() {
    _maxHoldTimer?.cancel();
    _ackTimer?.cancel();
    _maxHoldTimer = null;
    _ackTimer = null;
    _recording = false;
    _sending = false;
    _path = null;
    _startedAt = null;
    _lastError = null;
    _hostContext = null;
    _recorderOverride = null;
    minHoldOverride = minHold;
    onSendClip = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _maxHoldTimer?.cancel();
    _ackTimer?.cancel();
    _hostContext = null;
    super.dispose();
  }
}