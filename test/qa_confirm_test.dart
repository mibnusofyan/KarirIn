import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/logic/match_score.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/confirm_profile_screen.dart';
import 'package:karirin/screens/qa_screen.dart';
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
    initialLocation: location,
    routes: [
      GoRoute(path: Routes.qa, builder: (_, _) => const QaScreen()),
      GoRoute(
        path: Routes.confirm,
        builder: (_, s) => ConfirmProfileScreen(editing: s.uri.queryParameters['edit'] == '1'),
      ),
      for (final route in [Routes.create, Routes.processing, Routes.home])
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
  await tester.scrollUntilVisible(finder.hitTestable(), 120, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Finder choice(String label) => find.bySemanticsLabel(label);

Future<void> tapChoice(WidgetTester tester, String label) async {
  await reveal(tester, choice(label));
  await tester.tap(choice(label));
  await tester.pump();
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Lanjut'));
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.ancestor(of: find.text(label), matching: find.byType(FilledButton))).onPressed != null;

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  group('Tanya jawab', () {
    testWidgets('all eight questions build a profile and start processing', (tester) async {
      final app = await mount(tester, location: Routes.qa, setup: (n) => n.setSignupName('Bayu Pratama'));
      expect(find.text('1 dari 8'), findsOneWidget);
      expect(enabled(tester, 'Lanjut'), isFalse);
      await tapChoice(tester, 'SMA/SMK');
      expect(enabled(tester, 'Lanjut'), isTrue);
      await next(tester);

      await tester.enterText(find.byType(TextField), 'Teknik Komputer dan Jaringan');
      await tester.pump();
      await next(tester);

      await tapChoice(tester, 'Microsoft Excel');
      await tapChoice(tester, 'Jaringan Komputer');
      expect(find.text('2 dipilih'), findsOneWidget);
      await next(tester);

      await tapChoice(tester, 'Magang/PKL');
      await next(tester);

      await tester.enterText(find.byType(TextField), 'Saat PKL saya memasang jaringan di 20 komputer.');
      await tester.pump();
      await next(tester);

      await tapChoice(tester, 'Teknologi Informasi');
      await next(tester);
      await tapChoice(tester, 'Purwokerto');
      await next(tester);
      await tapChoice(tester, 'Kantor');
      await tester.tap(find.text('Susun profil saya'));
      await tester.pumpAndSettle();

      expect(find.text('Destination /processing?kind=qa'), findsOneWidget);
      final p = app.container.read(appProvider).profile;
      expect(p.name, 'Bayu Pratama');
      expect(p.level, EduLevel.smaSmk);
      expect(p.major, 'Teknik Komputer dan Jaringan');
      expect(p.skills, ['Microsoft Excel', 'Jaringan Komputer']);
      expect(p.exps.single.title, 'Praktik Kerja Lapangan');
      expect(p.source, ProfileSource.qa);
    });

    testWidgets('"Belum ada" excludes other experience options', (tester) async {
      await mount(tester, location: Routes.qa);
      await tapChoice(tester, 'S1');
      await next(tester);
      await tester.enterText(find.byType(TextField), 'Manajemen');
      await tester.pump();
      await next(tester);
      await tapChoice(tester, 'Canva');
      await next(tester);

      bool selected(String label) => tester.getSemantics(choice(label)).flagsCollection.isSelected;
      await tapChoice(tester, 'Organisasi');
      await tapChoice(tester, 'Magang/PKL');
      await tapChoice(tester, 'Belum ada');
      expect(selected('Belum ada'), isTrue);
      expect(selected('Organisasi'), isFalse);
      expect(selected('Magang/PKL'), isFalse);
      await tapChoice(tester, 'Organisasi');
      expect(selected('Belum ada'), isFalse);
      expect(selected('Organisasi'), isTrue);
    });

    testWidgets('Kembali keeps earlier answers; back from the first question returns to Buat profil', (tester) async {
      await mount(tester, location: Routes.qa);
      await tapChoice(tester, 'D3');
      await next(tester);
      expect(find.text('Kembali'), findsOneWidget);
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('1 dari 8'), findsOneWidget);
      expect(tester.getSemantics(choice('D3')).flagsCollection.isSelected, isTrue);
      expect(find.text('Kembali'), findsNothing);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /create'), findsOneWidget);
    });
  });

  group('Periksa profil', () {
    testWidgets('groups identity, skills, experience and preferences with a summary', (tester) async {
      await mount(tester, location: Routes.confirm);
      expect(find.text('Rani Lestari'), findsOneWidget);
      expect(find.text('Langkah 2 dari 2'), findsOneWidget);
      for (final s in ['Keterampilan', 'Pengalaman', 'Preferensi kerja']) {
        await reveal(tester, find.text(s));
      }
      expect(find.text('7 keterampilan · 2 pengalaman · Kantor, Hybrid'), findsOneWidget);
    });

    testWidgets('adding a skill normalises it and explains the change', (tester) async {
      final app = await mount(tester, location: Routes.confirm);
      final input = find.widgetWithText(TextField, 'Tambah keterampilan');
      await reveal(tester, input);
      await tester.enterText(input, 'ms excel');
      await tester.tap(find.bySemanticsLabel('Tambah keterampilan').last);
      await tester.pumpAndSettle();
      expect(find.text('Microsoft Excel sudah ada di profilmu.'), findsOneWidget);
      await tester.enterText(input, 'SQL');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).profile.skills, contains('SQL'));
    });

    testWidgets('removing every work mode blocks saving with a clear reason', (tester) async {
      await mount(tester, location: Routes.confirm);
      for (final m in ['Kantor', 'Hybrid']) {
        await reveal(tester, find.bySemanticsLabel(m));
        await tester.tap(find.bySemanticsLabel(m));
        await tester.pumpAndSettle();
      }
      expect(find.text('Pilih minimal satu mode kerja.'), findsOneWidget);
      expect(enabled(tester, 'Simpan & lihat lowongan'), isFalse);
      await tester.tap(find.bySemanticsLabel('Remote'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'Simpan & lihat lowongan'), isTrue);
      await tester.tap(find.text('Simpan & lihat lowongan'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /home'), findsOneWidget);
    });

    testWidgets('editing identity updates the profile and the Match Score inputs', (tester) async {
      final app = await mount(tester, location: Routes.confirm);
      await tester.tap(find.bySemanticsLabel('Ubah identitas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Jurusan'), 'Akuntansi');
      await tester.enterText(find.widgetWithText(TextField, 'Kota'), 'Banyumas');
      await reveal(tester, find.text('Simpan').last);
      await tester.tap(find.text('Simpan').last);
      await tester.pumpAndSettle();
      final p = app.container.read(appProvider).profile;
      expect(p.major, 'Akuntansi');
      expect(p.city, 'Banyumas');
      expect(find.text('Identitas diperbarui'), findsOneWidget);
      // j5 requires S1 Akuntansi in Banyumas: education and location now fully match.
      final r = computeMatch(jobById('j5'), p);
      expect(r.sp, 1);
      expect(r.sl, 1);
    });

    testWidgets('identity requires a name', (tester) async {
      final app = await mount(tester, location: Routes.confirm);
      await tester.tap(find.bySemanticsLabel('Ubah identitas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nama lengkap'), '  ');
      await reveal(tester, find.text('Simpan').last);
      await tester.tap(find.text('Simpan').last);
      await tester.pumpAndSettle();
      expect(find.text('Nama wajib diisi.'), findsOneWidget);
      expect(app.container.read(appProvider).profile.name, 'Rani Lestari');
    });
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('Q&A and profile review have no overflow at width $width, text scale $scale', (tester) async {
        final app = await mount(tester, location: Routes.qa, width: width, scale: scale);
        await tapChoice(tester, 'S1');
        await next(tester);
        await tester.enterText(find.byType(TextField), 'Manajemen');
        await tester.pump();
        await next(tester);
        await reveal(tester, choice('Copywriting'));
        expect(tester.takeException(), isNull);

        app.router.go(Routes.confirm);
        await tester.pumpAndSettle();
        await reveal(tester, find.bySemanticsLabel('Remote'));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.bySemanticsLabel('Ubah identitas').hitTestable(),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.bySemanticsLabel('Ubah identitas'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
