import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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
      'Lowongan yang benar-benar cocok',
      'Setiap lowongan diberi Match Score 0–100 lengkap dengan alasannya. Kamu tahu mana yang layak dilamar lebih dulu.',
      KColors.primaryContainer,
    ),
    (
      'Skor rendah jadi rencana belajar',
      'Lihat keterampilan yang masih kurang, pelajari materi gratisnya, dan skor langsung dihitung ulang.',
      KColors.secondaryContainer,
    ),
    (
      'Latihan wawancara untuk posisi itu',
      'AI Interview Coach menyusun pertanyaan dari deskripsi lowongan dan menilai jawabanmu dengan rubrik yang jelas.',
      KColors.tertiaryContainer,
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_i < 2) {
      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      context.go(Routes.auth);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(onPressed: () => context.go(Routes.auth), child: const Text('Lewati')),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final (title, body, bg) = _slides[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minHeight: 264),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
                        alignment: Alignment.center,
                        child: [const _MatchPreview(), const _GapPreview(), const _CoachPreview()][i],
                      ),
                      const SizedBox(height: 32),
                      Text(title, style: KText.headlineMedium),
                      const SizedBox(height: 8),
                      Text(body, style: KText.bodyLarge.copyWith(color: KColors.onSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Row(
              children: [
                for (var d = 0; d < 3; d++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    width: d == _i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: d == _i ? KColors.primary : KColors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.fromLTRB(24, 0, 20, 0),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_i == 2 ? 'Mulai' : 'Lanjut'),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x26000000), blurRadius: 3, spreadRadius: 1, offset: Offset(0, 1)),
      ],
    ),
    child: child,
  );
}

class _MatchPreview extends StatelessWidget {
  const _MatchPreview();

  @override
  Widget build(BuildContext context) {
    Widget seg(int flex, double v) => Expanded(
      flex: flex,
      child: Bar(value: v, color: KColors.secondary, height: 8),
    );
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              ScoreTile(score: 80),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staf Administrasi Keuangan',
                      style: TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w500),
                    ),
                    Text('PT Sinar Mandiri Abadi · Purwokerto', style: KText.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              seg(50, .75),
              const SizedBox(width: 3),
              seg(15, .5),
              const SizedBox(width: 3),
              seg(15, 1),
              const SizedBox(width: 3),
              seg(10, 1),
              const SizedBox(width: 3),
              seg(10, 1),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              for (final t in ['Skill wajib 50%', 'Tambahan 15%', 'Pendidikan 15%', 'Pengalaman 10%', 'Lokasi 10%'])
                Text(
                  t,
                  style: const TextStyle(fontSize: 11, height: 16 / 11, color: KColors.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GapPreview extends StatelessWidget {
  const _GapPreview();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData ic, String t, String sub, String gain) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconCircle(ic),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: KText.labelLarge),
                Text(sub, style: KText.bodySmall),
              ],
            ),
          ),
          Text(
            gain,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: KColors.secondary),
          ),
        ],
      ),
    );
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('80', style: TextStyle(fontSize: 36, height: 44 / 36)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: KColors.onSurfaceVariant),
              SizedBox(width: 8),
              Text(
                '92,5',
                style: TextStyle(fontSize: 36, height: 44 / 36, fontWeight: FontWeight.w500, color: KColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row(Icons.menu_book_rounded, 'Pelaporan Keuangan', 'Kursus gratis · 3 jam', '+12,5'),
          row(Icons.play_circle_rounded, 'Software Akuntansi', 'Video · 2 jam', '+7,5'),
        ],
      ),
    );
  }
}

class _CoachPreview extends StatelessWidget {
  const _CoachPreview();

  @override
  Widget build(BuildContext context) {
    Widget asp(String n, int v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(n, style: const TextStyle(fontSize: 11, height: 16 / 11)),
            Text(
              '$v',
              style: const TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Bar(value: v / 25, color: v / 25 >= .75 ? KColors.secondary : KColors.midBar),
      ],
    );
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('Pertanyaan 2 dari 5 · Perilaku', bg: KColors.primaryContainer, fg: KColors.onPrimaryContainer),
          const SizedBox(height: 10),
          const Text(
            'Pernahkah kamu menemukan kesalahan pada catatan keuangan? Apa yang kamu lakukan?',
            style: TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: asp('Relevansi', 22)),
              const SizedBox(width: 14),
              Expanded(child: asp('Struktur STAR', 18)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: asp('Kejelasan', 20)),
              const SizedBox(width: 14),
              Expanded(child: asp('Bukti konkret', 15)),
            ],
          ),
        ],
      ),
    );
  }
}
