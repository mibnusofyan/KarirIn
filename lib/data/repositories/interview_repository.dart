import 'package:cloud_firestore/cloud_firestore.dart';

import '../../logic/interview.dart';
import '../models.dart';

/// Finished practice sessions (`users/{uid}/interviews`), written once and never edited.
abstract interface class InterviewRepository {
  Future<void> saveSession(String uid, {required Job job, required bool voice, required List<AnsweredQuestion> results});
}

class MockInterviewRepository implements InterviewRepository {
  final sessions = <String, List<List<AnsweredQuestion>>>{};

  @override
  Future<void> saveSession(String uid, {required Job job, required bool voice, required List<AnsweredQuestion> results}) async =>
      (sessions[uid] ??= []).add(results);
}

class FirestoreInterviewRepository implements InterviewRepository {
  FirestoreInterviewRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<void> saveSession(String uid, {required Job job, required bool voice, required List<AnsweredQuestion> results}) {
    final avg = averageScore(results);
    return _db.collection('users').doc(uid).collection('interviews').add({
      'jobId': job.id,
      'jobTitle': job.title,
      'mode': voice ? 'suara' : 'ketik',
      'finishedAt': FieldValue.serverTimestamp(),
      'items': [for (final r in results) r.toMap()],
      'average': {'relevansi': avg.relevansi, 'struktur': avg.struktur, 'kejelasan': avg.kejelasan, 'bukti': avg.bukti, 'total': avg.total},
      'offlineGraded': results.where((r) => r.score.offline).length,
    });
  }
}
