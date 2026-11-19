import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/game_api.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';
import 'rules.dart';
import 'sudoku_engine.dart';

class SudokuView extends StatefulWidget {
  final PlayContext ctx;
  const SudokuView({super.key, required this.ctx});

  @override
  State<SudokuView> createState() => _SudokuViewState();
}

class _SudokuViewState extends State<SudokuView> with RoundClock {
  late SudokuGame game;
  int _sel = -1;
  bool _notesMode = false;
  int _hints = 0;
  int _undos = 0;
  int _solved = 0;
  int _digits = 0;
  bool _ended = false;
  final FocusNode _focus = FocusNode();

  PlayContext get ctx => widget.ctx;
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    final level = (ctx.generated as GeneratedLevel<SudokuLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? SudokuGame.restore(level, snap) : SudokuGame(level);
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _solved = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    startClock(initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0, limit: level.timeLimit);
  }

  @override
  void dispose() {
    stopClock();
    _focus.dispose();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(_chain ? _solved > 0 : game.won);

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _solved});

  void _input(int d) {
    if (_sel < 0 || _ended || game.isGiven(_sel)) return;
    if (_notesMode) {
      setState(() => game.toggleNote(_sel, d));
      ctx.sfx(Sfx.tap);
      _persist();
      return;
    }
    final ok = game.place(_sel, d);
    _digits++;
    ctx.sfx(ok ? Sfx.place : Sfx.error);
    setState(() {});
    _persist();
    if (game.won) {
      if (_chain) {
        _solved++;
        ctx.sfx(Sfx.combo);
        final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _solved]));
        setState(() {
          game = SudokuGame(SudokuRules().build(next).puzzle);
          _sel = -1;
        });
        _persist();
        return;
      }
      _end(true);
    } else if (game.lost) {
      _offerContinue();
    }
  }

  Future<void> _offerContinue() async {
    if (ctx.spec.mode == GameModeId.zen) {
      game.forgive();
      return;
    }
    clockPaused = true;
    final again = await ctx.requestContinue();
    clockPaused = false;
    if (!mounted) return;
    if (again) {
      setState(game.forgive);
    } else {
      _end(false);
    }
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    final stars = _chain ? (_solved >= 5 ? 3 : _solved >= 2 ? 2 : 1) : SudokuRules.stars(game, seconds);
    ctx.finish(RoundResult(
      won: won,
      score: _chain ? _solved * 1000 : (won ? (5000 - seconds * 2 - game.mistakes * 300).clamp(100, 5000) : 0),
      stars: won ? stars : 0,
      seconds: seconds,
      moves: game.moves,
      hintsUsed: _hints,
      undosUsed: _undos,
      gameStats: {
        'digits_placed': _digits,
        'perfect_sudoku': won && game.mistakes == 0 && _hints == 0 ? 1 : 0,
        'x_sudoku': won && game.level.diagonal ? 1 : 0,
      },
    ));
  }

  Future<void> _hint() async {
    final i = game.hintCell();
    if (i == null) return;
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() {
      game.reveal(i);
      _sel = i;
    });
    _persist();
    if (game.won) _end(true);
  }

  Future<void> _autoNotes() async {
    if (!await ctx.requestBooster()) return;
    setState(game.autoNotes);
    _persist();
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final label = e.logicalKey.keyLabel;
    final d = int.tryParse(label);
    if (d != null && d >= 1 && d <= 9) {
      _input(d);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace || e.logicalKey == LogicalKeyboardKey.delete) {
      if (_sel >= 0) setState(() => game.erase(_sel));
      return KeyEventResult.handled;
    }
    var s = _sel < 0 ? 40 : _sel;
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) s -= 9;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) s += 9;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) s -= 1;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) s += 1;
    if (s != _sel && s >= 0 && s < 81) {
      setState(() => _sel = s);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    final l = game.level;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(children: [
        PlayHud(items: [
          (Icons.timer, timeText),
          (Icons.close, '${l.mistakeLimit > 0 ? '${game.mistakes}/${l.mistakeLimit}' : game.mistakes}'),
          if (l.diagonal) (Icons.close_fullscreen, 'X'),
          if (_chain) (Icons.emoji_events, '$_solved'),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final side = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) - 16;
            return Center(
              child: GestureDetector(
                onTapUp: (d) {
                  final cell = side / 9;
                  final x = (d.localPosition.dx / cell).floor().clamp(0, 8);
                  final y = (d.localPosition.dy / cell).floor().clamp(0, 8);
                  setState(() => _sel = y * 9 + x);
                  ctx.sfx(Sfx.tap);
                },
                child: Semantics(
                  label: 'sudoku grid',
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: _GridPainter(game, _sel, Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            );
          }),
        ),
        _pad(t),
        BoosterBar(buttons: [
          BoosterButton(Icons.undo, t('undo'), game.canUndo
              ? () {
                  setState(() {
                    game.undo();
                    _undos++;
                  });
                  _persist();
                }
              : null),
          BoosterButton(Icons.backspace, 'Erase', _sel >= 0 ? () => setState(() => game.erase(_sel)) : null),
          BoosterButton(Icons.edit_note, 'Notes', () => setState(() => _notesMode = !_notesMode), active: _notesMode),
          BoosterButton(Icons.auto_fix_high, 'Auto notes', _autoNotes),
          BoosterButton(Icons.lightbulb, t('hint'), _hint),
        ]),
      ]),
    );
  }

  Widget _pad(String Function(String, [Map<String, Object>]) t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        for (var d = 1; d <= 9; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(28, 52)),
                onPressed: game.countOf(d) >= 9 ? null : () => _input(d),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$d', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('${9 - game.countOf(d)}', style: const TextStyle(fontSize: 10)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  final SudokuGame g;
  final int sel;
  final Color accent;
  _GridPainter(this.g, this.sel, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 9;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final selVal = sel >= 0 ? g.values[sel] : 0;
    final peers = sel >= 0 ? g.peers[sel].toSet() : <int>{};
    for (var i = 0; i < 81; i++) {
      final x = i % 9, y = i ~/ 9;
      final r = Rect.fromLTWH(x * c, y * c, c, c);
      Color? bg;
      if (g.level.diagonal && (x == y || x + y == 8)) bg = const Color(0xFFF3E5F5);
      if (peers.contains(i)) bg = const Color(0xFFE3F2FD);
      if (selVal != 0 && g.values[i] == selVal) bg = const Color(0xFFBBDEFB);
      if (i == sel) bg = accent.withValues(alpha: 0.35);
      if (g.conflicts(i) && !g.isGiven(i)) bg = const Color(0xFFFFCDD2);
      if (bg != null) canvas.drawRect(r, Paint()..color = bg);
      final v = g.values[i];
      if (v != 0) {
        final wrong = v != g.level.solution[i];
        paintText(canvas, '$v', r.center, c * 0.6,
            g.isGiven(i) ? Colors.black87 : (wrong ? Colors.red : const Color(0xFF1565C0)),
            weight: g.isGiven(i) ? FontWeight.bold : FontWeight.w500);
      } else if (g.notes[i] != 0) {
        for (var d = 1; d <= 9; d++) {
          if (g.notes[i] & (1 << d) == 0) continue;
          final nx = (d - 1) % 3, ny = (d - 1) ~/ 3;
          paintText(canvas, '$d', Offset(x * c + (nx + 0.5) * c / 3, y * c + (ny + 0.5) * c / 3), c * 0.24,
              Colors.black54, weight: FontWeight.w400);
        }
      }
    }
    for (var k = 0; k <= 9; k++) {
      final p = Paint()
        ..color = Colors.black87
        ..strokeWidth = k % 3 == 0 ? 2.5 : 0.8;
      canvas.drawLine(Offset(k * c, 0), Offset(k * c, size.height), p);
      canvas.drawLine(Offset(0, k * c), Offset(size.width, k * c), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
