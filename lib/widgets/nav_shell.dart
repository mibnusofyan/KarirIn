import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/career_theme.dart';

/// Bottom navigation for the five main sections.
class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    (Routes.home, 'Beranda', Icons.home_outlined, Icons.home_rounded),
    (
      Routes.gap,
      'Skill Gap',
      Icons.trending_up_rounded,
      Icons.trending_up_rounded,
    ),
    (
      Routes.coach,
      'Latihan',
      Icons.record_voice_over_outlined,
      Icons.record_voice_over_rounded,
    ),
    (Routes.tracker, 'Lamaran', Icons.work_outline_rounded, Icons.work_rounded),
    (
      Routes.profile,
      'Profil',
      Icons.person_outline_rounded,
      Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _tabs
        .indexWhere((t) => location.startsWith(t.$1))
        .clamp(0, _tabs.length - 1);
    return Scaffold(
      body: child,
      bottomNavigationBar: Theme(
        data: location == Routes.home
            ? CareerTheme.of(context)
            : Theme.of(context),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_tabs[i].$1),
          destinations: [
            for (final t in _tabs)
              NavigationDestination(
                icon: Icon(t.$3),
                selectedIcon: Icon(t.$4),
                label: t.$2,
              ),
          ],
        ),
      ),
    );
  }
}
