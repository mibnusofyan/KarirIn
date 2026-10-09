import 'dart:async';

import '../models.dart';

/// The confirmed profile of one user (`profiles/{uid}`).
abstract interface class ProfileRepository {
  /// Emits null until the user has confirmed a profile.
  Stream<Profile?> watch(String uid);
  Future<void> save(String uid, Profile profile);
  Future<void> delete(String uid);
}

/// In-memory profiles, lost when the app closes.
class MockProfileRepository implements ProfileRepository {
  final _profiles = <String, Profile>{};
  final _changes = StreamController<String>.broadcast();

  @override
  Stream<Profile?> watch(String uid) async* {
    yield _profiles[uid];
    yield* _changes.stream.where((id) => id == uid).map((_) => _profiles[uid]);
  }

  @override
  Future<void> save(String uid, Profile profile) async {
    _profiles[uid] = profile;
    _changes.add(uid);
  }

  @override
  Future<void> delete(String uid) async {
    _profiles.remove(uid);
    _changes.add(uid);
  }
}
