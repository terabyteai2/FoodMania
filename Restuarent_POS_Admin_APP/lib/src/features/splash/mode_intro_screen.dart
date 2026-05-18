import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

class ModeIntroScreen extends StatelessWidget {
  const ModeIntroScreen({required this.onContinue, super.key});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: _IntroWash()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      final hero = _HeroPanel(onContinue: onContinue);
                      final cards = _CapabilityCards(wide: wide);
                      if (!wide) {
                        return ListView(
                          children: [hero, SizedBox(height: 14), cards],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 5, child: hero),
                          SizedBox(width: 18),
                          Expanded(flex: 4, child: cards),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroWash extends StatelessWidget {
  const _IntroWash();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PosColors.primarySoft,
                    PosColors.background,
                    PosColors.accentSoft.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PosColors.primaryGlow.withValues(alpha: 0.20),
                    PosColors.primaryGlow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: PosGradients.brand,
                borderRadius: BorderRadius.circular(PosRadii.lg),
                boxShadow: PosShadows.glow,
              ),
              child: Icon(
                Icons.whatshot_rounded,
                color: PosColors.slate,
                size: 30,
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: PosColors.primarySoft,
                borderRadius: BorderRadius.circular(PosRadii.pill),
                border: Border.all(color: PosColors.line),
              ),
              child: Text(
                '✦  FOODMANIA POS',
                style: TextStyle(
                  color: PosColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.6,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Your restaurant,\nfully in control.',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(
                fontSize: 32,
                height: 1.08,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Take orders, manage your menu, and track every sale — all synced to the cloud in real time so your team is always on the same page.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: PosColors.muted,
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
            SizedBox(height: 22),
            PrimaryButton(
              label: 'Get Started',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => onContinue(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityCards extends StatelessWidget {
  const _CapabilityCards({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Capability(
        icon: Icons.receipt_long_rounded,
        title: 'Smart Orders',
        message:
            'Take orders from any table. Every order is tracked, printed, and synced — nothing slips through.',
        color: PosColors.primary,
      ),
      _Capability(
        icon: Icons.restaurant_menu_rounded,
        title: 'Live Menu',
        message:
            'Update item availability in seconds. Changes appear instantly on your customer menu page.',
        color: PosColors.accent,
      ),
      _Capability(
        icon: Icons.cloud_sync_rounded,
        title: 'Cloud Sync',
        message:
            'All data syncs automatically. Work offline and it catches up when connected.',
        color: PosColors.info,
      ),
    ];

    return Column(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
      children: cards
          .map(
            (card) =>
                Padding(padding: EdgeInsets.only(bottom: 10), child: card),
          )
          .toList(growable: false),
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.20),
                    color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(PosRadii.md),
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
