// arrow_path_painter.dart
//
// Renders the "bent path" arrow style shown in the reference screenshot:
// a thick rounded stroke that snakes through several cells via 90-degree
// turns and ends in a triangular arrowhead, drawn over a dotted-grid
// background.
//
// This implies a data model change from arrow_puzzle_core.dart: instead of
// one Arrow occupying exactly one cell with a single Direction, an arrow is
// now a PATH occupying a list of cells (an ordered list of Pos), with the
// arrowhead at the last point. See the model note at the bottom of this
// file for how that plugs into Board/LevelGenerator.

import 'package:flutter/material.dart';
import 'dart:math';
import 'core.dart' show Direction, Pos;

/// ---------- Dotted grid background ----------

class DottedGridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;
  final Color dotColor;
  final double dotRadius;
  final Set<Pos>? activeCells;
  final Set<Pos>? occupiedCells;
  final double progress;

  DottedGridPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    this.dotColor = Colors.grey,
    double? dotRadius,
    this.activeCells,
    this.occupiedCells,
    this.progress = 1.0,
  }) : dotRadius = dotRadius ?? (cellSize * 0.045).clamp(1.0, 1.8);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final dotPaint = Paint()..color = dotColor;
    final centerR = rows / 2.0;
    final centerC = cols / 2.0;
    final maxDist = sqrt(centerR * centerR + centerC * centerC);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final pos = Pos(r, c);
        if (activeCells != null && !activeCells!.contains(pos)) {
          continue;
        }
        // As long as an arrow occupies this cell, do NOT paint the dot underneath it
        if (occupiedCells != null && occupiedCells!.contains(pos)) {
          continue;
        }

        double currentDotRadius = dotRadius;
        Paint currentDotPaint = dotPaint;

        if (progress < 1.0) {
          final dist = sqrt(
            pow(r + 0.5 - centerR, 2) + pow(c + 0.5 - centerC, 2),
          );
          final normDist = (dist / max(1.0, maxDist)).clamp(0.0, 1.0);
          final dotProgress = ((progress - normDist * 0.35) / 0.65).clamp(
            0.0,
            1.0,
          );
          if (dotProgress <= 0.0) continue;

          currentDotRadius = dotRadius * dotProgress;
          currentDotPaint = Paint()
            ..color = dotColor.withValues(alpha: dotColor.a * dotProgress);
        }

        final center = Offset(
          c * cellSize + cellSize / 2,
          r * cellSize + cellSize / 2,
        );
        canvas.drawCircle(center, currentDotRadius, currentDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DottedGridPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.activeCells != activeCells ||
        oldDelegate.occupiedCells != occupiedCells ||
        oldDelegate.progress != progress;
  }
}

/// ---------- Bent-path arrow ----------

/// Paints a single arrow as a rounded polyline through [points]
/// (pixel-space, already converted from grid cells) with an arrowhead
/// at the final point, oriented along [headDirection] — always, even if
/// that differs from the path's geometric last-segment direction.
class ArrowPathPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double? strokeWidth;
  final double? arrowHeadLength;
  final double? arrowHeadWidth;
  final double cellSize;
  final bool isHinted;

  /// The arrow's logical facing direction (Arrow.headDirection). This is
  /// now ALWAYS what determines the drawn arrowhead's direction — see the
  /// note in paint() for why we don't fall back to path geometry.
  final Direction headDirection;

  final double progress;

  ArrowPathPainter({
    required this.points,
    required this.headDirection,
    this.cellSize = 32.0,
    this.color = const Color(0xFF1A1A2E),
    this.strokeWidth,
    this.arrowHeadLength,
    this.arrowHeadWidth,
    this.isHinted = false,
    this.progress = 1.0,
  }) : assert(points.isNotEmpty, 'An arrow path needs at least 1 point');

  @override
  void paint(Canvas canvas, Size size) {
    // headDirection is now ALWAYS the source of truth for which way the
    // arrowhead points and — critically — which way the exit animation
    // will move it. We never derive direction from path geometry, because
    // the generator can pick a headDirection independent of the path's
    // final segment (that's what lets it bend right at the tip). Using
    // geometry there would make the drawn arrow point one way while the
    // game moves it another.
    final dirNorm = _unitOffsetFor(headDirection);
    final effectiveCell = cellSize > 0 ? cellSize : 32.0;

    // UNIFORM styling across ALL arrows on the board:
    // Every arrow (single-cell or multi-cell) shares the exact same
    final effStroke = strokeWidth ?? (effectiveCell * 0.145).clamp(3.2, 6.5);
    final effHeadLen =
        arrowHeadLength ?? (effectiveCell * 0.33).clamp(8.0, 17.0);
    final effHeadWid =
        arrowHeadWidth ?? (effectiveCell * 0.42).clamp(10.5, 22.0);
    final filletRadius = (effectiveCell * 0.34).clamp(3.5, 10.5);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = effStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length == 1) {
      final totalLength = (effectiveCell * 0.74).clamp(14.0, 36.0);
      final center = points.first;
      final tip = center + dirNorm * (totalLength * 0.5);
      final baseCenter = tip - dirNorm * effHeadLen;
      final tail = center - dirNorm * (totalLength * 0.5);

      if (progress >= 1.0) {
        if (isHinted) {
          final glowPaint = Paint()
            ..color = const Color(0xFFFFB703).withValues(alpha: 0.55)
            ..strokeWidth = effStroke * 2.6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
          canvas.drawLine(tail, baseCenter, glowPaint);
          _drawArrowHead(
            canvas,
            tip: tip,
            direction: dirNorm,
            length: effHeadLen,
            width: effHeadWid,
            customPaint: glowPaint,
          );
        }

        // Draw straight shaft from tail to base of triangle
        canvas.drawLine(tail, baseCenter, linePaint);
        _drawArrowHead(
          canvas,
          tip: tip,
          direction: dirNorm,
          length: effHeadLen,
          width: effHeadWid,
        );
        return;
      }

      if (progress <= 0.0) return;

      final curHeadScale = (progress / 0.35).clamp(0.0, 1.0);
      final curHeadLen = effHeadLen * curHeadScale;
      final curHeadWid = effHeadWid * curHeadScale;

      final curShaftEnd = tail + (baseCenter - tail) * progress;
      final curTip = curShaftEnd + dirNorm * curHeadLen;

      if ((curShaftEnd - tail).distance > 0.5) {
        canvas.drawLine(tail, curShaftEnd, linePaint);
      }
      if (curHeadScale > 0.05) {
        _drawArrowHead(
          canvas,
          tip: curTip,
          direction: dirNorm,
          length: curHeadLen,
          width: curHeadWid,
        );
      }
      return;
    }

    final last = points.last;
    final secondLast = points[points.length - 2];
    final geomDelta = last - secondLast;
    final geomDir = geomDelta.distance == 0
        ? dirNorm
        : geomDelta / geomDelta.distance;

    final sameDirection =
        (geomDir.dx - dirNorm.dx).abs() < 0.01 &&
        (geomDir.dy - dirNorm.dy).abs() < 0.01;

    final Offset tip;
    final Offset baseCenter;
    final List<Offset> shaftPoints;

    if (sameDirection) {
      tip = last + dirNorm * (effectiveCell * 0.32);
      baseCenter = tip - dirNorm * effHeadLen;
      shaftPoints = List<Offset>.from(points);
      shaftPoints[shaftPoints.length - 1] = baseCenter;
    } else {
      final stubTip = last + dirNorm * (effectiveCell * 0.32);
      tip = stubTip;
      baseCenter = tip - dirNorm * effHeadLen;
      shaftPoints = List<Offset>.from(points)..add(baseCenter);
    }

    final path = _buildFilletedPath(shaftPoints, filletRadius);

    if (progress >= 1.0) {
      if (isHinted) {
        final glowPaint = Paint()
          ..color = const Color(0xFFFFB703).withValues(alpha: 0.55)
          ..strokeWidth = effStroke * 2.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, glowPaint);
        _drawArrowHead(
          canvas,
          tip: tip,
          direction: dirNorm,
          length: effHeadLen,
          width: effHeadWid,
          customPaint: glowPaint,
        );
      }

      canvas.drawPath(path, linePaint);
      _drawArrowHead(
        canvas,
        tip: tip,
        direction: dirNorm,
        length: effHeadLen,
        width: effHeadWid,
      );
      return;
    }

    if (progress <= 0.0) return;

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final totalLen = metric.length;
    final currentLen = totalLen * progress.clamp(0.0, 1.0);
    final drawnPath = metric.extractPath(0.0, currentLen);

    canvas.drawPath(drawnPath, linePaint);

    final headScale = (progress / 0.3).clamp(0.0, 1.0);
    if (headScale > 0.05) {
      final tangent = metric.getTangentForOffset(currentLen);
      if (tangent != null) {
        final blend = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);
        final tDir = tangent.vector;
        final blendedDir = tDir * (1.0 - blend) + dirNorm * blend;
        final forwardDir = blendedDir.distance == 0
            ? dirNorm
            : blendedDir / blendedDir.distance;

        final currentTip =
            tangent.position + forwardDir * (effHeadLen * headScale);

        _drawArrowHead(
          canvas,
          tip: currentTip,
          direction: forwardDir,
          length: effHeadLen * headScale,
          width: effHeadWid * headScale,
        );
      }
    }
  }

  Offset _unitOffsetFor(Direction d) {
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

  /// Builds a smooth polyline where each 90-degree corner bend is replaced
  /// with a rounded fillet arc (quadratic bezier).
  Path _buildFilletedPath(List<Offset> pts, double radius) {
    final path = Path();
    if (pts.isEmpty) return path;
    if (pts.length == 1) {
      path.moveTo(pts[0].dx, pts[0].dy);
      return path;
    }

    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 1; i < pts.length - 1; i++) {
      final prev = pts[i - 1];
      final cur = pts[i];
      final next = pts[i + 1];

      final d1 = cur - prev;
      final d2 = next - cur;
      final len1 = d1.distance;
      final len2 = d2.distance;

      if (len1 < 0.001 || len2 < 0.001) {
        path.lineTo(cur.dx, cur.dy);
        continue;
      }

      final v1 = d1 / len1;
      final v2 = d2 / len2;

      // Check if straight continuation
      if ((v1.dx - v2.dx).abs() < 0.01 && (v1.dy - v2.dy).abs() < 0.01) {
        path.lineTo(cur.dx, cur.dy);
        continue;
      }

      // 90-degree turn: smooth fillet
      final r = min(radius, min(len1 * 0.45, len2 * 0.45));
      final startFillet = cur - v1 * r;
      final endFillet = cur + v2 * r;

      path.lineTo(startFillet.dx, startFillet.dy);
      path.quadraticBezierTo(cur.dx, cur.dy, endFillet.dx, endFillet.dy);
    }

    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// Draws the solid filled triangular arrowhead matching the reference image.
  void _drawArrowHead(
    Canvas canvas, {
    required Offset tip,
    required Offset direction,
    double? length,
    double? width,
    Paint? customPaint,
  }) {
    final headLen = length ?? (arrowHeadLength ?? 10.0);
    final headWid = width ?? (arrowHeadWidth ?? 13.0);

    // Perpendicular vector for the triangle base
    final perp = Offset(-direction.dy, direction.dx);
    final baseCenter = tip - direction * headLen;
    final cornerLeft = baseCenter + perp * (headWid / 2);
    final cornerRight = baseCenter - perp * (headWid / 2);

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(cornerLeft.dx, cornerLeft.dy)
      ..lineTo(cornerRight.dx, cornerRight.dy)
      ..close();

    if (customPaint != null) {
      canvas.drawPath(headPath, customPaint);
      final fillPaint = Paint()
        ..color = customPaint.color.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;
      canvas.drawPath(headPath, fillPaint);
    } else {
      final headPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(headPath, headPaint);
    }
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final vx = b.dx - a.dx;
    final vy = b.dy - a.dy;
    final wx = p.dx - a.dx;
    final wy = p.dy - a.dy;
    final c1 = wx * vx + wy * vy;
    if (c1 <= 0) return (p - a).distance;
    final c2 = vx * vx + vy * vy;
    if (c2 <= c1) return (p - b).distance;
    final b1 = c1 / c2;
    final pb = Offset(a.dx + b1 * vx, a.dy + b1 * vy);
    return (p - pb).distance;
  }

  @override
  bool? hitTest(Offset position) {
    final effectiveCell = cellSize > 0 ? cellSize : 32.0;
    final dirNorm = _unitOffsetFor(headDirection);
    final effHeadLen =
        arrowHeadLength ?? (effectiveCell * 0.33).clamp(8.0, 17.0);
    final effHeadWid =
        arrowHeadWidth ?? (effectiveCell * 0.42).clamp(10.5, 22.0);
    // Hit radius ensures tap is directly on the arrow shaft or head,
    // covering the cell thickness while rejecting empty grid cells.
    final hitRadius = max(effHeadWid * 1.1, effectiveCell * 0.55);

    if (points.length == 1) {
      final totalLength = (effectiveCell * 0.74).clamp(14.0, 36.0);
      final center = points.first;
      final tip = center + dirNorm * (totalLength * 0.5);
      final baseCenter = tip - dirNorm * effHeadLen;
      final tail = center - dirNorm * (totalLength * 0.5);
      final perp = Offset(-dirNorm.dy, dirNorm.dx);
      final cornerLeft = baseCenter + perp * (effHeadWid / 2);
      final cornerRight = baseCenter - perp * (effHeadWid / 2);

      if (_distToSegment(position, tail, baseCenter) <= hitRadius) {
        return true;
      }
      if (_distToSegment(position, baseCenter, tip) <= hitRadius) {
        return true;
      }
      if (_distToSegment(position, tip, cornerLeft) <= hitRadius ||
          _distToSegment(position, tip, cornerRight) <= hitRadius ||
          _distToSegment(position, cornerLeft, cornerRight) <= hitRadius) {
        return true;
      }
      return false;
    }

    // Multi-cell arrow shaft segments:
    for (int i = 0; i < points.length - 1; i++) {
      if (_distToSegment(position, points[i], points[i + 1]) <= hitRadius) {
        return true;
      }
    }

    final last = points.last;
    final tip = last + dirNorm * (effectiveCell * 0.32);
    final baseCenter = tip - dirNorm * effHeadLen;
    final perp = Offset(-dirNorm.dy, dirNorm.dx);
    final cornerLeft = baseCenter + perp * (effHeadWid / 2);
    final cornerRight = baseCenter - perp * (effHeadWid / 2);

    if (_distToSegment(position, last, tip) <= hitRadius) {
      return true;
    }
    if (_distToSegment(position, tip, cornerLeft) <= hitRadius ||
        _distToSegment(position, tip, cornerRight) <= hitRadius ||
        _distToSegment(position, cornerLeft, cornerRight) <= hitRadius) {
      return true;
    }

    return false;
  }

  @override
  bool shouldRepaint(covariant ArrowPathPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.headDirection != headDirection ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.arrowHeadLength != arrowHeadLength ||
        oldDelegate.arrowHeadWidth != arrowHeadWidth ||
        oldDelegate.isHinted != isHinted ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.progress != progress;
  }
}

/// ---------- Widget wrapper ----------

/// Convenience widget: give it a list of grid cells (row, col) the arrow's
/// path occupies, in order from tail to head, plus the cellSize, and it
/// paints the bent-path arrow centered within those cells.
class ArrowPathWidget extends StatelessWidget {
  final List<Point<int>> cellPath; // (row, col) pairs, tail-to-head
  final double cellSize;
  final Color color;
  final bool isHinted;

  /// The arrow's overall facing direction (Arrow.headDirection from the
  /// core model). Always drives the arrowhead's drawn direction — this
  /// must match whatever direction you move the arrow on tap.
  final Direction headDirection;
  final double progress;
  final double padding;

  const ArrowPathWidget({
    super.key,
    required this.cellPath,
    required this.cellSize,
    required this.headDirection,
    this.color = const Color(0xFF1A1A2E),
    this.isHinted = false,
    this.progress = 1.0,
    this.padding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final points = cellPath
        .map(
          (p) => Offset(
            p.y * cellSize + cellSize / 2 + padding,
            p.x * cellSize + cellSize / 2 + padding,
          ),
        )
        .toList();

    return CustomPaint(
      painter: ArrowPathPainter(
        points: points,
        color: color,
        headDirection: headDirection,
        cellSize: cellSize,
        isHinted: isHinted,
        progress: progress,
      ),
    );
  }
}

/// ---------- Model note ----------
//
// To support this visual style, arrow_puzzle_core.dart's `Arrow` class
// should change from:
//
//   class Arrow { final Direction direction; }
//
// to something like:
//
//   class Arrow {
//     final List<Pos> path; // tail-to-head, must be orthogonally
//                           // contiguous (each step moves exactly one
//                           // cell up/down/left/right)
//     Direction get headDirection => ...; // derived from the last two
//                                          // points in `path`
//   }
//
// And Board.pathIsClear(p) needs to check that:
//   1. All cells in the arrow's own path are unobstructed by OTHER arrows
//      (an arrow can't overlap another arrow's cells at generation time),
//      and
//   2. The path extending forward from the head, in headDirection, is
//      clear all the way to the board edge.
//
// The LevelGenerator's reverse-construction idea still works, but instead
// of placing one Direction per cell, you'd grow a random walk of length
// 1-4 cells per arrow (respecting already-occupied cells) and only need
// the FINAL step's direction to have a clear forward path at build time.
