import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import 'streams.dart';

/// Largest CV accepted for Lamar cepat (firestore.rules allows six parts of [cvPartBytes]).
const maxQuickCvBytes = 5 * 1024 * 1024;

/// A Firestore document holds at most 1 MiB, so the CV copy is stored in parts of this size.
const cvPartBytes = 900 * 1024;

/// [bytes] in order, split into parts of at most [cvPartBytes].
List<Uint8List> splitCv(Uint8List bytes) => [
  for (var i = 0; i < bytes.length; i += cvPartBytes) Uint8List.sublistView(bytes, i, min(i + cvPartBytes, bytes.length)),
];

/// What the company receives with a Lamar cepat application, besides the account's email.
class QuickApplyPacket {
  const QuickApplyPacket({required this.profile, required this.letter, required this.cv, required this.consent});
  final Profile profile;

  /// Cover letter; may be empty.
  final String letter;

  /// The CV as a PDF.
  final Uint8List cv;

  /// The consent sentence the user ticked.
  final String consent;
}

/// The user's applications (`users/{uid}/applications`): logged after applying on the company's site, or sent with
/// Lamar cepat to a partner company, which then sets the status.
abstract interface class ApplicationRepository {
  /// Newest first.
  Stream<List<JobApplication>> watch(String uid);
  Future<void> upsert(String uid, JobApplication application);

  /// Lamar cepat: stores [application] with [packet], the CV copy in parts under `applications/{id}/cv`.
  /// Completes once the server has it.
  Future<void> sendQuick(String uid, JobApplication application, QuickApplyPacket packet);

  /// Deletes the application and the CV copy sent with it.
  Future<void> delete(String uid, String applicationId);
}

/// In-memory applications, lost when the app closes.
class MockApplicationRepository implements ApplicationRepository {
  MockApplicationRepository([Map<String, List<JobApplication>>? seed]) : _apps = {...?seed};

  final Map<String, List<JobApplication>> _apps;
  final _changes = StreamController<String>.broadcast();

  /// Packets sent with Lamar cepat, by application id.
  final sent = <String, QuickApplyPacket>{};

  List<JobApplication> _of(String uid) => List.unmodifiable(_apps[uid] ?? const <JobApplication>[]);

  @override
  Stream<List<JobApplication>> watch(String uid) =>
      currentThenChanges(() => _of(uid), _changes.stream.where((id) => id == uid).map((_) => _of(uid)));

  @override
  Future<void> upsert(String uid, JobApplication application) async {
    final list = [...?_apps[uid]];
    final i = list.indexWhere((a) => a.id == application.id);
    i < 0 ? list.insert(0, application) : list[i] = application;
    _apps[uid] = list;
    _changes.add(uid);
  }

  @override
  Future<void> sendQuick(String uid, JobApplication application, QuickApplyPacket packet) async {
    sent[application.id] = packet;
    await upsert(uid, application);
  }

  @override
  Future<void> delete(String uid, String applicationId) async {
    sent.remove(applicationId);
    _apps[uid] = [...?_apps[uid]]..removeWhere((a) => a.id == applicationId);
    _changes.add(uid);
  }
}

class FirestoreApplicationRepository implements ApplicationRepository {
  FirestoreApplicationRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users').doc(uid).collection('applications');

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  static Map<String, Object?> _fields(JobApplication a) => {
    for (final e in a.toMap().entries) e.key: e.value is DateTime ? Timestamp.fromDate(e.value as DateTime) : e.value,
  };

  @override
  Stream<List<JobApplication>> watch(String uid) => _col(uid)
      .orderBy('appliedAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) JobApplication.fromMap(d.id, d.data(), toDate: _date)]);

  @override
  Future<void> upsert(String uid, JobApplication a) => _col(uid).doc(a.id).set({
    ..._fields(a),
    // History of every stage the user recorded, for the tracker and later evaluation.
    'statusHistory': FieldValue.arrayUnion([
      {'status': a.status.name, 'at': Timestamp.now()},
    ]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  @override
  Future<void> sendQuick(String uid, JobApplication a, QuickApplyPacket p) {
    final doc = _col(uid).doc(a.id);
    final parts = splitCv(p.cv);
    // One batch, application first: the rules check that CV parts belong to a Lamar cepat application.
    final batch = _db.batch()
      ..set(doc, {
        ..._fields(a),
        'statusHistory': [
          {'status': a.status.name, 'at': Timestamp.now()},
        ],
        'applicant': p.profile.toMap(),
        'letter': p.letter,
        'cv': {'size': p.cv.length, 'mimeType': 'application/pdf', 'parts': parts.length},
        'consent': {'text': p.consent, 'acceptedAt': FieldValue.serverTimestamp()},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    for (final (i, part) in parts.indexed) {
      batch.set(doc.collection('cv').doc('$i'), {'data': Blob(part)});
    }
    return batch.commit();
  }

  @override
  Future<void> delete(String uid, String applicationId) async {
    final doc = _col(uid).doc(applicationId);
    final batch = _db.batch();
    for (final part in (await doc.collection('cv').get()).docs) {
      batch.delete(part.reference);
    }
    batch.delete(doc);
    await batch.commit();
  }
}
