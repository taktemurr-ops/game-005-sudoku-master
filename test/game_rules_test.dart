import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/core/level_plan.dart';
import 'package:game_005_sudoku_master/game/rules.dart';
import 'package:game_005_sudoku_master/game/sudoku_engine.dart';

void main() {
  final rules = SudokuRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('generated puzzles have exactly one solution and the right clue count', () {
    for (final n in [1, 50, 333, 9000]) {
      final g = rules.build(planner.spec(n));
      expect(g.validation.ok, isTrue);
      expect(countSolutions(g.puzzle.givens, g.puzzle.diagonal), 1);
      expect(g.puzzle.clues, inInclusiveRange(22, 46));
    }
  });

  test('diagonal (X) variant respects diagonals', () {
    final spec = planner.spec(500).copyWith(mechanics: const ['diagonal']);
    final l = rules.build(spec).puzzle;
    expect(l.diagonal, isTrue);
    final diag = List.generate(9, (k) => l.solution[k * 9 + k]).toSet();
    final anti = List.generate(9, (k) => l.solution[k * 9 + 8 - k]).toSet();
    expect(diag.length, 9);
    expect(anti.length, 9);
  });

  test('mistakes, notes, hint, undo, win', () {
    final l = rules.build(planner.spec(3)).puzzle;
    final g = SudokuGame(l);
    final i = List.generate(81, (k) => k).firstWhere((k) => !g.isGiven(k));
    final wrong = l.solution[i] % 9 + 1;
    expect(g.place(i, wrong), isFalse);
    expect(g.mistakes, 1);
    g.undo();
    expect(g.values[i], 0);
    g.toggleNote(i, 5);
    expect(g.notes[i] & (1 << 5), isNot(0));
    g.autoNotes();
    expect(g.notes[i] & (1 << l.solution[i]), isNot(0));
    var guard = 0;
    while (!g.won && guard++ < 100) {
      g.reveal(g.hintCell()!);
    }
    expect(g.won, isTrue);
  });

  test('resume restores state', () {
    final l = rules.build(planner.spec(7)).puzzle;
    final g = SudokuGame(l);
    g.reveal(g.hintCell()!);
    expect(SudokuGame.restore(l, g.serialize()).serialize(), g.serialize());
  });

  test('levels 1..40 unique, sampled to 50.000', () {
    for (var n = 1; n <= 40; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
    for (var n = 5000; n <= 50000; n += 15000) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue);
    }
  });
}
