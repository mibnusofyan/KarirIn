import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/logic/match_score.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/coach_screen.dart';
import 'package:karirin/screens/skill_gap_screen.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/theme/app_theme.dart';
import 'package:karirin/widgets/nav_shell.dart';

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
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (_, state, child) => NavShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.gap, builder: (_, _) => const SkillGapScreen()),
          GoRoute(path: Routes.coach, builder: (_, _) => const CoachScreen()),
        ],
      ),
      for (final route in [Routes.home, Routes.session, Routes.letter])
        GoRoute(
          path: route,
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
  return (container: container, router: router);
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// True when [finder] lies fully inside the visible screen, above the navigation bar.
bool onFirstScreen(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
  return rect.top >= 0 && rect.bottom <= navTop;
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  group('Rencana belajar', () {
    testWidgets('shows the target job, real score, potential and steps ordered by impact', (tester) async {
      await mount(tester, location: Routes.gap);
      expect(find.text('Staf Administrasi Keuangan'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('2 skill lagi menuju potensi 100.'), findsOneWidget);
      await reveal(tester, find.text('Software Akuntansi'));
      final first = tester.getTopLeft(find.text('Pelaporan Keuangan')).dy;
      final second = tester.getTopLeft(find.text('Software Akuntansi')).dy;
      expect(first, lessThan(second));
      expect(find.text('+12,5 poin'), findsOneWidget);
      expect(find.text('+7,5 poin'), findsOneWidget);
    });

    testWidgets('marking a skill recomputes 80 → 92,5 and moves it to mastered', (tester) async {
      final app = await mount(tester, location: Routes.gap);
      final button = find.bySemanticsLabel('Tandai Pelaporan Keuangan sudah saya kuasai');
      await reveal(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).learned, ['Pelaporan Keuangan']);
      expect(find.text('92,5'), findsWidgets);
      expect(find.text('Match Score Staf Administrasi Keuangan: 80 → 92,5'), findsOneWidget);
      await reveal(tester, find.text('Sudah kamu kuasai'));
      expect(find.text('Dikuasai'), findsOneWidget);
      expect(find.text('1 skill lagi menuju potensi 100.'), findsOneWidget);
    });

    testWidgets('resource sheet can mark the skill as mastered', (tester) async {
      final app = await mount(tester, location: Routes.gap);
      final resource = find.text('Dasar Menyusun Laporan Keuangan');
      await reveal(tester, resource);
      await tester.tap(resource);
      await tester.pumpAndSettle();
      expect(find.text('Konsep dasar'), findsOneWidget);
      await tester.tap(find.text('Tandai dikuasai'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).profile.skills, contains('Pelaporan Keuangan'));
      expect(find.text('Konsep dasar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the target uses the picker and keeps the choice', (tester) async {
      final app = await mount(tester, location: Routes.gap);
      await tester.tap(find.bySemanticsLabel('Ganti lowongan, saat ini Staf Administrasi Keuangan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Junior Data Analyst').last);
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).gapJobId, 'j3');
      expect(find.text('Junior Data Analyst'), findsOneWidget);
    });

    testWidgets('a complete job offers interview practice for that job', (tester) async {
      final app = await mount(
        tester,
        location: Routes.gap,
        setup: (n) {
          for (final s in [...jobById('j1').wajib, ...jobById('j1').tambahan]) {
            n.addSkill(s);
          }
        },
      );
      await reveal(tester, find.text('Skill untuk lowongan ini lengkap'));
      await tester.tap(find.text('Latihan wawancara'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).coachJobId, 'j1');
      expect(app.router.routeInformationProvider.value.uri.path, Routes.coach);
    });
  });

  group('Persiapan latihan', () {
    testWidgets('selected job, answer mode and start fit on the first screen at 390 × 844', (tester) async {
      await mount(tester, location: Routes.coach);
      expect(onFirstScreen(tester, find.text('Staf Administrasi Keuangan')), isTrue);
      expect(onFirstScreen(tester, find.bySemanticsLabel(RegExp('Jawab dengan Ketik'))), isTrue);
      expect(onFirstScreen(tester, find.bySemanticsLabel(RegExp('Jawab dengan Suara'))), isTrue);
      expect(onFirstScreen(tester, find.text('Mulai latihan')), isTrue);
      // The long radio list of every job is gone from the screen.
      expect(find.text('Junior Data Analyst'), findsNothing);
    });

    testWidgets('job can be changed, mode toggled, and the session started', (tester) async {
      final app = await mount(tester, location: Routes.coach);
      await tester.tap(find.bySemanticsLabel('Ganti lowongan, saat ini Staf Administrasi Keuangan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer Service Officer').last);
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).coachJobId, 'j4');

      await tester.tap(find.bySemanticsLabel(RegExp('Jawab dengan Suara')));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).voiceMode, isTrue);
      expect(find.textContaining('rekaman suara masih simulasi'), findsOneWidget);

      await tester.tap(find.text('Mulai latihan'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /session'), findsOneWidget);
    });

    testWidgets('the tab is named Belajar', (tester) async {
      await mount(tester, location: Routes.coach);
      expect(find.text('Belajar'), findsOneWidget);
      expect(find.text('Skill Gap'), findsNothing);
    });
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('learning and practice have no overflow at width $width, text scale $scale', (tester) async {
        final app = await mount(tester, location: Routes.gap, width: width, scale: scale);
        final resource = find.text(resourceFor('Pelaporan Keuangan').title);
        await reveal(tester, resource);
        await tester.tap(resource);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();
        await reveal(tester, find.textContaining('Materi gratis dikurasi'));
        expect(tester.takeException(), isNull);

        app.router.go(Routes.coach);
        await tester.pumpAndSettle();
        await reveal(tester, find.textContaining('Setiap jawaban mendapat umpan balik'));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Ganti'), -180, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ganti'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('learning potential matches the score logic', () {
    final job = jobById('j1');
    final r = computeMatch(job, raniProfile);
    final all = raniProfile.copyWith(skills: [...raniProfile.skills, ...skillGap(job, r).map((g) => g.skill)]);
    expect(computeMatch(job, all).total, 100);
  });
}
