// Writes the real-company catalogue (lib/data/catalog_real.dart) to backend/data/*.json for `npm --prefix backend run seed`.
// The fictional prototype jobs stay in the mock build only; the seed marks them inactive in Firestore.
// Run from the project root: dart run tool/export_seed.dart
import 'dart:convert';
import 'dart:io';

import 'package:karirin/data/catalog_real.dart';
import 'package:karirin/data/learning_videos.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';

void main() {
  const encoder = JsonEncoder.withIndent('  ');
  void write(String name, Object data) {
    final file = File('backend/data/$name')..createSync(recursive: true);
    file.writeAsStringSync('${encoder.convert(data)}\n');
    stdout.writeln('${file.path}: ${(data as List).length} item');
  }

  write('jobs.json', [
    for (final j in realJobs) {'id': j.id, ...j.toMap()},
  ]);
  write('skills.json', [
    for (final s in buildSkillCatalog(realJobs, {...resources, ...realResources})) {'id': s.id, ...withMaterial(s).toMap()},
  ]);
}

/// Every skill's material is its curated video (lib/data/learning_videos.dart), played inside the app.
Skill withMaterial(Skill s) {
  final v = learningVideos[s.name];
  if (v == null) throw StateError('Belum ada video belajar untuk skill "${s.name}" di lib/data/learning_videos.dart');
  final title = s.resource?.title ?? '${s.name} untuk Pemula';
  return Skill(
    name: s.name,
    synonyms: s.synonyms,
    resource: LearningResource(ResourceType.video, v.durationLabel, title, url: v.url, provider: v.channel),
  );
}
