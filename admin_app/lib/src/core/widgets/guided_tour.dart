import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

/// Guided-tour spotlight overlay (DESIGN.md §5.11).
///
/// Screens expose primary-action widgets to the tour by wrapping them in a
/// [TourSpot]; the shell resolves each spot to a screen rect via
/// [TourSpotRegistry] and renders a dim scrim with a cutout around the target
/// plus a tooltip card (title/body/Next/Skip). Steps whose spot is not
/// currently mounted are skipped automatically.
class TourSpotRegistry {
  TourSpotRegistry._();

  /// Multiple keys may legitimately share a name at the same time:
  /// - Every tab screen renders its own shared header, and [_LazyIndexedStack]
  ///   keeps visited tabs mounted, so `header.menu` exists once per visited
  ///   tab (only the selected tab's is visible).
  /// - A layout swap (phone ↔ wide rail) remounts the shell in the same frame
  ///   the old subtree is deactivated; the old spot only unregisters on
  ///   [State.deactivate], which fires before the new one's [State.initState].
  /// Resolution always prefers the visible spot (see [_isVisible]).
  static final Map<String, List<GlobalKey>> _keys =
      <String, List<GlobalKey>>{};

  static void register(String name, GlobalKey key) {
    final list = _keys[name] ??= <GlobalKey>[];
    // Idempotent: the same key can never be registered twice, even if a
    // lifecycle path calls register redundantly (activate/didUpdateWidget).
    if (!list.contains(key)) list.add(key);
  }

  static void unregister(String name, GlobalKey key) {
    final list = _keys[name];
    if (list == null) return;
    list.remove(key);
    if (list.isEmpty) _keys.remove(name);
  }

  /// Resolves [name] to the rect of the currently visible spot in global
  /// coordinates, or null when no visible spot is mounted. Keys are checked
  /// newest-first, so when two visible spots share a name (a pushed screen
  /// overlaying the shell) the most recently mounted one wins.
  static Rect? rectOf(String name) {
    final list = _keys[name];
    if (list == null) return null;
    for (final key in list.reversed) {
      final context = key.currentContext;
      if (context == null || !_isVisible(context)) continue;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final size = box.size;
      if (size.isEmpty) continue;
      return box.localToGlobal(Offset.zero) & size;
    }
    return null;
  }

  static bool has(String name) => rectOf(name) != null;

  @visibleForTesting
  static int countFor(String name) => _keys[name]?.length ?? 0;

  /// True when [context] is not hidden by any [Visibility]/[Offstage] ancestor
  /// (e.g. the unselected children of an [IndexedStack], which this SDK
  /// implements as `Visibility(visible: i == index)`). Spots in hidden tab
  /// children resolve to nothing.
  static bool _isVisible(BuildContext context) {
    var visible = true;
    context.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is Visibility && !widget.visible) {
        visible = false;
        return false; // stop walking once hidden
      }
      if (widget is Offstage && widget.offstage) {
        visible = false;
        return false;
      }
      return true;
    });
    return visible;
  }
}

/// Zero-visual wrapper that exposes [child] to the guided tour as a spotlight
/// target named [name]. It has no layout or paint impact. Spots register on
/// mount and unregister on [State.deactivate] (which fires before the
/// replacing widget's `initState` during a remount), so the registry never
/// holds keys for torn-down subtrees. Several spots may share a name when they
/// live in different [IndexedStack] children; only the visible one resolves.
class TourSpot extends StatefulWidget {
  const TourSpot({required this.name, required this.child, super.key});

  final String name;
  final Widget child;

  @override
  State<TourSpot> createState() => _TourSpotState();
}

class _TourSpotState extends State<TourSpot> {
  final GlobalKey _key = GlobalKey();
  bool _registered = false;

  void _register() {
    if (_registered) return;
    _registered = true;
    TourSpotRegistry.register(widget.name, _key);
  }

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant TourSpot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      TourSpotRegistry.unregister(oldWidget.name, _key);
      _register();
    }
  }

  @override
  void activate() {
    super.activate();
    _register();
  }

  @override
  void deactivate() {
    TourSpotRegistry.unregister(widget.name, _key);
    _registered = false;
    super.deactivate();
  }

  @override
  void dispose() {
    TourSpotRegistry.unregister(widget.name, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

enum TourSpotlightShape { roundedRect, circle }

/// One coach-mark step. Either points at a [TourSpot] by name
/// ([TourStep.spot]) or dims the whole screen with no cutout
/// ([TourStep.overview]).
class TourStep {
  const TourStep.spot({
    required this.spot,
    required this.title,
    required this.body,
    this.shape = TourSpotlightShape.roundedRect,
    this.onEnter,
  }) : isOverview = false;

  const TourStep.overview({
    required this.title,
    required this.body,
    this.onEnter,
  }) : spot = null,
       isOverview = true,
       shape = TourSpotlightShape.roundedRect;

  /// Name of the target [TourSpot]; null for overview steps.
  final String? spot;

  /// True for whole-screen dim steps (no cutout).
  final bool isOverview;

  /// Runs once when this step becomes active while its spot is not yet
  /// visible (e.g. opens the drawer or switches tabs so the target mounts).
  /// The overlay then waits up to ~1.5s for the spot to appear before
  /// skipping to the next step.
  final VoidCallback? onEnter;

  final String title;
  final String body;
  final TourSpotlightShape shape;
}

/// Full-screen coach-mark layer. Insert it via an [OverlayEntry] above the
/// shell (see `_MainShellState._startGuidedTour`). Taps on the scrim are
/// absorbed and do nothing; advancing happens only via Next/Done.
class GuidedTourOverlay extends StatefulWidget {
  const GuidedTourOverlay({
    required this.steps,
    required this.onFinished,
    super.key,
  });

  final List<TourStep> steps;
  final VoidCallback onFinished;

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  int _index = 0;

  /// Index whose missing spot already scheduled a skip-advance; guards
  /// against double-scheduling from repeated builds.
  int? _skipPendingFor;

  /// Index whose [TourStep.onEnter] already ran and whose spot is now being
  /// awaited. Reset in [_next].
  int? _enteredFor;

  /// Index whose wait-loop frame is already scheduled.
  int? _waitPendingFor;

  /// Frames spent waiting for an entered step's spot to become visible.
  int _waitFrames = 0;

  /// Longest wait for a spot after its enter action: the drawer slide-in
  /// animation (~250 ms) plus a couple of frames, comfortably under this.
  static const int _maxWaitFrames = 90;

  static const double _cardWidth = 340;
  static const double _cardSideMargin = 16;
  static const double _estimatedCardHeight = 168;

  /// Screen size for the on-screen spot check; resolved in
  /// [didChangeDependencies] (MediaQuery is not available in [initState]).
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // Deferred to the first frame: rect resolution needs [_screenSize].
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureStepVisible();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
    _ensureStepVisible();
  }

  /// True when [rect] intersects the screen area. Spots that are mounted but
  /// translated off-screen (a closed drawer row) are treated as not visible
  /// until the drawer slides in.
  bool _withinScreen(Rect rect, Size size) =>
      rect.right > 0 &&
      rect.left < size.width &&
      rect.top < size.height &&
      rect.bottom > 0;

  /// Advances past any step whose spot is not currently visible; steps with
  /// an [TourStep.onEnter] action instead run the action once and then wait
  /// up to [_maxWaitFrames] frames for the spot to appear. Safe to call from
  /// [build]: a pending skip/wait is only ever scheduled once per index.
  void _ensureStepVisible() {
    if (_index >= widget.steps.length) {
      widget.onFinished();
      return;
    }
    final step = widget.steps[_index];
    if (step.isOverview) return;
    final rect = TourSpotRegistry.rectOf(step.spot!);
    if (rect != null && _withinScreen(rect, _screenSize)) return;

    if (step.onEnter != null && _enteredFor != _index) {
      // Fire the enter action post-frame: it may call setState on the shell
      // (switch tabs / open the drawer), which is illegal during build.
      _enteredFor = _index;
      _waitFrames = 0;
      _scheduleEnter();
      return;
    }
    if (_enteredFor == _index) {
      if (_waitFrames >= _maxWaitFrames) {
        // Timed out — advance to the next step post-frame (setState during
        // build is illegal).
        if (_skipPendingFor == _index) return;
        _skipPendingFor = _index;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _skipPendingFor = null;
          if (mounted) _next();
        });
      } else {
        _scheduleWaitFrame();
      }
      return;
    }
    if (_skipPendingFor == _index) return;
    _skipPendingFor = _index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _skipPendingFor = null;
      if (!mounted) return;
      if (_index >= widget.steps.length) {
        widget.onFinished();
        return;
      }
      // Re-check after the frame (layout has now run): a spot mounted during
      // this frame's build must not be skipped.
      final step = widget.steps[_index];
      if (step.isOverview) return;
      final rect = TourSpotRegistry.rectOf(step.spot!);
      if (rect == null || !_withinScreen(rect, _screenSize)) {
        _next();
      }
    });
  }

  /// Runs the step's enter action after the frame, then starts the wait loop.
  void _scheduleEnter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.steps[_index].onEnter?.call();
      _waitFrames++;
      setState(() {});
    });
  }

  /// Schedules the next frame of the spot-wait loop: the rebuild re-resolves
  /// the target rect while the drawer slides in or the tab mounts.
  void _scheduleWaitFrame() {
    if (_waitPendingFor == _index) return;
    _waitPendingFor = _index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitPendingFor = null;
      if (!mounted) return;
      _waitFrames++;
      setState(() {});
    });
  }

  void _next() {
    _skipPendingFor = null;
    _enteredFor = null;
    _waitPendingFor = null;
    _waitFrames = 0;
    if (_index + 1 >= widget.steps.length) {
      widget.onFinished();
      return;
    }
    setState(() => _index++);
    _ensureStepVisible();
  }

  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    _ensureStepVisible();
    if (_index >= widget.steps.length) return const SizedBox.shrink();
    final step = widget.steps[_index];
    final media = MediaQuery.of(context);
    final size = media.size;
    final rect = step.isOverview ? null : TourSpotRegistry.rectOf(step.spot!);
    if (!step.isOverview && (rect == null || !_withinScreen(rect, size))) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            // Absorb scrim taps — advancing happens only via Next (avoids
            // accidental dismissals while tapping through).
            onTap: () {},
            child: CustomPaint(
              painter: _SpotlightPainter(spotlight: rect, shape: step.shape),
            ),
          ),
        ),
        Positioned(
          left: _cardSideMargin,
          right: _cardSideMargin,
          top: _cardTop(size, media.padding, rect),
          child: Align(
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _TooltipCard(
                key: ValueKey<int>(_index),
                step: step,
                index: _index,
                total: widget.steps.length,
                onSkip: _skip,
                onNext: _next,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _cardTop(Size size, EdgeInsets padding, Rect? rect) {
    const margin = 12.0;
    final estHeight = _estimatedCardHeight;
    final maxTop = math.max(8.0, size.height - padding.bottom - estHeight - 8);
    if (rect == null) {
      // Overview: bottom-anchored above the safe area.
      return math.max(24.0, maxTop - margin);
    }
    if (rect.top > size.height * 0.45) {
      // Target in the lower half → card sits above it.
      return math.max(8.0, rect.top - estHeight - margin);
    }
    return math.min(rect.bottom + margin, maxTop);
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onNext,
    super.key,
  });

  final TourStep step;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      width: _GuidedTourOverlayState._cardWidth,
      padding: const EdgeInsets.fromLTRB(
        PosSpacing.sp4,
        PosSpacing.sp3,
        PosSpacing.sp4,
        PosSpacing.sp3,
      ),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
        boxShadow: PosShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TfText(
                  step.title,
                  style: TfTextStyles.rowTitle.copyWith(color: PosColors.text),
                ),
              ),
              const SizedBox(width: PosSpacing.sp2),
              TfText(
                '${index + 1}/$total',
                style: TfTextStyles.label.copyWith(color: PosColors.muted),
              ),
            ],
          ),
          const SizedBox(height: PosSpacing.sp2),
          TfText(
            step.body,
            style: TfTextStyles.body.copyWith(color: PosColors.ink2),
          ),
          const SizedBox(height: PosSpacing.sp3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressDots(current: index, total: total),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TfButton(
                    label: 'Skip',
                    variant: TfButtonVariant.ghost,
                    size: TfButtonSize.sm,
                    fullWidth: false,
                    onPressed: onSkip,
                  ),
                  const SizedBox(width: PosSpacing.sp2),
                  TfButton(
                    label: isLast ? 'Done' : 'Next',
                    variant: TfButtonVariant.primary,
                    size: TfButtonSize.sm,
                    fullWidth: false,
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == current ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: i == current ? PosColors.primary : PosColors.surface3,
              borderRadius: BorderRadius.circular(PosRadii.pill),
            ),
          ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.spotlight, required this.shape});

  final Rect? spotlight;
  final TourSpotlightShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = PosColors.tourScrim;
    if (spotlight == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    final rect = spotlight!.inflate(8);
    final radius = switch (shape) {
      TourSpotlightShape.circle => Radius.circular(rect.shortestSide / 2),
      TourSpotlightShape.roundedRect => const Radius.circular(PosRadii.md),
    };
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, radius));
    final full = Path()..addRect(Offset.zero & size);
    final cut = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(cut, scrim);
    canvas.drawPath(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = PosColors.primary,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight || oldDelegate.shape != shape;
}
