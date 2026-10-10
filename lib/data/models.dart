/// Domain models. Shapes mirror the Firestore collections in proposal Tabel 3.2
/// (jobs, profiles, applications, interviews) so the mock repository can later
/// be swapped for Firebase without touching the UI.
library;

/// Firestore stores enums by name, so renaming an enum value is a data migration.
T _byName<T extends Enum>(List<T> values, Object? name, T fallback) => values.firstWhere((v) => v.name == name, orElse: () => fallback);

List<String> _strings(Object? v) => [for (final x in (v as List?) ?? const []) x as String];

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
    this.applyUrl,
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

  /// Official application channel; null until the curated job has one.
  final String? applyUrl;

  bool get anyMajor => eduFields.contains('Semua');

  /// Firestore `jobs/{id}` fields (the id is the document id).
  Map<String, Object?> toMap() => {
    'title': title,
    'company': company,
    'city': city,
    'mode': mode.name,
    'field': field,
    'salaryText': salary,
    'wajib': wajib,
    'tambahan': tambahan,
    'eduMin': eduMin.name,
    'eduFields': eduFields,
    'expYears': expYears,
    'desc': desc,
    'applyUrl': applyUrl,
  };

  factory Job.fromMap(String id, Map<String, Object?> m) => Job(
    id: id,
    title: m['title'] as String,
    company: m['company'] as String,
    city: m['city'] as String,
    mode: _byName(WorkMode.values, m['mode'], WorkMode.kantor),
    field: m['field'] as String,
    salary: (m['salaryText'] as String?) ?? '',
    wajib: _strings(m['wajib']),
    tambahan: _strings(m['tambahan']),
    eduMin: _byName(EduLevel.values, m['eduMin'], EduLevel.smaSmk),
    eduFields: _strings(m['eduFields']),
    expYears: (m['expYears'] as num?)?.toInt() ?? 0,
    desc: (m['desc'] as String?) ?? '',
    applyUrl: m['applyUrl'] as String?,
  );
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

  Map<String, Object?> toMap() => {'title': title, 'org': org, 'type': type.name, 'months': months, 'field': field, 'desc': desc};

  factory Experience.fromMap(Map<String, Object?> m) => Experience(
    title: m['title'] as String,
    org: (m['org'] as String?) ?? '-',
    type: _byName(ExperienceType.values, m['type'], ExperienceType.magang),
    months: (m['months'] as num?)?.toInt() ?? 0,
    field: (m['field'] as String?) ?? 'umum',
    desc: (m['desc'] as String?) ?? '',
  );
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
    this.interests = const [],
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

  /// Fields of work the user is interested in (Q&A question 6).
  final List<String> interests;

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
    List<String>? interests,
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
    interests: interests ?? this.interests,
  );

  /// Firestore `profiles/{uid}` fields owned by the profile itself.
  Map<String, Object?> toMap() => {
    'name': name,
    'level': level.name,
    'major': major,
    'school': school,
    'city': city,
    'modes': [for (final m in modes) m.name],
    'source': source.name,
    'skills': skills,
    'exps': [for (final e in exps) e.toMap()],
    'interests': interests,
  };

  factory Profile.fromMap(Map<String, Object?> m) => Profile(
    name: m['name'] as String,
    level: _byName(EduLevel.values, m['level'], EduLevel.smaSmk),
    major: (m['major'] as String?) ?? '-',
    school: (m['school'] as String?) ?? '-',
    city: (m['city'] as String?) ?? '',
    modes: [for (final x in (m['modes'] as List?) ?? const []) _byName(WorkMode.values, x, WorkMode.kantor)],
    source: _byName(ProfileSource.values, m['source'], ProfileSource.qa),
    skills: _strings(m['skills']),
    exps: [for (final e in (m['exps'] as List?) ?? const []) Experience.fromMap(Map<String, Object?>.from(e as Map))],
    interests: _strings(m['interests']),
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
  const LearningResource(this.type, this.duration, this.title, {this.url});
  final ResourceType type;
  final String duration;
  final String title;

  /// Free learning material; null until the team curates a link.
  final String? url;

  Map<String, Object?> toMap() => {'type': type.name, 'duration': duration, 'title': title, 'url': url};

  factory LearningResource.fromMap(Map<String, Object?> m) => LearningResource(
    _byName(ResourceType.values, m['type'], ResourceType.modul),
    (m['duration'] as String?) ?? '',
    m['title'] as String,
    url: m['url'] as String?,
  );
}

/// A canonical skill with its spelling variants (Firestore `skills`).
class Skill {
  const Skill({required this.name, this.synonyms = const [], this.resource});
  final String name;
  final List<String> synonyms;
  final LearningResource? resource;

  /// Document id: lowercase name with non-alphanumerics collapsed to `-`.
  String get id => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  Map<String, Object?> toMap() => {'name': name, 'synonyms': synonyms, 'resource': resource?.toMap()};

  factory Skill.fromMap(Map<String, Object?> m) => Skill(
    name: m['name'] as String,
    synonyms: _strings(m['synonyms']),
    resource: m['resource'] == null ? null : LearningResource.fromMap(Map<String, Object?>.from(m['resource'] as Map)),
  );
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

  /// A question from `jobs/{id}/questionSets` (written by `backend/src/generate-questions.ts`).
  factory InterviewQuestion.fromMap(Map<String, Object?> m) => InterviewQuestion(
    type: m['type'] == 'Teknis' ? 'Teknis' : 'Perilaku',
    text: m['text'] as String,
    demo: (m['demo'] as String?) ?? '',
    better: (m['better'] as String?) ?? '',
  );

  Map<String, Object?> toMap() => {'type': type, 'text': text, 'demo': demo, 'better': better};
}
