import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/screens/session_screen.dart';
import 'package:karirin/theme/app_theme.dart';

void main() {
  testWidgets('demo answer can be filled on every question of a session', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const SessionScreen()),
      ),
    );

    for (var i = 0; i < 4; i++) {
      expect(find.text('Pertanyaan ${i + 1} dari 5'), findsOneWidget);
      final demo = find.text('Isi contoh (demo)');
      await tester.scrollUntilVisible(demo.hitTestable(), 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(demo);
      await tester.pump();
      expect(find.text(interviewJ1[i].demo), findsOneWidget, reason: 'demo fill on question ${i + 1}');

      await tester.tap(find.text('Kirim jawaban'));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.textContaining('/ 100 untuk jawaban ini', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Pertanyaan berikutnya'));
      await tester.pumpAndSettle();
    }
  });
}
