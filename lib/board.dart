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

class _ArrowPuzzleScreenState extends State<ArrowPuzzleScreen> {
  late Board _board;
  late int _currentLevel;
  final LevelScore _score = LevelScore();
  late final TransformationController _transformationController;

  // Arrows currently playing their snake-track exit animation.
  final Set<Arrow> _exiting = {};

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
    if (widget.initialUnlockedLevel != null) {
      LevelProgress.highestUnlockedLevel = max(
        LevelProgress.highestUnlockedLevel,
        widget.initialUnlockedLevel!,
      );
    }
    _currentLevel = widget.initialLevel;
    _board = widget.board ?? LevelGenerator.generateLevel(_currentLevel);
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
    final newBoard = LevelGenerator.generateLevel(nextLevel);
    _transformationController.value = Matrix4.identity();
    _holdTimer?.cancel();
    _holdTimer = null;
    setState(() {
      _currentLevel = nextLevel;
      _board = newBoard;
      _exiting.clear();
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
    setState(() {
      if (levelNumber != null) _currentLevel = levelNumber;
      _board = newBoard;
      _exiting.clear();
      _blockedArrows.clear();
      _hintArrow = null;
      _shakeArrow = null;
      _heldArrow = null;
      _didHold = false;
      _score.heartsLost = 0;
    });
  }

  void _onTapArrow(Arrow arrow) {
    if (_exiting.contains(arrow)) return;

    final result = _board.tap(arrow.path.first);
    switch (result) {
      case TapResult.cleared:
        HapticFeedback.mediumImpact();
        setState(() {
          _exiting.add(arrow);
          _blockedArrows.remove(arrow);
          _hintArrow = null;
        });
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
    LevelProgress.completeLevel(_currentLevel);
    final stars = _score.stars;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Center(
          child: Column(
            children: [
              Text(
                _board.shapeName != null
                    ? '${_board.shapeName} Cleared!'
                    : 'Cleared!',
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
            ],
          ),
        ),
        content: Text(
          'Rating: ${_score.rating}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Out of hearts'),
        content: const Text('Try again?'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
              loadLevelNumber(_currentLevel);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size(0, 25),
          child: Text(
            'Level $_currentLevel',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
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
        title: Column(
          children: [
            Row(
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
          ],
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.refresh_rounded),
          //   tooltip: 'Restart',
          //   onPressed: () {
          //     HapticFeedback.selectionClick();
          //     loadLevelNumber(_currentLevel);
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Hint',
            onPressed: _useHint,
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
                          activeCells: _board.activeCells,
                          occupiedCells: {
                            for (final a in _board.arrows) ...a.path,
                          },
                        ),
                      ),
                      if (_heldArrow != null)
                        _buildTrajectoryRay(
                          _heldArrow!,
                          cellSize,
                          boardWidth,
                          boardHeight,
                        ),
                      for (final arrow in _board.arrows)
                        _buildRestingArrowTile(arrow, cellSize),
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
    );
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
        ? (cellSize * 0.60).clamp(10.0, 24.0) * 0.5
        : (cellSize * 0.28);
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

  Widget _buildRestingArrowTile(Arrow arrow, double cellSize) {
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
        ),
      ),
    );
  }

  Widget _buildExitingArrowTile(Arrow arrow, double cellSize) {
    final totalSteps = _stepsToFullyExit(arrow);
    return _ExitingArrowTile(
      key: ValueKey(arrow),
      arrow: arrow,
      cellSize: cellSize,
      totalSteps: totalSteps,
      duration: Duration(milliseconds: 50 * totalSteps),
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _exiting.remove(arrow);
        });
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

  const _ExitingArrowTile({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.totalSteps,
    required this.duration,
    required this.onComplete,
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
                color: const Color(0xFF1A1A2E),
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

/// Shows the bottom sheet allowing the player to select any unlocked level.
void showLevelSelectSheet({
  required BuildContext context,
  required int currentLevel,
  required ValueChanged<int> onSelectLevel,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Puzzle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: max(20, currentLevel + 4),
                  itemBuilder: (gridContext, index) {
                    final levelNum = index + 1;
                    final isCurrent = levelNum == currentLevel;
                    final isUnlocked = LevelProgress.isUnlocked(levelNum);
                    final config = LevelConfig.forLevel(levelNum);

                    return InkWell(
                      onTap: isUnlocked
                          ? () {
                              Navigator.of(sheetContext).pop();
                              onSelectLevel(levelNum);
                            }
                          : () {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Stage $levelNum is locked! Complete stage ${levelNum - 1} first.',
                                  ),
                                  duration: const Duration(milliseconds: 1200),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF1A1A2E)
                              : (isUnlocked
                                    ? const Color(0xFFF0F0F3)
                                    : const Color(0xFFEAEAEE)),
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(color: Colors.amber, width: 2)
                              : (isUnlocked
                                    ? null
                                    : Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      )),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isUnlocked) ...[
                              Icon(
                                Icons.lock_rounded,
                                size: 20,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$levelNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ] else ...[
                              Text(
                                '$levelNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                config.shape.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent
                                      ? Colors.amber
                                      : const Color(0xFFFB8500),
                                ),
                              ),
                              Text(
                                '${config.rows}x${config.cols}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isCurrent
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
