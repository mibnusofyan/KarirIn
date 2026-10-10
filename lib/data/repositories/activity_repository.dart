import 'package:cloud_firestore/cloud_firestore.dart';

import '../../logic/match_score.dart';

/// A notification written by the team's notify-new-jobs script (`users/{uid}/notifications`).
class AppNotification {
  const AppNotification({required this.id, required this.title, required this.body, this.jobId, this.createdAt, this.read = false});
  final String id;
  final String title;
  final String body;
  final String? jobId;
  final DateTime? createdAt;
  final bool read;
}

/// Data derived from the user's activity: score snapshots and notifications.
abstract interface class ActivityRepository {
  /// Stores the current Match Score per job (`users/{uid}/matches/{jobId}`), used to validate the score against
  /// manual ratings (proposal 3.2.3).
  Future<void> saveMatches(String uid, List<ScoredJob> scored);

  /// Newest first.
  Future<List<AppNotification>> fetchNotifications(String uid);
}

class MockActivityRepository implements ActivityRepository {
  final matches = <String, List<ScoredJob>>{};

  @override
  Future<void> saveMatches(String uid, List<ScoredJob> scored) async => matches[uid] = scored;

  @override
  Future<List<AppNotification>> fetchNotifications(String uid) async => const [];
}

class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  /// Bump when the weights or components of Persamaan (1) change.
  static const formulaVersion = 1;

  @override
  Future<void> saveMatches(String uid, List<ScoredJob> scored) {
    final batch = _db.batch();
    final col = _db.collection('users').doc(uid).collection('matches');
    for (final s in scored) {
      final r = s.result;
      batch.set(col.doc(s.job.id), {
        'total': double.parse(r.total.toStringAsFixed(1)),
        'category': r.category.name,
        'sw': r.sw,
        'st': r.st,
        'sp': r.sp,
        'se': r.se,
        'sl': r.sl,
        'matched': [...r.matchedWajib, ...r.matchedTambahan],
        'missing': [...r.missingWajib, ...r.missingTambahan],
        'formulaVersion': formulaVersion,
        'computedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  @override
  Future<List<AppNotification>> fetchNotifications(String uid) async {
    final snap = await _db.collection('users').doc(uid).collection('notifications').orderBy('createdAt', descending: true).limit(20).get();
    return [
      for (final d in snap.docs)
        AppNotification(
          id: d.id,
          title: (d.data()['title'] as String?) ?? '',
          body: (d.data()['body'] as String?) ?? '',
          jobId: d.data()['jobId'] as String?,
          createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
          read: (d.data()['read'] as bool?) ?? false,
        ),
    ];
  }
}
