import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/sudoku_game.dart';
import 'game/sudoku_generator.dart';
import 'services/sudoku_storage.dart';
import 'services/sudoku_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SudokuMasterApp());
}

class SudokuMasterApp extends StatelessWidget {
  const SudokuMasterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sudoku Master',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF61CFF4),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121C2F),
        ),
        home: const SudokuScreen(),
      );
}

enum _Page { home, play, settings, statistics }

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen>
    with WidgetsBindingObserver {
  final SudokuStorage _storage = SudokuStorage();
  SudokuGame game = SudokuGame.demo();
  SudokuDifficulty difficulty = SudokuDifficulty.easy;
  _Page page = _Page.home;
  SudokuSave? saved;
  SudokuStats stats = const SudokuStats();
  int? bestSeconds;
  int currentSeed = 0;
  int elapsedSeconds = 0;
  int selectedRow = 0;
  int selectedColumn = 2;
  bool noteMode = false;
  bool paused = false;
  bool finished = false;
  bool failed = false;
  bool highContrast = false;
  bool sound = true;
  bool haptics = true;
  String locale = 'tr';
  Timer? _timer;

  String tr(String key) => SudokuText.tr(locale, key);
  String get clock => '${(elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}';
  bool get blocked => paused || finished || failed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object?>([
        _storage.load(), _storage.locale(), _storage.highContrast(),
        _storage.sound(), _storage.haptics(), _storage.statistics(),
      ]);
      if (!mounted) return;
      setState(() {
        saved = values[0] as SudokuSave?;
        final storedLanguage = values[1] as String;
        locale = const ['tr', 'en', 'ar'].contains(storedLanguage)
            ? storedLanguage : 'tr';
        highContrast = values[2] as bool;
        sound = values[3] as bool;
        haptics = values[4] as bool;
        stats = values[5] as SudokuStats;
      });
    } catch (_) {
      // Corrupt or unavailable local preferences must not prevent offline play.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && page == _Page.play) {
      if (mounted) setState(() => paused = true);
      _timer?.cancel();
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (page != _Page.play || blocked) return;
      setState(() => elapsedSeconds++);
      if (elapsedSeconds % 10 == 0) unawaited(_save());
    });
  }

  Future<void> _save() async {
    if (finished) return;
    try {
      final item = SudokuSave(difficulty: difficulty, game: game,
          elapsedSeconds: elapsedSeconds, paused: paused, seed: currentSeed);
      await _storage.save(item);
      if (mounted) setState(() => saved = item);
    } catch (_) {
      // Continue offline even when the operating system denies storage.
    }
  }

  void _startNew(SudokuDifficulty selected) {
    _timer?.cancel();
    final seed = selected == SudokuDifficulty.daily
        ? SudokuGenerator.dailySeed(DateTime.now()) :
        DateTime.now().microsecondsSinceEpoch % 0x7fffffff;
    final generated = SudokuGenerator.generate(selected, seed: seed);
    setState(() {
      difficulty = selected;
      game = SudokuGame(generated.puzzle, generated.solution);
      currentSeed = seed;
      elapsedSeconds = 0;
      selectedRow = 0;
      selectedColumn = 0;
      paused = false;
      noteMode = false;
      finished = false;
      failed = false;
      bestSeconds = null;
      page = _Page.play;
    });
    unawaited(_storage.started());
    unawaited(_storage.best(selected).then((value) {
      if (mounted && page == _Page.play && difficulty == selected) {
        setState(() => bestSeconds = value);
      }
    }));
    _tick();
    unawaited(_save());
  }

  void _continue() {
    final item = saved;
    if (item == null) return;
    _timer?.cancel();
    setState(() {
      difficulty = item.difficulty;
      game = item.game;
      currentSeed = item.seed;
      elapsedSeconds = item.elapsedSeconds;
      selectedRow = 0;
      selectedColumn = 0;
      paused = item.paused;
      finished = false;
      failed = game.mistakes >= 3;
      page = _Page.play;
    });
    _tick();
  }

  Future<void> _newWithConfirmation(SudokuDifficulty selected) async {
    if (saved == null || page != _Page.play || finished || failed) {
      _startNew(selected);
      return;
    }
    final yes = await showDialog<bool>(context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('startConfirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: Text(tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true),
                child: Text(tr('newPuzzle'))),
          ],
        ));
    if (yes == true && mounted) _startNew(selected);
  }

  void _completeIfNeeded() {
    if (game.complete && !finished) {
      _timer?.cancel();
      setState(() {
        finished = true;
        paused = true;
      });
      unawaited(_storage.clearSave().then((_) {
        if (mounted) setState(() => saved = null);
      }));
      unawaited(_storage.completed(difficulty, elapsedSeconds).then((_) async {
        final updated = await _storage.statistics();
        if (mounted) setState(() => stats = updated);
      }));
    } else if (game.mistakes >= 3 && !failed) {
      setState(() => failed = true);
    }
  }

  void _enter(int digit) {
    if (blocked) return;
    final accepted = setStateAndTest(() {
      if (noteMode) return game.toggleNote(selectedRow, selectedColumn, digit);
      return game.input(selectedRow, selectedColumn, digit);
    });
    if (accepted) {
      if (!noteMode && digit > 0 && game.board[selectedRow][selectedColumn] !=
          game.solution[selectedRow][selectedColumn] && haptics) {
        unawaited(HapticFeedback.lightImpact());
      }
      _completeIfNeeded();
      unawaited(_save());
    }
  }

  bool setStateAndTest(bool Function() action) {
    var outcome = false;
    setState(() => outcome = action());
    return outcome;
  }

  void _undo() {
    if (blocked || !game.canUndo) return;
    setState(game.undo);
    unawaited(_save());
  }

  void _erase() {
    if (blocked) return;
    if (setStateAndTest(() => game.input(selectedRow, selectedColumn, 0))) {
      unawaited(_save());
    }
  }

  void _reveal() {
    if (blocked) return;
    setState(() {
      final found = game.revealHint();
      if (found != null) {
        selectedRow = found.$1;
        selectedColumn = found.$2;
      }
    });
    _completeIfNeeded();
    unawaited(_save());
  }

  void _logicalHint() {
    if (blocked) return;
    final hint = game.nextLogicalHint();
    if (hint == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('noMove'))));
    } else {
      setState(() {
        selectedRow = hint.$1;
        selectedColumn = hint.$2;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tr('logic')}: ${hint.$1 + 1}, ${hint.$2 + 1} → ${hint.$3}'),
      ));
    }
  }

  void _autoNotes() {
    if (blocked) return;
    setState(game.fillPencilMarks);
    unawaited(_save());
  }

  void _restart() {
    if (page != _Page.play) return;
    setState(() {
      game.restart();
      elapsedSeconds = 0;
      paused = false;
      finished = false;
      failed = false;
    });
    _tick();
    unawaited(_save());
  }

  void _goHome() {
    _timer?.cancel();
    if (page == _Page.play && !finished) unawaited(_save());
    setState(() => page = _Page.home);
  }

  Widget _menuCard(String label, IconData icon, VoidCallback? onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: FilledButton.tonalIcon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(label, style: const TextStyle(fontSize: 17))),
        ),
      );

  Widget _home() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 10),
      const Icon(Icons.grid_on_rounded, size: 66, color: Color(0xFF6DDBF5)),
      const SizedBox(height: 12),
      Text(tr('title'), textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      if (saved != null) _menuCard(tr('continue'), Icons.play_circle,
          _continue),
      const SizedBox(height: 10),
      Text(tr('newPuzzle'), style: Theme.of(context).textTheme.titleLarge),
      ...SudokuDifficulty.values.map((level) => _menuCard(
          tr(level.name), Icons.extension_rounded,
          () => _newWithConfirmation(level))),
      const SizedBox(height: 12),
      _menuCard(tr('statistics'), Icons.bar_chart, () {
        setState(() => page = _Page.statistics);
      }),
      _menuCard(tr('settings'), Icons.settings, () {
        setState(() => page = _Page.settings);
      }),
      const SizedBox(height: 10),
      Text(tr('privacy'), textAlign: TextAlign.center),
    ],
  );

  Widget _cell(int row, int column) {
    final value = game.board[row][column];
    final clue = game.fixed[row][column];
    final isSelected = selectedRow == row && selectedColumn == column;
    final inSameUnit = selectedRow == row || selectedColumn == column ||
        (selectedRow ~/ 3 == row ~/ 3 && selectedColumn ~/ 3 == column ~/ 3);
    final wrong = value != 0 && value != game.solution[row][column] && !clue;
    final notes = game.notesAt(row, column).toList()..sort();
    final base = isSelected
        ? (highContrast ? const Color(0xFF815E19) : const Color(0xFF2F719C))
        : inSameUnit ? const Color(0xFF29445E) : const Color(0xFF1E3047);
    return Expanded(child: GestureDetector(
      key: ValueKey('sudoku-$row-$column'),
      onTap: blocked ? null : () => setState(() {
        selectedRow = row;
        selectedColumn = column;
      }),
      child: Semantics(
        label: '${tr('puzzle')} ${row + 1}, ${column + 1}, ${value == 0 ? tr('chosen') : value}, ${tr('notes')} ${notes.join(', ')}',
        button: true,
        selected: isSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: base,
            border: Border(
              top: BorderSide(color: row % 3 == 0 ? Colors.white70 : Colors.white12,
                  width: row % 3 == 0 ? 1.7 : 0.35),
              left: BorderSide(color: column % 3 == 0 ? Colors.white70 : Colors.white12,
                  width: column % 3 == 0 ? 1.7 : 0.35),
              right: BorderSide(color: column == 8 ? Colors.white70 : Colors.transparent,
                  width: column == 8 ? 1.7 : 0),
              bottom: BorderSide(color: row == 8 ? Colors.white70 : Colors.transparent,
                  width: row == 8 ? 1.7 : 0),
            ),
          ),
          child: value != 0 ? FittedBox(
            child: Text('$value', style: TextStyle(fontSize: 24,
                fontWeight: clue ? FontWeight.w700 : FontWeight.w500,
                color: wrong ? Colors.redAccent :
                    clue ? Colors.white : const Color(0xFF7DEBFF))),
          ) : notes.isNotEmpty ? FittedBox(
            child: Padding(padding: const EdgeInsets.all(2),
              child: Text(notes.join(' '), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.amberAccent))),
          ) : const SizedBox.shrink(),
        ),
      ),
    ));
  }

  Widget _board() => AspectRatio(aspectRatio: 1, child: Column(
    children: List.generate(9, (r) => Expanded(child: Row(
      children: List.generate(9, (c) => _cell(r, c)),
    ))),
  ));

  Widget _command(String text, IconData icon, VoidCallback? action,
      {Key? key}) => OutlinedButton.icon(key: key, onPressed: action,
          icon: Icon(icon, size: 20), label: Text(text));

  Widget _play() => ListView(
    key: const ValueKey('play-screen'),
    padding: const EdgeInsets.all(12),
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(tr(difficulty.name),
            style: Theme.of(context).textTheme.titleMedium),
        Text('${tr('time')}: $clock', key: const ValueKey('timer')),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${tr('mistakes')}: ${game.mistakes}/3', key: const ValueKey('mistakes')),
        Text('${tr('hints')}: ${game.hintsUsed}'),
        Text(bestSeconds == null ? '' : '${tr('best')}: ${bestSeconds! ~/ 60}m'),
      ]),
      const SizedBox(height: 10),
      if (paused && !finished && !failed)
        Card(child: ListTile(title: Text(tr('pause'), textAlign: TextAlign.center),
          trailing: IconButton(onPressed: () { setState(() => paused = false); unawaited(_save()); },
              icon: const Icon(Icons.play_arrow), tooltip: tr('resume')))),
      if (finished || failed)
        Card(color: const Color(0xFF284B64), child: Padding(
          padding: const EdgeInsets.all(14), child: Column(children: [
            Text(tr(finished ? 'win' : 'lose'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(tr('victoryHint')),
            FilledButton(onPressed: () => _startNew(difficulty),
                child: Text(tr('newPuzzle'))),
          ]),
        )),
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540),
          child: _board()),
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.center, spacing: 5, runSpacing: 5,
        children: List.generate(9, (i) => SizedBox(width: 48,
          child: FilledButton.tonal(
            key: ValueKey('digit-${i + 1}'),
            onPressed: blocked ? null : () => _enter(i + 1),
            style: FilledButton.styleFrom(padding: EdgeInsets.zero),
            child: Text('${i + 1}', style: const TextStyle(fontSize: 19)),
          ),
        )),
      ),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 5,
        children: [
          _command(tr('erase'), Icons.backspace_outlined,
              blocked ? null : _erase, key: const ValueKey('erase')),
          _command(tr('undo'), Icons.undo,
              blocked || !game.canUndo ? null : _undo, key: const ValueKey('undo')),
          FilterChip(label: Text(tr('notes')), selected: noteMode,
              onSelected: blocked ? null : (value) => setState(() => noteMode = value)),
          _command(tr('autoNotes'), Icons.edit_note,
              blocked ? null : _autoNotes),
          _command(tr('logic'), Icons.psychology_outlined,
              blocked ? null : _logicalHint),
          _command(tr('hint'), Icons.lightbulb_outline,
              blocked ? null : _reveal, key: const ValueKey('hint')),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        _command(tr('pause'), Icons.pause,
            finished || failed ? null : () { setState(() => paused = !paused); unawaited(_save()); }),
        _command(tr('restart'), Icons.restart_alt, _restart),
        _command(tr('home'), Icons.home, _goHome),
      ]),
      const SizedBox(height: 10),
      Text(tr('saved'), textAlign: TextAlign.center),
    ],
  );

  Widget _settings() => ListView(padding: const EdgeInsets.all(14), children: [
    Text(tr('settings'), style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 14),
    ListTile(title: Text(tr('language')),
      trailing: DropdownButton<String>(value: locale,
        items: const [
          DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'ar', child: Text('العربية')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => locale = value);
          unawaited(_storage.setLocale(value));
        },
      )),
    SwitchListTile(title: Text(tr('contrast')), value: highContrast,
      onChanged: (value) { setState(() => highContrast = value);
        unawaited(_storage.setContrast(value)); }),
    SwitchListTile(title: Text(tr('sound')), value: sound,
      onChanged: (value) { setState(() => sound = value);
        unawaited(_storage.setSound(value)); }),
    SwitchListTile(title: Text(tr('haptics')), value: haptics,
      onChanged: (value) { setState(() => haptics = value);
        unawaited(_storage.setHaptics(value)); }),
    const SizedBox(height: 10),
    Text(tr('privacy')),
    const SizedBox(height: 10),
    FilledButton.tonalIcon(icon: const Icon(Icons.delete_forever),
      label: Text(tr('eraseData')), onPressed: () async {
        final yes = await showDialog<bool>(context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('deleteConfirm')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text(tr('cancel'))),
              FilledButton(onPressed: () => Navigator.pop(context, true),
                  child: Text(tr('delete'))),
            ],
          ));
        if (yes != true) return;
        await _storage.eraseAll();
        _timer?.cancel();
        if (!mounted) return;
        setState(() {
          saved = null;
          stats = const SudokuStats();
          locale = 'tr';
          highContrast = false;
          sound = true;
          haptics = true;
          page = _Page.home;
        });
      }),
  ]);

  Widget _statistics() => ListView(padding: const EdgeInsets.all(18), children: [
    Text(tr('statistics'), style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 14),
    ListTile(title: Text(tr('played')), trailing: Text('${stats.played}')),
    ListTile(title: Text(tr('completed')), trailing: Text('${stats.completed}')),
    ListTile(title: Text(tr('minutes')),
        trailing: Text('${stats.totalSeconds ~/ 60}')),
    ...SudokuDifficulty.values.map((mode) => ListTile(
      title: Text(tr(mode.name)),
      trailing: FutureBuilder<int?>(future: _storage.best(mode),
        builder: (context, snapshot) => Text(snapshot.data == null
            ? '—' : '${snapshot.data! ~/ 60}m ${snapshot.data! % 60}s')),
    )),
  ]);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      appBar: AppBar(title: const Text('Sudoku Master'), actions: [
        if (page != _Page.home)
          IconButton(tooltip: tr('home'), onPressed: _goHome,
              icon: const Icon(Icons.home_outlined)),
      ]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: switch (page) {
          _Page.home => _home(),
          _Page.play => _play(),
          _Page.settings => _settings(),
          _Page.statistics => _statistics(),
        },
      ))),
    ),
  );
}
