// Shared Match Score fixtures (test/fixtures/match_cases.json): profiles × the full catalogue with the score the
// Dart code computes. backend/test/match-score.test.ts checks the TypeScript port used by notify-new-jobs against
// the same file, so the two implementations cannot drift apart.
//
// After changing Persamaan (1), regenerate: flutter test test/match_fixtures_test.dart --dart-define=UPDATE_FIXTURES=true
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/catalog_extra.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/logic/match_score.dart';

const _update = bool.fromEnvironment('UPDATE_FIXTURES');
final _file = File('test/fixtures/match_cases.json');

/// Persona Bayu from the Q&A path (SMK TKJ, PKL, no CV).
const _bayu = Profile(
  name: 'Bayu Pratama',
  level: EduLevel.smaSmk,
  major: 'Teknik Komputer dan Jaringan',
  school: '-',
  city: 'Purwokerto',
  modes: [WorkMode.kantor],
  source: ProfileSource.qa,
  skills: ['Jaringan Komputer', 'Perakitan PC', 'Microsoft Excel'],
  exps: [Experience(title: 'Praktik Kerja Lapangan', org: 'Tempat PKL', type: ExperienceType.magang, months: 3, field: 'teknologi')],
);

/// Persona Sinta: D3 Statistika, two years of office work, wants data jobs, open to remote.
const _sinta = Profile(
  name: 'Sinta Ayu Wardani',
  level: EduLevel.d3,
  major: 'Statistika',
  school: '-',
  city: 'Yogyakarta',
  modes: [WorkMode.remote, WorkMode.hybrid],
  source: ProfileSource.cvPdf,
  skills: ['Microsoft Excel', 'SQL', 'Visualisasi Data', 'Komunikasi', 'Ketelitian Data'],
  exps: [Experience(title: 'Staf Administrasi', org: 'PT Graha Niaga', type: ExperienceType.kerja, months: 24, field: 'data')],
);

Map<String, Object?> _build() {
  final profiles = {
    'rani': raniProfile,
    'rani-pelaporan': raniProfile.copyWith(skills: [...raniProfile.skills, 'Pelaporan Keuangan']),
    'bayu': _bayu,
    'sinta': _sinta,
  };
  return {
    'profiles': {for (final e in profiles.entries) e.key: e.value.toMap()},
    'cases': [
      for (final MapEntry(key: name, value: p) in profiles.entries)
        for (final j in [...jobs, ...extraJobs])
          {'profile': name, 'jobId': j.id, 'total': double.parse(computeMatch(j, p).total.toStringAsFixed(4))},
    ],
  };
}

void main() {
  test('Match Score sama dengan fixture bersama Dart/TypeScript', () {
    final built = _build();
    if (_update) {
      _file
        ..createSync(recursive: true)
        ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(built)}\n');
    }
    final stored = jsonDecode(_file.readAsStringSync()) as Map<String, Object?>;
    expect(jsonEncode(built), jsonEncode(stored), reason: 'Rumus atau katalog berubah: perbarui fixture dengan UPDATE_FIXTURES=true');
    final j1 = (stored['cases']! as List).cast<Map<String, Object?>>().where((c) => c['jobId'] == 'j1');
    expect([for (final c in j1.take(2)) c['total']], [80.0, 92.5], reason: 'Tabel 2.4');
  });
}
