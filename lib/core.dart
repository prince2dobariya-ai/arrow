// arrow_puzzle_core.dart
//
// Core model + solvable level generator for the bent-path arrow style
// (arrows span 1-N contiguous cells and end in an arrowhead — see the
// reference screenshot). No Flutter dependencies; pure Dart logic so it's
// unit-testable on its own.

import 'dart:math';

enum Direction { up, down, left, right }

extension DirectionDelta on Direction {
  Point<int> get delta {
    switch (this) {
      case Direction.up:
        return const Point(-1, 0);
      case Direction.down:
        return const Point(1, 0);
      case Direction.left:
        return const Point(0, -1);
      case Direction.right:
        return const Point(0, 1);
    }
  }

  static Direction? fromDelta(Point<int> d) {
    for (final dir in Direction.values) {
      if (dir.delta == d) return dir;
    }
    return null;
  }
}

class Pos {
  final int row;
  final int col;
  const Pos(this.row, this.col);

  Pos step(Direction d) =>
      Pos(row + d.delta.x.toInt(), col + d.delta.y.toInt());

  @override
  bool operator ==(Object other) =>
      other is Pos && other.row == row && other.col == col;
  @override
  int get hashCode => row * 10007 + col;
  @override
  String toString() => '($row,$col)';
}

/// An arrow now occupies 1..N orthogonally-contiguous cells. [path] is
/// ordered tail-to-head; the arrowhead sits at path.last and points in
/// [headDirection].
class Arrow {
  final List<Pos> path;
  final Direction headDirection;

  Arrow({required this.path, required this.headDirection})
    : assert(path.isNotEmpty, 'Arrow path cannot be empty');

  Pos get head => path.last;
  Pos get tail => path.first;

  bool occupies(Pos p) => path.contains(p);
}

enum TapResult { invalidEmpty, blocked, cleared }

class Board {
  final int rows;
  final int cols;
  final List<Arrow> arrows;

  /// Order arrows should be cleared in, guaranteed valid at generation
  /// time. Used for hints. Cleared arrows are removed from the front.
  final List<Arrow> solutionOrder;
  final Set<Pos>? activeCells;
  final String? shapeName;

  Board({
    required this.rows,
    required this.cols,
    required this.arrows,
    required this.solutionOrder,
    this.activeCells,
    this.shapeName,
  });

  /// Fast lookup: which arrow (if any) occupies a given cell.
  Arrow? arrowAt(Pos p) {
    for (final a in arrows) {
      if (a.occupies(p)) return a;
    }
    return null;
  }

  bool get isCleared => arrows.isEmpty;

  bool _cellOccupiedByOther(Pos p, Arrow self) {
    for (final a in arrows) {
      if (identical(a, self)) continue;
      if (a.occupies(p)) return true;
    }
    return false;
  }

  /// An arrow is clearable if the path from its head, stepping in
  /// headDirection, reaches the board edge without hitting any cell
  /// belonging to another arrow.
  bool pathIsClear(Arrow arrow) {
    Pos p = arrow.head;
    while (true) {
      p = p.step(arrow.headDirection);
      if (p.row < 0 || p.row >= rows || p.col < 0 || p.col >= cols) {
        return true; // reached the edge cleanly
      }
      if (activeCells != null && !activeCells!.contains(p)) {
        continue; // empty cell outside shape silhouette, arrow can pass through!
      }
      if (_cellOccupiedByOther(p, arrow)) return false;
    }
  }

  /// Tapping any cell belonging to an arrow attempts to clear that whole
  /// arrow.
  TapResult tap(Pos p) {
    final arrow = arrowAt(p);
    if (arrow == null) return TapResult.invalidEmpty;
    if (!pathIsClear(arrow)) return TapResult.blocked;
    arrows.remove(arrow);
    solutionOrder.remove(arrow);
    return TapResult.cleared;
  }

  /// Next recommended arrow to clear, or null if the board is empty.
  Arrow? hint() => solutionOrder.isEmpty ? null : solutionOrder.first;
}

class LevelGenerator {
  final Random _rng;
  LevelGenerator({int? seed}) : _rng = Random(seed);

  /// Generates a 100% full, guaranteed solvable board for [levelNumber]
  /// using deterministic level progression configs.
  static Board generateLevel(int levelNumber) {
    final config = LevelConfig.forLevel(levelNumber);
    final generator = LevelGenerator(seed: config.seed);
    return generator.generate(
      rows: config.rows,
      cols: config.cols,
      maxArrowLength: config.maxArrowLength,
      activeCells: config.shape.activeCells,
      shapeName: config.shape.name,
    );
  }

  /// Generates a solvable board. If [arrowCount] is null, the entire board (or activeCells) is
  /// 100% filled with arrows (every active cell occupied, leaving no empty gaps).
  /// If [arrowCount] is provided, generates a board with at most [arrowCount] arrows.
  Board generate({
    required int rows,
    required int cols,
    int? arrowCount,
    int maxArrowLength = 4,
    int maxAttemptsPerArrow = 60,
    int maxOverallAttempts = 150,
    Set<Pos>? activeCells,
    String? shapeName,
  }) {
    if (arrowCount == null) {
      // 100% full board generation: tiles all active cells on the board
      final fullBoard = _generateFullBoard(
        rows: rows,
        cols: cols,
        maxArrowLength: maxArrowLength,
        maxAttempts: maxOverallAttempts,
        activeCells: activeCells,
        shapeName: shapeName,
      );
      if (fullBoard != null) return fullBoard;
    } else {
      for (int overall = 0; overall < maxOverallAttempts; overall++) {
        final result = _attemptGenerate(
          rows,
          cols,
          arrowCount,
          maxArrowLength,
          maxAttemptsPerArrow,
        );
        if (result != null) return result;
      }
      // Degrade gracefully: fewer, shorter arrows are always easier to fit.
      if (arrowCount > 1) {
        return generate(
          rows: rows,
          cols: cols,
          arrowCount: arrowCount - 1,
          maxArrowLength: maxArrowLength,
          maxAttemptsPerArrow: maxAttemptsPerArrow,
          maxOverallAttempts: maxOverallAttempts,
          activeCells: activeCells,
          shapeName: shapeName,
        );
      }
    }
    throw StateError('Could not generate a board for the given dimensions.');
  }

  Board? _generateFullBoard({
    required int rows,
    required int cols,
    required int maxArrowLength,
    required int maxAttempts,
    Set<Pos>? activeCells,
    String? shapeName,
  }) {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final board = _attemptFull(
        rows,
        cols,
        maxArrowLength,
        activeCells: activeCells,
        shapeName: shapeName,
      );
      if (board != null) return board;
    }
    return null;
  }

  Board? _attemptFull(
    int rows,
    int cols,
    int maxArrowLength, {
    Set<Pos>? activeCells,
    String? shapeName,
  }) {
    // 1. Tile 100% of the active shape cells with paths of length 1..maxArrowLength
    final grid = List.generate(rows, (_) => List<int>.filled(cols, -1));
    final tiles = <List<Pos>>[];

    final allCells =
        (activeCells != null
              ? activeCells.toList()
              : [
                  for (int r = 0; r < rows; r++)
                    for (int c = 0; c < cols; c++) Pos(r, c),
                ])
          ..shuffle(_rng);

    for (final start in allCells) {
      if (grid[start.row][start.col] != -1) continue;
      final path = <Pos>[start];
      grid[start.row][start.col] = tiles.length;
      final targetLen = 3 + _rng.nextInt(max(1, maxArrowLength - 2));

      Direction? lastDir;
      while (path.length < targetLen) {
        final cur = path.last;
        final validNeighbors = <Direction, Pos>{};
        for (final d in Direction.values) {
          final p = cur.step(d);
          if (p.row >= 0 &&
              p.row < rows &&
              p.col >= 0 &&
              p.col < cols &&
              (activeCells == null || activeCells.contains(p)) &&
              grid[p.row][p.col] == -1) {
            validNeighbors[d] = p;
          }
        }

        if (validNeighbors.isEmpty) break;

        final Direction nextDir;
        // 70% chance to continue in the same direction to form long straight segments,
        // U-turns, S-curves, and labyrinth snakes matching the reference image.
        if (lastDir != null &&
            validNeighbors.containsKey(lastDir) &&
            _rng.nextDouble() < 0.70) {
          nextDir = lastDir;
        } else {
          final dirs = validNeighbors.keys.toList()..shuffle(_rng);
          nextDir = dirs.first;
        }

        final next = validNeighbors[nextDir]!;
        grid[next.row][next.col] = tiles.length;
        path.add(next);
        lastDir = nextDir;
      }
      tiles.add(path);
    }

    // Merge any short tiles (<= 2 cells) into adjacent multi-cell paths whenever possible,
    // ensuring single-cell arrows never appear in high quantity and snakes remain long.
    final effectiveTiles = List<List<Pos>>.from(tiles);
    bool changed = true;
    int passes = 0;
    while (changed && passes < 5) {
      changed = false;
      passes++;
      for (int i = effectiveTiles.length - 1; i >= 0; i--) {
        if (effectiveTiles[i].length <= 2) {
          final isSingle = effectiveTiles[i].length == 1;
          for (int j = 0; j < effectiveTiles.length; j++) {
            if (i == j) continue;
            final other = effectiveTiles[j];
            final maxAllowed = isSingle
                ? max(maxArrowLength + 3, 8)
                : max(maxArrowLength + 2, 7);
            if (other.length + effectiveTiles[i].length > maxAllowed) continue;
            if (isSingle) {
              final singlePos = effectiveTiles[i].first;
              final distHead =
                  (other.last.row - singlePos.row).abs() +
                  (other.last.col - singlePos.col).abs();
              if (distHead == 1) {
                other.add(singlePos);
                effectiveTiles.removeAt(i);
                changed = true;
                break;
              }
              final distTail =
                  (other.first.row - singlePos.row).abs() +
                  (other.first.col - singlePos.col).abs();
              if (distTail == 1) {
                other.insert(0, singlePos);
                effectiveTiles.removeAt(i);
                changed = true;
                break;
              }
            } else {
              final pHead = effectiveTiles[i].last;
              final pTail = effectiveTiles[i].first;
              final distHeadToTail =
                  (other.last.row - pTail.row).abs() +
                  (other.last.col - pTail.col).abs();
              if (distHeadToTail == 1) {
                other.addAll(effectiveTiles[i]);
                effectiveTiles.removeAt(i);
                changed = true;
                break;
              }
              final distHeadToHead =
                  (other.last.row - pHead.row).abs() +
                  (other.last.col - pHead.col).abs();
              if (distHeadToHead == 1) {
                other.addAll(effectiveTiles[i].reversed);
                effectiveTiles.removeAt(i);
                changed = true;
                break;
              }
              final distTailToHead =
                  (other.first.row - pHead.row).abs() +
                  (other.first.col - pHead.col).abs();
              if (distTailToHead == 1) {
                other.insertAll(0, effectiveTiles[i]);
                effectiveTiles.removeAt(i);
                changed = true;
                break;
              }
            }
          }
        }
      }
    }

    // 2. Assign head directions in guaranteed solvable order
    final clearedCells = <Pos>{};
    final remainingTiles = Set<int>.from(
      List.generate(effectiveTiles.length, (i) => i),
    );
    final solutionOrder = <Arrow>[];

    while (remainingTiles.isNotEmpty) {
      final candidates = <_CandidateArrow>[];
      final candidateTileIndices = <int>[];

      for (final tileIdx in remainingTiles) {
        final path = effectiveTiles[tileIdx];

        final orientations = <List<Pos>>[];
        orientations.add(path);
        if (path.length > 1) {
          orientations.add(path.reversed.toList());
        }

        for (final oriented in orientations) {
          final head = oriented.last;
          final Direction? naturalDir;
          if (oriented.length > 1) {
            final prev = oriented[oriented.length - 2];
            final delta = Point(head.row - prev.row, head.col - prev.col);
            naturalDir = DirectionDelta.fromDelta(delta);
          } else {
            naturalDir = null;
          }

          // Multi-cell arrows must strictly follow the natural path direction
          // so arrows are always straight or cleanly curved, never with awkward kinks.
          final allowedDirections = naturalDir != null
              ? [naturalDir]
              : Direction.values;

          for (final dir in allowedDirections) {
            Pos p = head;
            bool canExit = true;
            while (true) {
              p = p.step(dir);
              if (p.row < 0 || p.row >= rows || p.col < 0 || p.col >= cols) {
                break;
              }
              if (activeCells != null && !activeCells.contains(p)) {
                continue; // free space outside the designed shape!
              }
              if (!clearedCells.contains(p)) {
                canExit = false;
                break;
              }
            }

            if (canExit) {
              candidates.add(_CandidateArrow(oriented, dir, true));
              candidateTileIndices.add(tileIdx);
            }
          }
        }
      }

      if (candidates.isEmpty) {
        return null; // Stuck, retry with new tiling pass
      }

      final choice = _rng.nextInt(candidates.length);
      final chosen = candidates[choice];
      final chosenTileIdx = candidateTileIndices[choice];

      remainingTiles.remove(chosenTileIdx);
      clearedCells.addAll(chosen.path);
      solutionOrder.add(
        Arrow(path: chosen.path, headDirection: chosen.headDirection),
      );
    }

    return Board(
      rows: rows,
      cols: cols,
      arrows: List.of(solutionOrder),
      solutionOrder: solutionOrder,
      activeCells: activeCells,
      shapeName: shapeName,
    );
  }

  Board? _attemptGenerate(
    int rows,
    int cols,
    int arrowCount,
    int maxArrowLength,
    int maxAttemptsPerArrow,
  ) {
    // occupied tracks cells taken by arrows built SO FAR in this
    // construction pass (i.e. arrows that will still be on the board when
    // the current one is cleared).
    final occupied = <Pos>{};
    final builtReversed = <Arrow>[]; // build order == reverse clear order

    for (int i = 0; i < arrowCount; i++) {
      final arrow = _tryBuildOneArrow(
        rows,
        cols,
        occupied,
        maxArrowLength,
        maxAttemptsPerArrow,
      );
      if (arrow == null) return null; // this pass failed, caller retries
      occupied.addAll(arrow.path);
      builtReversed.add(arrow);
    }

    // builtReversed[0] was placed first == cleared LAST.
    // Reverse it so solutionOrder[0] is cleared FIRST.
    final solutionOrder = builtReversed.reversed.toList();

    return Board(
      rows: rows,
      cols: cols,
      arrows: List.of(builtReversed),
      solutionOrder: solutionOrder,
    );
  }

  Arrow? _tryBuildOneArrow(
    int rows,
    int cols,
    Set<Pos> occupied,
    int maxArrowLength,
    int maxAttempts,
  ) {
    final freeCells = <Pos>[
      for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
          if (!occupied.contains(Pos(r, c))) Pos(r, c),
    ];
    if (freeCells.isEmpty) return null;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final start = freeCells[_rng.nextInt(freeCells.length)];
      final targetLen = 1 + _rng.nextInt(maxArrowLength);
      final path = _randomWalk(start, targetLen, occupied, rows, cols);
      if (path == null) continue;

      final headDir = _chooseHeadDirection(path, occupied, rows, cols);
      if (headDir == null) continue;

      return Arrow(path: path, headDirection: headDir);
    }
    return null;
  }

  /// Random-walks a contiguous, non-self-intersecting path of up to
  /// [targetLen] cells starting at [start], avoiding already-occupied
  /// cells. Returns fewer cells than targetLen if it gets stuck early
  /// (still a valid, shorter arrow) or null only if even a single cell
  /// isn't usable (shouldn't happen since start is free).
  List<Pos>? _randomWalk(
    Pos start,
    int targetLen,
    Set<Pos> occupied,
    int rows,
    int cols,
  ) {
    final path = <Pos>[start];
    final visited = <Pos>{start};

    while (path.length < targetLen) {
      final current = path.last;
      final options =
          Direction.values
              .map((d) => current.step(d))
              .where(
                (p) =>
                    p.row >= 0 &&
                    p.row < rows &&
                    p.col >= 0 &&
                    p.col < cols &&
                    !occupied.contains(p) &&
                    !visited.contains(p),
              )
              .toList()
            ..shuffle(_rng);

      if (options.isEmpty) break; // stop early; shorter arrow is fine
      path.add(options.first);
      visited.add(options.first);
    }
    return path;
  }

  /// Picks a head direction whose forward path (beyond the last path cell)
  /// is clear of currently-occupied cells. If the arrow is length 1, any
  /// of the 4 directions may work; if length > 1, we still allow any
  /// direction (the head doesn't have to continue the walk's direction),
  /// which is what lets the visual style bend right at the tip too.
  Direction? _chooseHeadDirection(
    List<Pos> path,
    Set<Pos> occupied,
    int rows,
    int cols,
  ) {
    final head = path.last;
    bool isValid(Direction d) {
      Pos p = head;
      while (true) {
        p = p.step(d);
        if (p.row < 0 || p.row >= rows || p.col < 0 || p.col >= cols) {
          return true;
        }
        if (occupied.contains(p) || path.contains(p)) return false;
      }
    }

    // Multi-cell arrows must strictly continue their natural incoming direction
    // so arrows are always smooth and straight, never with awkward kinks.
    if (path.length > 1) {
      final prev = path[path.length - 2];
      final naturalDelta = Point(head.row - prev.row, head.col - prev.col);
      final naturalDir = DirectionDelta.fromDelta(naturalDelta);
      if (naturalDir != null && isValid(naturalDir)) return naturalDir;
      return null;
    }

    final valid = Direction.values.where(isValid).toList();
    if (valid.isEmpty) return null;
    return valid[_rng.nextInt(valid.length)];
  }
}

class LevelScore {
  int heartsLost = 0;
  void registerBlockedTap() => heartsLost++;
  bool get isFailed => heartsLost >= 3;
  int get stars =>
      heartsLost == 0 ? 3 : (heartsLost == 1 ? 2 : (heartsLost == 2 ? 1 : 0));
  String get rating {
    if (heartsLost == 0) return 'Perfect';
    if (heartsLost == 1) return 'Great';
    return 'Cleared';
  }
}

class _CandidateArrow {
  final List<Pos> path;
  final Direction headDirection;
  final bool isNatural;
  _CandidateArrow(this.path, this.headDirection, this.isNatural);
}

class LevelConfig {
  final int levelNumber;
  final int rows;
  final int cols;
  final int maxArrowLength;
  final int seed;
  final BoardShape shape;

  const LevelConfig({
    required this.levelNumber,
    required this.rows,
    required this.cols,
    this.maxArrowLength = 4,
    required this.seed,
    required this.shape,
  });

  /// Designed board shapes progression:
  /// Each level generates an iconic designed shape (Cross, Frame, Stairs, Diamond, Heart, Hourglass, Shield, Crown, etc.)
  static LevelConfig forLevel(int level) {
    final lvl = level.clamp(1, 9999);
    final shape = BoardShape.forLevel(lvl);
    final maxLen = lvl <= 2 ? 5 : (lvl <= 5 ? 5 : 6);
    final seedVal = lvl * 101 + 7;

    return LevelConfig(
      levelNumber: lvl,
      rows: shape.rows,
      cols: shape.cols,
      maxArrowLength: maxLen,
      seed: seedVal,
      shape: shape,
    );
  }
}

/// Represents a distinct handcrafted/designed board shape silhouette.
class BoardShape {
  final String name;
  final int rows;
  final int cols;
  final Set<Pos> activeCells;

  const BoardShape({
    required this.name,
    required this.rows,
    required this.cols,
    required this.activeCells,
  });

  bool contains(Pos p) => activeCells.contains(p);

  static BoardShape fromAscii(String name, List<String> asciiGrid) {
    final rows = asciiGrid.length;
    final cols = asciiGrid[0].length;
    final active = <Pos>{};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < asciiGrid[r].length; c++) {
        if (asciiGrid[r][c] == '#' ||
            asciiGrid[r][c] == 'X' ||
            asciiGrid[r][c] == '1') {
          active.add(Pos(r, c));
        }
      }
    }
    return BoardShape(name: name, rows: rows, cols: cols, activeCells: active);
  }

  /// Procedurally generates a unique, connected random board shape design
  /// (4-way radial symmetry, bilateral vertical emblems, geometric frames/cutouts, or stepped clusters).
  static BoardShape generateProcedural(int level, {Random? rng}) {
    final rand = rng ?? Random(level * 7919 + 31);
    final size = level <= 1 ? 18 : (level <= 3 ? 20 : 22);
    final rows = size;
    final cols = size;

    final style = rand.nextInt(4);
    final active = <Pos>{};

    void addCell(int r, int c) {
      if (r >= 0 && r < rows && c >= 0 && c < cols) {
        active.add(Pos(r, c));
      }
    }

    if (style == 0) {
      // 4-way radial symmetry (Diamond / Mandala / Crystal)
      final midR = rows ~/ 2;
      final midC = cols ~/ 2;
      final rDistMax = max(1, midR);
      final cDistMax = max(1, midC);

      for (int r = 0; r <= midR; r++) {
        for (int c = 0; c <= midC; c++) {
          final dist = (r / rDistMax) + (c / cDistMax);
          if (dist <= 1.25) {
            addCell(midR + r, midC + c);
            addCell(midR - r, midC + c);
            addCell(midR + r, midC - c);
            addCell(midR - r, midC - c);
          }
        }
      }
    } else if (style == 1) {
      // Bilateral vertical symmetry (Emblem / Shield / Totem)
      final midC = cols ~/ 2;
      for (int r = 1; r < rows - 1; r++) {
        final width = 2 + rand.nextInt(max(2, midC - 1));
        for (int c = 0; c <= width; c++) {
          addCell(r, midC + c);
          addCell(r, midC - c);
        }
      }
    } else if (style == 2) {
      // Concentric geometric frame / fortress / donut
      final outerBorder = rows >= 18 ? 3 : 2;
      final innerStart = rows >= 18 ? 6 : 4;
      final innerEnd = rows - 1 - innerStart;
      for (int r = 1; r < rows - 1; r++) {
        for (int c = 1; c < cols - 1; c++) {
          final isOuterBorder =
              r <= outerBorder ||
              r >= rows - 1 - outerBorder ||
              c <= outerBorder ||
              c >= cols - 1 - outerBorder;
          final isInnerRing =
              (r >= innerStart &&
                  r <= innerEnd &&
                  c >= innerStart &&
                  c <= innerEnd) &&
              (r <= innerStart + 1 ||
                  r >= innerEnd - 1 ||
                  c <= innerStart + 1 ||
                  c >= innerEnd - 1);
          final isCrossbar =
              (r == rows ~/ 2 ||
              r == rows ~/ 2 - 1 ||
              c == cols ~/ 2 ||
              c == cols ~/ 2 - 1);
          if (isOuterBorder || isInnerRing || isCrossbar) {
            addCell(r, c);
          }
        }
      }
    } else {
      // Stepped pyramid / mountain silhouette
      final midC = cols ~/ 2;
      for (int r = 1; r < rows - 1; r++) {
        final span = (r <= rows ~/ 2) ? r : (rows - 1 - r);
        for (
          int c = max(0, midC - span);
          c <= min(cols - 1, midC + span);
          c++
        ) {
          addCell(r, c);
        }
      }
    }

    // Ensure connectivity and a solid core
    final midR = rows ~/ 2;
    final midC = cols ~/ 2;
    final coreR = rows >= 18 ? 2 : 1;
    for (int dr = -coreR; dr <= coreR; dr++) {
      for (int dc = -coreR; dc <= coreR; dc++) {
        addCell(midR + dr, midC + dc);
      }
    }

    // Prune any isolated cells that have fewer than 2 orthogonal neighbors
    // to guarantee no stranded single-cell islands or sharp isolated pixels exist.
    bool pruned = true;
    while (pruned) {
      pruned = false;
      final toRemove = <Pos>[];
      for (final p in active) {
        int neighbors = 0;
        if (active.contains(Pos(p.row - 1, p.col))) neighbors++;
        if (active.contains(Pos(p.row + 1, p.col))) neighbors++;
        if (active.contains(Pos(p.row, p.col - 1))) neighbors++;
        if (active.contains(Pos(p.row, p.col + 1))) neighbors++;
        if (neighbors < 2) {
          toRemove.add(p);
        }
      }
      if (toRemove.isNotEmpty) {
        active.removeAll(toRemove);
        pruned = true;
      }
    }

    final names = [
      'Emblem',
      'Mandala',
      'Crest',
      'Matrix',
      'Nexus',
      'Vortex',
      'Prism',
      'Orbit',
      'Pulse',
      'Apex',
      'Labyrinth',
      'Constellation',
    ];
    final name = names[rand.nextInt(names.length)];

    return BoardShape(name: name, rows: rows, cols: cols, activeCells: active);
  }

  static BoardShape forLevel(int level) {
    if (level > 0) {
      return generateProcedural(level);
    }
    switch (level) {
      case 1:
        return BoardShape.fromAscii('Cross', [
          '..#..',
          '..#..',
          '#####',
          '..#..',
          '..#..',
        ]);
      case 2:
        return BoardShape.fromAscii('Frame', [
          '#####',
          '#...#',
          '#...#',
          '#...#',
          '#####',
        ]);
      case 3:
        return BoardShape.fromAscii('Stairs', [
          '..##..',
          '..##..',
          '.####.',
          '.####.',
          '######',
          '######',
        ]);
      case 4:
        return BoardShape.fromAscii('Diamond', [
          '...#...',
          '..###..',
          '.#####.',
          '#######',
          '.#####.',
          '..###..',
          '...#...',
        ]);
      case 5:
        return BoardShape.fromAscii('Heart', [
          '.##.##.',
          '#######',
          '#######',
          '.#####.',
          '..###..',
          '...#...',
          '.......',
        ]);
      case 6:
        return BoardShape.fromAscii('Hourglass', [
          '#######',
          '.#####.',
          '..###..',
          '...#...',
          '..###..',
          '.#####.',
          '#######',
        ]);
      case 7:
        return BoardShape.fromAscii('Shield', [
          '.######.',
          '########',
          '########',
          '########',
          '.######.',
          '..####..',
          '...##...',
          '....#...',
        ]);
      case 8:
        return BoardShape.fromAscii('Crown', [
          '#..#..#.',
          '#..#..#.',
          '.######.',
          '########',
          '########',
          '..####..',
          '........',
        ]);
      case 9:
        return BoardShape.fromAscii('Donut', [
          '..####..',
          '.######.',
          '##....##',
          '##....##',
          '##....##',
          '##....##',
          '.######.',
          '..####..',
        ]);
      case 10:
        return BoardShape.fromAscii('Star', [
          '....#....',
          '...###...',
          '..#####..',
          '.#######.',
          '#########',
          '.#######.',
          '..#####..',
          '...###...',
          '....#....',
        ]);
      case 11:
        return BoardShape.fromAscii('Butterfly', [
          '##.....##',
          '###...###',
          '####.####',
          '.#######.',
          '...###...',
          '.#######.',
          '####.####',
          '###...###',
          '##.....##',
        ]);
      case 12:
      default:
        return BoardShape.fromAscii('Castle', [
          '#.#...#.#.',
          '###...###.',
          '#########.',
          '#########.',
          '.#######..',
          '.#######..',
          '.#######..',
          '#########.',
          '#########.',
          '..........',
        ]);
    }
  }
}

/// Tracks progression and unlocked levels.
/// Levels start with only Level 1 unlocked. Subsequent levels unlock
/// sequentially as the player clears previous levels.
class LevelProgress {
  static int highestUnlockedLevel = 1;

  /// True if [level] is unlocked and accessible to play.
  static bool isUnlocked(int level) => level <= highestUnlockedLevel;

  /// Call when [level] is cleared to unlock the next level.
  static void completeLevel(int level) {
    if (level >= highestUnlockedLevel) {
      highestUnlockedLevel = level + 1;
    }
  }

  /// Resets progression back to Level 1 unlocked.
  static void reset() {
    highestUnlockedLevel = 1;
  }
}
