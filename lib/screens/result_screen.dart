import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../logic/interview.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'session_screen.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final job = jobById(st.coachJobId);
    // Before any session has been completed, show the demo answers so the screen is never empty.
    final results = st.interviewResults.isNotEmpty
        ? st.interviewResults
        : [for (final q in interviewJ1) AnsweredQuestion(q, gradeAnswer(q.demo))];
    final avg = averageScore(results);
    final total = avg.total;
    final weakest = ([...avg.aspects]..sort((a, b) => a.$2.compareTo(b.$2))).first.$1;
    final verdict = total >= 75
        ? 'Siap wawancara'
        : total >= 50
        ? 'Hampir siap'
        : 'Perlu latihan lagi';

    return Scaffold(
      appBar: topBar(title: 'Hasil wawancara', onBack: () => context.back(Routes.coach)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: KColors.primaryContainer, borderRadius: BorderRadius.circular(28)),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: total / 100),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => RingGauge(
                          value: v,
                          size: 104,
                          thickness: 10,
                          color: KColors.primary,
                          trackColor: Colors.white,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total',
                                style: const TextStyle(fontSize: 32, height: 36 / 32, color: KColors.onPrimaryContainer),
                              ),
                              const Text(
                                '/ 100',
                                style: TextStyle(fontSize: 11, height: 16 / 11, color: KColors.onPrimaryContainer),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(color: KColors.onPrimaryContainer),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.title,
                                style: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(verdict, style: const TextStyle(fontSize: 22, height: 28 / 22)),
                              const SizedBox(height: 4),
                              Text(focusByAspect[weakest]!, style: const TextStyle(fontSize: 14, height: 20 / 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AspectGrid(aspects: avg.aspects),
                const SectionLabel('Per pertanyaan', padding: EdgeInsets.only(top: 24, bottom: 4)),
                for (var i = 0; i < results.length; i++)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 72),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: KColors.surfaceContainerHighest,
                          child: Text('${i + 1}', style: KText.labelLarge),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(results[i].question.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.bodyMedium),
                                Text(results[i].question.type, style: KText.bodySmall),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${results[i].score.total}', style: KText.titleMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          BottomActionBar(
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.pushReplacement(Routes.session),
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  label: const Text('Ulangi'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(label: 'Buat surat lamaran', onPressed: () => context.push('${Routes.letter}?job=${job.id}')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
