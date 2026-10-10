// Tahap B3 on the Firebase path, against in-memory repositories: applications, reminders, learning proofs and
// score snapshots.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/backend.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/data/repositories/activity_repository.dart';
import 'package:karirin/data/repositories/application_repository.dart';
import 'package:karirin/data/repositories/auth_repository.dart';
import 'package:karirin/data/repositories/profile_repository.dart';
import 'package:karirin/data/repositories/providers.dart';
import 'package:karirin/data/repositories/user_repository.dart';
import 'package:karirin/services/reminders.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/state/session.dart';

class _RecordingReminders implements ReminderScheduler {
  final scheduled = <String, JobApplication>{};
  int permissionRequests = 0;
  bool cleared = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> show({required String title, required String body, required String payload}) async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> schedule(JobApplication a) async {
    if (a.reminderAt == null || a.remind == null || !a.status.isActive) {
      scheduled.remove(a.id);
    } else {
      scheduled[a.id] = a;
    }
  }

  @override
  Future<void> cancel(String applicationId) async => scheduled.remove(applicationId);

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
    cleared = true;
  }
}

void main() {
  late ProviderContainer c;
  late MockApplicationRepository apps;
  late MockProfileRepository profiles;
  late MockActivityRepository activity;
  late _RecordingReminders reminders;
  late MockAuthRepository auth;

  AppNotifier n() => c.read(appProvider.notifier);
  AppState st() => c.read(appProvider);

  Future<void> signIn({List<JobApplication> existing = const []}) async {
    session.value = SessionStatus.loading;
    auth = MockAuthRepository();
    apps = MockApplicationRepository({'demo': existing});
    profiles = MockProfileRepository();
    activity = MockActivityRepository();
    reminders = _RecordingReminders();
    await profiles.save('demo', raniProfile);
    c = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(Backend.firebase),
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(MockUserRepository()),
        profileRepositoryProvider.overrideWithValue(profiles),
        applicationRepositoryProvider.overrideWithValue(apps),
        activityRepositoryProvider.overrideWithValue(activity),
        reminderSchedulerProvider.overrideWithValue(reminders),
      ],
    );
    c.read(appProvider);
    await pumpEventQueue();
    await auth.signIn(email: 'rani@contoh.id', password: 'rahasia123');
    await pumpEventQueue();
  }

  tearDown(() => c.dispose());

  test('mencatat lamaran: tanggal nyata, tersimpan, pengingat H+7 pukul 09.00 terjadwal', () async {
    await signIn();
    final before = DateTime.now();
    n().recordApplication(jobs.first);
    await pumpEventQueue();
    final a = (await apps.watch('demo').first).single;
    expect(a.jobId, jobs.first.id);
    expect(a.appliedAt!.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    expect(a.date, formatShortDateId(a.appliedAt!));
    final due = DateTime(before.year, before.month, before.day + 7, 9);
    expect(a.reminderAt, due);
    expect(a.remind, 'Tindak lanjut ${formatShortDateId(due)}');
    expect(reminders.scheduled.keys, [a.id]);
    expect(reminders.permissionRequests, 1);
    expect(st().applications.single.id, a.id, reason: 'state mengikuti stream');
  });

  test('ubah status: wawancara memakai label persiapan; status selesai membatalkan pengingat', () async {
    await signIn();
    n().recordApplication(jobs[1]);
    await pumpEventQueue();
    final id = st().applications.single.id;

    n().updateApplication(id, AppStage.wawancara, true);
    await pumpEventQueue();
    expect(st().applications.single.remind, startsWith('Persiapan wawancara '));
    expect(reminders.scheduled[id]?.status, AppStage.wawancara);

    n().updateApplication(id, AppStage.ditolak, false);
    await pumpEventQueue();
    final stored = (await apps.watch('demo').first).single;
    expect(stored.status, AppStage.ditolak);
    expect(stored.remind, isNull);
    expect(stored.reminderAt, isNull);
    expect(reminders.scheduled, isEmpty);
  });

  test('lamaran tersimpan dimuat saat masuk dan pengingatnya dijadwalkan ulang di perangkat', () async {
    final future = DateTime.now().add(const Duration(days: 3));
    await signIn(
      existing: [
        JobApplication(id: 'x1', title: 'Kasir', company: 'Toko Swalayan Mitra', status: AppStage.tes, date: '', reminderAt: future, remind: 'Tindak lanjut'),
        JobApplication(id: 'x2', title: 'Admin', company: 'PT Graha Niaga', status: AppStage.diterima, date: ''),
      ],
    );
    expect(st().applications.map((a) => a.id), ['x1', 'x2']);
    expect(reminders.scheduled.keys, ['x1']);
  });

  test('mematikan pengingat membatalkan semua, menyalakan menjadwalkan ulang; keluar membersihkan', () async {
    await signIn();
    n().recordApplication(jobs.first);
    await pumpEventQueue();
    n().toggleNotifyReminders();
    await pumpEventQueue();
    expect(reminders.scheduled, isEmpty);
    n().toggleNotifyReminders();
    await pumpEventQueue();
    expect(reminders.scheduled, hasLength(1));
    await n().signOut();
    await pumpEventQueue();
    expect(reminders.cleared, isTrue);
    expect(st().applications, isEmpty);
  });

  test('bukti belajar tersimpan bersama profil dan snapshot skor ikut diperbarui', () async {
    await signIn();
    n().selectGapJob('j1');
    n().master('Pelaporan Keuangan');
    n().recordLearningProof('Pelaporan Keuangan', ' https://contoh.id/sertifikat/123 ');
    await pumpEventQueue();
    final stored = await profiles.fetch('demo');
    expect(stored?.learned, ['Pelaporan Keuangan']);
    expect(stored?.proofs, {'Pelaporan Keuangan': 'https://contoh.id/sertifikat/123'});
    final j1 = activity.matches['demo']!.firstWhere((s) => s.job.id == 'j1');
    expect(j1.result.total, 92.5, reason: 'Tabel 2.4: 80 → 92,5 setelah menguasai Pelaporan Keuangan');
  });

  test('label pengingat: mode mock memakai tanggal demo, Firebase memakai tanggal nyata', () {
    expect(followUpReminder(AppStage.dikirim), 'Tindak lanjut 15 Okt');
    expect(followUpReminder(AppStage.wawancara, at: DateTime(2026, 11, 2)), 'Persiapan wawancara 2 Nov');
    expect(followUpAt(DateTime(2026, 10, 28, 22, 15)), DateTime(2026, 11, 4, 9));
  });

  test('lamaran Firestore dibaca utuh dari peta dokumen', () {
    final a = JobApplication(
      id: 'a1',
      jobId: 'j4',
      title: 'Customer Service Officer',
      company: 'BPR Artha Sejahtera',
      status: AppStage.tes,
      date: '',
      appliedAt: DateTime(2026, 10, 9),
      reminderAt: DateTime(2026, 10, 16, 9),
      remind: 'Tindak lanjut 16 Okt',
    );
    final back = JobApplication.fromMap('a1', a.toMap(), toDate: (v) => v as DateTime?);
    expect(back.toMap(), a.toMap());
    expect(back.date, '9 Okt');
    expect(JobApplication.fromMap('z', {'status': 'aneh'}, toDate: (_) => null).status, AppStage.dikirim);
  });
}
