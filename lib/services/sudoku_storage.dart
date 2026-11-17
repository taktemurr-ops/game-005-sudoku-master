import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/sudoku_game.dart';
import '../game/sudoku_generator.dart';

class SudokuSave {
  final SudokuDifficulty difficulty;
  final SudokuGame game;
  final int elapsedSeconds;
  final bool paused;
  final int seed;

  const SudokuSave({required this.difficulty, required this.game,
      required this.elapsedSeconds, required this.paused, required this.seed});

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'mode': difficulty.name,
    'elapsed': elapsedSeconds,
    'paused': paused,
    'seed': seed,
    'game': game.toSnapshot(),
  };

  static SudokuSave? decode(Object? raw) {
    if (raw is! Map<String, dynamic> || raw['schema'] != 1) return null;
    try {
      final name = raw['mode'];
      final elapsed = raw['elapsed'];
      final paused = raw['paused'];
      final seed = raw['seed'];
      if (name is! String || elapsed is! int || elapsed < 0 ||
          elapsed > 3600000 || paused is! bool || seed is! int) return null;
      final modes = SudokuDifficulty.values.where((m) => m.name == name);
      if (modes.length != 1) return null;
      final game = SudokuGame.fromSnapshot(raw['game']);
      if (game == null) return null;
      return SudokuSave(difficulty: modes.single, game: game,
          elapsedSeconds: elapsed, paused: paused, seed: seed);
    } catch (_) {
      return null;
    }
  }
}

class SudokuStats {
  final int completed;
  final int played;
  final int totalSeconds;
  const SudokuStats({this.completed = 0, this.played = 0,
      this.totalSeconds = 0});
}

/// Device-local, versioned persistence. Does not send device/user data online.
class SudokuStorage {
  static const prefix = 'sudoku_master_v2_';
  static const sessionKey = '${prefix}session';
  static const localeKey = '${prefix}locale';
  static const contrastKey = '${prefix}high_contrast';
  static const soundKey = '${prefix}sound';
  static const hapticsKey = '${prefix}haptics';

  Future<SudokuSave?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(sessionKey);
    if (encoded == null) return null;
    try {
      return SudokuSave.decode(jsonDecode(encoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SudokuSave save) async =>
      (await SharedPreferences.getInstance()).setString(
          sessionKey, jsonEncode(save.toJson()));

  Future<void> clearSave() async =>
      (await SharedPreferences.getInstance()).remove(sessionKey);

  Future<void> started() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${prefix}played', (prefs.getInt('${prefix}played') ?? 0) + 1);
  }

  Future<void> completed(SudokuDifficulty mode, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${prefix}completed', (prefs.getInt('${prefix}completed') ?? 0) + 1);
    await prefs.setInt('${prefix}seconds',
        (prefs.getInt('${prefix}seconds') ?? 0) + seconds);
    final key = '${prefix}best_${mode.name}';
    final current = prefs.getInt(key);
    if (current == null || seconds < current) await prefs.setInt(key, seconds);
    if (mode == SudokuDifficulty.daily) {
      await prefs.setInt('${prefix}daily_completed_seed', SudokuGenerator.dailySeed(DateTime.now()));
    }
  }

  Future<SudokuStats> statistics() async {
    final prefs = await SharedPreferences.getInstance();
    return SudokuStats(completed: prefs.getInt('${prefix}completed') ?? 0,
        played: prefs.getInt('${prefix}played') ?? 0,
        totalSeconds: prefs.getInt('${prefix}seconds') ?? 0);
  }

  Future<int?> best(SudokuDifficulty mode) async =>
      (await SharedPreferences.getInstance()).getInt('${prefix}best_${mode.name}');

  Future<bool> completedToday() async =>
      (await SharedPreferences.getInstance()).getInt('${prefix}daily_completed_seed') ==
      SudokuGenerator.dailySeed(DateTime.now());

  Future<String> locale() async =>
      (await SharedPreferences.getInstance()).getString(localeKey) ?? 'tr';
  Future<void> setLocale(String value) async =>
      (await SharedPreferences.getInstance()).setString(localeKey, value);
  Future<bool> highContrast() async =>
      (await SharedPreferences.getInstance()).getBool(contrastKey) ?? false;
  Future<void> setContrast(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(contrastKey, value);
  Future<bool> sound() async =>
      (await SharedPreferences.getInstance()).getBool(soundKey) ?? true;
  Future<void> setSound(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(soundKey, value);
  Future<bool> haptics() async =>
      (await SharedPreferences.getInstance()).getBool(hapticsKey) ?? true;
  Future<void> setHaptics(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(hapticsKey, value);

  /// Removes all game-specific keys, including session, settings and statistics.
  Future<void> eraseAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}
