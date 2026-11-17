import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/game/sudoku_game.dart';
import 'package:game_005_sudoku_master/game/sudoku_generator.dart';
import 'package:game_005_sudoku_master/services/sudoku_storage.dart';

void main() {
  test('an input can be undone while preserving score and original notes', () {
    final game = SudokuGame.demo();
    expect(game.toggleNote(0, 2, 4), isTrue);
    expect(game.input(0, 2, 9), isTrue);
    expect(game.mistakes, 1);
    expect(game.undo(), isTrue);
    expect(game.board[0][2], 0);
    expect(game.mistakes, 0);
    expect(game.notesAt(0, 2), {4});
    expect(game.undo(), isTrue);
    expect(game.notesAt(0, 2), isEmpty);
  });

  test('automatic notes are legal and undo restores prior pencil state', () {
    final game = SudokuGame.demo();
    game.fillPencilMarks();
    expect(game.notesAt(0, 2), game.candidatesAt(0, 2));
    expect(game.notesAt(0, 0), isEmpty);
    expect(game.undo(), isTrue);
    expect(game.notesAt(0, 2), isEmpty);
  });

  test('save round trip retains board, mode, hints and elapsed time', () {
    final game = SudokuGame.demo();
    game.toggleNote(0, 2, 4);
    game.input(0, 3, 6);
    final save = SudokuSave(difficulty: SudokuDifficulty.hard,
        game: game, elapsedSeconds: 142, paused: true, seed: 123);
    final restored = SudokuSave.decode(save.toJson());
    expect(restored, isNotNull);
    expect(restored!.difficulty, SudokuDifficulty.hard);
    expect(restored.elapsedSeconds, 142);
    expect(restored.paused, isTrue);
    expect(restored.seed, 123);
    expect(restored.game.board, game.board);
    expect(restored.game.notesAt(0, 2), {4});
  });

  test('corrupted saves and illegal fixed-cell edits are rejected', () {
    final base = SudokuGame.demo().toSnapshot();
    final bad = Map<String, dynamic>.from(base);
    bad['board'] = [for (var r = 0; r < 9; r++)
      [for (var c = 0; c < 9; c++) if (r == 0 && c == 0) 8 else (base['board'] as List)[r][c]]];
    expect(SudokuGame.fromSnapshot(bad), isNull);
    final session = SudokuSave(difficulty: SudokuDifficulty.easy,
        game: SudokuGame.demo(), elapsedSeconds: 20, paused: false, seed: 11).toJson();
    session['elapsed'] = -1;
    expect(SudokuSave.decode(session), isNull);
    session['elapsed'] = 20;
    session['mode'] = 'invalid';
    expect(SudokuSave.decode(session), isNull);
  });

  test('a complete board is recorded as solved', () {
    final demo = SudokuGame.demo();
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (!demo.fixed[r][c]) demo.input(r, c, demo.solution[r][c]);
      }
    }
    expect(demo.complete, isTrue);
  });
}
