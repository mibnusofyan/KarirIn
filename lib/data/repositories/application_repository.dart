import 'dart:async';

import '../models.dart';
import 'streams.dart';

/// Applications the user logged after applying through the company's official channel
/// (`users/{uid}/applications`).
abstract interface class ApplicationRepository {
  /// Newest first.
  Stream<List<JobApplication>> watch(String uid);
  Future<void> upsert(String uid, JobApplication application);
  Future<void> delete(String uid, String applicationId);
}

/// In-memory applications, lost when the app closes.
class MockApplicationRepository implements ApplicationRepository {
  MockApplicationRepository([Map<String, List<JobApplication>>? seed]) : _apps = {...?seed};

  final Map<String, List<JobApplication>> _apps;
  final _changes = StreamController<String>.broadcast();

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
  Future<void> delete(String uid, String applicationId) async {
    _apps[uid] = [...?_apps[uid]]..removeWhere((a) => a.id == applicationId);
    _changes.add(uid);
  }
}
