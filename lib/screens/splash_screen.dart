import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    })
    ..forward();

  void _next() {
    if (mounted) context.go(Routes.onboarding);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: KColors.brandNavy),
    child: Scaffold(
      backgroundColor: KColors.brandNavy,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _c.stop();
          _next();
        },
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const KarirInMark(size: 72),
                  ),
                  const SizedBox(height: 24),
                  const Text.rich(
                    TextSpan(
                      text: 'Karir',
                      children: [
                        TextSpan(
                          text: 'In',
                          style: TextStyle(color: KColors.secondaryContainer),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 40, height: 48 / 40, fontWeight: FontWeight.w700, letterSpacing: -.5, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cocok skill-nya, siap kerjanya.',
                    style: TextStyle(fontSize: 16, height: 24 / 16, color: KColors.primaryContainer),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Center(
                child: SizedBox(
                  width: 152,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => Bar(value: _c.value, color: KColors.secondaryContainer, track: Colors.white.withValues(alpha: .2)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
