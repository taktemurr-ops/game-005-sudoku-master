import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/game/sudoku_generator.dart';
import 'package:game_005_sudoku_master/game/sudoku_game.dart';

void main() {
  test('daily seed is stable for the same calendar date', () {
    expect(SudokuGenerator.dailySeed(DateTime(2026, 11, 17)), 20261117);
    expect(SudokuGenerator.dailySeed(DateTime(2026, 11, 18)), 20261118);
  });

  test('known solved, contradictory, and ambiguous grids', () {
    final demo = SudokuGame.demo();
    expect(SudokuGenerator.countSolutions(demo.solution), 1);
    final invalid = demo.solution.map((r) => List<int>.from(r)).toList();
    invalid[0][0] = invalid[0][1];
    expect(SudokuGenerator.countSolutions(invalid), 0);
    expect(SudokuGenerator.countSolutions(List.generate(9, (_) => List.filled(9, 0))), 2);
  });

  for (final mode in SudokuDifficulty.values) {
    test('$mode generates valid uniquely solvable reproducible boards', () {
      final a = SudokuGenerator.generate(mode, seed: 10005);
      final b = SudokuGenerator.generate(mode, seed: 10005);
      expect(a.puzzle, b.puzzle);
      expect(a.solution, b.solution);
      expect(SudokuGame.isValidGrid(a.solution), isTrue);
      expect(SudokuGame.isValidGrid(a.puzzle), isTrue);
      expect(SudokuGenerator.countSolutions(a.puzzle, limit: 2), 1);
      final clues = a.puzzle.expand((r) => r).where((v) => v != 0).length;
      expect(clues, inInclusiveRange(17, 81));
      expect(a.puzzle.expand((r) => r).where((v) => v == 0), isNotEmpty);
      final engine = SudokuGame(a.puzzle, a.solution);
      expect(engine.complete, isFalse);
    });
  }
}
