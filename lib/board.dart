// arrow_puzzle_board.dart
//
// Flutter widget layer for the bent-path arrow puzzle. Depends on:
//   - arrow_puzzle_core.dart  (Board, Arrow, Pos, Direction, LevelGenerator, LevelScore)
//   - arrow_path_painter.dart (DottedGridPainter, ArrowPathWidget)
//
// Usage:
//   final generator = LevelGenerator();
//   final board = generator.generate(rows: 6, cols: 6, arrowCount: 10);
//   ArrowPuzzleScreen(board: board)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core.dart';
import 'path_painter.dart';
import 'grid_line_painter.dart';

class ArrowPuzzleScreen extends StatefulWidget {
  final Board? board;
  final int initialLevel;
  final int? initialUnlockedLevel;

  const ArrowPuzzleScreen({
    super.key,
    this.board,
    this.initialLevel = 1,
    this.initialUnlockedLevel,
  });

  @override
  State<ArrowPuzzleScreen> createState() => _ArrowPuzzleScreenState();
}

class _ArrowPuzzleScreenState extends State<ArrowPuzzleScreen>
    with TickerProviderStateMixin {
  late Board _board;
  late int _currentLevel;
  final LevelScore _score = LevelScore();
  late final TransformationController _transformationController;

  late final AnimationController _introController;
  late final Animation<double> _boardZoomAnimation;
  late final Animation<double> _boardFadeAnimation;

  bool _showArrowGrid = false;
  late final AnimationController _gridAnimationController;

  // Arrows currently playing their snake-track exit animation.
  final Set<Arrow> _exiting = {};

  // Red arrows that are currently playing their snake-track exit animation.
  final Set<Arrow> _exitingRedArrows = {};

  // Arrows that failed validation on tap (turned red). Subsequent taps
  // on these arrows will not decrease player's life.
  final Set<Arrow> _blockedArrows = {};

  Arrow? _hintArrow;
  Arrow? _shakeArrow;

  // Arrow currently held down by player to inspect projected trajectory.
  Arrow? _heldArrow;
  Timer? _holdTimer;
  bool _didHold = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _boardZoomAnimation = Tween<double>(begin: 1.5, end: 0.9).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _boardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 0.0,
    );

    if (widget.initialUnlockedLevel != null) {
      LevelProgress.highestUnlockedLevel = max(
        LevelProgress.highestUnlockedLevel,
        widget.initialUnlockedLevel!,
      );
    }
    _currentLevel = widget.initialLevel;
    LevelProgress.setCurrentLevel(_currentLevel);
    _board = widget.board ?? LevelGenerator.generateLevel(_currentLevel);
    _introController.forward();
  }

  /// Loads a specific level number if unlocked, generating its deterministic full board.
  void loadLevelNumber(int level, {bool force = false}) {
    final nextLevel = level.clamp(1, 9999);
    if (!force && !LevelProgress.isUnlocked(nextLevel)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stage $nextLevel is locked! Complete stage ${nextLevel - 1} first.',
            ),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    LevelProgress.setCurrentLevel(nextLevel);
    final newBoard = LevelGenerator.generateLevel(nextLevel);
    _transformationController.value = Matrix4.identity();
    _holdTimer?.cancel();
    _holdTimer = null;
    _gridAnimationController.reset();
    _introController.forward(from: 0.0);
    setState(() {
      _showArrowGrid = false;
      _currentLevel = nextLevel;
      _board = newBoard;
      _exiting.clear();
      _exitingRedArrows.clear();
      _blockedArrows.clear();
      _hintArrow = null;
      _shakeArrow = null;
      _heldArrow = null;
      _didHold = false;
      _score.heartsLost = 0;
    });
  }

  /// Call this to move to a new level/board (e.g. after the current one is
  /// fully cleared). Because the Stack is keyed to `_board` itself,
  /// assigning a new Board instance here makes Flutter rebuild that whole
  /// subtree fresh — no slide-in animation from stale positions.
  void loadLevel(Board newBoard, {int? levelNumber}) {
    _transformationController.value = Matrix4.identity();
    _holdTimer?.cancel();
    _holdTimer = null;
    _gridAnimationController.reset();
    _introController.forward(from: 0.0);
    setState(() {
      _showArrowGrid = false;
      if (levelNumber != null) _currentLevel = levelNumber;
      _board = newBoard;
      _exiting.clear();
      _exitingRedArrows.clear();
      _blockedArrows.clear();
      _hintArrow = null;
      _shakeArrow = null;
      _heldArrow = null;
      _didHold = false;
      _score.heartsLost = 0;
    });
  }

  void _checkAutoExitBlockedArrows() {
    if (!mounted || _blockedArrows.isEmpty) return;

    final unblocked = <Arrow>[];
    for (final arrow in _blockedArrows) {
      if (_board.pathIsClear(arrow)) {
        unblocked.add(arrow);
      }
    }

    if (unblocked.isEmpty) return;

    final currentBoard = _board;
    for (int i = 0; i < unblocked.length; i++) {
      final arrow = unblocked[i];
      // Immediately remove from board model so subsequent arrows know the path is clear
      _board.arrows.remove(arrow);
      _board.solutionOrder.remove(arrow);
      _blockedArrows.remove(arrow);
      _exitingRedArrows.add(arrow);
      if (_hintArrow == arrow) _hintArrow = null;
      if (_heldArrow == arrow) _heldArrow = null;
      if (_shakeArrow == arrow) _shakeArrow = null;

      Future.delayed(Duration(milliseconds: 100 * (i + 1)), () {
        if (!mounted || _board != currentBoard) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _exiting.add(arrow);
        });
      });
    }

    // Check again in case unblocking these red arrows unblocked further red arrows
    Future.delayed(Duration(milliseconds: 100 * unblocked.length + 40), () {
      if (!mounted || _board != currentBoard) return;
      _checkAutoExitBlockedArrows();
    });
  }

  void _onTapArrow(Arrow arrow) {
    if (_exiting.contains(arrow)) return;

    final result = _board.tap(arrow.path.first);
    switch (result) {
      case TapResult.cleared:
        HapticFeedback.mediumImpact();
        final wasBlocked = _blockedArrows.contains(arrow);
        if (wasBlocked) {
          _exitingRedArrows.add(arrow);
        }
        setState(() {
          _exiting.add(arrow);
          _blockedArrows.remove(arrow);
          _hintArrow = null;
        });
        _checkAutoExitBlockedArrows();
        break;
      case TapResult.blocked:
        HapticFeedback.heavyImpact();
        final alreadyBlocked = _blockedArrows.contains(arrow);
        setState(() {
          if (!alreadyBlocked) {
            _score.registerBlockedTap();
            _blockedArrows.add(arrow);
          }
          _shakeArrow = arrow;
        });
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          setState(() => _shakeArrow = null);
        });
        if (!alreadyBlocked && _score.isFailed) {
          Future.delayed(const Duration(milliseconds: 300), _showFailDialog);
        }
        break;
      case TapResult.invalidEmpty:
        break;
    }
  }

  void _onArrowTapDown(Arrow arrow) {
    if (_introController.isAnimating && _introController.value < 0.85) return;
    if (_exiting.contains(arrow)) return;
    _holdTimer?.cancel();
    _didHold = false;
    _holdTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _heldArrow = arrow;
        _didHold = true;
      });
    });
  }

  void _onArrowTapUp(Arrow arrow) {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_didHold) {
      setState(() {
        _heldArrow = null;
        _didHold = false;
      });
    } else {
      _onTapArrow(arrow);
    }
  }

  void _onArrowTapCancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_heldArrow != null || _didHold) {
      setState(() {
        _heldArrow = null;
        _didHold = false;
      });
    }
  }

  /// How many single-cell steps [arrow] needs to travel so all parts of the arrow
  /// (including its trailing tail) have completely crossed the board boundary.
  int _stepsToFullyExit(Arrow arrow) {
    final head = arrow.head;
    int distToEdge;
    switch (arrow.headDirection) {
      case Direction.up:
        distToEdge = head.row + 1;
        break;
      case Direction.down:
        distToEdge = _board.rows - head.row;
        break;
      case Direction.left:
        distToEdge = head.col + 1;
        break;
      case Direction.right:
        distToEdge = _board.cols - head.col;
        break;
    }
    // Tail needs (path.length - 1) steps to reach head, then distToEdge to cross edge,
    // plus 2 extra cells buffer to ensure the arrowhead and stroke are completely off-screen.
    return (arrow.path.length - 1) + distToEdge + 2;
  }

  /// Builds the full trajectory track in board pixel coordinates starting from
  /// the arrow's tail and extending forward in [headDirection] off the board.
  static List<Offset> _buildTrack({
    required Arrow arrow,
    required double cellSize,
    required int totalSteps,
  }) {
    final track = <Offset>[];
    for (final p in arrow.path) {
      track.add(
        Offset(
          p.col * cellSize + cellSize / 2,
          p.row * cellSize + cellSize / 2,
        ),
      );
    }
    final dirOffset = _directionUnitOffset(arrow.headDirection) * cellSize;
    final headPos = track.last;
    final buffer = totalSteps + arrow.path.length + 10;
    for (int i = 1; i <= buffer; i++) {
      track.add(headPos + dirOffset * i.toDouble());
    }
    return track;
  }

  /// Computes the snake-like polyline points at [progress] steps along [track].
  /// As the tail moves past corners, it enters the straight line of the head,
  /// causing bent arrows (e.g. 2x3 grid) to slither and straighten out completely.
  static List<Offset> _computeSnakePoints({
    required List<Offset> track,
    required double progress,
    required int pathLength,
    required Direction headDirection,
    required double cellSize,
  }) {
    if (pathLength <= 1) {
      final dirOffset = _directionUnitOffset(headDirection) * cellSize;
      final currentCenter = track[0] + dirOffset * progress;
      return [currentCenter];
    }

    final int l = pathLength - 1;
    final double dTail = progress;
    final double dHead = progress + l;

    final int iTail = dTail.floor();
    final double fTail = dTail - iTail;

    final int iHead = dHead.floor();
    final double fHead = dHead - iHead;

    final pTail = Offset.lerp(track[iTail], track[iTail + 1], fTail)!;
    final pHead = Offset.lerp(track[iHead], track[iHead + 1], fHead)!;

    final result = <Offset>[pTail];
    for (int k = iTail + 1; k <= iHead; k++) {
      final pt = track[k];
      if ((pt - result.last).distanceSquared > 0.01) {
        result.add(pt);
      }
    }
    if ((pHead - result.last).distanceSquared > 0.01) {
      result.add(pHead);
    }

    return result;
  }

  static Offset _directionUnitOffset(Direction d) {
    switch (d) {
      case Direction.up:
        return const Offset(0, -1);
      case Direction.down:
        return const Offset(0, 1);
      case Direction.left:
        return const Offset(-1, 0);
      case Direction.right:
        return const Offset(1, 0);
    }
  }

  void _useHint() {
    HapticFeedback.selectionClick();
    setState(() => _hintArrow = _board.hint());
  }

  void _showWinDialog() {
    HapticFeedback.mediumImpact();
    _gridAnimationController.reset();
    setState(() {
      _showArrowGrid = false;
    });
    final stars = _score.stars;
    LevelProgress.completeLevel(_currentLevel, stars);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Center(
          child: Column(
            children: [
              Text(
                'Level $_currentLevel Cleared!',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Icon(
                    index < stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 36,
                  );
                }),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD166),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+$stars',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rating: ${_score.rating}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
              loadLevelNumber(_currentLevel + 1);
            },
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showFailDialog() {
    HapticFeedback.vibrate();
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Out of Moves',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, anim1, anim2) {
        return _buildOutOfMovesDialog();
      },
    );
  }

  Widget _buildOutOfMovesDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main Container Card
          Container(
            margin: const EdgeInsets.only(top: 40),
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                  blurRadius: 36,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'OUT OF MOVES',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You ran out of hearts! Arrows collided.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.70),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),

                // Stats Dashboard Inset
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Stage
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'STAGE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_currentLevel',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      // Hearts
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HEARTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(
                              3,
                              (_) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 1.5),
                                child: Icon(
                                  Icons.heart_broken_rounded,
                                  size: 18,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      // Remaining
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'REMAINING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                size: 14,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_board.arrows.length}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Revive Option (Spend Stars to continue)
                ValueListenableBuilder<int>(
                  valueListenable: StarMoney.notifier,
                  builder: (context, balance, _) {
                    const reviveCost = 5;
                    final canRevive = balance >= reviveCost;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canRevive
                                ? const Color(0xFF3B82F6)
                                : Colors.white.withValues(alpha: 0.08),
                            foregroundColor: Colors.white,
                            elevation: canRevive ? 4 : 0,
                            shadowColor: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: canRevive
                              ? () async {
                                  final navigator = Navigator.of(context);
                                  final spent = await StarMoney.spend(
                                    reviveCost,
                                  );
                                  if (spent && mounted) {
                                    HapticFeedback.mediumImpact();
                                    navigator.pop();
                                    setState(() {
                                      _score.heartsLost = 2; // Restore 1 heart
                                    });
                                  }
                                }
                              : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                size: 18,
                                color: Color(0xFFFF5252),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'REVIVE (+1 LIFE)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      size: 14,
                                      color: Color(0xFFFFB703),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$reviveCost',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: canRevive
                                            ? const Color(0xFFFFB703)
                                            : Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Primary Try Again Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB703),
                      foregroundColor: const Color(0xFF1A1A2E),
                      elevation: 6,
                      shadowColor: const Color(
                        0xFFFFB703,
                      ).withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      loadLevelNumber(_currentLevel);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.replay_rounded, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'TRY AGAIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Secondary Stage Select Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.grid_view_rounded, size: 17),
                        SizedBox(width: 6),
                        Text(
                          'Stage Select',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overhanging Floating Broken Heart Badge
          Positioned(
            top: 0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B6B), Color(0xFFDC2626)],
                ),
                border: Border.all(color: const Color(0xFF1A1A2E), width: 5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.50),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.heart_broken_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateArrowProgress(Arrow arrow, double introProgress) {
    if (introProgress >= 1.0) return 1.0;
    if (introProgress <= 0.0) return 0.0;

    final centerR = _board.rows / 2.0;
    final centerC = _board.cols / 2.0;
    final maxDist = sqrt(centerR * centerR + centerC * centerC);

    final head = arrow.path.last;
    final dist = sqrt(
      pow(head.row + 0.5 - centerR, 2) + pow(head.col + 0.5 - centerC, 2),
    );
    final normDist = (dist / max(1.0, maxDist)).clamp(0.0, 1.0);

    final start = normDist * 0.25;
    final progress = ((introProgress - start) / 0.70).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(progress);
  }

  @override
  void dispose() {
    _introController.dispose();
    _gridAnimationController.dispose();
    _holdTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAEDF6),
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size(0, 32),
          child: Row(
            mainAxisAlignment: .center,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Icon(
                  Icons.favorite,
                  color: i < (3 - _score.heartsLost)
                      ? Colors.red
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Home',
          onPressed: () {
            HapticFeedback.selectionClick();
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Level $_currentLevel',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: StarMoney.notifier,
            builder: (context, balance, _) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  spacing: 4,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        '$balance',
                        key: ValueKey(balance),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            margin: .only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              spacing: 4,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  size: 13,
                  color: Color(0xFF3B82F6),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    '${_board.arrows.length}',
                    key: ValueKey(_board.arrows.length),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final cellFromW = (maxW * 0.90) / _board.cols.clamp(1, 999);
          final cellFromH = (maxH * 0.84) / _board.rows.clamp(1, 999);
          final cellSize = min(cellFromW, cellFromH);
          final boardWidth = cellSize * _board.cols;
          final boardHeight = cellSize * _board.rows;

          return InteractiveViewer(
            transformationController: _transformationController,
            clipBehavior: .none,
            minScale: 1,
            maxScale: 2.5,
            boundaryMargin: const .all(200),
            panEnabled: true,
            scaleEnabled: true,
            child: Center(
              child: AnimatedBuilder(
                animation: _introController,
                builder: (context, _) {
                  final introVal = _introController.value;
                  return Transform.scale(
                    scale: _boardZoomAnimation.value,
                    alignment: .center,
                    child: Opacity(
                      opacity: _boardFadeAnimation.value,
                      child: SizedBox(
                        width: boardWidth,
                        height: boardHeight,
                        child: KeyedSubtree(
                          key: ValueKey(_board),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: Size(boardWidth, boardHeight),
                                painter: DottedGridPainter(
                                  rows: _board.rows,
                                  cols: _board.cols,
                                  cellSize: cellSize,
                                  progress: introVal,
                                  activeCells: _board.activeCells,
                                  occupiedCells: {
                                    for (final a in _board.arrows) ...a.path,
                                  },
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _gridAnimationController,
                                builder: (context, _) {
                                  final gridProgress =
                                      _gridAnimationController.value * introVal;
                                  if (gridProgress <= 0.001) {
                                    return const SizedBox.shrink();
                                  }
                                  return Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        size: Size(boardWidth, boardHeight),
                                        painter: ArrowGridPainter(
                                          arrows: _board.arrows,
                                          cellSize: cellSize,
                                          boardWidth: boardWidth,
                                          boardHeight: boardHeight,
                                          progress: gridProgress,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (_heldArrow != null)
                                _buildTrajectoryRay(
                                  _heldArrow!,
                                  cellSize,
                                  boardWidth,
                                  boardHeight,
                                ),
                              for (final arrow in _board.arrows)
                                _buildRestingArrowTile(
                                  arrow,
                                  cellSize,
                                  progress: _calculateArrowProgress(
                                    arrow,
                                    introVal,
                                  ),
                                ),
                              for (final arrow in _exiting)
                                _buildExitingArrowTile(arrow, cellSize),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                spacing: 6,
                mainAxisSize: .min,
                children: [
                  Row(
                    mainAxisAlignment: .center,
                    spacing: 4,
                    children: const [
                      Icon(Icons.pinch_outlined, size: 12, color: Colors.grey),
                      Text(
                        "Pinch & zoom the board",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Row(
                    spacing: 24,
                    mainAxisAlignment: .center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: .circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          iconSize: 26,
                          color: const Color(0xFF1A1A2E),
                          tooltip: 'Restart',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            loadLevelNumber(_currentLevel);
                          },
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.lightbulb_outline),
                          iconSize: 26,
                          color: const Color(0xFF1A1A2E),
                          tooltip: 'Hint',
                          onPressed: _useHint,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: _showArrowGrid
                              ? const Color(0xFFBAC4E2)
                              : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.grid_3x3),
                          iconSize: 26,
                          color: const Color(0xFF1A1A2E),
                          tooltip: 'Grid',
                          onPressed: _toggleArrowGrid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleArrowGrid() {
    HapticFeedback.selectionClick();
    setState(() {
      _showArrowGrid = !_showArrowGrid;
      if (_showArrowGrid) {
        _gridAnimationController.forward();
      } else {
        _gridAnimationController.reverse();
      }
    });
  }

  Widget _buildTrajectoryRay(
    Arrow arrow,
    double cellSize,
    double boardWidth,
    double boardHeight,
  ) {
    final headCenter = Offset(
      arrow.head.col * cellSize + cellSize / 2,
      arrow.head.row * cellSize + cellSize / 2,
    );
    final dirNorm = _directionUnitOffset(arrow.headDirection);

    final double headExtension = arrow.path.length == 1
        ? (cellSize * 0.68).clamp(12.0, 32.0) * 0.5
        : (cellSize * 0.32);
    final tip = headCenter + dirNorm * headExtension;

    final Offset rayEnd;
    switch (arrow.headDirection) {
      case Direction.up:
        rayEnd = Offset(tip.dx, -cellSize * 0.8);
        break;
      case Direction.down:
        rayEnd = Offset(tip.dx, boardHeight + cellSize * 0.8);
        break;
      case Direction.left:
        rayEnd = Offset(-cellSize * 0.8, tip.dy);
        break;
      case Direction.right:
        rayEnd = Offset(boardWidth + cellSize * 0.8, tip.dy);
        break;
    }

    const rayColor = Colors.lightBlue;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(boardWidth, boardHeight),
          painter: _TrajectoryRayPainter(
            start: tip,
            end: rayEnd,
            color: rayColor,
            cellSize: cellSize,
          ),
        ),
      ),
    );
  }

  Widget _buildRestingArrowTile(
    Arrow arrow,
    double cellSize, {
    double progress = 1.0,
  }) {
    final minRow = arrow.path.map((p) => p.row).reduce(min);
    final maxRow = arrow.path.map((p) => p.row).reduce(max);
    final minCol = arrow.path.map((p) => p.col).reduce(min);
    final maxCol = arrow.path.map((p) => p.col).reduce(max);

    final boxWidth = (maxCol - minCol + 1) * cellSize;
    final boxHeight = (maxRow - minRow + 1) * cellSize;

    final basePos = Offset(minCol * cellSize, minRow * cellSize);

    final isHinted = _hintArrow == arrow;
    final isShaking = _shakeArrow == arrow;
    final isBlocked = _blockedArrows.contains(arrow);
    final isHeld = _heldArrow == arrow;
    final arrowColor = isHeld
        ? const Color(0xFF3B82F6) // Electric blue when held down
        : isBlocked
        ? const Color(0xFFE53935)
        : const Color(0xFF1A1A2E);

    // Path points relative to this arrow's own bounding box.
    final relativePath = arrow.path
        .map((p) => Point(p.row - minRow, p.col - minCol))
        .toList();

    return AnimatedPositioned(
      key: ValueKey(arrow),
      duration: const Duration(milliseconds: 60),
      curve: Curves.linear,
      left: basePos.dx + (isShaking ? 3 : 0),
      top: basePos.dy,
      width: boxWidth,
      height: boxHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTapDown: (_) => _onArrowTapDown(arrow),
        onTapUp: (_) => _onArrowTapUp(arrow),
        onTapCancel: _onArrowTapCancel,
        child: ArrowPathWidget(
          cellPath: relativePath,
          cellSize: cellSize,
          headDirection: arrow.headDirection,
          color: arrowColor,
          isHinted: isHinted,
          progress: progress,
        ),
      ),
    );
  }

  Widget _buildExitingArrowTile(Arrow arrow, double cellSize) {
    final totalSteps = _stepsToFullyExit(arrow);
    final isRed = _exitingRedArrows.contains(arrow);
    return _ExitingArrowTile(
      key: ValueKey(arrow),
      arrow: arrow,
      cellSize: cellSize,
      totalSteps: totalSteps,
      color: isRed ? const Color(0xFFE53935) : const Color(0xFF1A1A2E),
      duration: Duration(milliseconds: 50 * totalSteps),
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _exiting.remove(arrow);
          _exitingRedArrows.remove(arrow);
        });
        _checkAutoExitBlockedArrows();
        if (_board.isCleared && _exiting.isEmpty) {
          _showWinDialog();
        }
      },
    );
  }
}

class _ExitingArrowTile extends StatefulWidget {
  final Arrow arrow;
  final double cellSize;
  final int totalSteps;
  final Duration duration;
  final VoidCallback onComplete;
  final Color color;

  const _ExitingArrowTile({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.totalSteps,
    required this.duration,
    required this.onComplete,
    this.color = const Color(0xFF1A1A2E),
  });

  @override
  State<_ExitingArrowTile> createState() => _ExitingArrowTileState();
}

class _ExitingArrowTileState extends State<_ExitingArrowTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Offset> _track;

  @override
  void initState() {
    super.initState();
    _track = _ArrowPuzzleScreenState._buildTrack(
      arrow: widget.arrow,
      cellSize: widget.cellSize,
      totalSteps: widget.totalSteps,
    );
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value * widget.totalSteps.toDouble();
            final points = _ArrowPuzzleScreenState._computeSnakePoints(
              track: _track,
              progress: progress,
              pathLength: widget.arrow.path.length,
              headDirection: widget.arrow.headDirection,
              cellSize: widget.cellSize,
            );
            return CustomPaint(
              painter: ArrowPathPainter(
                points: points,
                headDirection: widget.arrow.headDirection,
                cellSize: widget.cellSize,
                color: widget.color,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for the trajectory laser ray projected when an arrow is held.
class _TrajectoryRayPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double cellSize;

  _TrajectoryRayPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft luminous outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..strokeWidth = (cellSize * 0.16).clamp(5.0, 9.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, glowPaint);

    // 2. Focused vibrant core laser beam
    final corePaint = Paint()
      ..color = color.withValues(alpha: 0.90)
      ..strokeWidth = (cellSize * 0.07).clamp(2.4, 3.8)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, corePaint);

    // 3. Arrowhead emission flare dot
    final flarePaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, (cellSize * 0.08).clamp(2.5, 4.5), flarePaint);
  }

  @override
  bool shouldRepaint(covariant _TrajectoryRayPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.color != color ||
        oldDelegate.cellSize != cellSize;
  }
}
