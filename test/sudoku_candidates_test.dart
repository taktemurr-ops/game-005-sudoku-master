import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/game/sudoku_game.dart';

void main() {
  test('candidates use row, column and box constraints', () {
    final game = SudokuGame.demo();
    expect(game.candidatesAt(0, 2), {1, 2, 4});
    expect(game.candidatesAt(0, 0), isEmpty);
    expect(game.candidatesAt(-1, 0), isEmpty);
  });

  test('candidate calculation does not reveal solution or change state', () {
    final game = SudokuGame.demo();
    final original = game.board.map((row) => List<int>.of(row)).toList();
    game.candidatesAt(0, 2);
    game.nextLogicalHint();
    expect(game.board, original);
    expect(game.hintsUsed, 0);
    expect(game.mistakes, 0);
  });

  test('candidates update after a correct entry and reset restores them', () {
    final game = SudokuGame.demo();
    final initial = game.candidatesAt(0, 3);
    expect(game.input(0, 2, 4), true);
    expect(game.candidatesAt(0, 2), isEmpty);
    expect(game.candidatesAt(0, 3).contains(4), false);
    game.restart();
    expect(game.candidatesAt(0, 3), initial);
  });
}
