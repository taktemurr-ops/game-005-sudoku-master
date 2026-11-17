import 'dart:math';

/// Five offline difficulties, including a stable daily challenge.
enum SudokuDifficulty { easy, medium, hard, expert, daily }

extension SudokuDifficultyRules on SudokuDifficulty {
  int get targetClues => switch (this) {
        SudokuDifficulty.easy => 40,
        SudokuDifficulty.medium => 34,
        SudokuDifficulty.hard => 30,
        SudokuDifficulty.expert => 26,
        SudokuDifficulty.daily => 32,
      };
}

class GeneratedSudoku {
  final List<List<int>> puzzle;
  final List<List<int>> solution;
  final SudokuDifficulty difficulty;
  final int seed;
  const GeneratedSudoku({required this.puzzle, required this.solution,
      required this.difficulty, required this.seed});
}

/// Generates distinct, valid Sudoku solutions and removes clues only when
/// the puzzle retains exactly one solution. Pure Dart, no network or SDK.
class SudokuGenerator {
  static const int _maxAttempts = 4;

  static int dailySeed(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  static GeneratedSudoku generate(SudokuDifficulty difficulty, {int? seed}) {
    final chosenSeed = seed ?? Random().nextInt(0x7fffffff);
    GeneratedSudoku? best;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final random = Random(chosenSeed + attempt * 100003);
      final solution = _shuffledSolution(random);
      final puzzle = _copy(solution);
      final order = List<int>.generate(81, (i) => i)..shuffle(random);
      var clues = 81;
      for (final index in order) {
        if (clues <= difficulty.targetClues) break;
        final row = index ~/ 9;
        final column = index % 9;
        final previous = puzzle[row][column];
        puzzle[row][column] = 0;
        if (countSolutions(puzzle, limit: 2) != 1) {
          puzzle[row][column] = previous;
        } else {
          clues--;
        }
      }
      final candidate = GeneratedSudoku(puzzle: puzzle, solution: solution,
          difficulty: difficulty, seed: chosenSeed);
      if (best == null || clues < _clueCount(best.puzzle)) best = candidate;
      if (clues <= difficulty.targetClues) break;
    }
    return best!;
  }

  static int _clueCount(List<List<int>> puzzle) =>
      puzzle.expand((row) => row).where((digit) => digit != 0).length;

  static List<List<int>> _copy(List<List<int>> grid) =>
      grid.map((row) => List<int>.from(row)).toList();

  static List<List<int>> _shuffledSolution(Random random) {
    final digits = List<int>.generate(9, (i) => i + 1)..shuffle(random);
    List<int> shuffledGroups() {
      final groups = [0, 1, 2]..shuffle(random);
      return [for (final group in groups)
        ...((List<int>.generate(3, (i) => group * 3 + i))..shuffle(random))];
    }
    final rows = shuffledGroups();
    final columns = shuffledGroups();
    final transpose = random.nextBool();
    return List<List<int>>.generate(9, (r) => List<int>.generate(9, (c) {
      final rr = transpose ? rows[c] : rows[r];
      final cc = transpose ? columns[r] : columns[c];
      return digits[(rr * 3 + rr ~/ 3 + cc) % 9];
    }));
  }

  /// Bounds the search at [limit] solutions; 2 is sufficient for uniqueness.
  /// Minimum-remaining-values selection prevents exponential blowups on typical
  /// game levels and avoids copying grids for each recursion step.
  static int countSolutions(List<List<int>> input, {int limit = 2}) {
    if (limit < 1 || input.length != 9 ||
        input.any((row) => row.length != 9)) return 0;
    final grid = _copy(input);
    final rows = List<int>.filled(9, 0);
    final columns = List<int>.filled(9, 0);
    final boxes = List<int>.filled(9, 0);
    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        final digit = grid[row][column];
        if (digit == 0) continue;
        if (digit < 1 || digit > 9) return 0;
        final mask = 1 << digit;
        final box = row ~/ 3 * 3 + column ~/ 3;
        if (((rows[row] | columns[column] | boxes[box]) & mask) != 0) {
          return 0;
        }
        rows[row] |= mask;
        columns[column] |= mask;
        boxes[box] |= mask;
      }
    }
    var solutions = 0;
    void search() {
      if (solutions >= limit) return;
      var bestRow = -1;
      var bestColumn = -1;
      var bestMask = 0;
      var bestCount = 10;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (grid[r][c] != 0) continue;
          final box = r ~/ 3 * 3 + c ~/ 3;
          final mask = 0x3fe & ~(rows[r] | columns[c] | boxes[box]);
          var count = 0;
          for (var d = 1; d <= 9; d++) {
            if ((mask & (1 << d)) != 0) count++;
          }
          if (count == 0) return;
          if (count < bestCount) {
            bestRow = r;
            bestColumn = c;
            bestMask = mask;
            bestCount = count;
          }
        }
      }
      if (bestRow == -1) {
        solutions++;
        return;
      }
      final box = bestRow ~/ 3 * 3 + bestColumn ~/ 3;
      for (var d = 1; d <= 9 && solutions < limit; d++) {
        final mask = 1 << d;
        if ((bestMask & mask) == 0) continue;
        grid[bestRow][bestColumn] = d;
        rows[bestRow] |= mask;
        columns[bestColumn] |= mask;
        boxes[box] |= mask;
        search();
        grid[bestRow][bestColumn] = 0;
        rows[bestRow] &= ~mask;
        columns[bestColumn] &= ~mask;
        boxes[box] &= ~mask;
      }
    }
    search();
    return solutions;
  }
}
