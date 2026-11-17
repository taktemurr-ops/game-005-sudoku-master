import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_005_sudoku_master/game/sudoku_game.dart';
import 'package:game_005_sudoku_master/game/sudoku_generator.dart';
import 'package:game_005_sudoku_master/services/sudoku_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('local save, statistics, best time and selective wipe', () async {
    final storage = SudokuStorage();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('another_app', 'preserve');
    final item = SudokuSave(difficulty: SudokuDifficulty.medium,
        game: SudokuGame.demo(), elapsedSeconds: 42, paused: true, seed: 5);
    await storage.save(item);
    expect((await storage.load())!.elapsedSeconds, 42);
    await storage.started();
    await storage.completed(SudokuDifficulty.medium, 47);
    await storage.completed(SudokuDifficulty.medium, 51);
    expect((await storage.best(SudokuDifficulty.medium)), 47);
    expect((await storage.statistics()).completed, 2);
    await storage.setLocale('ar');
    expect(await storage.locale(), 'ar');
    await storage.eraseAll();
    expect(await storage.load(), isNull);
    expect((await storage.statistics()).played, 0);
    expect(prefs.getString('another_app'), 'preserve');
  });
}
