import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// 9x9 Sudoku (optionally X-Sudoku with both diagonals).
class SudokuLevel {
  final List<int> givens; // 81, 0 = empty
  final List<int> solution; // 81
  final bool diagonal;
  final int mistakeLimit; // 0 = unlimited
  final int timeLimit;
  final int difficulty;
  final int seed;

  const SudokuLevel({
    required this.givens,
    required this.solution,
    required this.diagonal,
    required this.mistakeLimit,
    required this.timeLimit,
    required this.difficulty,
    required this.seed,
  });

  int get clues => givens.where((v) => v != 0).length;
}

/// Peers of every cell (row, column, box, diagonals if enabled).
List<List<int>> sudokuPeers(bool diagonal) {
  final peers = List.generate(81, (_) => <int>{});
  for (var i = 0; i < 81; i++) {
    final r = i ~/ 9, c = i % 9;
    for (var k = 0; k < 9; k++) {
      peers[i].add(r * 9 + k);
      peers[i].add(k * 9 + c);
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var a = 0; a < 3; a++) {
      for (var b = 0; b < 3; b++) {
        peers[i].add((br + a) * 9 + bc + b);
      }
    }
    if (diagonal) {
      if (r == c) {
        for (var k = 0; k < 9; k++) {
          peers[i].add(k * 9 + k);
        }
      }
      if (r + c == 8) {
        for (var k = 0; k < 9; k++) {
          peers[i].add(k * 9 + 8 - k);
        }
      }
    }
    peers[i].remove(i);
  }
  return peers.map((s) => s.toList()).toList();
}

final _peersStd = sudokuPeers(false);
final _peersDiag = sudokuPeers(true);
List<List<int>> peersFor(bool diagonal) => diagonal ? _peersDiag : _peersStd;

int _bitCount(int x) {
  var c = 0;
  while (x != 0) {
    x &= x - 1;
    c++;
  }
  return c;
}

/// Counts solutions up to [limit]. Optionally fills [out] with the first.
int countSolutions(List<int> grid, bool diagonal, {int limit = 2, List<int>? out, SeededRandom? rnd}) {
  final peers = peersFor(diagonal);
  final g = List.of(grid);
  var found = 0;

  int candidates(int i) {
    var used = 0;
    for (final p in peers[i]) {
      if (g[p] != 0) used |= 1 << g[p];
    }
    return (~used) & 0x3FE;
  }

  bool rec() {
    var best = -1, bestMask = 0, bestCount = 10;
    for (var i = 0; i < 81; i++) {
      if (g[i] != 0) continue;
      final m = candidates(i);
      final c = _bitCount(m);
      if (c == 0) return false;
      if (c < bestCount) {
        best = i;
        bestMask = m;
        bestCount = c;
        if (c == 1) break;
      }
    }
    if (best < 0) {
      found++;
      if (out != null && found == 1) out.setAll(0, g);
      return found >= limit;
    }
    final digits = [for (var d = 1; d <= 9; d++) if (bestMask & (1 << d) != 0) d];
    if (rnd != null) rnd.shuffle(digits);
    for (final d in digits) {
      g[best] = d;
      if (rec()) return true;
    }
    g[best] = 0;
    return false;
  }

  // Givens must not conflict.
  for (var i = 0; i < 81; i++) {
    if (grid[i] == 0) continue;
    for (final p in peers[i]) {
      if (grid[p] == grid[i]) return 0;
    }
  }
  rec();
  return found;
}

SudokuLevel generateSudoku(LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final diagonal = spec.has('diagonal');
  final full = List<int>.filled(81, 0);
  countSolutions(List<int>.filled(81, 0), diagonal, limit: 1, out: full, rnd: r);
  const targets = [46, 42, 38, 35, 33, 31, 29, 28, 27, 26];
  var target = targets[(spec.difficulty - 1).clamp(0, 9)];
  if (diagonal) target -= 2;
  final grid = List.of(full);
  final order = List.generate(81, (i) => i);
  r.shuffle(order);
  var clues = 81;
  for (final i in order) {
    if (clues <= target) break;
    final keep = grid[i];
    grid[i] = 0;
    if (countSolutions(grid, diagonal) != 1) {
      grid[i] = keep;
    } else {
      clues--;
    }
  }
  return SudokuLevel(
    givens: grid,
    solution: full,
    diagonal: diagonal,
    mistakeLimit: spec.has('mistake_limit') ? 3 : 0,
    timeLimit: spec.mode == GameModeId.timeAttack ? 600 : (spec.has('timer') ? 300 + (81 - clues) * 12 : 0),
    difficulty: spec.difficulty,
    seed: spec.seed,
  );
}

class SudokuGame {
  final SudokuLevel level;
  late List<int> values;
  late List<int> notes; // bitmask per cell
  int mistakes = 0;
  int moves = 0;
  final List<String> _undo = [];

  SudokuGame(this.level) {
    values = List.of(level.givens);
    notes = List.filled(81, 0);
  }

  List<List<int>> get peers => peersFor(level.diagonal);

  bool isGiven(int i) => level.givens[i] != 0;

  bool get won {
    for (var i = 0; i < 81; i++) {
      if (values[i] != level.solution[i]) return false;
    }
    return true;
  }

  bool get lost => level.mistakeLimit > 0 && mistakes >= level.mistakeLimit;

  /// Places a digit. Returns false when it is wrong (counts a mistake).
  bool place(int i, int d) {
    if (isGiven(i)) return true;
    _push();
    values[i] = d;
    notes[i] = 0;
    moves++;
    if (d != level.solution[i]) {
      mistakes++;
      return false;
    }
    // Clear this digit from peer notes.
    for (final p in peers[i]) {
      notes[p] &= ~(1 << d);
    }
    return true;
  }

  void erase(int i) {
    if (isGiven(i)) return;
    _push();
    values[i] = 0;
    notes[i] = 0;
  }

  void toggleNote(int i, int d) {
    if (isGiven(i) || values[i] != 0) return;
    _push();
    notes[i] ^= 1 << d;
  }

  bool conflicts(int i) {
    final v = values[i];
    if (v == 0) return false;
    for (final p in peers[i]) {
      if (values[p] == v) return true;
    }
    return false;
  }

  int candidates(int i) {
    var used = 0;
    for (final p in peers[i]) {
      if (values[p] != 0) used |= 1 << values[p];
    }
    return (~used) & 0x3FE;
  }

  /// Booster: fill every empty cell's notes with its candidates.
  void autoNotes() {
    _push();
    for (var i = 0; i < 81; i++) {
      if (values[i] == 0) notes[i] = candidates(i);
    }
  }

  /// Hint: the empty (or wrong) cell with the fewest candidates.
  int? hintCell() {
    var best = -1, bestC = 99;
    for (var i = 0; i < 81; i++) {
      if (values[i] == level.solution[i]) continue;
      if (values[i] != 0) return i; // fix mistakes first
      final c = _bitCount(candidates(i));
      if (c < bestC) {
        bestC = c;
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  void reveal(int i) {
    _push();
    values[i] = level.solution[i];
    notes[i] = 0;
    for (final p in peers[i]) {
      notes[p] &= ~(1 << values[i]);
    }
  }

  int countOf(int d) => values.where((v) => v == d).length;

  bool get canUndo => _undo.isNotEmpty;

  void _push() {
    _undo.add(_snap());
    if (_undo.length > 100) _undo.removeAt(0);
  }

  void undo() {
    if (_undo.isNotEmpty) _restore(_undo.removeLast());
  }

  String _snap() => '${values.join(',')}#${notes.join(',')}#$mistakes#$moves';

  void _restore(String s) {
    final p = s.split('#');
    values = p[0].split(',').map(int.parse).toList();
    notes = p[1].split(',').map(int.parse).toList();
    mistakes = int.parse(p[2]);
    moves = int.parse(p[3]);
  }

  String serialize() => _snap();

  static SudokuGame restore(SudokuLevel l, String s) => SudokuGame(l).._restore(s);

  /// Continue after too many mistakes.
  void forgive() => mistakes = 0;
}
