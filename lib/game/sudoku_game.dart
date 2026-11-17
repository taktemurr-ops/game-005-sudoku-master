/// Offline Sudoku model. Grid cells are 0 (empty) or 1–9. No SDK dependencies.
class SudokuGame {
  late final List<List<int>> puzzle;
  late final List<List<int>> solution;
  late List<List<int>> board;
  late final List<List<bool>> fixed;
  int mistakes = 0;
  int hintsUsed = 0;
  final Map<int, Set<int>> pencilMarks = <int, Set<int>>{};
  final List<_UndoState> _history = <_UndoState>[];

  SudokuGame(List<List<int>> initialPuzzle, List<List<int>> initialSolution) {
    for (final grid in [initialPuzzle, initialSolution]) {
      if (grid.length != 9 || grid.any((r) => r.length != 9) ||
          grid.any((row) => row.any((digit) => digit < 0 || digit > 9))) {
        throw ArgumentError('Sudoku grids must be 9×9 with digits 0–9.');
      }
    }
    if (!isValidGrid(initialSolution) ||
        initialSolution.any((row) => row.contains(0))) {
      throw ArgumentError('Solution must be a valid complete Sudoku.');
    }
    if (!isValidGrid(initialPuzzle)) {
      throw ArgumentError('Contradictory puzzle clues.');
    }
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (initialPuzzle[r][c] != 0 &&
            initialPuzzle[r][c] != initialSolution[r][c]) {
          throw ArgumentError('Puzzle clues contradict the supplied solution.');
        }
      }
    }
    puzzle = _copy(initialPuzzle);
    solution = _copy(initialSolution);
    board = _copy(puzzle);
    fixed = puzzle.map((row) => row.map((digit) => digit != 0).toList()).toList();
  }

  static List<List<int>> _copy(List<List<int>> grid) =>
      grid.map((row) => List<int>.from(row)).toList();

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
    if (grid.length != 9 || grid.any((row) => row.length != 9)) return false;
    bool valid(Iterable<int> values) {
      final seen = <int>{};
      for (final digit in values) {
        if (digit < 0 || digit > 9 || (digit > 0 && !seen.add(digit))) {
          return false;
        }
      }
      return true;
    }
    for (var i = 0; i < 9; i++) {
      if (!valid(grid[i]) || !valid([for (var r = 0; r < 9; r++) grid[r][i]])) {
        return false;
      }
    }
    for (var r = 0; r < 9; r += 3) {
      for (var c = 0; c < 9; c += 3) {
        if (!valid([for (var dr = 0; dr < 3; dr++)
          for (var dc = 0; dc < 3; dc++) grid[r + dr][c + dc]])) {
          return false;
        }
      }
    }
    return true;
  }

  int _index(int r, int c) => r * 9 + c;
  bool _inBounds(int r, int c) => r >= 0 && r < 9 && c >= 0 && c < 9;
  bool get canUndo => _history.isNotEmpty;
  bool get complete => List.generate(9, (r) => r)
      .every((r) => List.generate(9, (c) => c)
          .every((c) => board[r][c] == solution[r][c]));

  Set<int> notesAt(int row, int column) => _inBounds(row, column)
      ? Set<int>.unmodifiable(pencilMarks[_index(row, column)] ?? <int>{})
      : <int>{};

  void _recordUndo() {
    _history.add(_UndoState(_copy(board), mistakes, hintsUsed,
        {for (final entry in pencilMarks.entries) entry.key: Set<int>.from(entry.value)}));
    if (_history.length > 100) _history.removeAt(0);
  }

  bool undo() {
    if (_history.isEmpty) return false;
    final previous = _history.removeLast();
    board = _copy(previous.board);
    mistakes = previous.mistakes;
    hintsUsed = previous.hintsUsed;
    pencilMarks
      ..clear()
      ..addAll({for (final entry in previous.notes.entries)
        entry.key: Set<int>.from(entry.value)});
    return true;
  }

  bool toggleNote(int row, int column, int digit) {
    if (!_inBounds(row, column) || digit < 1 || digit > 9 ||
        fixed[row][column] || board[row][column] != 0) return false;
    _recordUndo();
    final index = _index(row, column);
    final marks = pencilMarks.putIfAbsent(index, () => <int>{});
    if (!marks.add(digit)) marks.remove(digit);
    if (marks.isEmpty) pencilMarks.remove(index);
    return true;
  }

  bool input(int row, int column, int digit) {
    if (!_inBounds(row, column) || digit < 0 || digit > 9 || fixed[row][column]) {
      return false;
    }
    if (board[row][column] == digit && !pencilMarks.containsKey(_index(row, column))) {
      return true;
    }
    _recordUndo();
    board[row][column] = digit;
    pencilMarks.remove(_index(row, column));
    if (digit != 0 && digit != solution[row][column]) mistakes++;
    return true;
  }

  Set<int> candidatesAt(int row, int column) {
    if (!_inBounds(row, column) || fixed[row][column] ||
        board[row][column] != 0) return <int>{};
    final used = <int>{};
    for (var i = 0; i < 9; i++) {
      used.add(board[row][i]);
      used.add(board[i][column]);
    }
    for (var r = row ~/ 3 * 3; r < row ~/ 3 * 3 + 3; r++) {
      for (var c = column ~/ 3 * 3; c < column ~/ 3 * 3 + 3; c++) {
        used.add(board[r][c]);
      }
    }
    return {for (var n = 1; n <= 9; n++) if (!used.contains(n)) n};
  }

  (int, int, int)? nextLogicalHint() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final options = candidatesAt(r, c);
        if (options.length == 1) return (r, c, options.single);
      }
    }
    return null;
  }

  (int, int)? revealHint() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (!fixed[r][c] && board[r][c] != solution[r][c]) {
          _recordUndo();
          board[r][c] = solution[r][c];
          pencilMarks.remove(_index(r, c));
          hintsUsed++;
          return (r, c);
        }
      }
    }
    return null;
  }

  /// Adds legal candidates to all empty cells without guessing the solution.
  void fillPencilMarks() {
    _recordUndo();
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final options = candidatesAt(r, c);
        final index = _index(r, c);
        if (options.isNotEmpty) {
          pencilMarks[index] = options;
        } else {
          pencilMarks.remove(index);
        }
      }
    }
  }

  void restart() {
    board = _copy(puzzle);
    mistakes = 0;
    hintsUsed = 0;
    pencilMarks.clear();
    _history.clear();
  }

  Map<String, dynamic> toSnapshot() => {
    'schema': 2,
    'puzzle': _copy(puzzle),
    'solution': _copy(solution),
    'board': _copy(board),
    'mistakes': mistakes,
    'hintsUsed': hintsUsed,
    'notes': {for (final entry in pencilMarks.entries)
      entry.key.toString(): (entry.value.toList()..sort())},
  };

  /// Untrusted stored state is strictly validated; broken saves are ignored.
  static SudokuGame? fromSnapshot(Object? raw) {
    try {
      if (raw is! Map<String, dynamic> || raw['schema'] != 2) return null;
      List<List<int>>? parseGrid(Object? value) {
        if (value is! List || value.length != 9) return null;
        final result = <List<int>>[];
        for (final row in value) {
          if (row is! List || row.length != 9 || row.any((n) => n is! int || n < 0 || n > 9)) {
            return null;
          }
          result.add(row.cast<int>().toList());
        }
        return result;
      }
      final puzzle = parseGrid(raw['puzzle']);
      final solution = parseGrid(raw['solution']);
      final board = parseGrid(raw['board']);
      if (puzzle == null || solution == null || board == null) return null;
      final mistakes = raw['mistakes'];
      final hintsUsed = raw['hintsUsed'];
      if (mistakes is! int || mistakes < 0 || mistakes > 10000 ||
          hintsUsed is! int || hintsUsed < 0 || hintsUsed > 81) return null;
      final game = SudokuGame(puzzle, solution);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (game.fixed[r][c] && board[r][c] != puzzle[r][c]) return null;
        }
      }
      game.board = board;
      game.mistakes = mistakes;
      game.hintsUsed = hintsUsed;
      final notes = raw['notes'];
      if (notes is! Map) return null;
      for (final entry in notes.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null || index < 0 || index >= 81 ||
            entry.value is! List ||
            (entry.value as List).any((n) => n is! int || n < 1 || n > 9) ||
            board[index ~/ 9][index % 9] != 0) return null;
        game.pencilMarks[index] = (entry.value as List).cast<int>().toSet();
      }
      return game;
    } catch (_) {
      return null;
    }
  }
}

class _UndoState {
  final List<List<int>> board;
  final int mistakes;
  final int hintsUsed;
  final Map<int, Set<int>> notes;
  const _UndoState(this.board, this.mistakes, this.hintsUsed, this.notes);
}
