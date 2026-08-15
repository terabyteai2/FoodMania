import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:local_pos/src/services/support_stt_controller.dart';

class FakeMicRecorder implements SupportMicRecorder {
  FakeMicRecorder({this.permissionGranted = true, this.stopPath});

  bool permissionGranted;
  String? stopPath;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<String> start({required int sampleRate}) async {
    startCalls++;
    return '/tmp/fake_recording.wav';
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    return stopPath;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupportSttController controller;
  late FakeMicRecorder recorder;
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('stt_test');
    recorder = FakeMicRecorder();
    controller = SupportSttController.instance;
    controller.resetForTest();
    // swap in the fake recorder via the test-only seam
    controller.attachRecorderForTest(recorder);
  });

  tearDown(() async {
    controller.resetForTest();
    await tmpDir.delete(recursive: true);
  });

  test('start records and exposes isRecording', () async {
    await controller.start();
    expect(controller.isRecording, isTrue);
    expect(recorder.startCalls, 1);
  });

  test('start is a no-op while already recording', () async {
    await controller.start();
    await controller.start();
    expect(recorder.startCalls, 1);
  });

  test('denied permission surfaces permission_denied', () async {
    recorder.permissionGranted = false;
    await controller.start();
    expect(controller.isRecording, isFalse);
    expect(controller.lastError, 'permission_denied');
  });

  test('cancel discards the clip without sending', () async {
    await controller.start();
    await controller.cancel();
    expect(controller.isRecording, isFalse);
    expect(recorder.cancelCalls, 1);
    expect(recorder.stopCalls, 0);
  });

  test('short hold is discarded as accidental', () async {
    await controller.start();
    await controller.stopAndSend();
    expect(controller.isSending, isFalse);
    expect(controller.lastError, isNull);
    expect(recorder.cancelCalls, 1);
    expect(recorder.stopCalls, 0);
  });

  test('stopAndSend ships base64 wav over the WS seam', () async {
    final file = File('${tmpDir.path}/clip.wav');
    await file.writeAsBytes(<int>[1, 2, 3, 4]);
    recorder.stopPath = file.path;

    Uint8List? sent;
    controller.onSendClip = (bytes) async {
      sent = bytes;
    };
    controller.minHoldOverride = Duration.zero;
    await controller.start();
    await controller.stopAndSend();

    expect(sent, isNotNull);
    expect(sent!.length, 4);
    expect(controller.isSending, isTrue);
    expect(controller.lastError, isNull);

    controller.handleResult('ok');
    expect(controller.isSending, isFalse);
  });

  test('empty clip surfaces empty error', () async {
    recorder.stopPath = null;
    controller.minHoldOverride = Duration.zero;
    await controller.start();
    await controller.stopAndSend();
    expect(controller.lastError, 'empty');
    expect(controller.isSending, isFalse);
  });

  test('server error ack surfaces stt_failed', () async {
    final file = File('${tmpDir.path}/clip.wav');
    await file.writeAsBytes(<int>[1, 2, 3, 4]);
    recorder.stopPath = file.path;

    controller.onSendClip = (bytes) async {};
    controller.minHoldOverride = Duration.zero;
    await controller.start();
    await controller.stopAndSend();
    controller.handleResult('error');
    expect(controller.isSending, isFalse);
    expect(controller.lastError, 'stt_failed');
  });
}