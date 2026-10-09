import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backend.dart';
import '../router.dart';

/// Where the signed-in user stands; drives the router redirect when running on Firebase.
enum SessionStatus {
  /// Waiting for the first auth state and the user's data.
  loading,
  signedOut,

  /// Signed in, but no confirmed profile yet.
  needsProfile,
  ready,
}

/// Global so the router (created outside Riverpod) can listen to it. Mock builds are always [SessionStatus.ready].
final session = ValueNotifier<SessionStatus>(backend == Backend.mock ? SessionStatus.ready : SessionStatus.loading);

const _onboardingSeenKey = 'onboarding_seen';

Future<void> markOnboardingSeen() async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_onboardingSeenKey, true);
  } catch (_) {
    // Showing onboarding twice is harmless.
  }
}

/// Where the splash goes once its animation ends. Waits for the session when it is still loading.
Future<String> routeAfterSplash() async {
  if (backend == Backend.mock) return Routes.onboarding;
  while (session.value == SessionStatus.loading) {
    await _nextChange(session);
  }
  switch (session.value) {
    case SessionStatus.ready:
      return Routes.home;
    case SessionStatus.needsProfile:
      return Routes.create;
    case SessionStatus.signedOut || SessionStatus.loading:
      try {
        final seen = (await SharedPreferences.getInstance()).getBool(_onboardingSeenKey) ?? false;
        return seen ? Routes.auth : Routes.onboarding;
      } catch (_) {
        return Routes.onboarding;
      }
  }
}

Future<void> _nextChange(Listenable l) {
  final done = Completer<void>();
  void listener() {
    l.removeListener(listener);
    done.complete();
  }

  l.addListener(listener);
  return done.future;
}

/// Firebase-only redirect: signed-out users stay on the welcome screens, users without a profile stay in
/// profile creation, and signed-in users skip sign-in.
String? sessionRedirect(String location, {Backend mode = backend}) {
  if (mode == Backend.mock) return null;
  const welcome = {Routes.splash, Routes.onboarding, Routes.auth};
  const setup = {Routes.create, Routes.qa, Routes.processing, Routes.confirm};
  return switch (session.value) {
    SessionStatus.loading => location == Routes.splash ? null : Routes.splash,
    SessionStatus.signedOut => welcome.contains(location) ? null : Routes.auth,
    SessionStatus.needsProfile => location == Routes.splash || setup.contains(location) ? null : Routes.create,
    SessionStatus.ready => location == Routes.auth || location == Routes.onboarding ? Routes.home : null,
  };
}
