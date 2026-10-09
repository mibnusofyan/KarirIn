import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/logic/cover_letter.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/letter_screen.dart';
import 'package:karirin/screens/profile_screen.dart';
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
        routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
      ),
      GoRoute(
        path: Routes.letter,
        builder: (_, s) => LetterScreen(jobId: s.uri.queryParameters['job'] ?? 'j1'),
      ),
      for (final route in [Routes.confirm, Routes.auth, '/job/:id'])
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
  await tester.scrollUntilVisible(finder.hitTestable(), 150, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  group('Surat lamaran', () {
    testWidgets('shows the job, the highlighted skills and the letter for the profile', (tester) async {
      await mount(tester, location: '${Routes.letter}?job=j1');
      expect(find.text('Staf Administrasi Keuangan'), findsOneWidget);
      for (final s in letterHighlights(jobById('j1'), raniProfile)) {
        expect(find.text(s), findsOneWidget);
      }
      final letter = coverLetter(jobById('j1'), raniProfile, LetterTone.formal, 0);
      expect(find.text(letter), findsOneWidget);
      expect(find.text('Bagikan'), findsNothing);
    });

    testWidgets('tone switch and regenerate change the text', (tester) async {
      await mount(tester, location: '${Routes.letter}?job=j1');
      await tester.tap(find.text('Ringkas'));
      await tester.pumpAndSettle();
      expect(find.text(coverLetter(jobById('j1'), raniProfile, LetterTone.ringkas, 0)), findsOneWidget);
      await tester.tap(find.byTooltip('Buat ulang'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text(coverLetter(jobById('j1'), raniProfile, LetterTone.ringkas, 1)), findsOneWidget);
    });

    testWidgets('copy puts the exact letter on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await mount(tester, location: '${Routes.letter}?job=j4');
      await tester.tap(find.text('Salin surat'));
      await tester.pumpAndSettle();
      expect(copied, coverLetter(jobById('j4'), raniProfile, LetterTone.formal, 0));
      expect(find.text('Surat lamaran disalin'), findsOneWidget);
    });
  });

  group('Profil', () {
    testWidgets('identity and skills come first; learned skills are marked', (tester) async {
      await mount(tester, location: Routes.profile, setup: (n) => n.addSkill('Pelaporan Keuangan'));
      expect(find.text('Rani Lestari'), findsOneWidget);
      expect(find.text('Dari CV'), findsOneWidget);
      expect(find.bySemanticsLabel('Keterampilan 8'), findsOneWidget);
      final settings = tester.getTopLeft(find.text('Pengaturan', skipOffstage: false)).dy;
      expect(tester.getTopLeft(find.text('Keterampilan').first).dy, lessThan(settings));
    });

    testWidgets('edit opens the profile review in edit mode', (tester) async {
      await mount(tester, location: Routes.profile);
      await tester.tap(find.text('Edit profil'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /confirm?edit=1'), findsOneWidget);
    });

    testWidgets('deleting the CV asks first, keeps the profile and disables the action', (tester) async {
      final app = await mount(tester, location: Routes.profile);
      await reveal(tester, find.text('Hapus berkas CV'));
      await tester.tap(find.text('Hapus berkas CV'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus berkas CV?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).hasCv, isTrue);

      await tester.tap(find.text('Hapus berkas CV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus berkas'));
      await tester.pumpAndSettle();
      final st = app.container.read(appProvider);
      expect(st.hasCv, isFalse);
      expect(st.profile.name, 'Rani Lestari');
      expect(find.text('Berkas CV sudah dihapus'), findsOneWidget);
      await tester.tap(find.text('Hapus berkas CV'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus berkas CV?'), findsNothing);
    });

    testWidgets('a Q&A profile has no CV to delete', (tester) async {
      await mount(
        tester,
        location: Routes.profile,
        setup: (n) => n.useQaProfile({
          0: 'D3',
          7: ['Kantor'],
        }),
      );
      expect(find.text('Dari tanya-jawab'), findsOneWidget);
      await reveal(tester, find.text('Tidak ada CV; profil dari tanya-jawab'));
    });

    testWidgets('notification switches toggle the settings', (tester) async {
      final app = await mount(tester, location: Routes.profile);
      await reveal(tester, find.text('Lowongan baru yang cocok'));
      await tester.tap(find.text('Lowongan baru yang cocok'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).notifyNewJobs, isFalse);
    });

    testWidgets('deleting the account resets data and returns to sign-in', (tester) async {
      final app = await mount(tester, location: Routes.profile, setup: (n) => n.addSkill('SQL'));
      await reveal(tester, find.text('Hapus akun'));
      await tester.tap(find.text('Hapus akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus permanen'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /auth'), findsOneWidget);
      expect(app.container.read(appProvider).profile.skills, isNot(contains('SQL')));
    });
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('letter and profile have no overflow at width $width, text scale $scale', (tester) async {
        final app = await mount(tester, location: Routes.profile, width: width, scale: scale, setup: (n) => n.addSkill('SQL'));
        await reveal(tester, find.textContaining('UU No. 27 Tahun 2022'));
        expect(tester.takeException(), isNull);

        app.router.go('${Routes.letter}?job=j1');
        await tester.pumpAndSettle();
        await reveal(tester, find.textContaining('disusun dari templat'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('ProfileSource and CV state stay consistent after a new CV', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(appProvider.notifier)..deleteCv();
    expect(c.read(appProvider).hasCv, isFalse);
    n.useCvProfile(ProfileSource.cvPhoto);
    expect(c.read(appProvider).hasCv, isTrue);
  });
}
