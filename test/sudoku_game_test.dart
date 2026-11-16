import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/game/sudoku_game.dart';

void main() {
  test('the demo puzzle starts valid and incomplete', () {
    final game = SudokuGame.demo();
    expect(SudokuGame.isValidGrid(game.board), true);
    expect(game.complete, false);
  });
  test('locked clues cannot be edited', () {
    final game = SudokuGame.demo();
    expect(game.input(0, 0, 2), false);
    expect(game.board[0][0], 5);
  });
  test('correct answer fills an empty cell', () {
    final game = SudokuGame.demo();
    expect(game.input(0, 2, 4), true);
    expect(game.board[0][2], 4);
    expect(game.mistakes, 0);
  });
  test('wrong input increases mistake count', () {
    final game = SudokuGame.demo();
    expect(game.input(0, 2, 2), true);
    expect(game.mistakes, 1);
    game.restart();
    expect(game.mistakes, 0);
    expect(game.board[0][2], 0);
  });
  test('invalid box duplicates are detected', () {
    final game = SudokuGame.demo();
    game.board[0][2] = 5;
    expect(SudokuGame.isValidGrid(game.board), false);
  });
}
