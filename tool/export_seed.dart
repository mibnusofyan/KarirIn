// Writes the curated prototype data to backend/data/*.json for `npm --prefix backend run seed`.
// Run from the project root: dart run tool/export_seed.dart
import 'dart:convert';
import 'dart:io';

import 'package:karirin/data/catalog_extra.dart';
import 'package:karirin/data/mock_data.dart';

void main() {
  const encoder = JsonEncoder.withIndent('  ');
  void write(String name, Object data) {
    final file = File('backend/data/$name')..createSync(recursive: true);
    file.writeAsStringSync('${encoder.convert(data)}\n');
    stdout.writeln('${file.path}: ${(data as List).length} item');
  }

  final allJobs = [...jobs, ...extraJobs];
  write('jobs.json', [for (final j in allJobs) {'id': j.id, ...j.toMap()}]);
  write('skills.json', [
    for (final s in buildSkillCatalog(allJobs, {...resources, ...extraResources})) {'id': s.id, ...s.toMap()},
  ]);
}
