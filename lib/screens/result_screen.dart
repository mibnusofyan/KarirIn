import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../logic/interview.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Hasil latihan: overall score, one strength, one priority, then per-question detail.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final job = st.job(st.coachJobId);
    final isExample = st.interviewResults.isEmpty;
    // Before any session has been completed, show the demo answers so the screen is never empty.
    final results = isExample ? [for (final q in interviewJ1) AnsweredQuestion(q, gradeAnswer(q.demo))] : st.interviewResults;
    final avg = averageScore(results);
    final total = avg.total;
    final sorted = [...avg.aspects]..sort((a, b) => a.$2.compareTo(b.$2));
    final weakest = sorted.first;
    final strongest = sorted.last;
    final verdict = total >= 75
        ? 'Siap wawancara'
        : total >= 50
        ? 'Hampir siap'
        : 'Perlu latihan lagi';

    return CareerTheme(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => context.back(Routes.coach),
          ),
          title: const Text('Hasil latihan'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            if (isExample) ...[
              const CareerPill(
                'Contoh dari jawaban demo. Selesaikan satu sesi untuk melihat hasilmu.',
                icon: Icons.info_outline_rounded,
                background: Colors.white,
              ),
              const SizedBox(height: 12),
            ],
            _ScoreHero(total: total, verdict: verdict, jobTitle: job.title, answered: results.length),
            const SizedBox(height: 16),
            InsightTile(positive: true, title: 'Kekuatan utama · ${strongest.$1}', body: strengthByAspect[strongest.$1]!),
            const SizedBox(height: 10),
            InsightTile(positive: false, title: 'Prioritas berikutnya · ${weakest.$1}', body: focusByAspect[weakest.$1]!),
            const SizedBox(height: 28),
            const Text('Rincian aspek', style: CareerText.title),
            const SizedBox(height: 4),
            const Text('Rata-rata dari semua jawaban, masing-masing 0–25.', style: CareerText.small),
            const SizedBox(height: 14),
            for (final (name, v) in avg.aspects)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: RubricRow(name: name, value: v, track: Colors.white),
              ),
            const SizedBox(height: 14),
            const Text('Per pertanyaan', style: CareerText.title),
            const SizedBox(height: 4),
            const Text('Ketuk untuk melihat umpan balik tiap jawaban.', style: CareerText.small),
            const SizedBox(height: 10),
            for (final (i, r) in results.indexed) _QuestionResult(number: i + 1, item: r),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: CareerColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CareerButton(label: 'Latihan lagi', icon: Icons.replay_rounded, onPressed: () => context.pushReplacement(Routes.session)),
                  TextButton.icon(
                    onPressed: () => context.push('${Routes.letter}?job=${job.id}'),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Buat surat lamaran'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.total, required this.verdict, required this.jobTitle, required this.answered});
  final int total, answered;
  final String verdict, jobTitle;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC4D6E7);
    final ring = Semantics(
      label: 'Skor latihan $total dari 100',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: total / 100),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => RingGauge(
          value: v,
          size: 92,
          thickness: 8,
          color: total >= 75 ? const Color(0xFFB5E5D4) : CareerColors.yellow,
          trackColor: const Color(0xFF2B4A72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                textScaler: TextScaler.noScaling,
                style: CareerText.heading.copyWith(fontSize: 28, color: Colors.white),
              ),
              Text(
                'dari 100',
                textScaler: TextScaler.noScaling,
                style: CareerText.small.copyWith(color: light),
              ),
            ],
          ),
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(jobTitle.toUpperCase(), style: CareerText.eyebrow.copyWith(color: light)),
        const SizedBox(height: 6),
        Text(verdict, style: CareerText.title.copyWith(color: Colors.white, fontSize: 22)),
        const SizedBox(height: 6),
        Text('Rata-rata $answered jawaban. Penilaian latihan, bukan keputusan perusahaan.', style: CareerText.small.copyWith(color: light)),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CareerColors.navy, borderRadius: BorderRadius.circular(24)),
      child: MediaQuery.textScalerOf(context).scale(14) > 21
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ring, const SizedBox(height: 16), text])
          : Row(
              children: [
                ring,
                const SizedBox(width: 18),
                Expanded(child: text),
              ],
            ),
    );
  }
}

class _QuestionResult extends StatelessWidget {
  const _QuestionResult({required this.number, required this.item});
  final int number;
  final AnsweredQuestion item;

  @override
  Widget build(BuildContext context) {
    final s = item.score;
    final good = s.total >= 75;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CareerColors.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const RoundedRectangleBorder(),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: CareerColors.background,
            child: Text('$number', textScaler: TextScaler.noScaling, style: CareerText.label),
          ),
          title: Text(item.question.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: CareerText.body),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CareerPill(
                  '${s.total} / 100',
                  color: good ? CareerColors.teal : CareerColors.amber,
                  background: good ? CareerColors.mint : CareerColors.amberLight,
                ),
                Text(item.question.type, style: CareerText.small),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(item.question.text, style: CareerText.label),
            ),
            const SizedBox(height: 12),
            for (final (name, v) in s.aspects)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RubricRow(name: name, value: v),
              ),
            const SizedBox(height: 4),
            _note(Icons.thumb_up_alt_outlined, CareerColors.teal, s.good),
            const SizedBox(height: 8),
            _note(Icons.flag_outlined, CareerColors.amber, s.improve),
          ],
        ),
      ),
    );
  }

  Widget _note(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: CareerText.body)),
    ],
  );
}
