import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/career_theme.dart';
import '../widgets/common.dart';

/// Short branded splash: the K mark scales in, then onboarding. Tap anywhere to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Total time before moving on.
  static const duration = Duration(milliseconds: 1400);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: SplashScreen.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    })
    ..forward();
  bool _left = false;

  void _next() {
    if (_left || !mounted) return;
    _left = true;
    context.go(Routes.onboarding);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Entrance uses the first ~40% of the timeline.
    final entrance = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .4, curve: Curves.easeOutCubic),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: CareerColors.navy),
      child: Scaffold(
        backgroundColor: CareerColors.navy,
        body: Semantics(
          label: 'KarirIn. Cocok skill-nya, siap kerjanya. Ketuk untuk melanjutkan.',
          button: true,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _c.stop();
              _next();
            },
            child: Stack(
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: entrance,
                    builder: (context, child) {
                      final t = reduceMotion ? 1.0 : entrance.value;
                      return Opacity(
                        opacity: t,
                        child: Transform.scale(scale: .9 + .1 * t, child: child),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(40)),
                          child: const KarirInMark(size: 104),
                        ),
                        const SizedBox(height: 28),
                        const Text.rich(
                          TextSpan(
                            text: 'Karir',
                            children: [
                              TextSpan(
                                text: 'In',
                                style: TextStyle(color: Color(0xFFB5E5D4)),
                              ),
                            ],
                          ),
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 42,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Cocok skill-nya, siap kerjanya.',
                          style: CareerText.body.copyWith(fontSize: 16, color: const Color(0xFFC4D6E7)),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 56,
                  child: Center(
                    child: SizedBox(
                      width: 120,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, _) =>
                            Bar(value: _c.value, color: CareerColors.yellow, track: Colors.white.withValues(alpha: .15), height: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
