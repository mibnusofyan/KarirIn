// Validation of Gemini output before it reaches the app (proposal 3.1.3): every AI answer is JSON checked
// against the expected shape, clamped to valid ranges and normalised to the KarirIn vocabulary.
import 'dart:convert';

import '../../data/models.dart';
import '../../logic/interview.dart';
import '../../logic/match_score.dart';

/// Why an AI call produced nothing usable, worded for the user.
class AiFailure implements Exception {
  const AiFailure(this.message);
  final String message;

  static const network = AiFailure('Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.');
  static const quota = AiFailure('Kuota AI hari ini sedang penuh. Coba lagi beberapa saat lagi.');
  static const invalid = AiFailure('Jawaban AI tidak dapat dibaca. Coba lagi.');
  static const disabled = AiFailure('Fitur AI sedang dinonaktifkan sementara.');
  static const unreadable = AiFailure('Tidak ada data CV yang terbaca. Pastikan berkas berisi CV yang jelas, lalu coba lagi.');

  @override
  String toString() => message;
}

/// Fields of work a job or experience can belong to; anything else becomes `umum`.
const jobFields = ['keuangan', 'pemasaran', 'data', 'layanan', 'logistik', 'teknologi', 'administrasi', 'umum'];

/// Parses a JSON object from model text, tolerating a Markdown code fence around it.
Map<String, Object?> decodeJsonObject(String? text) {
  if (text == null || text.trim().isEmpty) throw AiFailure.invalid;
  var t = text.trim();
  final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(t);
  if (fence != null) t = fence.group(1)!;
  try {
    final v = jsonDecode(t);
    if (v is Map<String, Object?>) return v;
  } on FormatException {
    // Fall through.
  }
  throw AiFailure.invalid;
}

String _str(Object? v, {int max = 200}) {
  final s = (v is String ? v : '').trim().replaceAll(RegExp(r'\s+'), ' ');
  return s.length > max ? s.substring(0, max).trim() : s;
}

int _int(Object? v, {required int min, required int max}) {
  final n = v is num ? v.round() : int.tryParse('$v') ?? min;
  return n.clamp(min, max);
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) => values.firstWhere((e) => e.name == name, orElse: () => fallback);

/// Profile read from a CV. Skills are normalised against [catalog] and de-duplicated; unknown enum values fall
/// back to safe defaults the user then checks on Konfirmasi Profil.
Profile parseExtractedProfile(Map<String, Object?> j, {required List<Skill> catalog, required ProfileSource source}) {
  final skills = <String>[];
  for (final raw in (j['skills'] as List?) ?? const []) {
    final s = normalizeSkill(_str(raw, max: 60), catalog);
    if (s.isNotEmpty && !skills.any((x) => x.toLowerCase() == s.toLowerCase())) skills.add(s);
    if (skills.length == 40) break;
  }
  final exps = <Experience>[
    for (final e in ((j['exps'] as List?) ?? const []).whereType<Map>().take(10))
      if (_str(e['title']).isNotEmpty)
        Experience(
          title: _str(e['title'], max: 80),
          org: _str(e['org'], max: 80).isEmpty ? '-' : _str(e['org'], max: 80),
          type: _enum(ExperienceType.values, e['type'], ExperienceType.kerja),
          months: _int(e['months'], min: 0, max: 600),
          field: jobFields.contains(e['field']) ? e['field'] as String : 'umum',
          desc: _str(e['desc'], max: 240),
        ),
  ];
  final name = _str(j['name'], max: 80);
  if (name.isEmpty && skills.isEmpty && exps.isEmpty) throw AiFailure.unreadable;
  return Profile(
    name: name,
    level: _enum(EduLevel.values, j['level'], EduLevel.smaSmk),
    major: _str(j['major'], max: 80).isEmpty ? '-' : _str(j['major'], max: 80),
    school: _str(j['school'], max: 100).isEmpty ? '-' : _str(j['school'], max: 100),
    city: _str(j['city'], max: 60),
    modes: const [WorkMode.kantor],
    source: source,
    skills: skills,
    exps: exps,
  );
}

/// One graded answer; aspects are clamped to 0–25 and empty feedback falls back to the rubric's wording.
AnswerScore parseGrade(Map<String, Object?> j) {
  final scores = [
    ('Relevansi', _int(j['relevansi'], min: 0, max: 25)),
    ('Struktur STAR', _int(j['struktur'], min: 0, max: 25)),
    ('Kejelasan', _int(j['kejelasan'], min: 0, max: 25)),
    ('Bukti konkret', _int(j['bukti'], min: 0, max: 25)),
  ];
  final strongest = ([...scores]..sort((a, b) => b.$2.compareTo(a.$2))).first.$1;
  final weakest = ([...scores]..sort((a, b) => a.$2.compareTo(b.$2))).first.$1;
  final good = _str(j['good'], max: 300);
  final improve = _str(j['improve'], max: 300);
  final better = (j['better'] is String ? (j['better'] as String).trim() : '');
  return AnswerScore(
    relevansi: scores[0].$2,
    struktur: scores[1].$2,
    kejelasan: scores[2].$2,
    bukti: scores[3].$2,
    good: good.isEmpty ? strengthByAspect[strongest]! : good,
    improve: improve.isEmpty ? focusByAspect[weakest]! : improve,
    better: better.length < 40 ? null : (better.length > 1500 ? better.substring(0, 1500) : better),
  );
}

/// A generated cover letter; rejects output that is too short or does not address the right company.
String parseLetter(Map<String, Object?> j, {required Job job}) {
  final text = (j['surat'] is String ? j['surat'] as String : '').replaceAll('\r\n', '\n').trim();
  if (text.length < 200 || text.length > 4000 || !text.contains(job.company)) throw AiFailure.invalid;
  return text;
}
