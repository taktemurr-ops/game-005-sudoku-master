import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_005_sudoku_master/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home screen offers modes, statistics and offline privacy', (tester) async {
    await tester.pumpWidget(const SudokuMasterApp());
    expect(find.text('Sudoku Master'), findsOneWidget);
    expect(find.text('Kolay'), findsOneWidget);
    expect(find.text('Günlük'), findsOneWidget);
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Çevrimdışı'), findsOneWidget);
    expect(find.text('Yerel verileri sil'), findsOneWidget);
  });

  testWidgets('start a game, input, toggle notes and undo', (tester) async {
    await tester.pumpWidget(const SudokuMasterApp());
    await tester.tap(find.text('Kolay'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mistakes')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sudoku-0-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('digit-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('undo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pump();
    expect(find.byKey(const ValueKey('hint')), findsOneWidget);
  });
}
