import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_005_sudoku_master/main.dart';

void main() {
  testWidgets('Sudoku Master initial screen renders on a phone', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const SudokuMasterApp());
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Sudoku Master'), findsOneWidget);
  });
}
