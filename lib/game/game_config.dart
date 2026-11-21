import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'rules.dart';
import 'sudoku_view.dart';

final gameConfig = GameConfig(
  gameId: 'game-005-sudoku-master',
  title: const ['Sudoku Ustası', 'Sudoku Master', 'Sudoku Meister', 'Maestro del Sudoku', 'Maître du Sudoku'],
  tagline: const [
    'Klasik ve çapraz Sudoku, sınırsız bulmaca!',
    'Classic and X-Sudoku, unlimited puzzles!',
    'Klassisches und X-Sudoku ohne Ende!',
    '¡Sudoku clásico y X, sin límites!',
    'Sudoku classique et X, à l\'infini !',
  ],
  seedColor: const Color(0xFF1565C0),
  icon: Icons.grid_on,
  rules: SudokuRules(),
  buildPlay: (ctx) => SudokuView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.grid_3x3, [
      'Her satır, sütun ve 3×3 kutuya 1-9 rakamlarını birer kez yerleştir.',
      'Place digits 1-9 once in every row, column and 3×3 box.',
      'Jede Ziffer 1-9 einmal pro Zeile, Spalte und Box.',
      'Cada dígito 1-9 una vez por fila, columna y caja.',
      'Chaque chiffre 1-9 une fois par ligne, colonne et bloc.',
    ]),
    TutorialStep(Icons.close_fullscreen, [
      'Çapraz (X) bölümlerde iki köşegen de 1-9 içermelidir.',
      'In X levels both diagonals must contain 1-9 as well.',
      'Bei X-Leveln gelten auch beide Diagonalen.',
      'En niveles X también cuentan las diagonales.',
      'Dans les niveaux X, les diagonales comptent aussi.',
    ]),
    TutorialStep(Icons.edit_note, [
      'Not modu ile aday rakamları yaz; otomatik not güçlendiricisi tüm adayları doldurur.',
      'Use notes mode for candidates; the auto-notes booster fills them all.',
      'Notizmodus für Kandidaten; Auto-Notizen füllt alle.',
      'Usa notas; las notas automáticas rellenan todo.',
      'Mode notes ; les notes auto remplissent tout.',
    ]),
  ],
);
