import 'dart:ui';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// Formats a score the Indonesian way with at most one decimal: 92.5 → "92,5".
String fmt(num n) {
  final r = (n * 10).round() / 10;
  final s = r == r.truncateToDouble() ? r.toInt().toString() : r.toString();
  return s.replaceAll('.', ',');
}

/// Joins a list as "a, b dan c".
String joinId(List<String> a) {
  if (a.isEmpty) return '';
  if (a.length == 1) return a.first;
  return '${a.sublist(0, a.length - 1).join(', ')} dan ${a.last}';
}

enum MatchCategory {
  high('Sangat Cocok', KColors.secondaryContainer, KColors.onSecondaryContainer, KColors.secondary),
  mid('Cukup Cocok', KColors.tertiaryContainer, KColors.onTertiaryContainer, KColors.midBar),
  low('Perlu Persiapan', KColors.errorContainer, KColors.onErrorContainer, KColors.error);

  const MatchCategory(this.label, this.bg, this.fg, this.bar);
  final String label;
  final Color bg;
  final Color fg;
  final Color bar;

  static MatchCategory of(double total) => total >= 75
      ? high
      : total >= 50
      ? mid
      : low;
}

/// Bar colour for a 0–1 component value.
Color barColor(double v) => v >= 0.75
    ? KColors.secondary
    : v >= 0.5
    ? KColors.midBar
    : KColors.error;

class MatchResult {
  const MatchResult({
    required this.matchedWajib,
    required this.missingWajib,
    required this.matchedTambahan,
    required this.missingTambahan,
    required this.sw,
    required this.st,
    required this.sp,
    required this.se,
    required this.sl,
    required this.relevantMonths,
    required this.levelOk,
    required this.fieldOk,
    required this.cityOk,
    required this.modeOk,
  });

  final List<String> matchedWajib;
  final List<String> missingWajib;
  final List<String> matchedTambahan;
  final List<String> missingTambahan;
  final double sw, st, sp, se, sl;
  final double relevantMonths;
  final bool levelOk, fieldOk, cityOk, modeOk;

  /// Persamaan (1): Match Score = 100 × (0,50·Sw + 0,15·St + 0,15·Sp + 0,10·Se + 0,10·Sl)
  double get total => 100 * (0.5 * sw + 0.15 * st + 0.15 * sp + 0.1 * se + 0.1 * sl);

  MatchCategory get category => MatchCategory.of(total);
}

/// Deterministic Match Score (proposal 2.2.2): AI only extracts data, the score is a fixed weighted formula.
MatchResult computeMatch(Job job, Profile p) {
  bool has(String s) => p.skills.contains(s);
  final mW = job.wajib.where(has).toList();
  final xW = job.wajib.where((s) => !has(s)).toList();
  final mT = job.tambahan.where(has).toList();
  final xT = job.tambahan.where((s) => !has(s)).toList();

  final levelOk = p.level.rank >= job.eduMin.rank;
  final fieldOk = job.anyMajor || job.eduFields.contains(p.major);
  final sp = levelOk && fieldOk
      ? 1.0
      : (levelOk || fieldOk)
      ? 0.5
      : 0.0;

  // Internships and organisations count half; 1 when the job needs no experience.
  var se = 1.0;
  var rel = 0.0;
  if (job.expYears > 0) {
    rel = p.exps.where((e) => e.field == job.field).fold(0.0, (a, e) => a + (e.type == ExperienceType.kerja ? e.months : e.months / 2));
    se = (rel / (job.expYears * 12)).clamp(0.0, 1.0);
  }

  // "Seluruh Indonesia": the programme places hires nationwide, so any home city matches.
  final cityOk = job.mode == WorkMode.remote || job.city == anyCity || job.city == p.city;
  final modeOk = p.modes.contains(job.mode);
  final sl = cityOk && modeOk
      ? 1.0
      : (cityOk || modeOk)
      ? 0.5
      : 0.0;

  return MatchResult(
    matchedWajib: mW,
    missingWajib: xW,
    matchedTambahan: mT,
    missingTambahan: xT,
    sw: mW.length / job.wajib.length,
    st: mT.length / job.tambahan.length,
    sp: sp,
    se: se,
    sl: sl,
    relevantMonths: rel,
    levelOk: levelOk,
    fieldOk: fieldOk,
    cityOk: cityOk,
    modeOk: modeOk,
  );
}

class ScoredJob {
  const ScoredJob(this.job, this.result);
  final Job job;
  final MatchResult result;
}

/// All jobs sorted by Match Score, highest first.
List<ScoredJob> rankJobs(List<Job> jobs, Profile p) =>
    jobs.map((j) => ScoredJob(j, computeMatch(j, p))).toList()..sort((a, b) => b.result.total.compareTo(a.result.total));

/// A missing skill with the points it would add if mastered.
class GapItem {
  const GapItem(this.skill, this.wajib, this.gain);
  final String skill;
  final bool wajib;
  final double gain;
}

/// Missing skills for [job], most score impact first.
List<GapItem> skillGap(Job job, MatchResult r) => [
  ...r.missingWajib.map((s) => GapItem(s, true, 50 / job.wajib.length)),
  ...r.missingTambahan.map((s) => GapItem(s, false, 15 / job.tambahan.length)),
]..sort((a, b) => b.gain.compareTo(a.gain));

/// Normalises common skill spellings to the KarirIn canonical list ("MS Excel" → "Microsoft Excel").
/// [catalog] (Firestore `skills`) is matched first, case-insensitively, on names and synonyms.
String normalizeSkill(String raw, [List<Skill> catalog = const []]) {
  final v = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  final key = v.toLowerCase();
  for (final s in catalog) {
    if (s.name.toLowerCase() == key || s.synonyms.any((x) => x.toLowerCase() == key)) return s.name;
  }
  if (RegExp(r'^(ms\s*excel|excel)$', caseSensitive: false).hasMatch(v)) return 'Microsoft Excel';
  if (RegExp(r'^(ms\s*word|word)$', caseSensitive: false).hasMatch(v)) return 'Microsoft Word';
  return v;
}
