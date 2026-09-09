// grid_line_painter.dart
//
// Draws the grid lines behind the puzzle board (like a tic-tac-toe style
// grid). Use this as a background layer inside the Stack, underneath the
// arrow tiles from arrow_puzzle_board.dart.
//
// Usage inside ArrowPuzzleScreen's Stack:
//
//   Stack(
//     children: [
//       CustomPaint(
//         size: Size(boardWidth, boardHeight),
//         painter: GridLinePainter(
//           rows: _board.rows,
//           cols: _board.cols,
//           cellSize: cellSize,
//         ),
//       ),
//       // ...arrow tiles go here, on top...
//     ],
//   )

import 'package:flutter/material.dart';

class GridLinePainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;
  final Color lineColor;
  final double lineWidth;
  final Color? backgroundColor;

  GridLinePainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    this.lineColor = const Color(0x33000000), // soft translucent black
    this.lineWidth = 1.5,
    this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = cols * cellSize;
    final height = rows * cellSize;

    if (backgroundColor != null) {
      final bgPaint = Paint()..color = backgroundColor!;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Vertical lines: cols + 1 of them (including both outer edges).
    for (int c = 0; c <= cols; c++) {
      final x = c * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, height), linePaint);
    }

    // Horizontal lines: rows + 1 of them.
    for (int r = 0; r <= rows; r++) {
      final y = r * cellSize;
      canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);
    }

    // Slightly thicker outer border so the board reads as a contained unit.
    final borderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth * 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant GridLinePainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}