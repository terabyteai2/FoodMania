import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });

  group('GuidedTourOverlay', () {
    Widget harness({
      required List<TourStep> steps,
      required VoidCallback onFinished,
    }) {
      return MaterialApp(
        home: Stack(
          children: [
            const Positioned.fill(
              child: TourSpot(
                name: 'spot.a',
                child: SizedBox(height: 100, width: 100),
              ),
            ),
            GuidedTourOverlay(steps: steps, onFinished: onFinished),
          ],
        ),
      );
    }

    testWidgets('shows first step, advances with Next, finishes with Done',
        (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        harness(
          steps: [
            const TourStep.overview(title: 'Step One', body: 'First body'),
            const TourStep.spot(
              spot: 'spot.a',
              title: 'Step Two',
              body: 'Second body',
            ),
            const TourStep.spot(
              spot: 'spot.a',
              title: 'Step Three',
              body: 'Third body',
            ),
          ],
          onFinished: () => finished++,
        ),
      );

      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step Two'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step Three'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('Skip finishes the tour', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.overview(title: 'Step One', body: 'First body'),
          ],
          onFinished: () => finished++,
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('skips steps whose spot is not mounted', (tester) async {
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.spot(
              spot: 'missing.spot',
              title: 'Skipped Step',
              body: 'Never shown',
            ),
            TourStep.overview(title: 'Visible Step', body: 'Shown body'),
          ],
          onFinished: () {},
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Skipped Step'), findsNothing);
      expect(find.text('Visible Step'), findsOneWidget);
    });

    testWidgets('scrim taps are absorbed and do not advance',
        (tester) async {
      await tester.pumpWidget(
        harness(
          steps: const [
            TourStep.overview(title: 'Step One', body: 'First body'),
            TourStep.overview(title: 'Step Two', body: 'Second body'),
          ],
          onFinished: () {},
        ),
      );

      // Tap well away from the tooltip card — the step must not change.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('Step Two'), findsNothing);
    });

    testWidgets('enter action fires once and the step waits for its spot',
        (tester) async {
      var enters = 0;
      var showSpot = false;
      await tester.pumpWidget(
        MaterialApp(
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
      await tester.pumpWidget(
        MaterialApp(
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
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(enters, 1);
      expect(find.text('Drawer Step'), findsOneWidget);
    });

    testWidgets('skips a step whose spot never appears after the wait',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              GuidedTourOverlay(
                steps: [
                  TourStep.spot(
                    spot: 'spot.never',
                    title: 'Never Appears',
                    body: 'Times out',
                    onEnter: () {},
                  ),
                  const TourStep.overview(title: 'After', body: 'Falls through'),
                ],
                onFinished: () {},
              ),
            ],
          ),
        ),
      );

      // Enter fires post-frame, then the wait loop polls up to 90 frames.
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Never Appears'), findsNothing);
      expect(find.text('After'), findsOneWidget);
    });
  });
}
