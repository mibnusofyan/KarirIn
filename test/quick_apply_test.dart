// Lamar cepat: the CV copy split for Firestore, the application model, the state actions on the Firebase path (against
// in-memory repositories) and the flow from Detail Lowongan to Pelacak on the mock build.

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:karirin/data/backend.dart';
import 'package:karirin/data/catalog_partner.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/data/repositories/application_repository.dart';
import 'package:karirin/data/repositories/auth_repository.dart';
import 'package:karirin/data/repositories/profile_repository.dart';
import 'package:karirin/data/repositories/providers.dart';
import 'package:karirin/data/repositories/user_repository.dart';
import 'package:karirin/router.dart';
import 'package:karirin/screens/job_detail_screen.dart';
import 'package:karirin/screens/quick_apply_screen.dart';
import 'package:karirin/screens/tracker_screen.dart';
import 'package:karirin/services/reminders.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/state/session.dart';
import 'package:karirin/theme/app_theme.dart';

final _pdf = Uint8List.fromList([...'%PDF-1.4'.codeUnits, ...List.filled(2000, 7)]);

void main() {
  setUpAll(() async {
    // Measure the bundled typeface, as the other screen tests do.
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'));
    }
    await loader.load();
  });

  group('CV terpotong', () {
    test('dipotong per 900 KB dan tersusun kembali utuh', () {
      final cv = Uint8List.fromList(List.generate(2 * 1024 * 1024, (i) => i % 251));
      final parts = splitCv(cv);
      expect(parts.map((p) => p.length), [cvPartBytes, cvPartBytes, cv.length - 2 * cvPartBytes]);
      expect(Uint8List.fromList([for (final p in parts) ...p]), cv);
    });

    test('CV maksimal 5 MB muat dalam enam potongan (batas firestore.rules)', () {
      expect(splitCv(Uint8List(maxQuickCvBytes)).length, 6);
      expect(splitCv(Uint8List(10)).length, 1);
    });

    test('ukuran berkas ditulis dalam KB atau MB', () {
      expect(formatFileSize(300 * 1024), '300 KB');
      expect(formatFileSize(1258291), '1,2 MB');
    });
  });

  group('model', () {
    test('lamaran cepat dibaca dengan catatan, riwayat berurutan, dan ukuran CV', () {
      final t = DateTime(2026, 10, 16, 9);
      final a = JobApplication.fromMap('q1', {
        'title': 'Admin Gudang',
        'company': 'CV Berkah Logistik',
        'status': 'wawancara',
        'quick': true,
        'note': 'Senin 27 Okt, 10.00 via Zoom.',
        'appliedAt': t,
        'cv': {'size': 320 * 1024, 'parts': 1},
        'statusHistory': [
          {'status': 'wawancara', 'at': t.add(const Duration(days: 2))},
          {'status': 'dikirim', 'at': t},
        ],
      }, toDate: (v) => v is DateTime ? v : null);
      expect(a.quick, isTrue);
      expect(a.note, 'Senin 27 Okt, 10.00 via Zoom.');
      expect(a.history.map((h) => h.status), [AppStage.dikirim, AppStage.wawancara]);
      expect(a.cvSize, 320 * 1024);
      expect(a.toMap()['quick'], isTrue);
    });

    test('lamaran situs perusahaan tidak menulis field quick', () {
      const a = JobApplication(id: 'a1', title: 'Kasir', company: 'Toko', status: AppStage.dikirim, date: '');
      expect(a.toMap().containsKey('quick'), isFalse);
      expect(JobApplication.fromMap('a1', a.toMap(), toDate: (v) => v is Timestamp ? v.toDate() : null).quick, isFalse);
    });

    test('lowongan mitra membawa quickApply; lowongan nyata tidak', () {
      final mitra = partnerJobs.first;
      expect(Job.fromMap(mitra.id, mitra.toMap()).quickApply, isTrue);
      expect(Job.fromMap('j2', jobs[1].toMap()).quickApply, isFalse);
      expect(jobs[1].toMap().containsKey('quickApply'), isFalse);
    });
  });

  group('aksi di jalur Firebase', () {
    late ProviderContainer c;
    late MockApplicationRepository apps;
    late MockAuthRepository auth;
    final job = jobs.firstWhere((j) => j.quickApply);

    AppNotifier n() => c.read(appProvider.notifier);
    AppState st() => c.read(appProvider);

    setUp(() async {
      session.value = SessionStatus.loading;
      auth = MockAuthRepository();
      apps = MockApplicationRepository({'demo': const []});
      final profiles = MockProfileRepository();
      await profiles.save('demo', raniProfile);
      c = ProviderContainer(
        overrides: [
          backendProvider.overrideWithValue(Backend.firebase),
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(MockUserRepository()),
          profileRepositoryProvider.overrideWithValue(profiles),
          applicationRepositoryProvider.overrideWithValue(apps),
          reminderSchedulerProvider.overrideWithValue(const NoopReminderScheduler()),
        ],
      );
      c.read(appProvider);
      await pumpEventQueue();
      await auth.signIn(email: 'rani@contoh.id', password: 'rahasia123');
      await pumpEventQueue();
    });
    tearDown(() => c.dispose());

    test('mengirim lamaran beserta profil, surat, CV, dan persetujuan', () async {
      final confirmed = await n().sendQuickApplication(job, cv: _pdf, letter: '  Dengan hormat  ', consent: quickApplyConsent(job));
      await pumpEventQueue();
      expect(confirmed, isTrue);
      final a = st().applications.single;
      expect(a.quick, isTrue);
      expect(a.status, AppStage.dikirim);
      expect(a.jobId, job.id);
      expect(a.cvSize, _pdf.length);
      expect(a.remind, isNull, reason: 'status Lamar cepat datang dari perusahaan, bukan pengingat tindak lanjut');
      final packet = apps.sent[a.id]!;
      expect(packet.cv, _pdf);
      expect(packet.letter, 'Dengan hormat');
      expect(packet.profile.name, raniProfile.name);
      expect(packet.consent, contains(job.company));
    });

    test('tidak bisa melamar dua kali atau saat offline', () async {
      await n().sendQuickApplication(job, cv: _pdf, letter: '', consent: 'setuju');
      expect(() => n().sendQuickApplication(job, cv: _pdf, letter: '', consent: 'setuju'), throwsA(isA<QuickApplyFailure>()));
      n().setOffline(true);
      final other = jobs.lastWhere((j) => j.quickApply && j.id != job.id);
      await expectLater(n().sendQuickApplication(other, cv: _pdf, letter: '', consent: 'setuju'), throwsA(isA<QuickApplyFailure>()));
      expect(st().applications.where((a) => a.jobId == other.id), isEmpty);
    });

    test('status lamaran cepat tidak dapat diubah pengguna; menarik lamaran menghapusnya', () async {
      await n().sendQuickApplication(job, cv: _pdf, letter: '', consent: 'setuju');
      await pumpEventQueue();
      final id = st().applications.single.id;
      n().updateApplication(id, AppStage.diterima, false);
      await pumpEventQueue();
      expect(st().applications.single.status, AppStage.dikirim);

      n().withdrawApplication(id);
      await pumpEventQueue();
      expect(st().applications, isEmpty);
      expect(apps.sent, isEmpty);
      expect(await apps.watch('demo').first, isEmpty);
    });
  });

  group('alur di aplikasi (build mock)', () {
    Future<(ProviderContainer, GoRouter)> mount(WidgetTester tester, String location) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(path: '/job/:id', builder: (_, s) => JobDetailScreen(jobId: s.pathParameters['id']!)),
          GoRoute(path: '/apply/:id', builder: (_, s) => QuickApplyScreen(jobId: s.pathParameters['id']!)),
          GoRoute(path: Routes.tracker, builder: (_, _) => const TrackerScreen()),
          for (final route in [Routes.home, Routes.gap, Routes.coach])
            GoRoute(path: route, builder: (_, s) => Scaffold(body: Text('Destination ${s.uri}'))),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return (container, router);
    }

    FilledButton sendButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.ancestor(of: find.text('Kirim lamaran'), matching: find.byType(FilledButton)));

    testWidgets('lowongan mitra dilamar di aplikasi setelah persetujuan, lalu tampil di Pelacak', (tester) async {
      final job = jobs.firstWhere((j) => j.quickApply);
      final (container, router) = await mount(tester, Routes.job(job.id));
      expect(find.text('Lamar cepat · Mitra demo'), findsOneWidget);

      await tester.tap(find.text('Lamar cepat'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickApplyScreen), findsOneWidget);
      expect(find.text('CV kamu (PDF)'), findsOneWidget, reason: 'CV Rani yang tersimpan di perangkat');
      expect(sendButton(tester).onPressed, isNull, reason: 'belum ada persetujuan');

      final consent = find.byType(CheckboxListTile);
      await tester.scrollUntilVisible(consent, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(consent);
      await tester.pumpAndSettle();
      await tester.tap(consent);
      await tester.pumpAndSettle();
      expect(sendButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Kirim lamaran'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, Routes.tracker);
      expect(find.text('Lamaran terkirim ke ${job.company}'), findsOneWidget);
      final sent = container.read(appProvider).applications.first;
      expect((sent.quick, sent.jobId), (true, job.id));
      // Let the toast go away; it covers the bottom of the list.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final details = find.bySemanticsLabel('Lihat detail ${job.title}');
      await tester.scrollUntilVisible(details, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Ubah status ${job.title}'), findsNothing);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Status diperbarui oleh ${job.company}. CV terkirim: PDF, ${formatFileSize(sent.cvSize!)}.'), findsOneWidget);

      await tester.tap(find.text('Tarik lamaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Tarik lamaran').last);
      await tester.pumpAndSettle();
      expect(container.read(appProvider).applicationFor(job), isNull);
      expect(find.text('Lamaran ke ${job.company} ditarik'), findsOneWidget);
    });

    testWidgets('lowongan yang sudah dilamar mengarah ke Pelacak', (tester) async {
      final job = jobs.firstWhere((j) => j.quickApply);
      final (container, router) = await mount(tester, Routes.job(job.id));
      await container.read(appProvider.notifier).sendQuickApplication(job, cv: _pdf, letter: '', consent: 'setuju');
      await tester.pumpAndSettle();
      expect(find.text('Lamar cepat'), findsNothing);
      await tester.tap(find.text('Lihat status lamaran'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, Routes.tracker);
    });

    testWidgets('lowongan perusahaan nyata tetap lewat situs perusahaan', (tester) async {
      await mount(tester, Routes.job('j3'));
      expect(find.text('Lamar cepat'), findsNothing);
      expect(find.text('Lamar cepat · Mitra demo'), findsNothing);
      expect(find.text('Lamar sekarang'), findsOneWidget);
    });
  });
}
