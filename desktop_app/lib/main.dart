import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'desktop/app/desktop_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Route sqflite through the FFI backend on desktop — the reused
  // LocalDatabaseService opens the same SQLite schema this way.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const DesktopApp());
}
