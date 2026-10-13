// Writes the real-company catalogue (lib/data/catalog_real.dart) to backend/data/*.json for `npm --prefix backend run seed`.
// The fictional prototype jobs stay in the mock build only; the seed marks them inactive in Firestore.
// Run from the project root: dart run tool/export_seed.dart
import 'dart:convert';
import 'dart:io';

import 'package:karirin/data/catalog_real.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';

void main() {
  const encoder = JsonEncoder.withIndent('  ');
  void write(String name, Object data) {
    final file = File('backend/data/$name')..createSync(recursive: true);
    file.writeAsStringSync('${encoder.convert(data)}\n');
    stdout.writeln('${file.path}: ${(data as List).length} item');
  }

  write('jobs.json', [for (final j in realJobs) {'id': j.id, ...j.toMap()}]);
  write('skills.json', [
    for (final s in buildSkillCatalog(realJobs, {...resources, ...realResources})) {'id': s.id, ...withMaterial(s).toMap()},
  ]);
}

/// Every skill gets learning material with a link. Until the team curates a course per skill, the link is a search
/// for free videos on the material's title, which always resolves.
Skill withMaterial(Skill s) {
  final r = s.resource ?? LearningResource(ResourceType.modul, '2 jam', '${s.name} untuk Pemula');
  final url = r.url ?? 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(r.title)}';
  return Skill(name: s.name, synonyms: s.synonyms, resource: LearningResource(r.type, r.duration, r.title, url: url));
}
