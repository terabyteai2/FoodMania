import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cap the decoded-image cache below Flutter's 100MB / 1000-image default to
  // keep memory in check on mid-range Android phones.
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes =
        48 <<
        20 // 48 MB
    ..maximumSize = 120;
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialise Firebase for push notifications (FCM).
  // On non-Android platforms where Firebase is not configured, the call
  // throws; catching it allows the app to start without Firebase there.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[QB-FCM] Firebase init skipped: $e');
  }

  runApp(LocalPosApp());
}
