import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/logic/interview.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/result_screen.dart';
import 'package:karirin/screens/session_screen.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/theme/app_theme.dart';

Future<({ProviderContainer container, GoRouter router})> mount(
  WidgetTester tester, {
  required String location,
  double width = 390,
  double scale = 1,
  void Function(AppNotifier)? setup,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  setup?.call(container.read(appProvider.notifier));
  final router = GoRouter(
    initialLocation: Routes.coach,
    routes: [
      GoRoute(
        path: Routes.coach,
        builder: (_, _) => const Scaffold(body: Text('Destination /coach')),
      ),
      GoRoute(path: Routes.session, builder: (_, _) => const SessionScreen()),
      GoRoute(path: Routes.result, builder: (_, _) => const ResultScreen()),
      GoRoute(
        path: Routes.letter,
        builder: (_, state) => Scaffold(body: Text('Destination ${state.uri}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Push so the session/result has somewhere to go back to, as in the app.
  router.push(location);
  await tester.pumpAndSettle();
  return (container: container, router: router);
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder.hitTestable(), 150, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> answerWithDemo(WidgetTester tester) async {
  await reveal(tester, find.text('Isi contoh (demo)'));
  await tester.tap(find.text('Isi contoh (demo)'));
  await tester.pump();
  await tester.tap(find.text('Kirim jawaban'));
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle();
}

String location(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  group('Sesi latihan', () {
    testWidgets('a full session saves five graded answers and opens the results', (tester) async {
      final app = await mount(tester, location: Routes.session);
      for (var i = 0; i < 5; i++) {
        expect(find.text('Pertanyaan ${i + 1} dari 5'), findsOneWidget);
        await answerWithDemo(tester);
        expect(find.text('UMPAN BALIK'), findsOneWidget);
        expect(find.text('Yang sudah baik'), findsOneWidget);
        expect(find.text('Coba tingkatkan'), findsOneWidget);
        await tester.tap(find.text(i == 4 ? 'Lihat hasil latihan' : 'Pertanyaan berikutnya'));
        await tester.pumpAndSettle();
      }
      final saved = app.container.read(appProvider).interviewResults;
      expect(saved, hasLength(5));
      expect(saved.first.score.total, gradeAnswer(interviewJ1.first.demo).total);
      expect(location(app.router), Routes.result);
      expect(find.text('Hasil latihan'), findsOneWidget);
    });

    testWidgets('STAR help is collapsed until opened', (tester) async {
      await mount(tester, location: Routes.session);
      expect(find.textContaining('Konteks singkat'), findsNothing);
      await tester.tap(find.text('Bantuan: pola STAR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Konteks singkat'), findsOneWidget);
    });

    testWidgets('submit stays disabled below three words', (tester) async {
      final app = await mount(tester, location: Routes.session);
      await tester.enterText(find.byType(TextField), 'Saya bisa');
      await tester.pump();
      await tester.tap(find.text('Kirim jawaban'));
      await tester.pumpAndSettle();
      expect(find.text('UMPAN BALIK'), findsNothing);
      expect(find.text('2 kata · minimal 3 kata'), findsOneWidget);
      expect(app.container.read(appProvider).interviewResults, isEmpty);
    });

    testWidgets('closing with progress asks before discarding', (tester) async {
      final app = await mount(tester, location: Routes.session);
      await answerWithDemo(tester);
      await tester.tap(find.byTooltip('Tutup sesi'));
      await tester.pumpAndSettle();
      expect(find.text('Akhiri latihan?'), findsOneWidget);
      await tester.tap(find.text('Lanjut berlatih'));
      await tester.pumpAndSettle();
      expect(location(app.router), Routes.session);
      await tester.tap(find.byTooltip('Tutup sesi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Akhiri'));
      await tester.pumpAndSettle();
      expect(location(app.router), Routes.coach);
    });

    testWidgets('closing without progress leaves immediately', (tester) async {
      final app = await mount(tester, location: Routes.session);
      await tester.tap(find.byTooltip('Tutup sesi'));
      await tester.pumpAndSettle();
      expect(find.text('Akhiri latihan?'), findsNothing);
      expect(location(app.router), Routes.coach);
    });

    testWidgets('voice mode records (simulated) into an editable transcript', (tester) async {
      await mount(tester, location: Routes.session, setup: (n) => n.setVoiceMode(true));
      expect(find.text('Simulasi'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Mulai merekam'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mendengarkan… ketuk untuk berhenti'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Berhenti merekam'));
      await tester.pumpAndSettle();
      expect(find.text('Transkrip'), findsOneWidget);
      expect(find.text(interviewJ1.first.demo), findsOneWidget);
    });
  });

  group('Hasil latihan', () {
    testWidgets('shows one strength and one priority from the real averages', (tester) async {
      final results = [for (final q in interviewJ1) AnsweredQuestion(q, gradeAnswer(q.better))];
      await mount(tester, location: Routes.result, setup: (n) => n.saveInterviewResults(results));
      final avg = averageScore(results);
      final sorted = [...avg.aspects]..sort((a, b) => a.$2.compareTo(b.$2));
      expect(find.text('${avg.total}'), findsOneWidget);
      expect(find.text('Kekuatan utama · ${sorted.last.$1}'), findsOneWidget);
      expect(find.text('Prioritas berikutnya · ${sorted.first.$1}'), findsOneWidget);
      expect(find.textContaining('Contoh dari jawaban demo'), findsNothing);
    });

    testWidgets('without a finished session the example is labelled as such', (tester) async {
      await mount(tester, location: Routes.result);
      expect(find.textContaining('Contoh dari jawaban demo'), findsOneWidget);
    });

    testWidgets('a question expands to its own feedback', (tester) async {
      await mount(tester, location: Routes.result);
      final first = find.text(interviewJ1.first.text);
      await reveal(tester, first);
      await tester.tap(first.hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text(gradeAnswer(interviewJ1.first.demo).good), findsWidgets);
    });

    testWidgets('practise again restarts the session; letter keeps the job', (tester) async {
      final app = await mount(tester, location: Routes.result, setup: (n) => n.selectCoachJob('j4'));
      await tester.tap(find.text('Buat surat lamaran'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /letter?job=j4'), findsOneWidget);
      app.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latihan lagi'));
      await tester.pumpAndSettle();
      expect(location(app.router), Routes.session);
      expect(find.text('Pertanyaan 1 dari 5'), findsOneWidget);
    });
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('session and results have no overflow at width $width, text scale $scale', (tester) async {
        final app = await mount(tester, location: Routes.session, width: width, scale: scale);
        await reveal(tester, find.text('Bantuan: pola STAR'));
        await tester.tap(find.text('Bantuan: pola STAR'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await answerWithDemo(tester);
        await reveal(tester, find.text('Lihat contoh jawaban yang lebih baik'));
        await tester.tap(find.text('Lihat contoh jawaban yang lebih baik'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        app.router.pushReplacement(Routes.result);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Per pertanyaan'));
        final last = find.text(interviewJ1.last.text);
        await reveal(tester, last);
        await tester.tap(last.hitTestable().first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
