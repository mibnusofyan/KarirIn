import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/confirm_profile_screen.dart';
import 'screens/create_profile_screen.dart';
import 'screens/home_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/letter_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qa_screen.dart';
import 'screens/result_screen.dart';
import 'screens/session_screen.dart';
import 'screens/skill_gap_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tracker_screen.dart';
import 'state/session.dart';
import 'widgets/nav_shell.dart';

abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const create = '/create';
  static const qa = '/qa';
  static const processing = '/processing';
  static const confirm = '/confirm';
  static const home = '/home';
  static const gap = '/gap';
  static const coach = '/coach';
  static const tracker = '/tracker';
  static const profile = '/profile';
  static const session = '/session';
  static const result = '/result';
  static const letter = '/letter';
  static String job(String id) => '/job/$id';
}

Page<void> _noAnim(Widget child, GoRouterState s) => NoTransitionPage(key: s.pageKey, child: child);

final router = GoRouter(
  initialLocation: Routes.splash,
  refreshListenable: session,
  redirect: (_, s) => sessionRedirect(s.matchedLocation),
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: Routes.auth, builder: (_, _) => const AuthScreen()),
    GoRoute(path: Routes.create, builder: (_, _) => const CreateProfileScreen()),
    GoRoute(path: Routes.qa, builder: (_, _) => const QaScreen()),
    GoRoute(
      path: Routes.processing,
      builder: (_, s) => ProcessingScreen(fromQa: s.uri.queryParameters['kind'] == 'qa'),
    ),
    GoRoute(
      path: Routes.confirm,
      builder: (_, s) => ConfirmProfileScreen(editing: s.uri.queryParameters['edit'] == '1'),
    ),
    ShellRoute(
      builder: (_, s, child) => NavShell(location: s.uri.path, child: child),
      routes: [
        GoRoute(path: Routes.home, pageBuilder: (_, s) => _noAnim(const HomeScreen(), s)),
        GoRoute(path: Routes.gap, pageBuilder: (_, s) => _noAnim(const SkillGapScreen(), s)),
        GoRoute(path: Routes.coach, pageBuilder: (_, s) => _noAnim(const CoachScreen(), s)),
        GoRoute(path: Routes.tracker, pageBuilder: (_, s) => _noAnim(const TrackerScreen(), s)),
        GoRoute(path: Routes.profile, pageBuilder: (_, s) => _noAnim(const ProfileScreen(), s)),
      ],
    ),
    GoRoute(
      path: '/job/:id',
      builder: (_, s) => JobDetailScreen(jobId: s.pathParameters['id']!),
    ),
    GoRoute(path: Routes.session, builder: (_, _) => const SessionScreen()),
    GoRoute(path: Routes.result, builder: (_, _) => const ResultScreen()),
    GoRoute(
      path: Routes.letter,
      builder: (_, s) => LetterScreen(jobId: s.uri.queryParameters['job'] ?? 'j1'),
    ),
  ],
);

extension NavX on BuildContext {
  /// Pops when there is somewhere to go back to, otherwise jumps to [fallback].
  void back(String fallback) => canPop() ? pop() : go(fallback);
}
