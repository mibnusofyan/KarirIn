import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../logic/interview.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Three stories: find opportunities, grow readiness, practise. One benefit per slide,
/// each with the same panel shape and the K mark's rising-steps motif.
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

  void _next() {
    if (_i < _slides.length - 1) {
      _pc.nextPage(
        duration: MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.go(Routes.auth);
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
                    if (!last) TextButton(onPressed: () => context.go(Routes.auth), child: const Text('Lewati')),
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

/// Same rounded panel for every slide; colour and illustration change with the story.
class _Panel extends StatelessWidget {
  const _Panel({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final bg = [CareerColors.navy, CareerColors.mint, CareerColors.amberLight][index];
    return ExcludeSemantics(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 260),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Small K-steps motif above the card, so it is never covered.
            Positioned(
              right: 20,
              top: 16,
              child: Opacity(
                opacity: index == 0 ? .7 : .45,
                child: const SizedBox(width: 50, height: 48, child: FittedBox(child: CareerSteps())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 76, 20, 20),
              child: [const _OpportunityArt(), const _ReadinessArt(), const _PracticeArt()][index],
            ),
          ],
        ),
      ),
    );
  }
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
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Color(0x1F0B1F3A), blurRadius: 20, offset: Offset(0, 8))],
    ),
    child: child,
  );
}

class _OpportunityArt extends StatelessWidget {
  const _OpportunityArt();

  @override
  Widget build(BuildContext context) {
    final job = jobById('j1');
    final r = computeMatch(job, raniProfile);
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompanyAvatar(company: job.company, size: 36),
              const SizedBox(width: 10),
              Expanded(child: Text(job.company, style: CareerText.small)),
            ],
          ),
          const SizedBox(height: 10),
          Text(job.title, style: CareerText.cardTitle),
          const SizedBox(height: 4),
          Text('${job.city} · ${job.mode.label} · ${job.salary}', style: CareerText.small),
          const SizedBox(height: 12),
          MatchBadge(result: r),
        ],
      ),
    );
  }
}

class _ReadinessArt extends StatelessWidget {
  const _ReadinessArt();

  @override
  Widget build(BuildContext context) {
    final job = jobById('j1');
    final before = computeMatch(job, raniProfile);
    final gap = skillGap(job, before).first;
    final after = computeMatch(job, raniProfile.copyWith(skills: [...raniProfile.skills, gap.skill]));
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(fmt(before.total), style: CareerText.heading.copyWith(fontSize: 34, color: CareerColors.muted)),
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Icon(Icons.arrow_forward_rounded, color: CareerColors.muted),
              ),
              Text(fmt(after.total), style: CareerText.heading.copyWith(fontSize: 34, color: CareerColors.teal)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.school_outlined, color: CareerColors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gap.skill, style: CareerText.label),
                    Text('${resourceFor(gap.skill).type.label} gratis · ${resourceFor(gap.skill).duration}', style: CareerText.small),
                  ],
                ),
              ),
              Text('+${fmt(gap.gain)}', style: CareerText.label.copyWith(color: CareerColors.teal)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeArt extends StatelessWidget {
  const _PracticeArt();

  @override
  Widget build(BuildContext context) {
    final q = interviewJ1[1];
    final score = gradeAnswer(q.better);
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CareerPill(q.type, icon: Icons.forum_outlined, color: CareerColors.navy, background: CareerColors.background),
          const SizedBox(height: 10),
          Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: CareerText.label),
          const SizedBox(height: 14),
          for (final (name, v) in score.aspects.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RubricRow(name: name, value: v),
            ),
        ],
      ),
    );
  }
}
