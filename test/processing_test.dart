import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/processing_screen.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/theme/app_theme.dart';

Future<({ProviderContainer container, GoRouter router})> mount(
  WidgetTester tester, {
  bool fromQa = false,
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
    initialLocation: Routes.create,
    routes: [
      GoRoute(
        path: Routes.create,
        builder: (_, _) => const Scaffold(body: Text('Destination /create')),
      ),
      GoRoute(
        path: Routes.processing,
        builder: (_, s) => ProcessingScreen(fromQa: s.uri.queryParameters['kind'] == 'qa'),
      ),
      GoRoute(
        path: Routes.confirm,
        builder: (_, _) => const Scaffold(body: Text('Destination /confirm')),
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
  await tester.pump();
  // Push so the screen has a page below it, as when it is opened from Buat profil.
  router.push('${Routes.processing}?kind=${fromQa ? 'qa' : 'pdf'}');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return (container: container, router: router);
}

Future<void> finish(WidgetTester tester) async {
  await tester.pump(ProcessingScreen.duration);
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

  testWidgets('shows progress with the current step, then a result state', (tester) async {
    await mount(tester, setup: (n) => n.useCvProfile(ProfileSource.cvPdf));
    expect(find.text('Membaca CV dan menyusun profilmu'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Mengunggah CV, (sedang berjalan|selesai)')), findsOneWidget);
    expect(find.bySemanticsLabel('Menyusun profil terstruktur, menunggu'), findsOneWidget);
    expect(find.text('Periksa profil'), findsNothing);

    await finish(tester);
    expect(find.text('Profilmu siap diperiksa'), findsOneWidget);
    expect(find.bySemanticsLabel('7 keterampilan'), findsOneWidget);
    expect(find.bySemanticsLabel('2 pengalaman'), findsOneWidget);
    expect(find.text('+3 lainnya'), findsOneWidget);
  });

  testWidgets('does not leave on its own; Periksa profil opens the review', (tester) async {
    await mount(tester);
    await finish(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Profilmu siap diperiksa'), findsOneWidget);
    await tester.tap(find.text('Periksa profil'));
    await tester.pumpAndSettle();
    expect(find.text('Destination /confirm'), findsOneWidget);
  });

  testWidgets('back is blocked while processing', (tester) async {
    await mount(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await tester.pump();
    expect(find.text('Membaca CV dan menyusun profilmu'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('photo and Q&A sources get their own wording', (tester) async {
    await mount(tester, setup: (n) => n.useCvProfile(ProfileSource.cvPhoto));
    expect(find.text('Membaca foto CV dan menyusun profilmu'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Q&A wording and result copy', (tester) async {
    await mount(
      tester,
      fromQa: true,
      setup: (n) => n.useQaProfile({
        0: 'SMA/SMK',
        2: ['Canva'],
        7: ['Kantor'],
      }),
    );
    expect(find.text('Menyusun profil dari jawabanmu'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Mengirim jawaban')), findsOneWidget);
    await finish(tester);
    expect(find.textContaining('dari jawabanmu. Periksa dulu'), findsOneWidget);
    expect(find.bySemanticsLabel('1 keterampilan'), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('processing has no overflow at width $width, text scale $scale', (tester) async {
        await mount(tester, width: width, scale: scale);
        expect(tester.takeException(), isNull);
        await finish(tester);
        await tester.scrollUntilVisible(find.text('+3 lainnya'), 150, scrollable: find.byType(Scrollable).first);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
