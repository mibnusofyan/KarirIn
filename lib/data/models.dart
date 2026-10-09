/// Domain models. Shapes mirror the Firestore collections in proposal Tabel 3.2
/// (jobs, profiles, applications, interviews) so the mock repository can later
/// be swapped for Firebase without touching the UI.
library;

enum EduLevel {
  smaSmk('SMA/SMK', 1),
  d3('D3', 2),
  s1('S1', 3);

  const EduLevel(this.label, this.rank);
  final String label;
  final int rank;

  static EduLevel fromLabel(String label) => values.firstWhere((e) => e.label == label, orElse: () => smaSmk);
}

enum WorkMode {
  kantor('Kantor'),
  hybrid('Hybrid'),
  remote('Remote');

  const WorkMode(this.label);
  final String label;
}

class Job {
  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.city,
    required this.mode,
    required this.field,
    required this.salary,
    required this.wajib,
    required this.tambahan,
    required this.eduMin,
    required this.eduFields,
    required this.expYears,
    required this.desc,
  });

  final String id;
  final String title;
  final String company;
  final String city;
  final WorkMode mode;
  final String field;
  final String salary;
  final List<String> wajib;
  final List<String> tambahan;
  final EduLevel eduMin;

  /// Accepted majors; `['Semua']` means any major.
  final List<String> eduFields;
  final int expYears;
  final String desc;

  bool get anyMajor => eduFields.contains('Semua');
}

enum ExperienceType { magang, organisasi, kerja }

class Experience {
  const Experience({required this.title, required this.org, required this.type, required this.months, required this.field, this.desc = ''});

  final String title;
  final String org;
  final ExperienceType type;
  final int months;
  final String field;
  final String desc;
}

enum ProfileSource { cvPdf, cvPhoto, qa }

class Profile {
  const Profile({
    required this.name,
    required this.level,
    required this.major,
    required this.school,
    required this.city,
    required this.modes,
    required this.source,
    required this.skills,
    required this.exps,
  });

  final String name;
  final EduLevel level;
  final String major;
  final String school;
  final String city;
  final List<WorkMode> modes;
  final ProfileSource source;
  final List<String> skills;
  final List<Experience> exps;

  String get firstName => name.split(' ').first;
  String get initials => name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();

  Profile copyWith({
    String? name,
    EduLevel? level,
    String? major,
    String? city,
    List<String>? skills,
    List<WorkMode>? modes,
    ProfileSource? source,
  }) => Profile(
    name: name ?? this.name,
    level: level ?? this.level,
    major: major ?? this.major,
    school: school,
    city: city ?? this.city,
    modes: modes ?? this.modes,
    source: source ?? this.source,
    skills: skills ?? this.skills,
    exps: exps,
  );
}

enum ResourceType {
  kursus('Kursus'),
  video('Video'),
  modul('Modul');

  const ResourceType(this.label);
  final String label;
}

class LearningResource {
  const LearningResource(this.type, this.duration, this.title);
  final ResourceType type;
  final String duration;
  final String title;
}

enum AppStage {
  dikirim('Dikirim'),
  tes('Tes'),
  wawancara('Wawancara'),
  diterima('Diterima'),
  ditolak('Ditolak');

  const AppStage(this.label);
  final String label;

  bool get isActive => this != diterima && this != ditolak;
}

class JobApplication {
  const JobApplication({
    required this.id,
    required this.title,
    required this.company,
    required this.status,
    required this.date,
    this.remind,
  });

  final String id;
  final String title;
  final String company;
  final AppStage status;
  final String date;
  final String? remind;

  JobApplication copyWith({AppStage? status, String? Function()? remind}) => JobApplication(
    id: id,
    title: title,
    company: company,
    status: status ?? this.status,
    date: date,
    remind: remind != null ? remind() : this.remind,
  );
}

enum QuestionKind { single, multi, text, area }

class QaQuestion {
  const QaQuestion({required this.title, required this.help, required this.kind, this.options = const [], this.hint});
  final String title;
  final String help;
  final QuestionKind kind;
  final List<String> options;
  final String? hint;
}

class InterviewQuestion {
  const InterviewQuestion({required this.type, required this.text, required this.demo, required this.better});
  final String type;
  final String text;

  /// Sample answer used by "Isi contoh (demo)" and the simulated voice transcript.
  final String demo;

  /// Model answer shown under "Lihat contoh jawaban yang lebih baik".
  final String better;

  InterviewQuestion withText(String t) => InterviewQuestion(type: type, text: t, demo: demo, better: better);
}
