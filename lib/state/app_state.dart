import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../logic/interview.dart';
import '../logic/match_score.dart';

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
  });

  factory AppState.initial() => const AppState(
    profile: raniProfile,
    learned: [],
    applications: initialApplications,
    savedJobIds: {},
    gapJobId: 'j1',
    coachJobId: 'j1',
    voiceMode: false,
    interviewResults: [],
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

  List<ScoredJob> get ranked => rankJobs(jobs, profile);

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
  );
}

/// Reminder set 7 days after a status change (demo date; reminders are stored as text).
String followUpReminder(AppStage status) => status == AppStage.wawancara ? 'Persiapan wawancara 15 Okt' : 'Tindak lanjut 15 Okt';

class AppNotifier extends Notifier<AppState> {
  @override
  AppState build() => AppState.initial();

  void setSignupName(String name) => state = state.copyWith(signupName: name);

  /// Profile extracted from an uploaded CV (simulated: Rani's CV).
  void useCvProfile(ProfileSource source) => state = state.copyWith(
    profile: raniProfile.copyWith(source: source),
    learned: [],
  );

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
    state = state.copyWith(
      learned: [],
      profile: Profile(
        name: state.signupName.trim().isEmpty ? 'Bayu Pratama' : state.signupName.trim(),
        level: EduLevel.fromLabel((a[0] as String?) ?? 'SMA/SMK'),
        major: ((a[1] as String?) ?? '').trim().isEmpty ? '-' : (a[1] as String).trim(),
        school: '-',
        city: (a[6] as String?) ?? 'Purwokerto',
        modes: modes.isEmpty ? const [WorkMode.kantor] : modes,
        source: ProfileSource.qa,
        skills: List.of((a[2] as List<String>?) ?? const []),
        exps: exps,
      ),
    );
  }

  void removeSkill(String skill) =>
      state = state.copyWith(profile: state.profile.copyWith(skills: state.profile.skills.where((s) => s != skill).toList()));

  /// Adds a skill after normalising its spelling. Returns false when empty or a duplicate.
  bool addSkill(String raw) {
    final v = normalizeSkill(raw);
    if (v.isEmpty || state.profile.skills.contains(v)) return false;
    state = state.copyWith(profile: state.profile.copyWith(skills: [...state.profile.skills, v]));
    return true;
  }

  /// Corrects the identity fields read by AI (they feed the education and location scores).
  void updateIdentity({required String name, required EduLevel level, required String major, required String city}) =>
      state = state.copyWith(
        profile: state.profile.copyWith(name: name.trim(), level: level, major: major.trim(), city: city.trim()),
      );

  void toggleMode(WorkMode m) {
    final modes = state.profile.modes;
    state = state.copyWith(profile: state.profile.copyWith(modes: modes.contains(m) ? modes.where((x) => x != m).toList() : [...modes, m]));
  }

  void selectGapJob(String id) => state = state.copyWith(gapJobId: id);
  void selectCoachJob(String id) => state = state.copyWith(coachJobId: id);
  void setVoiceMode(bool v) => state = state.copyWith(voiceMode: v);

  /// Marks [skill] as mastered and recomputes the score of the Skill Gap job.
  /// Returns the score before and after so the UI can announce the change.
  ({double before, double after, String jobTitle})? master(String skill) {
    final p = state.profile;
    if (p.skills.contains(skill)) return null;
    final job = jobById(state.gapJobId);
    final before = computeMatch(job, p).total;
    final np = p.copyWith(skills: [...p.skills, skill]);
    state = state.copyWith(profile: np, learned: [...state.learned, skill]);
    return (before: before, after: computeMatch(job, np).total, jobTitle: job.title);
  }

  void toggleSaved(String jobId) {
    final s = Set.of(state.savedJobIds);
    s.contains(jobId) ? s.remove(jobId) : s.add(jobId);
    state = state.copyWith(savedJobIds: s);
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

  void setOffline(bool v) => state = state.copyWith(offline: v);
  void toggleNotifyNewJobs() => state = state.copyWith(notifyNewJobs: !state.notifyNewJobs);
  void toggleNotifyReminders() => state = state.copyWith(notifyReminders: !state.notifyReminders);

  /// Hapus akun: wipes profile, CV, scores and applications.
  void deleteAccount() => state = AppState.initial().copyWith(offline: state.offline);
}

final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);
