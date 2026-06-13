import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    required this.bootFuture,
    required this.onFinished,
    super.key,
  });

  final Future<void> bootFuture;
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _finishAfterBoot();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/brand/splash.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: TfText(
              'QuickBites',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w500,
                color: PosColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finishAfterBoot() async {
    await Future.wait([
      widget.bootFuture,
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (mounted) widget.onFinished();
  }
}
