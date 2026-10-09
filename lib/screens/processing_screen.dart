import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// AI extraction status (simulated), then a result state that hands over to "Periksa profil".
/// Production: upload to Cloud Storage → `extractProfile` Cloud Function → Gemini.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, required this.fromQa});
  final bool fromQa;

  /// Simulated processing time.
  static const duration = Duration(milliseconds: 2400);

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: ProcessingScreen.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _done = true);
    })
    ..forward();
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<String> _steps(bool photo) => [
    widget.fromQa
        ? 'Mengirim jawaban'
        : photo
        ? 'Mengunggah foto CV'
        : 'Mengunggah CV',
    widget.fromQa
        ? 'Memahami jawabanmu'
        : photo
        ? 'Membaca teks dari foto'
        : 'Membaca dokumen',
    'Mengenali keterampilan & pengalaman',
    'Menyusun profil terstruktur',
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(appProvider).profile;
    final photo = profile.source == ProfileSource.cvPhoto;
    final steps = _steps(photo);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: _done,
      child: CareerTheme(
        child: Scaffold(
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: _done
                  ? _Result(key: const ValueKey('done'), profile: profile, fromQa: widget.fromQa)
                  : AnimatedBuilder(
                      key: const ValueKey('working'),
                      animation: _c,
                      builder: (context, _) => _Working(
                        value: _c.value,
                        title: widget.fromQa
                            ? 'Menyusun profil dari jawabanmu'
                            : photo
                            ? 'Membaca foto CV dan menyusun profilmu'
                            : 'Membaca CV dan menyusun profilmu',
                        steps: steps,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.value, required this.title, required this.steps});
  final double value;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    final active = (value * steps.length).floor().clamp(0, steps.length - 1);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      children: [
        Center(
          child: Semantics(
            label: 'Proses $pct persen',
            excludeSemantics: true,
            child: RingGauge(
              value: value,
              size: 148,
              thickness: 10,
              color: CareerColors.teal,
              trackColor: CareerColors.mint,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$pct%', textScaler: TextScaler.noScaling, style: CareerText.heading.copyWith(fontSize: 34)),
                  const Text('±15 detik', textScaler: TextScaler.noScaling, style: CareerText.small),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'DIPROSES AI',
          textAlign: TextAlign.center,
          style: CareerText.eyebrow.copyWith(color: CareerColors.teal),
        ),
        const SizedBox(height: 6),
        Text(title, textAlign: TextAlign.center, style: CareerText.title.copyWith(fontSize: 22)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CareerColors.line),
          ),
          child: Column(
            children: [
              for (final (i, label) in steps.indexed)
                _StepRow(label: label, state: i < active || value >= 1 ? _Step.done : (i == active ? _Step.active : _Step.todo)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Jangan tutup aplikasi selama proses berjalan. Pada demo ini, proses AI disimulasikan.',
          textAlign: TextAlign.center,
          style: CareerText.small,
        ),
      ],
    );
  }
}

enum _Step { done, active, todo }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});
  final String label;
  final _Step state;

  @override
  Widget build(BuildContext context) {
    final status = switch (state) {
      _Step.done => 'selesai',
      _Step.active => 'sedang berjalan',
      _Step.todo => 'menunggu',
    };
    return Semantics(
      container: true,
      label: '$label, $status',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 22,
              child: switch (state) {
                _Step.done => const Icon(Icons.check_circle_rounded, color: CareerColors.teal, size: 22),
                _Step.active => const Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: CareerColors.teal),
                ),
                _Step.todo => const Icon(Icons.radio_button_unchecked_rounded, color: CareerColors.line, size: 22),
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  label,
                  style: state == _Step.todo
                      ? CareerText.muted
                      : CareerText.body.copyWith(fontWeight: state == _Step.active ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({super.key, required this.profile, required this.fromQa});
  final Profile profile;
  final bool fromQa;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final found = [('${p.skills.length}', 'keterampilan'), ('${p.exps.length}', 'pengalaman'), (p.level.label, 'pendidikan')];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: CareerColors.mint, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: CareerColors.teal, size: 48),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'PROSES SELESAI',
                textAlign: TextAlign.center,
                style: CareerText.eyebrow.copyWith(color: CareerColors.teal),
              ),
              const SizedBox(height: 6),
              const Text('Profilmu siap diperiksa', textAlign: TextAlign.center, style: CareerText.heading),
              const SizedBox(height: 10),
              Text(
                fromQa
                    ? 'Kami menyusun profil dari jawabanmu. Periksa dulu sebelum skor kecocokan dihitung.'
                    : 'AI menemukan data berikut dari CV-mu. Periksa dulu sebelum skor kecocokan dihitung.',
                textAlign: TextAlign.center,
                style: CareerText.muted,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: CareerColors.navy, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: CareerText.title.copyWith(color: Colors.white)),
                    Text('${p.level.label} ${p.major} · ${p.city}', style: CareerText.small.copyWith(color: const Color(0xFFC4D6E7))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        for (final (value, label) in found)
                          Semantics(
                            container: true,
                            label: '$value $label',
                            excludeSemantics: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(value, style: CareerText.cardTitle.copyWith(color: CareerColors.yellow)),
                                Text(label, style: CareerText.small.copyWith(color: const Color(0xFFC4D6E7))),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (p.skills.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in p.skills.take(4)) CareerPill(s, color: CareerColors.navy, background: const Color(0xFFE8ECF6)),
                          if (p.skills.length > 4)
                            CareerPill('+${p.skills.length - 4} lainnya', color: CareerColors.navy, background: const Color(0xFFE8ECF6)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: CareerColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: CareerButton(label: 'Periksa profil', onPressed: () => context.go(Routes.confirm)),
          ),
        ),
      ],
    );
  }
}
