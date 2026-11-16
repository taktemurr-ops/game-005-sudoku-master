/// Pure Dart Sudoku model. Grid values are 0 (empty) or 1–9.
class SudokuGame {
  final List<List<int>> puzzle;
  final List<List<int>> solution;
  late List<List<int>> board;
  late final List<List<bool>> fixed;
  int mistakes = 0;
  int hintsUsed = 0;

  SudokuGame(this.puzzle, this.solution) {
    for (final grid in [puzzle, solution]) {
      if (grid.length != 9 || grid.any((row) => row.length != 9)) {
        throw ArgumentError('Grid must be 9×9.');
      }
      if (grid.any((row) => row.any((n) => n < 0 || n > 9))) {
        throw ArgumentError('Digits must be 0–9.');
      }
    }
    if (!isValidGrid(solution) || solution.any((r) => r.contains(0))) {
      throw ArgumentError('Solution must be a complete valid Sudoku.');
    }
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (puzzle[r][c] != 0 && puzzle[r][c] != solution[r][c]) {
          throw ArgumentError('Puzzle clue contradicts solution.');
        }
      }
    }
    board = puzzle.map((r) => List<int>.from(r)).toList();
    fixed = puzzle.map((r) => r.map((n) => n != 0).toList()).toList();
  }

  factory SudokuGame.demo() {
    final solution = [
      [5,3,4,6,7,8,9,1,2],
      [6,7,2,1,9,5,3,4,8],
      [1,9,8,3,4,2,5,6,7],
      [8,5,9,7,6,1,4,2,3],
      [4,2,6,8,5,3,7,9,1],
      [7,1,3,9,2,4,8,5,6],
      [9,6,1,5,3,7,2,8,4],
      [2,8,7,4,1,9,6,3,5],
      [3,4,5,2,8,6,1,7,9],
    ];
    final puzzle = [
      [5,3,0,0,7,0,0,0,0],
      [6,0,0,1,9,5,0,0,0],
      [0,9,8,0,0,0,0,6,0],
      [8,0,0,0,6,0,0,0,3],
      [4,0,0,8,0,3,0,0,1],
      [7,0,0,0,2,0,0,0,6],
      [0,6,0,0,0,0,2,8,0],
      [0,0,0,4,1,9,0,0,5],
      [0,0,0,0,8,0,0,7,9],
    ];
    return SudokuGame(puzzle, solution);
  }

  static bool isValidGrid(List<List<int>> grid) {
    if (grid.length != 9 || grid.any((r) => r.length != 9)) return false;
    bool valid(Iterable<int> numbers) {
      final used = <int>{};
      for (final number in numbers) {
        if (number < 0 || number > 9) return false;
        if (number != 0 && !used.add(number)) return false;
      }
      return true;
    }
    for (var i = 0; i < 9; i++) {
      if (!valid(grid[i]) || !valid(List.generate(9, (r) => grid[r][i]))) {
        return false;
      }
    }
    for (var br = 0; br < 9; br += 3) {
      for (var bc = 0; bc < 9; bc += 3) {
        if (!valid([
          for (var dr = 0; dr < 3; dr++)
            for (var dc = 0; dc < 3; dc++) grid[br + dr][bc + dc]
        ])) { return false; }
      }
    }
    return true;
  }

  bool input(int row, int column, int digit) {
    if (row < 0 || row >= 9 || column < 0 || column >= 9 ||
        digit < 0 || digit > 9 || fixed[row][column]) { return false; }
    board[row][column] = digit;
    if (digit != 0 && digit != solution[row][column]) { mistakes++; }
    return true;
  }

  /// Reveals the correct value in the first unresolved cell.
  /// Returns the revealed coordinate or null when already solved.
  (int, int)? revealHint() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board[r][c] != solution[r][c] && !fixed[r][c]) {
          board[r][c] = solution[r][c];
          hintsUsed++;
          return (r, c);
        }
      }
    }
    return null;
  }

  bool get complete {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board[r][c] != solution[r][c]) return false;
      }
    }
    return true;
  }

  void restart() {
    board = puzzle.map((r) => List<int>.from(r)).toList();
    mistakes = 0;
    hintsUsed = 0;
  }
}
