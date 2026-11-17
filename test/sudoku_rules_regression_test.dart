import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/game/sudoku_game.dart';

void main() {
  test('fixed clues cannot be edited and bad inputs are rejected', () {
    final game = SudokuGame.demo();
    expect(game.input(0, 0, 9), isFalse);
    expect(game.input(-1, 2, 1), isFalse);
    expect(game.input(0, 2, 10), isFalse);
    expect(game.board[0][0], 5);
    expect(game.mistakes, 0);
  });

  test('notes toggle, clear on input, and reset on restart', () {
    final game = SudokuGame.demo();
    expect(game.toggleNote(0, 2, 4), isTrue);
    expect(game.notesAt(0, 2), {4});
    expect(game.toggleNote(0, 2, 4), isTrue);
    expect(game.notesAt(0, 2), isEmpty);
    expect(game.toggleNote(0, 0, 4), isFalse);
    expect(game.toggleNote(0, 2, 4), isTrue);
    expect(game.input(0, 2, 4), isTrue);
    expect(game.notesAt(0, 2), isEmpty);
    game.restart();
    expect(game.board[0][2], 0);
    expect(game.notesAt(0, 2), isEmpty);
  });

  test('incorrect guesses count as mistakes, restart clears counts', () {
    final game = SudokuGame.demo();
    expect(game.input(0, 2, 9), isTrue);
    expect(game.mistakes, 1);
    expect(game.complete, isFalse);
    game.restart();
    expect(game.mistakes, 0);
    expect(game.hintsUsed, 0);
    expect(game.board[0][2], 0);
  });

  test('logical hints do not change the board or use paid hints', () {
    final game = SudokuGame.demo();
    final before = game.board.map((r) => List<int>.from(r)).toList();
    game.nextLogicalHint();
    expect(game.board, before);
    expect(game.hintsUsed, 0);
    expect(game.candidatesAt(0, 0), isEmpty);
  });
}
