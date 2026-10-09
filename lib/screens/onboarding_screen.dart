import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../state/session.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Three stories: find opportunities, grow readiness, practise. One benefit per slide,
/// each with an illustration on the same panel shape.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  static const _slides = [
    (
      eyebrow: 'TEMUKAN PELUANG',
      title: 'Lowongan yang benar-benar cocok.',
      body: 'Setiap lowongan diberi Match Score 0–100 lengkap dengan alasannya, jadi kamu tahu mana yang layak dilamar lebih dulu.',
    ),
    (
      eyebrow: 'TINGKATKAN KESIAPAN',
      title: 'Skor rendah jadi rencana belajar.',
      body: 'Lihat skill yang masih kurang, pelajari materi gratisnya, dan skor langsung dihitung ulang.',
    ),
    (
      eyebrow: 'BERLATIH',
      title: 'Latihan wawancara untuk posisi itu.',
      body: 'AI Interview Coach menyusun pertanyaan dari lowongan dan memberi umpan balik dengan rubrik yang jelas.',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _finish() {
    markOnboardingSeen();
    context.go(Routes.auth);
  }

  void _next() {
    if (_i < _slides.length - 1) {
      _pc.nextPage(
        duration: MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return CareerTheme(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const KarirInMark(size: 28),
                    const SizedBox(width: 8),
                    Text('${_i + 1} dari ${_slides.length}', style: CareerText.small),
                    const Spacer(),
                    if (!last) TextButton(onPressed: _finish, child: const Text('Lewati')),
                    if (last) const SizedBox(height: 48),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Panel(index: i),
                          const SizedBox(height: 28),
                          Text(s.eyebrow, style: CareerText.eyebrow.copyWith(color: CareerColors.teal)),
                          const SizedBox(height: 8),
                          Text(s.title, style: CareerText.heading),
                          const SizedBox(height: 10),
                          Text(s.body, style: CareerText.muted.copyWith(fontSize: 16)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Semantics(
                      label: 'Slide ${_i + 1} dari ${_slides.length}',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          for (var d = 0; d < _slides.length; d++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 6),
                              width: d == _i ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: d == _i ? CareerColors.teal : CareerColors.line,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CareerButton(label: last ? 'Mulai sekarang' : 'Lanjut', onPressed: _next),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same rounded panel for every slide, holding the story's illustration.
class _Panel extends StatelessWidget {
  const _Panel({required this.index});
  final int index;

  /// Illustrations from assets/images/onboarding (transparent PNG, 1448 × 1086).
  static const images = [
    'assets/images/onboarding/lowongan yang cocok.png',
    'assets/images/onboarding/meningkatkan skill.png',
    'assets/images/onboarding/latihan wawancara.png',
  ];

  @override
  Widget build(BuildContext context) {
    // Light tints so the navy and teal in the illustrations stay visible.
    final bg = [const Color(0xFFE8EEF7), CareerColors.mint, CareerColors.amberLight][index];
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
        child: LayoutBuilder(
          builder: (context, c) => AspectRatio(
            aspectRatio: 1448 / 1086,
            child: Image.asset(
              images[index],
              fit: BoxFit.contain,
              // Decode at display size instead of the full 1448 px.
              cacheWidth: (c.maxWidth * dpr).round(),
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
