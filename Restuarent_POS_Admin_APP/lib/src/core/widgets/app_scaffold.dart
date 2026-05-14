import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.floatingActionButton,
    this.showDatePill = true,
    this.showBackButton = false,
    this.pinHeader = false,
    this.centerHeader = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool showDatePill;
  final bool showBackButton;
  final bool pinHeader;
  final bool centerHeader;

  @override
  Widget build(BuildContext context) {
    const spacingScale = 1.0;
    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: pinHeader
            ? Stack(
                children: [
                  _TopWash(),
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          _horizontalPadding(context),
                          18 * spacingScale,
                          _horizontalPadding(context),
                          14 * spacingScale,
                        ),
                        child: _Header(
                          title: title,
                          subtitle: subtitle,
                          actions: actions,
                          showDatePill: showDatePill,
                          showBackButton: showBackButton,
                          centerHeader: centerHeader,
                        ),
                      ),
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                _horizontalPadding(context),
                                0,
                                _horizontalPadding(context),
                                24 * spacingScale,
                              ),
                              sliver: SliverToBoxAdapter(child: child),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Stack(
                children: [
                  _TopWash(),
                  CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          _horizontalPadding(context),
                          18 * spacingScale,
                          _horizontalPadding(context),
                          14 * spacingScale,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _Header(
                            title: title,
                            subtitle: subtitle,
                            actions: actions,
                            showDatePill: showDatePill,
                            showBackButton: showBackButton,
                            centerHeader: centerHeader,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          _horizontalPadding(context),
                          0,
                          _horizontalPadding(context),
                          24 * spacingScale,
                        ),
                        sliver: SliverToBoxAdapter(child: child),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  double _horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final base = width >= 1200
        ? 32.0
        : width >= 700
        ? 22.0
        : 16.0;
    return base.clamp(13.0, 38.0).toDouble();
  }
}

class _TopWash extends StatelessWidget {
  const _TopWash();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 154,
          decoration: BoxDecoration(
            gradient: PosGradients.softWash(opacity: 0.92),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.actions,
    required this.showDatePill,
    required this.showBackButton,
    required this.centerHeader,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showDatePill;
  final bool showBackButton;
  final bool centerHeader;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateLabel = _dateLabel();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final titleColumn = Column(
          crossAxisAlignment: centerHeader
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (showDatePill) ...[
              _DatePill(label: dateLabel),
              SizedBox(height: 12),
            ],
            Text(
              title,
              textAlign: centerHeader ? TextAlign.center : TextAlign.start,
              style: textTheme.headlineMedium,
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: centerHeader ? TextAlign.center : TextAlign.start,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
        final titleArea = showBackButton
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                  Expanded(child: titleColumn),
                ],
              )
            : titleColumn;
        if (centerHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: titleArea),
              if (actions.isNotEmpty) ...[
                SizedBox(height: 10),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ],
          );
        }
        if (actions.isEmpty) return titleArea;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleArea,
              SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleArea),
            SizedBox(width: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        );
      },
    );
  }

  String _dateLabel() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.line),
        boxShadow: [
          BoxShadow(
            color: Color(0x4A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: PosColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x88FFC107),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: PosColors.slate,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
