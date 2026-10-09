import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/onboarding_screen.dart';
import 'package:karirin/screens/splash_screen.dart';
import 'package:karirin/theme/app_theme.dart';

Future<GoRouter> mount(
  WidgetTester tester, {
  required String location,
  double width = 390,
  double scale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: Routes.auth,
        builder: (_, _) => const Scaffold(body: Text('Destination /auth')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
  await tester.pump();
  return router;
}

/// Finds the onboarding illustration, also when decoded through ResizeImage (cacheWidth).
Finder illustration(String file) => find.byWidgetPredicate((w) {
  if (w is! Image) return false;
  final provider = w.image is ResizeImage ? (w.image as ResizeImage).imageProvider : w.image;
  return provider is AssetImage && provider.assetName == 'assets/images/onboarding/$file';
});

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  group('Splash', () {
    testWidgets('moves to onboarding after the short splash', (tester) async {
      await mount(tester, location: Routes.splash);
      expect(find.text('Cocok skill-nya, siap kerjanya.'), findsOneWidget);
      await tester.pump(SplashScreen.duration - const Duration(milliseconds: 100));
      expect(find.byType(OnboardingScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('tapping skips the splash once', (tester) async {
      await mount(tester, location: Routes.splash);
      await tester.tap(find.byType(SplashScreen));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('with reduced motion the logo is shown immediately', (tester) async {
      await mount(tester, location: Routes.splash, reduceMotion: true);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('Cocok skill-nya, siap kerjanya.'), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 1);
      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
    });
  });

  group('Onboarding', () {
    testWidgets('three stories, each with its illustration, then sign-in', (tester) async {
      await mount(tester, location: Routes.onboarding);
      await tester.pumpAndSettle();
      expect(find.text('TEMUKAN PELUANG'), findsOneWidget);
      expect(find.text('1 dari 3'), findsOneWidget);
      expect(illustration('lowongan yang cocok.png'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('TINGKATKAN KESIAPAN'), findsOneWidget);
      expect(illustration('meningkatkan skill.png'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('BERLATIH'), findsOneWidget);
      expect(illustration('latihan wawancara.png'), findsOneWidget);
      expect(find.text('Lewati'), findsNothing);
      await tester.tap(find.text('Mulai sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /auth'), findsOneWidget);
    });

    testWidgets('swiping moves between stories and Lewati goes to sign-in', (tester) async {
      await mount(tester, location: Routes.onboarding);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 dari 3'), findsOneWidget);
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      expect(find.text('Destination /auth'), findsOneWidget);
    });
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('splash and onboarding have no overflow at width $width, text scale $scale', (tester) async {
        await mount(tester, location: Routes.splash, width: width, scale: scale);
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        await tester.pump(SplashScreen.duration);
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(i == 2 ? 'Mulai sekarang' : 'Lanjut'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Destination /auth'), findsOneWidget);
      });
    }
  }

  test('onboarding illustrations are bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final name in ['lowongan yang cocok', 'meningkatkan skill', 'latihan wawancara']) {
      final data = await rootBundle.load('assets/images/onboarding/$name.png');
      expect(data.lengthInBytes, greaterThan(0), reason: name);
    }
  });
}
