import 'package:cloud_firestore/cloud_firestore.dart';

import '../mock_data.dart' as mock;
import '../models.dart';

/// Curated catalogue: `jobs` and `skills` in Firestore, written only by the team's seed script.
abstract interface class JobRepository {
  /// Active jobs only.
  Future<List<Job>> fetchJobs();
  Future<List<Skill>> fetchSkills();

  /// The newest reviewed interview set for [jobId] (3 behavioural + 2 technical), or null when none exists yet.
  Future<List<InterviewQuestion>?> fetchQuestions(String jobId);
}

class MockJobRepository implements JobRepository {
  const MockJobRepository();

  @override
  Future<List<Job>> fetchJobs() async => mock.jobs;

  @override
  Future<List<Skill>> fetchSkills() async => mock.skillCatalog;

  @override
  Future<List<InterviewQuestion>?> fetchQuestions(String jobId) async => null;
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

  @override
  Future<List<InterviewQuestion>?> fetchQuestions(String jobId) async {
    final snap = await _db.collection('jobs').doc(jobId).collection('questionSets').orderBy('createdAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final qs = [
      for (final q in (snap.docs.first.data()['questions'] as List?) ?? const [])
        if (q is Map && q['text'] is String) InterviewQuestion.fromMap(Map<String, Object?>.from(q)),
    ];
    return qs.length == 5 ? qs : null;
  }
}
