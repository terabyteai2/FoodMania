import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

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
    this.fillBody = false,
    this.centerHeader = false,
    this.headerWidget,
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

  /// When [pinHeader] is true, place [child] in a bounded [Expanded] instead of
  /// a [CustomScrollView]. Required for tabbed pages (e.g. Stock).
  final bool fillBody;
  final bool centerHeader;

  /// When set, replaces the default title/actions header entirely. The widget
  /// is responsible for its own padding. Use [AppPageHeader] for tab roots.
  final Widget? headerWidget;

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
                      headerWidget != null
                          ? headerWidget!
                          : Padding(
                              padding: _headerPadding(),
                              child: _Header(
                                title: title,
                                subtitle: subtitle,
                                actions: actions,
                                showBackButton: showBackButton,
                                centerHeader: centerHeader,
                              ),
                            ),
                      Expanded(
                        child: fillBody
                            ? Padding(
                                padding: EdgeInsets.fromLTRB(
                                  _horizontalPadding(context),
                                  0,
                                  _horizontalPadding(context),
                                  0,
                                ),
                                child: child,
                              )
                            : CustomScrollView(
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
                        padding: headerWidget != null
                            ? EdgeInsets.zero
                            : _headerPadding(),
                        sliver: SliverToBoxAdapter(
                          child:
                              headerWidget ??
                              _Header(
                                title: title,
                                subtitle: subtitle,
                                actions: actions,
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

  EdgeInsets _headerPadding() {
    return showBackButton
        ? const EdgeInsets.fromLTRB(14, 4, 14, 12)
        : const EdgeInsets.fromLTRB(16, 6, 16, 12);
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
    required this.showBackButton,
    required this.centerHeader,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;
  final bool centerHeader;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleFontSize = showBackButton ? 22.0 : 26.0;
        final titleColumn = Column(
          crossAxisAlignment: centerHeader
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TfText(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: centerHeader ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: PosColors.primaryDark,
                height: showBackButton ? 1.18 : 1.15,
                letterSpacing: 0,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 1),
              TfText(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: centerHeader ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: PosColors.muted,
                  height: 1.25,
                  letterSpacing: 0,
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
                    child: Transform.translate(
                      offset: const Offset(-8, 0),
                      child: Tooltip(
                        message: 'Back',
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.of(context).maybePop(),
                              child: const Center(
                                child: TfSourceIcon(
                                  name: TfSourceIconName.back,
                                  size: 22,
                                  strokeWidth: 2,
                                  color: PosColors.primaryDark,
                                ),
                              ),
                            ),
                          ),
                        ),
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
        if (actions.isEmpty) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(alignment: Alignment.centerLeft, child: titleArea),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleArea),
            SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  actions[i],
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
