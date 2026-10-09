// The Firebase sync in AppNotifier, run against in-memory repositories (no network, no Firebase).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/backend.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/data/repositories/auth_repository.dart';
import 'package:karirin/data/repositories/profile_repository.dart';
import 'package:karirin/data/repositories/providers.dart';
import 'package:karirin/data/repositories/user_repository.dart';
import 'package:karirin/logic/match_score.dart';
import 'package:karirin/router.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/state/session.dart';

class _Backend {
  _Backend() {
    container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(Backend.firebase),
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    container.read(appProvider);
  }

  final auth = MockAuthRepository();
  final users = MockUserRepository();
  final profiles = MockProfileRepository();
  late final ProviderContainer container;

  AppState get state => container.read(appProvider);
  AppNotifier get n => container.read(appProvider.notifier);
}

/// Firebase emits the new user before `updateDisplayName` lands, so the first event has no name.
class _NamelessRegisterAuth extends MockAuthRepository {
  @override
  Future<void> register({required String name, required String email, required String password}) =>
      super.register(name: '', email: email, password: password);
}

class _RecordingUsers extends MockUserRepository {
  final ensured = <AuthUser>[];

  @override
  Future<UserData> ensure(AuthUser user) {
    ensured.add(user);
    return super.ensure(user);
  }
}

const _bayuAnswers = <int, Object>{
  0: 'SMA/SMK',
  1: 'Teknik Komputer dan Jaringan',
  2: ['Jaringan Komputer', 'Perakitan PC'],
  3: ['Magang/PKL'],
  5: ['Teknologi Informasi'],
  6: 'Purwokerto',
  7: ['Kantor'],
};

void main() {
  setUp(() => session.value = SessionStatus.loading);

  test('belum login → signedOut, tanpa data contoh', () async {
    final b = _Backend();
    addTearDown(b.container.dispose);
    await pumpEventQueue();
    expect(session.value, SessionStatus.signedOut);
    expect(b.state.applications, isEmpty);
  });

  test('daftar → perlu profil; profil baru disimpan setelah dikonfirmasi', () async {
    final b = _Backend();
    addTearDown(b.container.dispose);
    await b.auth.register(name: 'Bayu Pratama', email: 'bayu@contoh.id', password: 'rahasia123');
    await pumpEventQueue();
    expect(session.value, SessionStatus.needsProfile);
    expect(b.state.signupName, 'Bayu Pratama');
    expect(b.state.skills, isNotEmpty);

    b.n.useQaProfile(_bayuAnswers);
    b.n.addSkill('ms excel');
    await pumpEventQueue();
    expect(await b.profiles.fetch('demo'), isNull, reason: 'belum dikonfirmasi');

    b.n.confirmProfile();
    await pumpEventQueue();
    expect(session.value, SessionStatus.ready);
    final stored = await b.profiles.fetch('demo');
    expect(stored?.profile.name, 'Bayu Pratama');
    expect(stored?.profile.interests, ['Teknologi Informasi']);
    expect(stored?.profile.skills, contains('Microsoft Excel'));

    // After confirmation every change is written through.
    b.n.master('Pelaporan Keuangan');
    await pumpEventQueue();
    expect((await b.profiles.fetch('demo'))?.learned, ['Pelaporan Keuangan']);
  });

  test('dokumen pengguna memakai nama yang diketik walau event login belum membawa nama', () async {
    final auth = _NamelessRegisterAuth();
    final users = _RecordingUsers();
    final c = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(Backend.firebase),
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        profileRepositoryProvider.overrideWithValue(MockProfileRepository()),
      ],
    );
    addTearDown(c.dispose);
    c.read(appProvider);
    await pumpEventQueue(); // The signed-out event arrives at startup, before anyone types on Daftar.
    c.read(appProvider.notifier).setSignupName('Sinta Ayu ');
    await auth.register(name: 'Sinta Ayu', email: 'sinta@contoh.id', password: 'rahasia123');
    await pumpEventQueue();
    expect(users.ensured.single.displayName, 'Sinta Ayu');
    expect(c.read(appProvider).signupName, 'Sinta Ayu');
  });

  test('masuk lagi memuat profil, skill dikuasai, simpanan, dan pengaturan', () async {
    final b = _Backend();
    addTearDown(b.container.dispose);
    await b.profiles.save('demo', raniProfile, learned: ['Pelaporan Keuangan']);
    await b.users.ensure(const AuthUser(uid: 'demo', email: 'rani@contoh.id', displayName: 'Rani', provider: 'password'));
    await b.users.setSavedJobs('demo', {'j3'});
    await b.users.setNotifications('demo', newJobs: false, reminders: true);

    await b.auth.signIn(email: 'rani@contoh.id', password: 'rahasia123');
    await pumpEventQueue();
    expect(session.value, SessionStatus.ready);
    expect(b.state.profile.name, 'Rani Lestari');
    expect(b.state.learned, ['Pelaporan Keuangan']);
    expect(b.state.savedJobIds, {'j3'});
    expect(b.state.notifyNewJobs, isFalse);
    expect(b.state.ranked.first.result.total, greaterThan(0));
  });

  test('simpan lowongan dan toggle notifikasi tersimpan; keluar mengosongkan state', () async {
    final b = _Backend();
    addTearDown(b.container.dispose);
    await b.profiles.save('demo', raniProfile);
    await b.auth.signIn(email: 'rani@contoh.id', password: 'rahasia123');
    await pumpEventQueue();

    b.n.toggleSaved('j2');
    b.n.toggleNotifyReminders();
    await pumpEventQueue();
    final stored = await b.users.ensure(const AuthUser(uid: 'demo', email: '', displayName: '', provider: 'password'));
    expect(stored.savedJobIds, {'j2'});
    expect(stored.notifyReminders, isFalse);

    await b.n.signOut();
    await pumpEventQueue();
    expect(session.value, SessionStatus.signedOut);
    expect(b.state.savedJobIds, isEmpty);
  });

  test('hapus akun menghapus profil dan dokumen pengguna', () async {
    final b = _Backend();
    addTearDown(b.container.dispose);
    await b.profiles.save('demo', raniProfile);
    await b.auth.signIn(email: 'rani@contoh.id', password: 'rahasia123');
    await pumpEventQueue();
    await b.users.setSavedJobs('demo', {'j1'});

    await b.n.deleteAccount();
    await pumpEventQueue();
    expect(await b.profiles.fetch('demo'), isNull);
    final fresh = await b.users.ensure(const AuthUser(uid: 'demo', email: '', displayName: '', provider: 'password'));
    expect(fresh.savedJobIds, isEmpty);
    expect(session.value, SessionStatus.signedOut);
  });

  group('redirect router', () {
    String? go(SessionStatus s, String loc) {
      session.value = s;
      return sessionRedirect(loc, mode: Backend.firebase);
    }

    test('mode mock tidak pernah mengalihkan', () {
      session.value = SessionStatus.signedOut;
      expect(sessionRedirect(Routes.home, mode: Backend.mock), isNull);
    });

    test('belum login hanya boleh di layar sambutan', () {
      expect(go(SessionStatus.signedOut, Routes.home), Routes.auth);
      expect(go(SessionStatus.signedOut, Routes.create), Routes.auth);
      expect(go(SessionStatus.signedOut, Routes.onboarding), isNull);
      expect(go(SessionStatus.signedOut, Routes.auth), isNull);
    });

    test('tanpa profil tetap di alur pembuatan profil', () {
      expect(go(SessionStatus.needsProfile, Routes.auth), Routes.create);
      expect(go(SessionStatus.needsProfile, Routes.home), Routes.create);
      expect(go(SessionStatus.needsProfile, Routes.qa), isNull);
      expect(go(SessionStatus.needsProfile, Routes.confirm), isNull);
    });

    test('siap: melewati Masuk, bebas ke mana pun', () {
      expect(go(SessionStatus.ready, Routes.auth), Routes.home);
      expect(go(SessionStatus.ready, Routes.job('j1')), isNull);
      expect(go(SessionStatus.ready, Routes.confirm), isNull);
    });

    test('memuat: tetap di splash', () {
      expect(go(SessionStatus.loading, Routes.home), Routes.splash);
      expect(go(SessionStatus.loading, Routes.splash), isNull);
    });
  });

  test('normalisasi memakai katalog: nama, sinonim, huruf besar-kecil, spasi', () {
    final catalog = skillCatalog;
    expect(normalizeSkill('  ms   EXCEL ', catalog), 'Microsoft Excel');
    expect(normalizeSkill('sql', catalog), 'SQL');
    expect(normalizeSkill('Kotlin', catalog), 'Kotlin');
    expect(const Skill(name: 'Git', synonyms: ['GitHub']).name, normalizeSkill('github', const [Skill(name: 'Git', synonyms: ['GitHub'])]));
  });

  test('pengguna tanpa profil memakai lowongan katalog', () async {
    final b = _Backend();
    addTearDown(b.container.dispose);
    await b.auth.signIn(email: 'x@contoh.id', password: 'rahasia123');
    await pumpEventQueue();
    expect(b.state.jobs.map((j) => j.id), jobs.map((j) => j.id));
    expect(b.state.job('tidak-ada').id, b.state.jobs.first.id);
    expect(b.state.resourceForSkill('Microsoft Excel').title, resources['Microsoft Excel']!.title);
    expect(b.state.profile.source, isA<ProfileSource>());
  });
}
