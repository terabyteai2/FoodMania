import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app_scope.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';
import 'tf_design_system.dart';

/// Guided-tour spotlight overlay (DESIGN.md §5.11).
///
/// Screens expose primary-action widgets to the tour by wrapping them in a
/// [TourSpot]; the shell resolves each spot to a screen rect via
/// [TourSpotRegistry] and renders a dim scrim with a cutout around the target
/// plus a tooltip card (title/body/hint/Continue/Skip). The scrim is always
/// painted — the screen stays dimmed between steps, while a target resolves,
/// and until the user finishes or skips. The cutout is interactive: the real
/// widget under it receives taps, so the user clicks the highlighted button
/// to advance (see [TourSpotRegistry.notifySpotTapped]). The tour never
/// auto-advances: when a step's spot is not visible, the card shows an
/// explicit Continue button (steps with a navigation target run it first).
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

  /// Single-slot tap listener owned by the active [GuidedTourOverlay]. Only
  /// one tour can be on screen at a time, so one slot suffices; the overlay
  /// clears it on dispose.
  static void Function(String name)? _tapListener;

  static void setTapListener(void Function(String name)? listener) {
    _tapListener = listener;
  }

  /// Called by [TourSpot] on any pointer-down within its box. The listener
  /// is passive — it never competes in the gesture arena, so the wrapped
  /// button's own tap still fires.
  static void notifySpotTapped(String name) {
    _tapListener?.call(name);
  }

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
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => TourSpotRegistry.notifySpotTapped(widget.name),
        child: KeyedSubtree(key: _key, child: widget.child),
      );
}

enum TourSpotlightShape { roundedRect, circle }

/// One coach-mark step pointing at a [TourSpot] by name. The step advances
/// when the user taps the highlighted element itself; when the target is not
/// visible the card offers Continue (which runs the step's navigation target
/// first) and Skip.
class TourStep {
  const TourStep.spot({
    required this.spot,
    required this.title,
    required this.body,
    this.shape = TourSpotlightShape.roundedRect,
    this.onEnter,
  });

  /// Name of the target [TourSpot].
  final String spot;

  /// Runs once when this step becomes active while its spot is not yet
  /// visible (e.g. opens the drawer or switches tabs so the target mounts).
  /// The overlay then polls for the spot and switches to spotlight mode the
  /// moment it appears; if it never appears the card stays on screen with a
  /// Continue button (no auto-advance).
  final VoidCallback? onEnter;

  final String title;
  final String body;
  final TourSpotlightShape shape;
}

/// Full-screen coach-mark layer. Insert it via an [OverlayEntry] above the
/// shell (see [SupportChatController.startGuide]). The background stays
/// dimmed for the whole tour. Taps outside the spotlight hole are absorbed;
/// the spotlighted widget stays interactive — tapping it fires its real
/// action and advances the tour. Steps whose target is not visible show a
/// Continue button instead; the tour never advances on its own.
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

  /// Index whose [TourStep.onEnter] already ran and whose spot is now being
  /// awaited. Reset in [_next].
  int? _enteredFor;

  /// Guards against a second pointer-down on the same spot advancing two
  /// steps before the frame (lock is released post-frame).
  bool _advanceLocked = false;

  /// Index the pending-spot poll timer is currently running for.
  int? _recheckFor;
  Timer? _recheckTimer;

  static const double _cardWidth = 340;
  static const double _cardSideMargin = 16;
  static const double _estimatedCardHeight = 200;

  /// Screen size for the on-screen spot check; resolved in
  /// [didChangeDependencies] (MediaQuery is not available in [initState]).
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    TourSpotRegistry.setTapListener(_onSpotTapped);
    // Deferred to the first frame: rect resolution needs [_screenSize] and a
    // completed layout pass for the spots underneath.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureStepVisible();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _stopRecheck();
    TourSpotRegistry.setTapListener(null);
    super.dispose();
  }

  /// Click-to-advance: a pointer-down on the current step's spot advances
  /// the tour. The spot's own button action still fires — this listener is
  /// passive and only observes.
  void _onSpotTapped(String name) {
    if (_advanceLocked || _index >= widget.steps.length) return;
    if (widget.steps[_index].spot != name) return;
    _advanceLocked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _advanceLocked = false;
    });
    _next();
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

  /// Keeps the current step's card on screen in all states. The tour NEVER
  /// auto-advances: if the spotlight target is not visible yet, the card
  /// stays in "Continue" mode until the user acts. For steps with an
  /// [TourStep.onEnter] action (the step's deeplink navigation) the spot is
  /// polled in the background so the card flips to spotlight mode the moment
  /// the target mounts. Safe to call from [build]: scheduling is deferred.
  void _ensureStepVisible() {
    if (_index >= widget.steps.length) return;
    final step = widget.steps[_index];
    final rect = TourSpotRegistry.rectOf(step.spot);
    if (rect != null && _withinScreen(rect, _screenSize)) {
      _stopRecheck();
      return;
    }
    if (step.onEnter == null) return; // no way for the target to appear
    if (_enteredFor != _index) {
      // Fire the enter action post-frame: it may call setState on the shell
      // (switch tabs / open the drawer), which is illegal during build.
      _enteredFor = _index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _enteredFor != _index) return;
        widget.steps[_index].onEnter?.call();
        setState(() {});
      });
    }
    _ensureRecheck();
  }

  /// Polls for the entered step's spot to become visible (throttled), so the
  /// card switches to spotlight mode without user input once the target
  /// mounts. Never advances — the user stays in control.
  void _ensureRecheck() {
    if (_recheckTimer != null && _recheckFor == _index) return;
    _recheckFor = _index;
    _recheckTimer?.cancel();
    _recheckTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _recheckFor != _index) {
        _stopRecheck();
        return;
      }
      setState(() {});
    });
  }

  void _stopRecheck() {
    _recheckTimer?.cancel();
    _recheckTimer = null;
    _recheckFor = null;
  }

  void _next() {
    _stopRecheck();
    _enteredFor = null;
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
    final rect = TourSpotRegistry.rectOf(step.spot);
    final spotlight =
        (rect != null && _withinScreen(rect, size)) ? rect : null;

    return Stack(
      children: [
        Positioned.fill(
          child: _ScrimHitBox(
            // Full dim while the target resolves; a hit-through hole once
            // the spotlight is on. Taps outside the hole are absorbed by the
            // hit-test; inside the hole the real widget stays interactive
            // (click-to-advance).
            hole: spotlight,
            child: CustomPaint(
              painter: _SpotlightPainter(
                spotlight: spotlight,
                shape: step.shape,
              ),
            ),
          ),
        ),
        Positioned(
          left: _cardSideMargin,
          right: _cardSideMargin,
          top: _cardTop(size, media.padding, spotlight),
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
                requiresContinue: spotlight == null,
                onContinue: _next,
                onSkip: _skip,
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
      // No target yet: center the card vertically.
      return math.min(math.max(8.0, (size.height - estHeight) / 2), maxTop);
    }
    if (rect.top > size.height * 0.45) {
      // Target in the lower half → card sits above it.
      return math.max(8.0, rect.top - estHeight - margin);
    }
    return math.min(rect.bottom + margin, maxTop);
  }
}

/// Scrim that absorbs hits everywhere except inside the spotlight hole, so
/// the real widget under the cutout stays interactive (click-to-advance).
/// With no hole (target not yet visible) the whole screen dims and absorbs.
class _ScrimHitBox extends SingleChildRenderObjectWidget {
  const _ScrimHitBox({required this.hole, required super.child});

  /// Hole rect in this box's coordinates (the box is full-screen), or null
  /// while no spotlight is up.
  final Rect? hole;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ScrimRenderObject(hole);

  @override
  void updateRenderObject(BuildContext context, _ScrimRenderObject render) {
    render.hole = hole;
  }
}

class _ScrimRenderObject extends RenderProxyBox {
  _ScrimRenderObject(this.hole);

  Rect? hole;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final hole = this.hole;
    if (hole != null && hole.contains(position)) return false;
    return super.hitTestChildren(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) {
    final hole = this.hole;
    return hole == null || !hole.contains(position);
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.step,
    required this.index,
    required this.total,
    required this.requiresContinue,
    required this.onContinue,
    required this.onSkip,
    super.key,
  });

  final TourStep step;
  final int index;
  final int total;

  /// True when the spotlight target is not visible yet: the card stays on
  /// screen (the screen stays dimmed) and an explicit Continue advances.
  final bool requiresContinue;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(AppScope.read(context).language);
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
          const SizedBox(height: PosSpacing.sp2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                requiresContinue
                    ? Icons.arrow_forward_rounded
                    : Icons.touch_app_outlined,
                size: 14,
                color: PosColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TfText(
                  requiresContinue
                      ? strings.guidedTourContinueHint
                      : strings.guidedTourTapHint,
                  style: TfTextStyles.label.copyWith(color: PosColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: PosSpacing.sp3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressDots(current: index, total: total),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (requiresContinue) ...[
                    TfButton(
                      label: strings.guidedTourContinue,
                      variant: TfButtonVariant.accent,
                      size: TfButtonSize.sm,
                      fullWidth: false,
                      onPressed: onContinue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  TfButton(
                    label: strings.guidedTourSkip,
                    variant: TfButtonVariant.ghost,
                    size: TfButtonSize.sm,
                    fullWidth: false,
                    onPressed: onSkip,
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

  /// Target rect, or null while the target is not visible (the screen stays
  /// fully dimmed, no hole and no outline).
  final Rect? spotlight;
  final TourSpotlightShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = PosColors.tourScrim;
    final spotlight = this.spotlight;
    if (spotlight == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    final rect = spotlight.inflate(8);
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
