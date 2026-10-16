import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'reminders.dart';

/// Push messages for "Lowongan baru yang cocok" (notify-new-jobs script) and Lamar cepat status changes
/// (recruiter script).
abstract interface class PushService {
  /// Stores this device's FCM token under `users/{uid}.fcmTokens` and starts handling messages.
  /// [askPermission] shows Android's notification permission prompt when it has not been answered yet.
  Future<void> register(String uid, {required bool askPermission});

  /// Removes this device's token from the account (on sign-out).
  Future<void> unregister(String uid);
}

class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<void> register(String uid, {required bool askPermission}) async {}

  @override
  Future<void> unregister(String uid) async {}
}

class FcmPushService implements PushService {
  FcmPushService(this._local, [FirebaseFirestore? db, FirebaseMessaging? messaging])
    : _db = db ?? FirebaseFirestore.instance,
      _messaging = messaging ?? FirebaseMessaging.instance;

  final ReminderScheduler _local;
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;
  final _subs = <StreamSubscription<Object?>>[];
  bool _listening = false;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  void _listen() {
    if (_listening) return;
    _listening = true;
    // In the foreground Android does not show push notifications itself, so show it as a local notification.
    _subs.add(
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        final jobId = m.data['jobId'];
        if (n == null) return;
        _local.show(title: n.title ?? 'KarirIn', body: n.body ?? '', payload: jobId == null ? 'tracker' : 'job:$jobId');
      }),
    );
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_opened));
    unawaited(_messaging.getInitialMessage().then((m) => m == null ? null : _opened(m)));
  }

  void _opened(RemoteMessage m) {
    final jobId = m.data['jobId'];
    if (jobId is String && jobId.isNotEmpty) {
      notificationTaps.add('job:$jobId');
    } else if (m.data['applicationId'] != null) {
      notificationTaps.add('tracker');
    }
  }

  @override
  Future<void> register(String uid, {required bool askPermission}) async {
    _listen();
    try {
      await _local.init();
      if (askPermission) await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token != null) await _user(uid).update({'fcmTokens': FieldValue.arrayUnion([token])});
      _subs.add(_messaging.onTokenRefresh.listen((t) => _user(uid).update({'fcmTokens': FieldValue.arrayUnion([t])})));
    } catch (e) {
      // No Play services or no network: the app works without push.
      debugPrint('Push: $e');
    }
  }

  @override
  Future<void> unregister(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _user(uid).update({'fcmTokens': FieldValue.arrayRemove([token])}).timeout(const Duration(seconds: 5));
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Push: $e');
    }
  }
}
