import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';

import '../screens/login_screen.dart';
import '../shell/desk_shell.dart';
import '../theme/desk_theme.dart';

/// Root of the QuickBytes Windows desktop app.
///
/// Constructs the reused [PosAppController] (the whole business/data layer from
/// `admin_app`), mounts it via [AppScope]/[AppModel] exactly like the mobile
/// app, and gates between boot → login → the desktop shell.
class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> with WidgetsBindingObserver {
  late final PosAppController _controller;
  bool _bootDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = PosAppController();
    _controller
        .initialize()
        .then((_) {
          if (mounted) setState(() => _bootDone = true);
        })
        .catchError((Object error, StackTrace stack) {
          debugPrint('Controller initialize failed: $error');
          if (mounted) setState(() => _bootDone = true);
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _controller.onResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller.onPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final text = _controller.strings;
          return AppModel(
            controller: _controller,
            child: MaterialApp(
              title: text.appTitle,
              debugShowCheckedModeBanner: false,
              locale: _controller.language.locale,
              supportedLocales: AppLanguage.values
                  .map((language) => language.locale)
                  .toList(growable: false),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: deskThemeData(),
              themeMode: ThemeMode.light,
              home: _home(),
            ),
          );
        },
      ),
    );
  }

  Widget _home() {
    if (!_bootDone) return const _DeskSplash();
    if (!_controller.isLoggedIn) return const LoginScreen();
    return const DeskShell();
  }
}

class _DeskSplash extends StatelessWidget {
  const _DeskSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: PosColors.background,
      body: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
