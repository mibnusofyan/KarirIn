import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'streams.dart';

/// The signed-in account, independent of the auth provider.
class AuthUser {
  const AuthUser({required this.uid, required this.email, required this.displayName, required this.provider});
  final String uid;
  final String email;
  final String displayName;

  /// `password` or `google`.
  final String provider;
}

/// A failure the user can act on, already worded in Bahasa Indonesia.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.field});
  final String message;

  /// `email` or `password` when the message belongs under that field.
  final String? field;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  /// Emits the current user (or null) on listen, then on every change.
  Stream<AuthUser?> authStateChanges();
  Future<void> signIn({required String email, required String password});
  Future<void> register({required String name, required String email, required String password});

  /// Returns false when the user closed the Google account picker.
  Future<bool> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Firebase only deletes accounts that signed in within the last few minutes.
  bool get recentlySignedIn;

  /// The signed-in user's id, or null.
  String? get currentUid;

  /// Deletes the account itself; the caller removes the user's data first.
  Future<void> deleteAccount();
}

/// Accepts any input and keeps the user in memory.
class MockAuthRepository implements AuthRepository {
  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();

  void _set(AuthUser? u) => _changes.add(_user = u);

  @override
  Stream<AuthUser?> authStateChanges() => currentThenChanges(() => _user, _changes.stream);

  @override
  Future<void> signIn({required String email, required String password}) async =>
      _set(AuthUser(uid: 'demo', email: email, displayName: '', provider: 'password'));

  @override
  Future<void> register({required String name, required String email, required String password}) async =>
      _set(AuthUser(uid: 'demo', email: email, displayName: name, provider: 'password'));

  @override
  Future<bool> signInWithGoogle() async {
    _set(const AuthUser(uid: 'demo', email: 'demo@gmail.com', displayName: '', provider: 'google'));
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => _set(null);

  @override
  bool get recentlySignedIn => true;

  @override
  String? get currentUid => _user?.uid;

  @override
  Future<void> deleteAccount() async => _set(null);
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance {
    _auth.setLanguageCode('id');
  }

  final FirebaseAuth _auth;
  Future<void>? _googleReady;

  static AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(
          uid: u.uid,
          email: u.email ?? '',
          displayName: u.displayName ?? '',
          provider: u.providerData.any((p) => p.providerId == 'google.com') ? 'google' : 'password',
        );

  // userChanges (not authStateChanges) so the display name set right after registering is picked up.
  @override
  Stream<AuthUser?> authStateChanges() => _auth.userChanges().map(_map).distinct((a, b) => a?.uid == b?.uid);

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseAuthException catch (e) {
      throw authFailureFor(e.code);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> register({required String name, required String email, required String password}) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user?.updateDisplayName(name.trim());
  });

  @override
  Future<bool> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    // The Android plugin reads the web client id from google-services.json.
    await (_googleReady ??= google.initialize());
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw const AuthFailure('Masuk dengan Google gagal. Periksa koneksi lalu coba lagi.');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthFailure('Masuk dengan Google gagal. Coba lagi.');
    await _guard(() => _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken)));
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleReady != null) await GoogleSignIn.instance.signOut();
  }

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  bool get recentlySignedIn {
    final at = _auth.currentUser?.metadata.lastSignInTime;
    return at != null && DateTime.now().difference(at) < const Duration(minutes: 4);
  }

  @override
  Future<void> deleteAccount() => _guard(() async {
    await _auth.currentUser?.delete();
    if (_googleReady != null) await GoogleSignIn.instance.signOut();
  });
}

/// Maps Firebase Auth error codes to messages for the form.
AuthFailure authFailureFor(String code) => switch (code) {
  'invalid-email' => const AuthFailure('Format email tidak valid.', field: 'email'),
  'email-already-in-use' => const AuthFailure('Email ini sudah terdaftar. Pilih Masuk.', field: 'email'),
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' => const AuthFailure('Email atau kata sandi salah.'),
  'weak-password' => const AuthFailure('Kata sandi terlalu lemah. Gunakan minimal 8 karakter.', field: 'password'),
  'user-disabled' => const AuthFailure('Akun ini dinonaktifkan.'),
  'too-many-requests' => const AuthFailure('Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.'),
  'network-request-failed' => const AuthFailure('Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.'),
  'requires-recent-login' => const AuthFailure('Demi keamanan, keluar lalu masuk kembali sebelum menghapus akun.'),
  'account-exists-with-different-credential' => const AuthFailure(
    'Email ini sudah terdaftar dengan kata sandi. Masuk dengan email dan kata sandi.',
  ),
  _ => const AuthFailure('Terjadi kesalahan. Coba lagi.'),
};
