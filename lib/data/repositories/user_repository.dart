import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_repository.dart';

/// Account-level data in `users/{uid}`: saved jobs, notification settings and consent.
class UserData {
  const UserData({this.savedJobIds = const {}, this.notifyNewJobs = true, this.notifyReminders = true});
  final Set<String> savedJobIds;
  final bool notifyNewJobs;
  final bool notifyReminders;
}

abstract interface class UserRepository {
  /// Creates the document on first sign-in (keeping existing fields) and returns what is stored.
  Future<UserData> ensure(AuthUser user);
  Future<void> setSavedJobs(String uid, Set<String> jobIds);
  Future<void> setNotifications(String uid, {required bool newJobs, required bool reminders});

  /// Records the explicit consent to process a CV (UU No. 27/2022) with the version of the text shown.
  Future<void> recordCvConsent(String uid, String version);
  Future<void> delete(String uid);
}

class MockUserRepository implements UserRepository {
  final _users = <String, UserData>{};

  @override
  Future<UserData> ensure(AuthUser user) async => _users.putIfAbsent(user.uid, UserData.new);

  @override
  Future<void> setSavedJobs(String uid, Set<String> jobIds) async {
    final u = _users[uid] ?? const UserData();
    _users[uid] = UserData(savedJobIds: jobIds, notifyNewJobs: u.notifyNewJobs, notifyReminders: u.notifyReminders);
  }

  @override
  Future<void> setNotifications(String uid, {required bool newJobs, required bool reminders}) async =>
      _users[uid] = UserData(savedJobIds: _users[uid]?.savedJobIds ?? const {}, notifyNewJobs: newJobs, notifyReminders: reminders);

  @override
  Future<void> recordCvConsent(String uid, String version) async {}

  @override
  Future<void> delete(String uid) async => _users.remove(uid);
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  @override
  Future<UserData> ensure(AuthUser user) async {
    final ref = _doc(user.uid);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) {
      await ref.set({
        'displayName': user.displayName,
        'email': user.email,
        'provider': user.provider,
        'createdAt': FieldValue.serverTimestamp(),
        'settings': {'notifyNewJobs': true, 'notifyReminders': true},
        'savedJobIds': <String>[],
      });
      return const UserData();
    }
    final settings = Map<String, dynamic>.from((data['settings'] as Map?) ?? const {});
    return UserData(
      savedJobIds: {for (final id in (data['savedJobIds'] as List?) ?? const []) id as String},
      notifyNewJobs: settings['notifyNewJobs'] as bool? ?? true,
      notifyReminders: settings['notifyReminders'] as bool? ?? true,
    );
  }

  @override
  Future<void> setSavedJobs(String uid, Set<String> jobIds) =>
      _doc(uid).update({'savedJobIds': jobIds.toList(), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> setNotifications(String uid, {required bool newJobs, required bool reminders}) => _doc(uid).update({
    'settings': {'notifyNewJobs': newJobs, 'notifyReminders': reminders},
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> recordCvConsent(String uid, String version) => _doc(uid).update({
    'consent': {'cvProcessing': true, 'version': version, 'acceptedAt': FieldValue.serverTimestamp()},
  });

  /// Deletes the user document and every subcollection under it (the client SDK does not cascade).
  @override
  Future<void> delete(String uid) async {
    for (final sub in const ['applications', 'interviews', 'matches', 'notifications']) {
      final docs = (await _doc(uid).collection(sub).get()).docs;
      for (var i = 0; i < docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _doc(uid).delete();
  }
}
