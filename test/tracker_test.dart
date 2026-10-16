import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/tracker_screen.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/theme/app_theme.dart';
import 'package:karirin/widgets/nav_shell.dart';

Future<({ProviderContainer container, GoRouter router})> mount(
  WidgetTester tester, {
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
    initialLocation: Routes.tracker,
    routes: [
      ShellRoute(
        builder: (_, state, child) => NavShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.tracker, builder: (_, _) => const TrackerScreen()),
          GoRoute(
            path: Routes.coach,
            builder: (_, _) => const Scaffold(body: Text('Destination /coach')),
          ),
        ],
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
  await tester.scrollUntilVisible(finder.hitTestable(), 150, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

JobApplication app(ProviderContainer c, String id) => c.read(appProvider).applications.firstWhere((a) => a.id == id);

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  testWidgets('summary counts active applications by stage', (tester) async {
    await mount(tester);
    // Sample data: Wawancara, Dikirim, Tes active; Ditolak finished.
    expect(find.bySemanticsLabel('3 lamaran aktif. Dikirim 1, Tes & wawancara 2, Selesai 1'), findsOneWidget);
  });

  testWidgets('agenda lists reminders of active applications and links interview practice to the job', (tester) async {
    final a = await mount(tester);
    await reveal(tester, find.text('Pengingat aktif'));
    expect(find.text('Wawancara 10 Okt, 09.00'), findsOneWidget);
    expect(find.text('Tes online 9 Okt, 10.00'), findsOneWidget);
    await tester.tap(find.text('Latihan wawancara'));
    await tester.pumpAndSettle();
    expect(a.container.read(appProvider).coachJobId, 'j4');
    expect(find.text('Destination /coach'), findsOneWidget);
  });

  testWidgets('filters split active and finished applications', (tester) async {
    await mount(tester);
    final finished = find.text('Selesai  1');
    await reveal(tester, finished);
    await tester.tap(finished);
    await tester.pumpAndSettle();
    expect(find.text('Staf Administrasi'), findsOneWidget);
    expect(find.text('Kasir'), findsNothing);
    await tester.tap(find.text('Aktif  3'));
    await tester.pumpAndSettle();
    expect(find.text('Staf Administrasi'), findsNothing);
    await reveal(tester, find.text('Kasir'));
    expect(find.text('Kasir'), findsOneWidget);
  });

  testWidgets('an empty filter explains itself and can return to all', (tester) async {
    await mount(tester, setup: (n) => n.updateApplication('a4', AppStage.tes, false));
    final finished = find.text('Selesai  0');
    await reveal(tester, finished);
    await tester.tap(finished);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Belum ada lamaran selesai'));
    await tester.tap(find.text('Lihat semua lamaran'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada lamaran selesai'), findsNothing);
  });

  testWidgets('status sheet previews the reminder and saves the new stage', (tester) async {
    final a = await mount(tester);
    final change = find.bySemanticsLabel('Ubah status Kasir');
    await reveal(tester, change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(find.text('Perbarui status'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Wawancara\\.')));
    await tester.pumpAndSettle();
    expect(find.text('Pengingat: Persiapan wawancara 15 Okt (7 hari lagi)'), findsOneWidget);
    await tester.tap(find.text('Simpan status'));
    await tester.pumpAndSettle();
    expect(app(a.container, 'a3').status, AppStage.wawancara);
    expect(app(a.container, 'a3').remind, 'Persiapan wawancara 15 Okt');
    expect(find.text('Status Kasir: Wawancara'), findsOneWidget);
  });

  testWidgets('finishing an application clears its reminder', (tester) async {
    final a = await mount(tester);
    final change = find.bySemanticsLabel('Ubah status Admin Media Sosial');
    await reveal(tester, change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Diterima\\.')));
    await tester.pumpAndSettle();
    expect(find.text('Ingatkan tindak lanjut'), findsNothing);
    await tester.tap(find.text('Simpan status'));
    await tester.pumpAndSettle();
    expect(app(a.container, 'a2').status, AppStage.diterima);
    expect(app(a.container, 'a2').remind, isNull);
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('tracker has no overflow at width $width, text scale $scale', (tester) async {
        await mount(tester, width: width, scale: scale);
        await reveal(tester, find.textContaining('KarirIn tidak melamar atas namamu'));
        expect(tester.takeException(), isNull);
        final change = find.bySemanticsLabel('Ubah status Staf Administrasi');
        await reveal(tester, change);
        await tester.tap(change);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
