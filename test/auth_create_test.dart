import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/auth_screen.dart';
import 'package:karirin/screens/create_profile_screen.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/theme/app_theme.dart';

Future<({ProviderContainer container, GoRouter router})> mount(
  WidgetTester tester, {
  required String location,
  double width = 390,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: Routes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(path: Routes.create, builder: (_, _) => const CreateProfileScreen()),
      for (final route in [Routes.qa, Routes.processing])
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

Finder field(String label) => find.widgetWithText(TextField, label);

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  group('Masuk/Daftar', () {
    testWidgets('errors appear under their field and clear while typing', (tester) async {
      final app = await mount(tester, location: Routes.auth);
      await reveal(tester, find.text('Masuk').last);
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Masukkan email yang valid, mis. nama@email.com.'), findsOneWidget);
      expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
      final emailBottom = tester.getBottomLeft(field('Email')).dy;
      expect(tester.getTopLeft(find.text('Masukkan email yang valid, mis. nama@email.com.')).dy, lessThan(emailBottom + 4));

      await tester.enterText(field('Email'), 'r');
      await tester.pump();
      expect(find.text('Masukkan email yang valid, mis. nama@email.com.'), findsNothing);
      expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
      expect(app.router.routeInformationProvider.value.uri.path, Routes.auth);
    });

    testWidgets('Daftar asks for a name and keeps it for the profile', (tester) async {
      final app = await mount(tester, location: Routes.auth);
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();
      expect(find.text('Mulai perjalanan\nkariermu.'), findsOneWidget);
      await tester.enterText(field('Nama lengkap'), 'Bayu Pratama');
      await tester.enterText(field('Email'), 'bayu@email.com');
      await tester.enterText(field('Kata sandi'), 'rahasia123');
      await reveal(tester, find.text('Buat akun'));
      await tester.tap(find.text('Buat akun'));
      await tester.pumpAndSettle();
      expect(app.container.read(appProvider).signupName, 'Bayu Pratama');
      expect(app.router.routeInformationProvider.value.uri.path, Routes.create);
    });

    testWidgets('switching mode clears old errors', (tester) async {
      await mount(tester, location: Routes.auth);
      await reveal(tester, find.widgetWithText(FilledButton, 'Masuk'));
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Daftar').hitTestable(), -120, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();
      expect(find.text('Kata sandi minimal 8 karakter.'), findsNothing);
      expect(find.text('Minimal 8 karakter.'), findsOneWidget);
    });

    testWidgets('password visibility can be toggled', (tester) async {
      await mount(tester, location: Routes.auth);
      bool obscured() => tester.widget<TextField>(field('Kata sandi')).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.byTooltip('Tampilkan kata sandi'));
      await tester.pump();
      expect(obscured(), isFalse);
    });

    testWidgets('with the keyboard open the submit button is still reachable', (tester) async {
      await mount(tester, location: Routes.auth, keyboard: 320);
      await reveal(tester, find.widgetWithText(FilledButton, 'Masuk'));
      expect(tester.takeException(), isNull);
      expect(tester.getBottomLeft(find.widgetWithText(FilledButton, 'Masuk')).dy, lessThanOrEqualTo(844 - 320));
    });
  });

  group('Buat profil', () {
    testWidgets('recommends the PDF path while keeping alternatives visible', (tester) async {
      await mount(tester, location: Routes.create);
      expect(find.text('Disarankan'), findsOneWidget);
      expect(find.text('Unggah CV (PDF)'), findsOneWidget);
      await reveal(tester, find.text('Belum punya CV?'));
      expect(find.text('Foto CV'), findsOneWidget);
    });

    testWidgets('CV upload needs explicit consent before processing', (tester) async {
      final app = await mount(tester, location: Routes.create);
      await tester.tap(find.text('Pilih berkas PDF'));
      await tester.pumpAndSettle();
      final accept = find.widgetWithText(FilledButton, 'Setuju & pilih berkas');
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await reveal(tester, accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(find.text('Destination /processing?kind=pdf'), findsOneWidget);
      expect(app.container.read(appProvider).profile.source, ProfileSource.cvPdf);
    });

    testWidgets('cancelling consent stays on the screen', (tester) async {
      final app = await mount(tester, location: Routes.create);
      await reveal(tester, find.text('Foto CV'));
      await tester.tap(find.text('Foto CV'));
      await tester.pumpAndSettle();
      expect(find.text('Setuju & buka kamera'), findsOneWidget);
      await reveal(tester, find.text('Batal'));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(app.router.routeInformationProvider.value.uri.path, Routes.create);
    });

    testWidgets('no CV goes to the Q&A', (tester) async {
      await mount(tester, location: Routes.create);
      await reveal(tester, find.text('Belum punya CV?'));
      await tester.tap(find.text('Belum punya CV?'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /qa'), findsOneWidget);
    });
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('auth and create profile have no overflow at width $width, text scale $scale', (tester) async {
        final app = await mount(tester, location: Routes.auth, width: width, scale: scale);
        await tester.tap(find.text('Daftar'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Buat akun'));
        await tester.tap(find.text('Buat akun'));
        await tester.pumpAndSettle();
        await reveal(tester, find.textContaining('belum tersambung ke server'));
        expect(tester.takeException(), isNull);

        app.router.go(Routes.create);
        await tester.pumpAndSettle();
        await reveal(tester, find.textContaining('bisa dihapus kapan saja'));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Foto CV').hitTestable(), -120, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('Foto CV'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
