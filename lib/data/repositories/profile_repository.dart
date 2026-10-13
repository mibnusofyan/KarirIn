import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';

/// A confirmed profile plus the skills the user marked as mastered through Skill Gap and the proof they gave
/// (skill → certificate link or note).
typedef StoredProfile = ({Profile profile, List<String> learned, Map<String, String> proofs});

/// Largest profile photo accepted, in bytes (also enforced by firestore.rules).
const maxProfilePhotoBytes = 600 * 1024;

/// The confirmed profile of one user (`profiles/{uid}`) and their profile photo (`profilePhotos/{uid}`).
abstract interface class ProfileRepository {
  /// Null until the user has confirmed a profile.
  Future<StoredProfile?> fetch(String uid);
  Future<void> save(String uid, Profile profile, {List<String> learned = const [], Map<String, String> proofs = const {}});

  /// Deletes the profile and the photo.
  Future<void> delete(String uid);

  /// The photo as image bytes (JPEG or PNG, already resized by the app); null when the user has none.
  Future<Uint8List?> fetchPhoto(String uid);
  Future<void> savePhoto(String uid, Uint8List image);
  Future<void> deletePhoto(String uid);
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
  Future<void> delete(String uid) async {
    _profiles.remove(uid);
    _photos.remove(uid);
  }

  final _photos = <String, Uint8List>{};

  @override
  Future<Uint8List?> fetchPhoto(String uid) async => _photos[uid];

  @override
  Future<void> savePhoto(String uid, Uint8List image) async => _photos[uid] = image;

  @override
  Future<void> deletePhoto(String uid) async => _photos.remove(uid);
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
      proofs: {
        for (final e in proofs.entries)
          if (e.value is String) e.key: e.value as String,
      },
    );
  }

  @override
  Future<void> save(String uid, Profile profile, {List<String> learned = const [], Map<String, String> proofs = const {}}) =>
      _doc(uid).set({...profile.toMap(), 'learned': learned, 'learningProofs': proofs, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> delete(String uid) async {
    await deletePhoto(uid);
    await _doc(uid).delete();
  }

  // Cloud Storage needs the paid Blaze plan, so the small resized photo is kept as bytes in its own document,
  // apart from the profile that is rewritten on every change.
  DocumentReference<Map<String, dynamic>> _photo(String uid) => _db.collection('profilePhotos').doc(uid);

  @override
  Future<Uint8List?> fetchPhoto(String uid) async {
    final image = (await _photo(uid).get()).data()?['image'];
    return image is Blob ? image.bytes : null;
  }

  @override
  Future<void> savePhoto(String uid, Uint8List image) => _photo(uid).set({'image': Blob(image), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> deletePhoto(String uid) => _photo(uid).delete();
}
