// Writes the curated prototype data to backend/data/*.json for `npm --prefix backend run seed`.
// Run from the project root: dart run tool/export_seed.dart
import 'dart:convert';
import 'dart:io';

import 'package:karirin/data/mock_data.dart';

void main() {
  const encoder = JsonEncoder.withIndent('  ');
  void write(String name, Object data) {
    final file = File('backend/data/$name')..createSync(recursive: true);
    file.writeAsStringSync('${encoder.convert(data)}\n');
    stdout.writeln('${file.path}: ${(data as List).length} item');
  }

  write('jobs.json', [
    for (final j in jobs) {'id': j.id, ...j.toMap()},
  ]);
  write('skills.json', [
    for (final s in skillCatalog) {'id': s.id, ...s.toMap()},
  ]);
}
