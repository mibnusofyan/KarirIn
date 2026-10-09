import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Remote Config defaults (plan section 5.3). The APK is frozen at submission, so AI models and switches stay
/// changeable from the console.
const remoteConfigDefaults = <String, Object>{
  'ai_model_extract': 'gemini-3.8-flash',
  'ai_model_fast': 'gemini-3.5-flash-lite',
  'ai_enabled': true,
  'consent_version': '2026-10-v1',
  'max_cv_mb': 5,
};

/// `--dart-define=USE_EMULATOR=true` (debug builds): Auth and Firestore go to the Local Emulator Suite on the
/// development machine instead of the real project. 10.0.2.2 is the host as seen from the Android emulator.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

/// Connects to Firebase before the first frame. Only called when built with `BACKEND=firebase`.
Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_useEmulator && !kReleaseMode) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  }

  // Play Integrity in release builds (configured for apps distributed outside Google Play); debug builds and
  // emulators use the debug provider, whose token is registered in the Firebase console.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);

  final config = FirebaseRemoteConfig.instance;
  await config.setDefaults(remoteConfigDefaults);
  await config.setConfigSettings(
    RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
  );
  // Defaults are enough to start; fresh values apply once fetched and are not worth delaying the splash for.
  unawaited(config.fetchAndActivate().catchError((Object _) => false));
}
