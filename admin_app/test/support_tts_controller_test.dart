import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:local_pos/src/services/support_tts_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SupportTtsController.instance.resetForTest();
  });

  test('loads persisted mute state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'support_tts_muted': true,
    });
    await SupportTtsController.instance.loadMuteState();
    expect(SupportTtsController.instance.muted, isTrue);
  });

  test('toggle persists mute state', () async {
    await SupportTtsController.instance.loadMuteState();
    expect(SupportTtsController.instance.muted, isFalse);
    await SupportTtsController.instance.setMuted(true);
    expect(SupportTtsController.instance.muted, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('support_tts_muted'), isTrue);
    await SupportTtsController.instance.setMuted(false);
    expect(SupportTtsController.instance.muted, isFalse);
  });

  test('audio chunks are dropped while muted', () async {
    await SupportTtsController.instance.loadMuteState();
    await SupportTtsController.instance.setMuted(true);
    SupportTtsController.instance
        .handleAudioChunk(base64Encode(<int>[1, 2, 3]));
    expect(SupportTtsController.instance.speaking, isFalse);
  });

  test('chunks while unmuted do not throw without a platform player',
      () async {
    await SupportTtsController.instance.loadMuteState();
    SupportTtsController.instance
        .handleAudioChunk(base64Encode(<int>[1, 2, 3]));
    SupportTtsController.instance.handleAudioDone();
    expect(SupportTtsController.instance.speaking, isFalse);
  });
}