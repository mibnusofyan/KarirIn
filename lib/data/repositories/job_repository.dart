import 'package:cloud_firestore/cloud_firestore.dart';

import '../mock_data.dart' as mock;
import '../models.dart';

/// Curated catalogue: `jobs` and `skills` in Firestore, written only by the team's seed script.
abstract interface class JobRepository {
  /// Active jobs only.
  Future<List<Job>> fetchJobs();
  Future<List<Skill>> fetchSkills();
}

class MockJobRepository implements JobRepository {
  const MockJobRepository();

  @override
  Future<List<Job>> fetchJobs() async => mock.jobs;

  @override
  Future<List<Skill>> fetchSkills() async => mock.skillCatalog;
}

class FirestoreJobRepository implements JobRepository {
  FirestoreJobRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<List<Job>> fetchJobs() async {
    final snap = await _db.collection('jobs').where('active', isEqualTo: true).get();
    return [for (final d in snap.docs) Job.fromMap(d.id, d.data())]..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<List<Skill>> fetchSkills() async {
    final snap = await _db.collection('skills').get();
    return [for (final d in snap.docs) Skill.fromMap(d.data())];
  }
}
