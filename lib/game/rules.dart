import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'sudoku_engine.dart';

class SudokuRules extends GameRules<SudokuLevel> {
  @override
  String get gameId => 'game-005-sudoku-master';

  @override
  List<String> get optionalMechanics => const ['diagonal', 'mistake_limit', 'timer'];

  @override
  List<GameModeId> get modes => const [
        GameModeId.campaign,
        GameModeId.endless,
        GameModeId.timeAttack,
        GameModeId.daily,
        GameModeId.weekly,
        GameModeId.challenge,
        GameModeId.zen,
      ];

  @override
  List<GameStat> get gameStats => const [
        GameStat('digits_placed', 'Yerleştirilen rakam', 'Digits placed', scale: 100),
        GameStat('perfect_sudoku', 'Hatasız sudoku', 'Flawless sudokus', scale: 2),
        GameStat('x_sudoku', 'Çapraz sudoku', 'X-Sudokus'),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('digits', 'digits_placed', [80, 160, 300]),
        MissionTemplate('perfect', 'perfect_sudoku', [1, 2, 3], coinReward: 80),
      ];

  @override
  SudokuLevel generate(LevelSpec spec) => generateSudoku(spec);

  @override
  Validation validate(SudokuLevel l, LevelSpec spec) {
    if (l.givens.length != 81 || l.solution.contains(0)) return const Validation.fail('shape');
    for (var i = 0; i < 81; i++) {
      if (l.givens[i] != 0 && l.givens[i] != l.solution[i]) return const Validation.fail('givens');
    }
    if (countSolutions(l.solution, l.diagonal, limit: 1) != 1) return const Validation.fail('bad solution');
    if (countSolutions(l.givens, l.diagonal) != 1) return const Validation.fail('not unique');
    return Validation.ok(l.clues);
  }

  static int stars(SudokuGame g, int seconds) {
    if (!g.won) return 0;
    if (g.mistakes == 0) return 3;
    if (g.mistakes <= 2) return 2;
    return 1;
  }
}

GameRules createRules() => SudokuRules();
