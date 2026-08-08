import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/widgets/guided_tour.dart';

void main() {
  group('TourSpotRegistry', () {
    testWidgets('registers while mounted and unregisters on dispose',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: TourSpot(
              name: 'registry.test',
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );

      expect(TourSpotRegistry.has('registry.test'), isTrue);
      final rect = TourSpotRegistry.rectOf('registry.test');
      expect(rect, isNotNull);
      expect(rect!.width, 40);
      expect(rect.height, 40);

      // Replacing the subtree disposes the spot → unregisters it.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(TourSpotRegistry.has('registry.test'), isFalse);
      expect(TourSpotRegistry.rectOf('registry.test'), isNull);
    });

    test('registering the same key twice is idempotent', () {
      final key = GlobalKey();
      TourSpotRegistry.register('registry.dedupe', key);
      TourSpotRegistry.register('registry.dedupe', key);
      expect(TourSpotRegistry.countFor('registry.dedupe'), 1);

      TourSpotRegistry.unregister('registry.dedupe', key);
      TourSpotRegistry.unregister('registry.dedupe', key);
      expect(TourSpotRegistry.countFor('registry.dedupe'), 0);
      expect(TourSpotRegistry.rectOf('registry.dedupe'), isNull);
    });

    testWidgets('same-name spots resolve to the selected IndexedStack child',
        (tester) async {
      Widget stack(int index) => MaterialApp(
            home: Center(
              child: IndexedStack(
                index: index,
                children: const [
                  TourSpot(
                    name: 'registry.tabs',
                    child: SizedBox(width: 40, height: 40),
                  ),
                  TourSpot(
                    name: 'registry.tabs',
                    child: SizedBox(width: 60, height: 60),
                  ),
                ],
              ),
            ),
          );

      await tester.pumpWidget(stack(0));
      expect(TourSpotRegistry.has('registry.tabs'), isTrue);
      expect(TourSpotRegistry.rectOf('registry.tabs')!.width, 40);

      await tester.pumpWidget(stack(1));
      expect(TourSpotRegistry.rectOf('registry.tabs')!.width, 60);

      await tester.pumpWidget(stack(0));
      expect(TourSpotRegistry.rectOf('registry.tabs')!.width, 40);
    });

    testWidgets('slot swaps in one frame do not collide (layout-swap window)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TourSpot(
              name: 'registry.swap',
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      expect(TourSpotRegistry.has('registry.swap'), isTrue);

      // Changing the slot's widget type (phone Scaffold ↔ wide rail Row)
      // deactivates the old spot while the new one mounts in the same build
      // scope; the old dispose only runs at end of frame.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                TourSpot(
                  name: 'registry.swap',
                  child: SizedBox(width: 50, height: 50),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = TourSpotRegistry.rectOf('registry.swap');
      expect(rect, isNotNull);
      expect(rect!.width, 50);
    });

    test('tap listener receives spot taps and clears on null', () {
      final tapped = <String>[];
      TourSpotRegistry.setTapListener(tapped.add);
      TourSpotRegistry.notifySpotTapped('spot.x');
      TourSpotRegistry.setTapListener(null);
      TourSpotRegistry.notifySpotTapped('spot.y');
      expect(tapped, ['spot.x']);
    });

    testWidgets('pointer-down on a TourSpot notifies the registry',
        (tester) async {
      final tapped = <String>[];
      TourSpotRegistry.setTapListener(tapped.add);
      addTearDown(() => TourSpotRegistry.setTapListener(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: TourSpot(
              name: 'registry.tap',
              child: ColoredBox(
                color: Colors.amber,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TourSpot));
      expect(tapped, ['registry.tap']);
    });
  });

  group('GuidedTourOverlay', () {
    /// Full-screen harness: a real [TourSpot] at (40,40)-(140,140) behind the
    /// overlay, exactly like the shell. [AppScope] is required by the
    /// tooltip card for localized copy.
    Widget harness({
      required List<TourStep> steps,
      required VoidCallback onFinished,
    }) {
      final controller = PosAppController()..language = AppLanguage.en;
      return AppScope(
        controller: controller,
        child: MaterialApp(
          home: Stack(
            children: [
              // ColoredBox is hit-testable (like a real button), so taps on
              // the spot reach the passive listener inside TourSpot.
              const Positioned(
                left: 40,
                top: 40,
                child: TourSpot(
                  name: 'spot.a',
                  child: ColoredBox(
                    color: Colors.amber,
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
              ),
              GuidedTourOverlay(steps: steps, onFinished: onFinished),
            ],
          ),
        ),
      );
    }

    const spotACenter = Offset(90, 90);

    testWidgets(
        'shows first step, advances on target tap, finishes on the last tap',
        (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step One',
              body: 'First body',
            ),
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step Two',
              body: 'Second body',
            ),
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step Three',
              body: 'Third body',
            ),
          ],
          onFinished: () => finished++,
        ),
      );

      // Second frame: the spot is laid out, the card renders (the first
      // build ran before layout).
      await tester.pump();

      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      // Click-to-advance: no Next button, hint instead.
      expect(find.text('Next'), findsNothing);
      expect(find.textContaining('Tap the highlighted button'), findsOneWidget);

      await tester.tapAt(spotACenter);
      await tester.pumpAndSettle();
      expect(find.text('Step Two'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);

      await tester.tapAt(spotACenter);
      await tester.pumpAndSettle();
      expect(find.text('Step Three'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);

      await tester.tapAt(spotACenter);
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('does not advance when a different spot is tapped',
        (tester) async {
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step One',
              body: 'First body',
            ),
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step Two',
              body: 'Second body',
            ),
          ],
          onFinished: () {},
        ),
      );

      await tester.pump();
      TourSpotRegistry.notifySpotTapped('spot.b');
      await tester.pumpAndSettle();
      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('Step Two'), findsNothing);
    });

    testWidgets('Skip finishes the tour', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step One',
              body: 'First body',
            ),
          ],
          onFinished: () => finished++,
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('an unresolved step stays on screen with Continue and does '
        'not auto-advance', (tester) async {
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'missing.spot',
              title: 'Skipped Step',
              body: 'Never shown',
            ),
            TourStep.spot(
              spot: 'spot.a',
              title: 'Visible Step',
              body: 'Shown body',
            ),
          ],
          onFinished: () {},
        ),
      );

      // No auto-skip: the card stays on the unresolved step (background dim
      // intact), showing Continue instead of silently moving on.
      await tester.pumpAndSettle();
      expect(find.text('Skipped Step'), findsOneWidget);
      expect(find.text('Visible Step'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Skipped Step'), findsNothing);
      expect(find.text('Visible Step'), findsOneWidget);
    });

    testWidgets('scrim taps outside the hole are absorbed and do not advance',
        (tester) async {
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step One',
              body: 'First body',
            ),
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step Two',
              body: 'Second body',
            ),
          ],
          onFinished: () {},
        ),
      );

      await tester.pump();
      // Tap well away from the hole and the tooltip card — the step must
      // not change.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('Step Two'), findsNothing);
    });

    testWidgets('tapping the hole reaches the real widget and fires its action',
        (tester) async {
      var pressed = 0;
      var finished = 0;
      final controller = PosAppController()..language = AppLanguage.en;
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: Stack(
              children: [
                Positioned(
                  left: 40,
                  top: 40,
                  child: TourSpot(
                    name: 'spot.a',
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: ElevatedButton(
                        onPressed: () => pressed++,
                        child: const Text('Press Me'),
                      ),
                    ),
                  ),
                ),
                GuidedTourOverlay(
                  steps: const [
                    TourStep.spot(
                      spot: 'spot.a',
                      title: 'Do It',
                      body: 'Tap the button',
                    ),
                  ],
                  onFinished: () => finished++,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      // The tap lands on the real button through the hole: its onPressed
      // fires AND the tour finishes.
      await tester.tapAt(spotACenter);
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(finished, 1);
    });

    testWidgets('tap listener is cleared when the overlay is disposed',
        (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'spot.a',
              title: 'Step One',
              body: 'First body',
            ),
          ],
          onFinished: () => finished++,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // No active listener: notifying must be a no-op.
      TourSpotRegistry.notifySpotTapped('spot.a');
      expect(finished, 0);
    });

    testWidgets('enter action fires once and the step waits for its spot',
        (tester) async {
      var enters = 0;
      var showSpot = false;
      final controller = PosAppController()..language = AppLanguage.en;
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Stack(
                  children: [
                    if (showSpot)
                      const Positioned.fill(
                        child: TourSpot(
                          name: 'spot.late',
                          child: SizedBox(height: 80, width: 80),
                        ),
                      ),
                    GuidedTourOverlay(
                      steps: [
                        TourStep.spot(
                          spot: 'spot.late',
                          title: 'Late Spot',
                          body: 'Waits for the target',
                          onEnter: () {
                            enters++;
                            setState(() => showSpot = true);
                          },
                        ),
                      ],
                      onFinished: () {},
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Spot mounts only after the enter action runs (post-frame).
      await tester.pump();
      await tester.pump();
      expect(enters, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Late Spot'), findsOneWidget);

      // Repeated frames must not re-run the action.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(enters, 1);
      expect(find.text('Late Spot'), findsOneWidget);
    });

    testWidgets('waits for an off-screen spot instead of skipping it',
        (tester) async {
      var enters = 0;
      var slide = 0.0;
      final controller = PosAppController()..language = AppLanguage.en;
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Stack(
                  children: [
                    FractionalTranslation(
                      // Off-screen like a closed drawer row; enter slides it in.
                      translation: Offset(-1 + slide, 0),
                      child: const TourSpot(
                        name: 'spot.slide',
                        child: SizedBox(width: 120, height: 40),
                      ),
                    ),
                    GuidedTourOverlay(
                      steps: [
                        TourStep.spot(
                          spot: 'spot.slide',
                          title: 'Drawer Step',
                          body: 'Points at the drawer row',
                          onEnter: () {
                            enters++;
                            setState(() => slide = 1.0);
                          },
                        ),
                      ],
                      onFinished: () {},
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(enters, 1);
      expect(find.text('Drawer Step'), findsOneWidget);
    });

    testWidgets(
        'a spot that never appears never auto-advances; Continue moves on',
        (tester) async {
      final controller = PosAppController()..language = AppLanguage.en;
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: Stack(
              children: [
                const Positioned(
                  left: 40,
                  top: 40,
                  child: TourSpot(
                    name: 'spot.a',
                    child: ColoredBox(
                      color: Colors.amber,
                      child: SizedBox(width: 100, height: 100),
                    ),
                  ),
                ),
                GuidedTourOverlay(
                  steps: [
                    TourStep.spot(
                      spot: 'spot.never',
                      title: 'Never Appears',
                      body: 'Times out',
                      onEnter: () {},
                    ),
                    const TourStep.spot(
                      spot: 'spot.a',
                      title: 'After',
                      body: 'Falls through',
                    ),
                  ],
                  onFinished: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Enter fires post-frame, then the poll runs — but no matter how long
      // we wait, the step never auto-advances.
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Never Appears'), findsOneWidget);
      expect(find.text('After'), findsNothing);

      // Only an explicit user action moves on.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Never Appears'), findsNothing);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('Continue finishes the tour on the last unresolved step',
        (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'never.here',
              title: 'Only Step',
              body: 'No target at all',
            ),
          ],
          onFinished: () => finished++,
        ),
      );

      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });
  });
}
