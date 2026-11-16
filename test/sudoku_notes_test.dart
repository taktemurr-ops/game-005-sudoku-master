import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/game/sudoku_game.dart';

void main() {
  test('notes toggle on empty editable cells', () {
    final game = SudokuGame.demo();
    expect(game.toggleNote(0, 2, 4), isTrue);
    expect(game.notesAt(0, 2), contains(4));
    expect(game.toggleNote(0, 2, 4), isTrue);
    expect(game.notesAt(0, 2), isEmpty);
  });

  test('notes cannot change fixed or filled cells', () {
    final game = SudokuGame.demo();
    expect(game.toggleNote(0, 0, 3), isFalse);
    expect(game.toggleNote(0, 2, 0), isFalse);
    expect(game.input(0, 2, 4), isTrue);
    expect(game.toggleNote(0, 2, 1), isFalse);
  });

  test('input, hints and restart clear notes', () {
    final game = SudokuGame.demo();
    game.toggleNote(0, 2, 9);
    game.input(0, 2, 4);
    expect(game.notesAt(0, 2), isEmpty);
    game.toggleNote(0, 3, 2);
    game.revealHint();
    expect(game.notesAt(0, 3), isEmpty);
    game.toggleNote(0, 5, 1);
    game.restart();
    expect(game.notesAt(0, 5), isEmpty);
  });
}
