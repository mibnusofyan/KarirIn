import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/logic/match_score.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/home_screen.dart';
import 'package:karirin/screens/job_detail_screen.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/theme/app_theme.dart';
import 'package:karirin/widgets/nav_shell.dart';

Future<({ProviderContainer container, GoRouter router})> mount(
  WidgetTester tester, {
  String location = '/home',
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
        builder: (_, state, child) =>
            NavShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
        ],
      ),
      GoRoute(
        path: '/job/:id',
        builder: (_, state) =>
            JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      for (final route in [
        Routes.gap,
        Routes.coach,
        Routes.letter,
        Routes.tracker,
        Routes.profile,
      ])
        GoRoute(
          path: route,
          builder: (_, state) =>
              Scaffold(body: Text('Destination ${state.uri}')),
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
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, router: router);
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Measure the actual bundled typeface, including wrapping at larger text sizes.
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        rootBundle.load(
          'assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf',
        ),
      );
    }
    await loader.load();
  });

  testWidgets('save toggles without opening the job, and persists in detail', (
    tester,
  ) async {
    final app = await mount(tester);
    final save = find.byTooltip('Simpan Staf Administrasi Keuangan');
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(app.container.read(appProvider).savedJobIds, contains('j1'));
    expect(app.router.routeInformationProvider.value.uri.path, Routes.home);
    expect(find.byType(JobDetailScreen), findsNothing);
    await tester.tap(find.text('Staf Administrasi Keuangan'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<JobDetailScreen>(find.byType(JobDetailScreen)).jobId,
      'j1',
    );
    await tester.tap(find.byTooltip('Hapus dari simpanan'));
    await tester.pumpAndSettle();
    expect(app.container.read(appProvider).savedJobIds, isNot(contains('j1')));
  });

  testWidgets('an empty category can return to all opportunities', (
    tester,
  ) async {
    await mount(
      tester,
      setup: (n) {
        // Every job becomes high/mid after mastering all skills: low should be empty.
        for (final skill
            in jobs.expand((j) => [...j.wajib, ...j.tambahan]).toSet()) {
          n.addSkill(skill);
        }
      },
    );
    final low = find.text('Perlu Persiapan  0');
    await tester.scrollUntilVisible(
      low,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(low);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada di kategori ini'), findsOneWidget);
    await tester.tap(find.text('Lihat semua lowongan'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada di kategori ini'), findsNothing);
    expect(find.text('Peluang untukmu'), findsOneWidget);
  });

  testWidgets(
    'score breakdown preserves all five reasons and the real computed score',
    (tester) async {
      final app = await mount(tester, location: '/job/j1');
      expect(find.text('Dihitung secara transparan'), findsNothing);
      await reveal(tester, find.text('Rincian Match Score'));
      await tester.tap(find.text('Rincian Match Score'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Dihitung secara transparan'));
      expect(find.text('37,5 / 50'), findsOneWidget);
      expect(find.text('7,5 / 15'), findsOneWidget);
      expect(find.text('Lokasi & preferensi · 10%'), findsOneWidget);
      app.container.read(appProvider.notifier).addSkill('Pelaporan Keuangan');
      await tester.pumpAndSettle();
      expect(
        computeMatch(
          jobById('j1'),
          app.container.read(appProvider).profile,
        ).total,
        92.5,
      );
      expect(find.text('Lamar di situs resmi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preparation routes to the selected job and keeps cover letter context',
    (tester) async {
      final app = await mount(tester, location: '/job/j4');
      await tester.tap(find.text('Persiapan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latihan wawancara'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).coachJobId, 'j4');
      expect(app.router.routeInformationProvider.value.uri.path, Routes.coach);
      app.router.go('/job/j4');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Persiapan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat surat lamaran'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /letter?job=j4'), findsOneWidget);
    },
  );

  testWidgets(
    'learning action uses the selected job and application requires explicit confirmation',
    (tester) async {
      final app = await mount(tester, location: '/job/j3');
      await tester.tap(find.text('Tingkatkan kecocokan'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).gapJobId, 'j3');
      expect(app.router.routeInformationProvider.value.uri.path, Routes.gap);
      app.router.go('/job/j3');
      await tester.pumpAndSettle();
      final before = app.container.read(appProvider).applications.length;
      await tester.tap(find.text('Lamar sekarang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nanti saja'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).applications.length, before);
      await tester.tap(find.text('Lamar sekarang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catat lamaran (demo)'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).applications.length, before + 1);
      expect(
        app.router.routeInformationProvider.value.uri.path,
        Routes.tracker,
      );
    },
  );

  testWidgets('offline retry restores the opportunities list', (tester) async {
    final app = await mount(tester, setup: (n) => n.setOffline(true));
    expect(find.text('Koneksi terputus'), findsOneWidget);
    expect(find.text('Peluang untukmu'), findsNothing);
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    expect(find.text('Memuat ulang…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(app.container.read(appProvider).offline, false);
    expect(find.text('Peluang untukmu'), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'discovery has no overflow at width $width and text scale $scale',
        (tester) async {
          final app = await mount(tester, width: width, scale: scale);
          await reveal(tester, find.text('Staf Administrasi Keuangan'));
          expect(tester.takeException(), isNull);
          app.router.go('/job/j1');
          await tester.pumpAndSettle();
          await reveal(tester, find.text('Rincian Match Score'));
          await tester.tap(find.text('Rincian Match Score'));
          await tester.pumpAndSettle();
          await reveal(tester, find.text('Dihitung secara transparan'));
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Persiapan'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
