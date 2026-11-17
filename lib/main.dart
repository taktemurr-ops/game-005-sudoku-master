import 'package:flutter/material.dart';
import 'game/sudoku_game.dart';

void main() => runApp(const SudokuMasterApp());

class SudokuMasterApp extends StatelessWidget {
  const SudokuMasterApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sudoku Master',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const SudokuScreen(),
  );
}

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});
  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  SudokuGame game = SudokuGame.demo();
  int selectedRow = 0;
  int selectedColumn = 2;
  bool noteMode = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sudoku Master'),
      actions: [IconButton(
        tooltip: 'Restart puzzle',
        onPressed: () => setState(game.restart),
        icon: const Icon(Icons.refresh),
      )]),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 590),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Mistakes: ${game.mistakes}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AspectRatio(aspectRatio: 1, child: Column(
            children: List.generate(9, (r) => Expanded(
              child: Row(children: List.generate(9, (c) {
                final v = game.board[r][c];
                final selected = r == selectedRow && c == selectedColumn;
                final clue = game.fixed[r][c];
                final notes = game.notesAt(r, c).toList()..sort();
                return Expanded(child: InkWell(
                  key: ValueKey('sudoku-$r-$c'),
                  onTap: () => setState(() {
                    selectedRow = r;
                    selectedColumn = c;
                  }),
                  child: Semantics(
                    label: 'Row ${r + 1}, column ${c + 1}, ${v == 0 ? 'empty' : v}, notes ${notes.join(', ')}',
                    button: true,
                    child: Container(
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF317EA1) :
                        clue ? const Color(0xFF1C3149) : const Color(0xFF263F55),
                      border: Border(
                        right: BorderSide(
                          color: c % 3 == 2 ? Colors.white : Colors.white24,
                          width: c % 3 == 2 ? 2 : 0.4),
                        bottom: BorderSide(
                          color: r % 3 == 2 ? Colors.white : Colors.white24,
                          width: r % 3 == 2 ? 2 : 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: v == 0 && notes.isNotEmpty
                      ? FittedBox(child: Text(notes.join(' '),
                          style: const TextStyle(fontSize: 10, color: Colors.amberAccent),
                          textAlign: TextAlign.center))
                      : FittedBox(child: Text(v == 0 ? '' : '$v',
                          style: TextStyle(fontSize: 22, fontWeight: clue ?
                            FontWeight.bold : FontWeight.normal,
                            color: clue ? Colors.white : Colors.cyanAccent))),
                  )),
                ));
              })),
            )),
          )),
          const SizedBox(height: 20),
          Wrap(spacing: 5, runSpacing: 6, alignment: WrapAlignment.center,
            children: List.generate(9, (i) => SizedBox(
              width: 49, child: FilledButton.tonal(
                onPressed: () => setState(() =>
                  noteMode
                    ? game.toggleNote(selectedRow, selectedColumn, i + 1)
                    : game.input(selectedRow, selectedColumn, i + 1)),
                child: Text('${i+1}'),
              ),
            )),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            title: const Text('Pencil notes'),
            value: noteMode,
            onChanged: (value) => setState(() => noteMode = value),
          ),
          TextButton.icon(
            onPressed: () => setState(() => game.input(selectedRow, selectedColumn, 0)),
            icon: const Icon(Icons.backspace_outlined),
            label: const Text('Erase'),
          ),
          TextButton.icon(
            onPressed: game.complete ? null : () => setState(() {
              final hint = game.nextLogicalHint();
              if (hint != null) {
                selectedRow = hint.$1;
                selectedColumn = hint.$2;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Logical hint: row ${hint.$1 + 1}, column ${hint.$2 + 1} = ${hint.$3}'),
                ));
              } else {
                final options = game.candidatesAt(selectedRow, selectedColumn).toList()..sort();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(options.isEmpty
                    ? 'Select an empty cell to see candidates.'
                    : 'Candidates: ${options.join(', ')}'),
                ));
              }
            }),
            icon: const Icon(Icons.psychology_outlined),
            label: const Text('Free logical hint (no ad)'),
          ),
          TextButton.icon(
            onPressed: game.complete ? null : () => setState(() {
              final hint = game.revealHint();
              if (hint != null) {
                selectedRow = hint.$1;
                selectedColumn = hint.$2;
              }
            }),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text('Hint (${game.hintsUsed} used)'),
          ),
          Text(game.complete ? 'Puzzle solved!' : 'Select a cell and enter a number.',
            textAlign: TextAlign.center),
        ])),
    ))),
  );
}
