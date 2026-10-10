import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';

/// A confirmed profile plus the skills the user marked as mastered through Skill Gap and the proof they gave
/// (skill → certificate link or note).
typedef StoredProfile = ({Profile profile, List<String> learned, Map<String, String> proofs});

/// The confirmed profile of one user (`profiles/{uid}`).
abstract interface class ProfileRepository {
  /// Null until the user has confirmed a profile.
  Future<StoredProfile?> fetch(String uid);
  Future<void> save(String uid, Profile profile, {List<String> learned = const [], Map<String, String> proofs = const {}});
  Future<void> delete(String uid);
}

/// In-memory profiles, lost when the app closes.
class MockProfileRepository implements ProfileRepository {
  final _profiles = <String, StoredProfile>{};

  @override
  Future<StoredProfile?> fetch(String uid) async => _profiles[uid];

  @override
  Future<void> save(String uid, Profile profile, {List<String> learned = const [], Map<String, String> proofs = const {}}) async =>
      _profiles[uid] = (profile: profile, learned: learned, proofs: proofs);

  @override
  Future<void> delete(String uid) async => _profiles.remove(uid);
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('profiles').doc(uid);

  @override
  Future<StoredProfile?> fetch(String uid) async {
    final data = (await _doc(uid).get()).data();
    if (data == null) return null;
    final proofs = Map<String, dynamic>.from((data['learningProofs'] as Map?) ?? const {});
    return (
      profile: Profile.fromMap(data),
      learned: [for (final s in (data['learned'] as List?) ?? const []) s as String],
      proofs: {for (final e in proofs.entries) if (e.value is String) e.key: e.value as String},
    );
  }

  @override
  Future<void> save(String uid, Profile profile, {List<String> learned = const [], Map<String, String> proofs = const {}}) =>
      _doc(uid).set({...profile.toMap(), 'learned': learned, 'learningProofs': proofs, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> delete(String uid) => _doc(uid).delete();
}
