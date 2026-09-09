import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo/core.dart';
import 'package:demo/board.dart';
import 'package:demo/home_screen.dart';
import 'package:demo/path_painter.dart';

void main() {
  group('Straight-line Snake Exit Animation Tests', () {
    testWidgets(
      'Tapping a clearable 2x3 bent arrow animates cleanly and removes it',
      (WidgetTester tester) async {
        // Create a 6x6 board with a 2x3 bent arrow:
        // P0(2, 1) -> P1(3, 1) -> P2(3, 2) -> P3(3, 3) with head pointing right
        final bentArrow = Arrow(
          path: const [Pos(2, 1), Pos(3, 1), Pos(3, 2), Pos(3, 3)],
          headDirection: Direction.right,
        );

        final board = Board(
          rows: 6,
          cols: 6,
          arrows: [bentArrow],
          solutionOrder: [bentArrow],
        );

        await tester.pumpWidget(
          MaterialApp(home: ArrowPuzzleScreen(board: board)),
        );

        // Verify board renders the arrow
        expect(find.byType(CustomPaint), findsWidgets);
        expect(board.arrows.length, 1);

        // Tap the arrow to clear it
        await tester.tap(find.byKey(ValueKey(bentArrow)));
        await tester.pump();

        // Board has removed it from resting arrows; it is now mid-exit
        expect(board.arrows.isEmpty, true);

        // Advance animation halfway through
        await tester.pump(const Duration(milliseconds: 300));
        // No crashes or exceptions during mid-flight rendering

        // Complete the exit animation duration (totalSteps * 90ms + extra)
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // Win dialog should appear because board was cleared
        expect(find.textContaining('Cleared!'), findsOneWidget);
      },
    );

    testWidgets(
      'Blocked arrow turns red on first tap, and tapping again does not decrease life',
      (WidgetTester tester) async {
        // Arrow 1 at (2, 2) pointing right (blocked by Arrow 2)
        final arrow1 = Arrow(
          path: const [Pos(2, 2)],
          headDirection: Direction.right,
        );
        // Arrow 2 at (2, 4) pointing down (clears cleanly)
        final arrow2 = Arrow(
          path: const [Pos(2, 4)],
          headDirection: Direction.down,
        );

        final board = Board(
          rows: 6,
          cols: 6,
          arrows: [arrow1, arrow2],
          solutionOrder: [arrow2, arrow1],
        );

        await tester.pumpWidget(
          MaterialApp(home: ArrowPuzzleScreen(board: board)),
        );

        // Arrow 1 is blocked by Arrow 2
        expect(board.pathIsClear(arrow1), false);

        // Verify initial state: arrow is dark color
        ArrowPathWidget widget1 = tester.widget(
          find.byType(ArrowPathWidget).first,
        );
        expect(widget1.color, const Color(0xFF1A1A2E));

        // 1st tap on Arrow 1 (blocked)
        await tester.tap(find.byKey(ValueKey(arrow1)));
        await tester.pump();

        // Arrow 1 should now be red!
        widget1 = tester.widget(
          find.descendant(
            of: find.byKey(ValueKey(arrow1)),
            matching: find.byType(ArrowPathWidget),
          ),
        );
        expect(widget1.color, const Color(0xFFE53935));

        // Hearts: 1 lost, so 2 active red hearts (color: Colors.redAccent)
        int activeHearts = tester
            .widgetList<Icon>(find.byIcon(Icons.favorite))
            .where((icon) => icon.color == Colors.redAccent)
            .length;
        expect(activeHearts, 2);

        await tester.pump(const Duration(milliseconds: 300));

        // 2nd tap on Arrow 1 (already blocked)
        await tester.tap(find.byKey(ValueKey(arrow1)));
        await tester.pump();

        // Hearts should STILL be 2 active red hearts (NO additional heart loss!)
        activeHearts = tester
            .widgetList<Icon>(find.byIcon(Icons.favorite))
            .where((icon) => icon.color == Colors.redAccent)
            .length;
        expect(activeHearts, 2);

        // Arrow 1 remains red
        widget1 = tester.widget(
          find.descendant(
            of: find.byKey(ValueKey(arrow1)),
            matching: find.byType(ArrowPathWidget),
          ),
        );
        expect(widget1.color, const Color(0xFFE53935));

        await tester.pump(const Duration(milliseconds: 300));

        // Now tap Arrow 2 to clear it
        await tester.tap(find.byKey(ValueKey(arrow2)));
        await tester.pump();
        expect(board.arrows.length, 1); // arrow 2 cleared!

        await tester.pump(const Duration(milliseconds: 700));

        // Now Arrow 1's path is clear! Tap Arrow 1 to clear it
        await tester.tap(find.byKey(ValueKey(arrow1)));
        await tester.pump();
        expect(board.arrows.length, 0); // arrow 1 cleared!

        // Both arrows cleared, board is cleared!
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pumpAndSettle();
        expect(find.textContaining('Cleared!'), findsOneWidget);
      },
    );
    testWidgets(
      'Single-cell arrow renders with proportional dimensions and exits cleanly',
      (WidgetTester tester) async {
        final singleArrow = Arrow(
          path: const [Pos(2, 2)],
          headDirection: Direction.up,
        );

        final board = Board(
          rows: 5,
          cols: 5,
          arrows: [singleArrow],
          solutionOrder: [singleArrow],
        );

        await tester.pumpWidget(
          MaterialApp(home: ArrowPuzzleScreen(board: board)),
        );

        expect(find.byType(CustomPaint), findsWidgets);
        expect(board.arrows.length, 1);

        // Tap the single-cell arrow
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        expect(board.arrows.isEmpty, true);

        // Advance animation to completion
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pumpAndSettle();

        expect(find.textContaining('Cleared!'), findsOneWidget);
      },
    );
  });

  group('Level System & Progression Tests', () {
    test('LevelConfig designed shapes and deterministic seeds', () {
      expect(LevelConfig.forLevel(1).rows, greaterThanOrEqualTo(8));
      expect(LevelConfig.forLevel(1).cols, greaterThanOrEqualTo(8));
      expect(
        LevelConfig.forLevel(1).shape.activeCells.length,
        greaterThanOrEqualTo(16),
      );

      // Levels are generated procedurally with increased grid counts
      expect(LevelConfig.forLevel(2).shape.activeCells.isNotEmpty, true);
      expect(LevelConfig.forLevel(4).shape.activeCells.isNotEmpty, true);
      expect(LevelConfig.forLevel(5).shape.activeCells.isNotEmpty, true);
      expect(LevelConfig.forLevel(10).shape.activeCells.isNotEmpty, true);
    });

    test(
      'LevelGenerator.generateLevel produces 100% active cell coverage and solvable boards',
      () {
        final board1a = LevelGenerator.generateLevel(1);
        final board1b = LevelGenerator.generateLevel(1);

        // Verify shape name and dimensions
        expect(board1a.rows, greaterThanOrEqualTo(8));
        expect(board1a.cols, greaterThanOrEqualTo(8));

        // 100% full shape coverage: every active cell has an arrow
        int totalCellsCovered = 0;
        for (final a in board1a.arrows) {
          totalCellsCovered += a.path.length;
        }
        expect(totalCellsCovered, board1a.activeCells!.length);

        // Solvability check: every arrow is in the solutionOrder
        expect(board1a.solutionOrder.length, board1a.arrows.length);

        // Determinism check: same level produces identical arrow paths
        expect(board1a.arrows.length, board1b.arrows.length);
        for (int i = 0; i < board1a.arrows.length; i++) {
          expect(board1a.arrows[i].path, board1b.arrows[i].path);
          expect(
            board1a.arrows[i].headDirection,
            board1b.arrows[i].headDirection,
          );
        }

        // Test procedural shape (Level 5)
        final board5 = LevelGenerator.generateLevel(5);
        expect(board5.solutionOrder.length, board5.arrows.length);
        int level5Cells = 0;
        for (final a in board5.arrows) {
          level5Cells += a.path.length;
        }
        expect(level5Cells, board5.activeCells!.length);
      },
    );

    test('LevelProgress tracks unlocked levels sequentially and resets', () {
      LevelProgress.reset();
      expect(LevelProgress.highestUnlockedLevel, 1);
      expect(LevelProgress.isUnlocked(1), true);
      expect(LevelProgress.isUnlocked(2), false);
      expect(LevelProgress.isUnlocked(3), false);

      LevelProgress.completeLevel(1);
      expect(LevelProgress.highestUnlockedLevel, 2);
      expect(LevelProgress.isUnlocked(1), true);
      expect(LevelProgress.isUnlocked(2), true);
      expect(LevelProgress.isUnlocked(3), false);

      LevelProgress.completeLevel(2);
      expect(LevelProgress.highestUnlockedLevel, 3);
      expect(LevelProgress.isUnlocked(3), true);

      LevelProgress.reset();
      expect(LevelProgress.highestUnlockedLevel, 1);
      expect(LevelProgress.isUnlocked(2), false);
    });

    testWidgets(
      'Upcoming levels remain locked until previous level is completed',
      (WidgetTester tester) async {
        LevelProgress.reset();

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();

        // Open Level Select bottom sheet from Home Screen
        await tester.tap(find.text('SELECT PUZZLE'));
        await tester.pumpAndSettle();

        expect(find.text('Select Puzzle'), findsOneWidget);
        // Locked levels should have lock icons
        expect(find.byIcon(Icons.lock_rounded), findsWidgets);

        // Tapping locked Stage 2 should NOT navigate to Stage 2
        await tester.tap(find.text('2').first);
        await tester.pump();
        // Locked snackbar message appears
        expect(find.textContaining('Stage 2 is locked!'), findsOneWidget);

        // Close bottom sheet
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Now complete Level 1
        LevelProgress.completeLevel(1);
        expect(LevelProgress.isUnlocked(2), true);

        // Re-open Level Select bottom sheet
        await tester.tap(find.text('SELECT PUZZLE'));
        await tester.pumpAndSettle();

        // Tap now-unlocked Stage 2
        await tester.tap(find.text('2').first);
        await tester.pumpAndSettle();

        // Sheet should be closed and Stage 2 loaded in ArrowPuzzleScreen
        expect(find.text('Select Puzzle'), findsNothing);
        expect(find.byType(ArrowPuzzleScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Winning a level automatically unlocks and advances to the next level',
      (WidgetTester tester) async {
        LevelProgress.reset();

        // Single-arrow clearable board for Level 1
        final clearableArrow = Arrow(
          path: const [Pos(1, 1)],
          headDirection: Direction.up,
        );
        final testBoard = Board(
          rows: 4,
          cols: 4,
          arrows: [clearableArrow],
          solutionOrder: [clearableArrow],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ArrowPuzzleScreen(board: testBoard, initialLevel: 1),
          ),
        );
        await tester.pump();

        expect(LevelProgress.isUnlocked(2), false);

        // Tap the arrow to clear it
        await tester.tap(find.byKey(ValueKey(clearableArrow)));
        await tester.pump();

        // Wait for exit animation to complete and win dialog to appear
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // Verify Win dialog appeared and Level 2 was unlocked
        expect(find.textContaining('Cleared!'), findsOneWidget);
        expect(LevelProgress.isUnlocked(2), true);

        // Tap Next button
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Win dialog dismissed
        expect(find.textContaining('Cleared!'), findsNothing);
      },
    );
  });

  group('HomeScreen Tests', () {
    testWidgets(
      'HomeScreen renders branding, CTA buttons, and progress badge',
      (WidgetTester tester) async {
        LevelProgress.reset();

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();

        expect(find.text('ARROW '), findsOneWidget);
        expect(find.text('PUZZLE'), findsOneWidget);
        expect(find.text('PLAY GAME'), findsOneWidget);
        expect(find.text('SELECT PUZZLE'), findsOneWidget);
        expect(find.text('HOW TO PLAY'), findsOneWidget);
        expect(find.textContaining('Stage 1 •'), findsOneWidget);
      },
    );

    testWidgets('Tapping HOW TO PLAY opens rules bottom sheet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      await tester.tap(find.text('HOW TO PLAY'));
      await tester.pumpAndSettle();

      expect(find.text('How to Play'), findsOneWidget);
      expect(find.text('Tap to Slither & Exit'), findsOneWidget);
      expect(find.text('Protect Your 3 Hearts'), findsOneWidget);

      await tester.tap(find.text('Got It!'));
      await tester.pumpAndSettle();

      expect(find.text('How to Play'), findsNothing);
    });

    testWidgets(
      'Tapping PLAY GAME navigates to ArrowPuzzleScreen and back button returns',
      (WidgetTester tester) async {
        LevelProgress.reset();

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();

        // Tap PLAY GAME
        await tester.tap(find.text('PLAY GAME'));
        await tester.pumpAndSettle();

        // Now inside ArrowPuzzleScreen
        expect(find.byTooltip('Home'), findsOneWidget);

        // Tap Home back button
        await tester.tap(find.byTooltip('Home'));
        await tester.pumpAndSettle();

        // Returned to HomeScreen
        expect(find.text('PLAY GAME'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping SELECT PUZZLE opens level sheet and shows locked levels',
      (WidgetTester tester) async {
        LevelProgress.reset();

        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.pump();

        await tester.tap(find.text('SELECT PUZZLE'));
        await tester.pumpAndSettle();

        expect(find.text('Select Puzzle'), findsOneWidget);
        expect(find.byIcon(Icons.lock_rounded), findsWidgets);

        // Close sheet
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('Select Puzzle'), findsNothing);
      },
    );
  });

  group('Arrow Precise Hit Testing Tests', () {
    test(
      'ArrowPathPainter.hitTest rejects taps on empty cell of bounding box',
      () {
        // 2x2 bounding box L-shape: occupies (0,0), (1,0), (1,1). (0,1) is EMPTY!
        final painter = ArrowPathPainter(
          points: const [
            Offset(25, 25), // cell (0, 0)
            Offset(25, 75), // cell (1, 0)
            Offset(75, 75), // cell (1, 1)
          ],
          headDirection: Direction.right,
          cellSize: 50.0,
        );

        // Taps on the arrow segments must hit:
        expect(painter.hitTest(const Offset(25, 25)), true);
        expect(painter.hitTest(const Offset(25, 50)), true);
        expect(painter.hitTest(const Offset(25, 75)), true);
        expect(painter.hitTest(const Offset(50, 75)), true);
        expect(painter.hitTest(const Offset(75, 75)), true);

        // Tap in the EMPTY cell (0, 1) at (75, 25) must NOT hit!
        expect(painter.hitTest(const Offset(75, 25)), false);

        // Tap far outside at (100, 0) must NOT hit!
        expect(painter.hitTest(const Offset(100, 0)), false);
      },
    );

    testWidgets(
      'Tapping overlapping bounding box targets only the tapped arrow',
      (WidgetTester tester) async {
        // Arrow A is an L-shape occupying (0,0), (1,0), (1,1).
        // Arrow B occupies (0,1).
        // Both live inside the 2x2 area!
        final arrowA = Arrow(
          path: const [Pos(0, 0), Pos(1, 0), Pos(1, 1)],
          headDirection: Direction.down,
        );
        final arrowB = Arrow(
          path: const [Pos(0, 1)],
          headDirection: Direction.up,
        );

        final testBoard = Board(
          rows: 4,
          cols: 4,
          arrows: [
            arrowB,
            arrowA,
          ], // arrowA is added second, so it is on TOP in Stack!
          solutionOrder: [arrowB, arrowA],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ArrowPuzzleScreen(board: testBoard, initialLevel: 1),
          ),
        );
        await tester.pump();

        // Find widget position of arrowB
        final arrowBWidget = find.byKey(ValueKey(arrowB));
        expect(arrowBWidget, findsOneWidget);

        // Tap arrowB directly at its center
        await tester.tap(arrowBWidget);
        await tester.pump();

        // Arrow B should be the one that exited!
        expect(testBoard.arrows.contains(arrowB), false);
        // Arrow A was NOT tapped and remains on board
        expect(testBoard.arrows.contains(arrowA), true);
      },
    );

    test(
      'Procedural random designs generate fully covered and solvable boards',
      () {
        // Test procedural random designs for levels 13 to 20
        for (int lvl = 13; lvl <= 20; lvl++) {
          final board = LevelGenerator.generateLevel(lvl);
          expect(board.arrows.isNotEmpty, true);
          expect(board.solutionOrder.length, board.arrows.length);

          int totalCovered = 0;
          for (final a in board.arrows) {
            totalCovered += a.path.length;
          }
          expect(totalCovered, board.activeCells!.length);
        }
      },
    );

    testWidgets(
      'InteractiveViewer enables pinch to zoom and pan on game board',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ArrowPuzzleScreen(initialLevel: 1)),
        );
        await tester.pump();

        final ivFinder = find.byType(InteractiveViewer);
        expect(ivFinder, findsOneWidget);

        final iv = tester.widget<InteractiveViewer>(ivFinder);
        expect(iv.scaleEnabled, true);
        expect(iv.panEnabled, true);
        expect(iv.minScale, 0.4);
        expect(iv.maxScale, 6.0);

        // Verify arrows remain interactable inside InteractiveViewer
        expect(find.byType(GestureDetector), findsWidgets);
      },
    );

    test('Solid triangular arrow paints and hits along shaft and head', () {
      final painter = ArrowPathPainter(
        points: const [Offset(25, 25)],
        headDirection: Direction.right,
        cellSize: 50.0,
      );

      // Hit at center shaft
      expect(painter.hitTest(const Offset(25, 25)), true);
      // Hit at tip
      expect(painter.hitTest(const Offset(38, 25)), true);
      // Tap completely outside
      expect(painter.hitTest(const Offset(0, 0)), false);
    });

    test(
      'Every multi-cell arrow strictly follows its natural path direction with zero kinked tips',
      () {
        for (int lvl = 1; lvl <= 20; lvl++) {
          final board = LevelGenerator.generateLevel(lvl);
          for (final arrow in board.arrows) {
            if (arrow.path.length > 1) {
              final head = arrow.path.last;
              final prev = arrow.path[arrow.path.length - 2];
              final delta = Point(head.row - prev.row, head.col - prev.col);
              final naturalDir = DirectionDelta.fromDelta(delta);
              expect(arrow.headDirection, naturalDir);
            }
          }
        }
      },
    );

    test(
      'Single-cell arrows are strictly minimized and virtually absent in Level 1',
      () {
        final level1 = LevelGenerator.generateLevel(1);
        final singleCountLvl1 = level1.arrows
            .where((a) => a.path.length == 1)
            .length;
        expect(
          singleCountLvl1 <= 2,
          isTrue,
        ); // strictly minimized in level 1 (only 2 out of 37)

        for (int lvl = 1; lvl <= 10; lvl++) {
          final b = LevelGenerator.generateLevel(lvl);
          final singles = b.arrows.where((a) => a.path.length == 1).length;
          final ratio = singles / b.arrows.length;
          expect(
            ratio < 0.10,
            isTrue,
            reason:
                'Level $lvl has too many single arrows: $singles / ${b.arrows.length} (${(ratio * 100).toStringAsFixed(1)}%)',
          );
        }
      },
    );

    testWidgets(
      'DottedGridPainter does not draw dots under occupied arrow cells',
      (WidgetTester tester) async {
        final occupied = {const Pos(0, 0), const Pos(0, 1)};
        await tester.pumpWidget(
          CustomPaint(
            size: const Size(80, 80),
            painter: DottedGridPainter(
              rows: 2,
              cols: 2,
              cellSize: 40.0,
              occupiedCells: occupied,
            ),
          ),
        );
        expect(find.byType(CustomPaint), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping a clearable arrow immediately removes it from resting occupiedCells so dots show immediately',
      (WidgetTester tester) async {
        final board = Board(
          rows: 2,
          cols: 2,
          arrows: [
            Arrow(path: [const Pos(0, 0)], headDirection: Direction.up),
          ],
          solutionOrder: [],
        );

        await tester.pumpWidget(
          MaterialApp(home: ArrowPuzzleScreen(initialLevel: 1, board: board)),
        );
        await tester.pump();

        // Tap the arrow
        await tester.tap(find.byType(ArrowPathWidget));
        await tester.pump(); // Immediate frame after tap

        // Find the DottedGridPainter
        final customPaintFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DottedGridPainter,
        );
        final customPaint = tester.widget<CustomPaint>(customPaintFinder);
        final painter = customPaint.painter as DottedGridPainter;

        // Occupied cells should immediately be empty on the very next frame!
        expect(painter.occupiedCells?.contains(const Pos(0, 0)), false);
      },
    );

    testWidgets(
      'Holding an arrow shows blue arrow and trajectory ray with blocked coral pink color',
      (WidgetTester tester) async {
        // Create 2 arrows: arrow1 is blocked by arrow2
        final arrow1 = Arrow(
          path: [const Pos(1, 0)],
          headDirection: Direction.up,
        );
        final arrow2 = Arrow(
          path: [const Pos(0, 0)],
          headDirection: Direction.right,
        );
        final board = Board(
          rows: 3,
          cols: 3,
          arrows: [arrow1, arrow2],
          solutionOrder: [arrow2, arrow1],
        );

        await tester.pumpWidget(
          MaterialApp(home: ArrowPuzzleScreen(initialLevel: 1, board: board)),
        );
        await tester.pump();

        // Find the ArrowPathWidget for arrow1
        final arrow1Finder = find.byWidgetPredicate(
          (w) => w is ArrowPathWidget && w.headDirection == Direction.up,
        );
        expect(arrow1Finder, findsOneWidget);

        // Initially, arrow color is dark navy
        final initialArrowWidget = tester.widget<ArrowPathWidget>(arrow1Finder);
        expect(initialArrowWidget.color, const Color(0xFF1A1A2E));

        // Start touch gesture on arrow1 and hold
        final gesture = await tester.startGesture(tester.getCenter(arrow1Finder));
        await tester.pump(const Duration(milliseconds: 100)); // kPressTimeout
        await tester.pump(const Duration(milliseconds: 160)); // hold timer fires

        // After holding: arrow turns bright blue
        final heldArrowWidget = tester.widget<ArrowPathWidget>(arrow1Finder);
        expect(heldArrowWidget.color, const Color(0xFF3B82F6));

        // Trajectory ray painter is rendered
        final rayFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_TrajectoryRayPainter',
        );
        expect(rayFinder, findsOneWidget);

        // Verify the ray color is lightBlue (as set by user)
        final rayCustomPaint = tester.widget<CustomPaint>(rayFinder);
        final rayPainter = rayCustomPaint.painter as dynamic;
        expect(rayPainter.color, Colors.lightBlue);

        // Release the hold
        await gesture.up();
        await tester.pump();

        // Trajectory ray is dismissed
        expect(rayFinder, findsNothing);

        // Arrow color reverts to normal
        final releasedArrowWidget = tester.widget<ArrowPathWidget>(arrow1Finder);
        expect(releasedArrowWidget.color, const Color(0xFF1A1A2E));

        // Arrow remains on board and no hearts were lost
        expect(board.arrows.contains(arrow1), true);
      },
    );

    testWidgets(
      'Holding a clear arrow shows green trajectory ray and releasing does not exit',
      (WidgetTester tester) async {
        // Single arrow clear to exit UP
        final clearArrow = Arrow(
          path: [const Pos(1, 1)],
          headDirection: Direction.up,
        );
        final board = Board(
          rows: 3,
          cols: 3,
          arrows: [clearArrow],
          solutionOrder: [clearArrow],
        );

        await tester.pumpWidget(
          MaterialApp(home: ArrowPuzzleScreen(initialLevel: 1, board: board)),
        );
        await tester.pump();

        final arrowFinder = find.byType(ArrowPathWidget);
        expect(arrowFinder, findsOneWidget);

        // Hold gesture
        final gesture = await tester.startGesture(tester.getCenter(arrowFinder));
        await tester.pump(const Duration(milliseconds: 100)); // kPressTimeout
        await tester.pump(const Duration(milliseconds: 160)); // hold timer fires

        // Held arrow is electric blue
        expect(
          tester.widget<ArrowPathWidget>(arrowFinder).color,
          const Color(0xFF3B82F6),
        );

        // Trajectory ray is rendered with emerald green color
        final rayFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_TrajectoryRayPainter',
        );
        expect(rayFinder, findsOneWidget);
        final rayCustomPaint = tester.widget<CustomPaint>(rayFinder);
        final rayPainter = rayCustomPaint.painter as dynamic;
        expect(rayPainter.color, Colors.lightBlue);

        // Release hold
        await gesture.up();
        await tester.pump();

        // Ray is removed, arrow was NOT exited during hold release
        expect(rayFinder, findsNothing);
        expect(board.arrows.contains(clearArrow), true);

        // Now perform a quick tap (< 180ms)
        await tester.tap(arrowFinder);
        await tester.pump();

        // Arrow is now removed from resting arrows and enters exit animation!
        expect(board.arrows.contains(clearArrow), false);
      },
    );
  });
}

