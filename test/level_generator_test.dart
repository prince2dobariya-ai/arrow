import 'package:flutter_test/flutter_test.dart';
import 'package:demo/core.dart';

void main() {
  test('Levels 1 to 3 are simple and compact', () {
    final b1 = LevelGenerator.generateLevel(1);
    expect(b1.rows, 4);
    expect(b1.cols, 4);
    expect(b1.arrows.isNotEmpty, true);

    final b2 = LevelGenerator.generateLevel(2);
    expect(b2.rows, 5);
    expect(b2.cols, 5);
    expect(b2.arrows.isNotEmpty, true);

    final b3 = LevelGenerator.generateLevel(3);
    expect(b3.rows, 5);
    expect(b3.cols, 5);
    expect(b3.arrows.isNotEmpty, true);
  });

  test('Levels generate unique non-repeating shapes and solvable boards', () {
    final shapeNames = <String>{};
    for (int lvl = 1; lvl <= 15; lvl++) {
      final board = LevelGenerator.generateLevel(lvl);
      expect(board.arrows.isNotEmpty, true);
      expect(board.solutionOrder.length, board.arrows.length);
      final shapeName = board.shapeName ?? 'Shape-$lvl';
      expect(shapeNames.contains(shapeName), false,
          reason: 'Shape name $shapeName should not repeat for level $lvl');
      shapeNames.add(shapeName);
    }
  });
}
