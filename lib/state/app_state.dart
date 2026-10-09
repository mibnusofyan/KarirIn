import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backend.dart';
import '../data/mock_data.dart' as mock;
import '../data/mock_data.dart' show initialApplications, raniProfile, resourceFor;
import '../data/models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/providers.dart';
import '../firebase/bootstrap.dart' show remoteConfigDefaults;
import '../logic/interview.dart';
import '../logic/match_score.dart';
import 'session.dart';

/// Set with `--dart-define=SIMULATE_OFFLINE=true` to demo black-box scenario 11 (koneksi terputus).
const _simulateOffline = bool.fromEnvironment('SIMULATE_OFFLINE');

class AppState {
  const AppState({
    required this.profile,
    required this.learned,
    required this.applications,
    required this.savedJobIds,
    required this.gapJobId,
    required this.coachJobId,
    required this.voiceMode,
    required this.interviewResults,
    required this.offline,
    required this.notifyNewJobs,
    required this.notifyReminders,
    required this.signupName,
    this.jobs = mock.jobs,
    this.skills = const [],
    this.cvDeleted = false,
  });

  /// Mock builds start with Rani's demo data; Firebase builds start empty and load the signed-in user's data.
  factory AppState.initial({bool demoData = backend == Backend.mock}) => AppState(
    profile: raniProfile,
    learned: const [],
    applications: demoData ? initialApplications : const [],
    savedJobIds: const {},
    gapJobId: 'j1',
    coachJobId: 'j1',
    voiceMode: false,
    interviewResults: const [],
    offline: _simulateOffline,
    notifyNewJobs: true,
    notifyReminders: true,
    signupName: '',
  );

  final Profile profile;

  /// Skills marked as mastered through Skill Gap.
  final List<String> learned;
  final List<JobApplication> applications;
  final Set<String> savedJobIds;
  final String gapJobId;
  final String coachJobId;
  final bool voiceMode;
  final List<AnsweredQuestion> interviewResults;
  final bool offline;
  final bool notifyNewJobs;
  final bool notifyReminders;

  /// Name typed on the Daftar form, used for a profile built from Q&A.
  final String signupName;

  /// The curated catalogue (from Firestore on Firebase builds).
  final List<Job> jobs;

  /// Canonical skills with synonyms and learning materials; empty until loaded.
  final List<Skill> skills;

  /// The uploaded CV file was deleted from Pengaturan; the extracted profile stays.
  final bool cvDeleted;

  /// Whether a CV file is stored for this profile.
  bool get hasCv => profile.source != ProfileSource.qa && !cvDeleted;

  List<ScoredJob> get ranked => rankJobs(jobs, profile);

  /// The job with [id]; falls back to the first job for an id no longer in the catalogue.
  Job job(String id) => jobs.firstWhere((j) => j.id == id, orElse: () => jobs.first);

  /// Learning material for [skill]: the curated catalogue first, then the bundled list.
  LearningResource resourceForSkill(String skill) => skills.where((s) => s.name == skill).firstOrNull?.resource ?? resourceFor(skill);

  AppState copyWith({
    Profile? profile,
    List<String>? learned,
    List<JobApplication>? applications,
    Set<String>? savedJobIds,
    String? gapJobId,
    String? coachJobId,
    bool? voiceMode,
    List<AnsweredQuestion>? interviewResults,
    bool? offline,
    bool? notifyNewJobs,
    bool? notifyReminders,
    String? signupName,
    List<Job>? jobs,
    List<Skill>? skills,
    bool? cvDeleted,
  }) => AppState(
    profile: profile ?? this.profile,
    learned: learned ?? this.learned,
    applications: applications ?? this.applications,
    savedJobIds: savedJobIds ?? this.savedJobIds,
    gapJobId: gapJobId ?? this.gapJobId,
    coachJobId: coachJobId ?? this.coachJobId,
    voiceMode: voiceMode ?? this.voiceMode,
    interviewResults: interviewResults ?? this.interviewResults,
    offline: offline ?? this.offline,
    notifyNewJobs: notifyNewJobs ?? this.notifyNewJobs,
    notifyReminders: notifyReminders ?? this.notifyReminders,
    signupName: signupName ?? this.signupName,
    jobs: jobs ?? this.jobs,
    skills: skills ?? this.skills,
    cvDeleted: cvDeleted ?? this.cvDeleted,
  );
}

/// Reminder set 7 days after a status change (demo date; reminders are stored as text).
String followUpReminder(AppStage status) => status == AppStage.wawancara ? 'Persiapan wawancara 15 Okt' : 'Tindak lanjut 15 Okt';

/// Offline writes never complete, so actions that must reach the server give up after this long.
const _writeTimeout = Duration(seconds: 15);

class AppNotifier extends Notifier<AppState> {
  /// The signed-in user on Firebase builds; null on mock builds and when signed out.
  String? _uid;

  /// Profile changes are written to Firestore only after the user confirmed the profile once.
  bool _confirmed = false;

  bool get _firebase => ref.read(backendProvider) == Backend.firebase;

  @override
  AppState build() {
    if (_firebase) {
      final sub = ref.read(authRepositoryProvider).authStateChanges().listen(_onAuth);
      ref.onDispose(sub.cancel);
    }
    return AppState.initial(demoData: !_firebase);
  }

  Future<void> _onAuth(AuthUser? user) async {
    if (user == null) {
      _uid = null;
      _confirmed = false;
      state = AppState.initial(demoData: false);
      session.value = SessionStatus.signedOut;
      return;
    }
    if (user.uid == _uid) return;
    try {
      await _hydrate(user);
    } catch (e, s) {
      // Firestore serves its offline cache, so this is rare; keep the user signed in with the bundled catalogue.
      _report(e, s);
      _uid = user.uid;
      session.value = SessionStatus.needsProfile;
    }
  }

  Future<void> _hydrate(AuthUser user) async {
    final jobsRepo = ref.read(jobRepositoryProvider);
    // Right after registering, the auth event can arrive before the display name is set; use the typed name.
    final name = user.displayName.isNotEmpty ? user.displayName : state.signupName.trim();
    final named = AuthUser(uid: user.uid, email: user.email, displayName: name, provider: user.provider);
    final (userData, stored, jobs, skills) = await (
      ref.read(userRepositoryProvider).ensure(named),
      ref.read(profileRepositoryProvider).fetch(user.uid),
      jobsRepo.fetchJobs().catchError((Object _) => mock.jobs),
      jobsRepo.fetchSkills().catchError((Object _) => mock.skillCatalog),
    ).wait;
    _uid = user.uid;
    _confirmed = stored != null;
    final firstJob = (jobs.isEmpty ? mock.jobs : jobs).first.id;
    state = AppState.initial(demoData: false).copyWith(
      jobs: jobs.isEmpty ? mock.jobs : jobs,
      skills: skills,
      profile: stored?.profile,
      learned: stored?.learned,
      savedJobIds: userData.savedJobIds,
      notifyNewJobs: userData.notifyNewJobs,
      notifyReminders: userData.notifyReminders,
      signupName: name,
      gapJobId: firstJob,
      coachJobId: firstJob,
    );
    session.value = _confirmed ? SessionStatus.ready : SessionStatus.needsProfile;
  }

  static void _report(Object e, StackTrace s) => debugPrint('KarirIn sync: $e\n$s');

  /// Runs a Firestore write for the signed-in user without blocking the UI. Writes made offline are queued by
  /// Firestore and sent when the connection returns, so their futures may not complete for a while.
  void _write(Future<void> Function(String uid) run) {
    final uid = _uid;
    if (uid == null) return;
    unawaited(run(uid).catchError(_report));
  }

  /// Sets the profile, saving it once the user has confirmed a profile.
  void _setProfile(Profile p, {List<String>? learned}) {
    state = state.copyWith(profile: p, learned: learned);
    if (_confirmed) _saveProfile();
  }

  void _saveProfile() => _write((uid) => ref.read(profileRepositoryProvider).save(uid, state.profile, learned: state.learned));

  /// "Simpan profil" on Konfirmasi Profil: stores the reviewed profile and unlocks the main app.
  void confirmProfile() {
    _confirmed = true;
    _saveProfile();
    if (_firebase) session.value = SessionStatus.ready;
  }

  void setSignupName(String name) => state = state.copyWith(signupName: name);

  /// Consent from the sheet on Buat Profil, stored with the version of the text shown.
  void recordCvConsent() => _write((uid) {
    var version = remoteConfigDefaults['consent_version'] as String;
    try {
      version = FirebaseRemoteConfig.instance.getString('consent_version');
    } catch (_) {
      // Firebase not initialised (tests): keep the bundled version.
    }
    return ref.read(userRepositoryProvider).recordCvConsent(uid, version);
  });

  /// Profile extracted from an uploaded CV (simulated: Rani's CV).
  void useCvProfile(ProfileSource source) {
    state = state.copyWith(cvDeleted: false);
    _setProfile(raniProfile.copyWith(source: source), learned: []);
  }

  /// Builds a profile from the 8 Q&A answers (persona Bayu, no CV).
  void useQaProfile(Map<int, Object> a) {
    final expChoices = ((a[3] as List<String>?) ?? const []).where((x) => x != 'Belum ada');
    final exps = expChoices
        .map(
          (x) => Experience(
            title: x == 'Magang/PKL' ? 'Praktik Kerja Lapangan' : x,
            org: x == 'Magang/PKL' ? 'Tempat PKL' : '-',
            type: x == 'Kerja paruh waktu'
                ? ExperienceType.kerja
                : x == 'Organisasi'
                ? ExperienceType.organisasi
                : ExperienceType.magang,
            months: 3,
            field: 'umum',
          ),
        )
        .toList();
    final modes = ((a[7] as List<String>?) ?? const []).map((m) => WorkMode.values.firstWhere((w) => w.label == m)).toList();
    _setProfile(
      Profile(
        name: state.signupName.trim().isEmpty ? 'Bayu Pratama' : state.signupName.trim(),
        level: EduLevel.fromLabel((a[0] as String?) ?? 'SMA/SMK'),
        major: ((a[1] as String?) ?? '').trim().isEmpty ? '-' : (a[1] as String).trim(),
        school: '-',
        city: (a[6] as String?) ?? 'Purwokerto',
        modes: modes.isEmpty ? const [WorkMode.kantor] : modes,
        source: ProfileSource.qa,
        skills: [for (final s in (a[2] as List<String>?) ?? const <String>[]) normalizeSkill(s, state.skills)],
        exps: exps,
        interests: List.of((a[5] as List<String>?) ?? const []),
      ),
      learned: [],
    );
  }

  void removeSkill(String skill) => _setProfile(state.profile.copyWith(skills: state.profile.skills.where((s) => s != skill).toList()));

  /// Adds a skill after normalising its spelling. Returns false when empty or a duplicate.
  bool addSkill(String raw) {
    final v = normalizeSkill(raw, state.skills);
    if (v.isEmpty || state.profile.skills.contains(v)) return false;
    _setProfile(state.profile.copyWith(skills: [...state.profile.skills, v]));
    return true;
  }

  /// Corrects the identity fields read by AI (they feed the education and location scores).
  void updateIdentity({required String name, required EduLevel level, required String major, required String city}) =>
      _setProfile(state.profile.copyWith(name: name.trim(), level: level, major: major.trim(), city: city.trim()));

  void toggleMode(WorkMode m) {
    final modes = state.profile.modes;
    _setProfile(state.profile.copyWith(modes: modes.contains(m) ? modes.where((x) => x != m).toList() : [...modes, m]));
  }

  void selectGapJob(String id) => state = state.copyWith(gapJobId: id);
  void selectCoachJob(String id) => state = state.copyWith(coachJobId: id);
  void setVoiceMode(bool v) => state = state.copyWith(voiceMode: v);

  /// Marks [skill] as mastered and recomputes the score of the Skill Gap job.
  /// Returns the score before and after so the UI can announce the change.
  ({double before, double after, String jobTitle})? master(String skill) {
    final p = state.profile;
    if (p.skills.contains(skill)) return null;
    final job = state.job(state.gapJobId);
    final before = computeMatch(job, p).total;
    final np = p.copyWith(skills: [...p.skills, skill]);
    _setProfile(np, learned: [...state.learned, skill]);
    return (before: before, after: computeMatch(job, np).total, jobTitle: job.title);
  }

  void toggleSaved(String jobId) {
    final s = Set.of(state.savedJobIds);
    s.contains(jobId) ? s.remove(jobId) : s.add(jobId);
    state = state.copyWith(savedJobIds: s);
    _write((uid) => ref.read(userRepositoryProvider).setSavedJobs(uid, s));
  }

  /// Logs an application sent via the company's official channel.
  void recordApplication(Job job) {
    if (state.applications.any((a) => a.title == job.title && a.company == job.company)) return;
    state = state.copyWith(
      applications: [
        JobApplication(
          id: 'a${DateTime.now().millisecondsSinceEpoch}',
          title: job.title,
          company: job.company,
          status: AppStage.dikirim,
          date: '8 Okt',
          remind: 'Tindak lanjut 15 Okt',
        ),
        ...state.applications,
      ],
    );
  }

  void updateApplication(String id, AppStage status, bool remind) {
    state = state.copyWith(
      applications: [
        for (final a in state.applications)
          if (a.id == id) a.copyWith(status: status, remind: () => remind ? followUpReminder(status) : null) else a,
      ],
    );
  }

  void saveInterviewResults(List<AnsweredQuestion> r) => state = state.copyWith(interviewResults: r);

  /// Hapus berkas CV: removes the stored file but keeps the confirmed profile.
  void deleteCv() => state = state.copyWith(cvDeleted: true);

  void setOffline(bool v) => state = state.copyWith(offline: v);

  void toggleNotifyNewJobs() {
    state = state.copyWith(notifyNewJobs: !state.notifyNewJobs);
    _saveNotifications();
  }

  void toggleNotifyReminders() {
    state = state.copyWith(notifyReminders: !state.notifyReminders);
    _saveNotifications();
  }

  void _saveNotifications() => _write(
    (uid) => ref.read(userRepositoryProvider).setNotifications(uid, newJobs: state.notifyNewJobs, reminders: state.notifyReminders),
  );

  /// Keluar. On Firebase builds the auth listener then resets the state and the router returns to Masuk.
  Future<void> signOut() async {
    if (!_firebase) return;
    await ref.read(authRepositoryProvider).signOut();
  }

  /// Hapus akun: wipes profile, CV, scores and applications. Throws [AuthFailure] when Firebase asks the user to
  /// sign in again first; the data is kept in that case.
  Future<void> deleteAccount() async {
    final uid = _uid;
    if (_firebase && uid != null) {
      final auth = ref.read(authRepositoryProvider);
      // Checked up front: the data must be deleted while still signed in (security rules), and a delete that
      // Firebase then refuses would leave an empty account behind.
      if (!auth.recentlySignedIn) throw authFailureFor('requires-recent-login');
      try {
        await ref.read(profileRepositoryProvider).delete(uid).timeout(_writeTimeout);
        await ref.read(userRepositoryProvider).delete(uid).timeout(_writeTimeout);
      } on TimeoutException {
        throw authFailureFor('network-request-failed');
      }
      await auth.deleteAccount();
      return;
    }
    state = AppState.initial().copyWith(offline: state.offline);
  }
}

final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);
