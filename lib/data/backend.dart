/// Which data source the app runs on.
///
/// Firebase by default. Mock (the offline prototype data) is used for `flutter test`, the web preview (there is
/// no web Firebase config) and backup demo builds. Force either with `--dart-define=BACKEND=mock|firebase`.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

enum Backend { mock, firebase }

final Backend backend = _resolve();

Backend _resolve() {
  const forced = String.fromEnvironment('BACKEND');
  if (forced == 'mock') return Backend.mock;
  if (forced == 'firebase') return Backend.firebase;
  if (kIsWeb) return Backend.mock;
  // `flutter test` sets FLUTTER_TEST; widget tests run on the prototype data.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return Backend.mock;
  return Backend.firebase;
}
