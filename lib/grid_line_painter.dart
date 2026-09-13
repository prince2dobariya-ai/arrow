import 'package:flutter/material.dart';
import 'core.dart' show Arrow, Direction;

/// Custom painter for the "Arrow Grid" feature.
///
/// When toggled on, it renders faint directional guide lines projecting outward
/// from the arrowheads of all arrows all the way to the screen edges.
class ArrowGridPainter extends CustomPainter {
  final List<Arrow> arrows;
  final bool Function(Arrow arrow)? isPathClear;
  final double cellSize;
  final double boardWidth;
  final double boardHeight;
  final double progress;
  final Color lineColor;
  final double lineWidth;
  final double extendDistance;

  ArrowGridPainter({
    required this.arrows,
    this.isPathClear,
    required this.cellSize,
    required this.boardWidth,
    required this.boardHeight,
    this.progress = 1.0,
    this.lineColor = const Color(0x383D4877),
    this.lineWidth = 1.8,
    this.extendDistance = 4000.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || arrows.isEmpty) return;

    final effectiveColor = lineColor.withValues(
      alpha: lineColor.a * progress.clamp(0.0, 1.0),
    );

    final linePaint = Paint()
      ..color = effectiveColor
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final arrow in arrows) {
      final headX = arrow.head.col * cellSize + cellSize / 2;
      final headY = arrow.head.row * cellSize + cellSize / 2;
      final start = Offset(headX, headY);

      final Offset end;
      switch (arrow.headDirection) {
        case Direction.up:
          end = Offset(headX, headY - extendDistance);
          break;
        case Direction.down:
          end = Offset(headX, headY + extendDistance);
          break;
        case Direction.left:
          end = Offset(headX - extendDistance, headY);
          break;
        case Direction.right:
          end = Offset(headX + extendDistance, headY);
          break;
      }

      canvas.drawLine(start, end, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ArrowGridPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.arrows != arrows ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.boardWidth != boardWidth ||
        oldDelegate.boardHeight != boardHeight ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineWidth != lineWidth;
  }
}