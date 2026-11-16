import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/domain/game_engine.dart';
import 'package:kirain/ui/widgets/answer_boxes.dart';
import 'package:kirain/ui/widgets/letter_board.dart';

// Memakai ThemeData biasa agar test tidak mengunduh font lewat google_fonts.
Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('LetterBoard menampilkan huruf tersedia dan meneruskan tap', (
    tester,
  ) async {
    final tiles = [
      for (var i = 0; i < 14; i++)
        TileView(
          id: i,
          letter: String.fromCharCode(65 + i),
          hidden: i == 1,
          used: i == 2,
        ),
    ];
    final tapped = <int>[];
    await tester.pumpWidget(wrap(LetterBoard(tiles: tiles, onTap: tapped.add)));

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing); // tersembunyi
    expect(find.text('C'), findsNothing); // terpakai
    await tester.tap(find.text('D'));
    expect(tapped, [3]);
  });

  testWidgets('AnswerBoxes: kotak terkunci tidak meneruskan tap', (
    tester,
  ) async {
    const slots = [
      SlotView(letter: 'K', locked: true),
      SlotView(letter: 'U'),
      SlotView(),
    ];
    final tapped = <int>[];
    await tester.pumpWidget(wrap(AnswerBoxes(slots: slots, onTap: tapped.add)));

    await tester.tap(find.text('K'));
    await tester.tap(find.text('U'));
    expect(tapped, [1]);
  });

  testWidgets('AnswerBoxes: jawaban panjang dipecah menjadi 2 baris', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final slots = [for (final c in 'BAWANGPUTIH'.split('')) SlotView(letter: c)];
    final tapped = <int>[];
    await tester.pumpWidget(wrap(AnswerBoxes(slots: slots, onTap: tapped.add)));

    expect(find.byType(Row), findsNWidgets(2));
    // 'B' di baris pertama, 'U' (indeks 7) di baris kedua.
    final b = tester.getCenter(find.text('B'));
    final u = tester.getCenter(find.text('U'));
    expect(u.dy, greaterThan(b.dy));
    await tester.tap(find.text('U'));
    expect(tapped, [7]);
  });

  testWidgets('AnswerBoxes: jawaban pendek tetap 1 baris', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final slots = [for (final c in 'KUDA'.split('')) SlotView(letter: c)];
    await tester.pumpWidget(wrap(AnswerBoxes(slots: slots, onTap: (_) {})));

    expect(find.byType(Row), findsOneWidget);
  });
}
