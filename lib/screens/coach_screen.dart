import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// AI Interview Coach setup: pick a job and an answer mode.
class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const PageHeader(title: 'AI Interview Coach', subtitle: 'Pertanyaan disusun dari deskripsi lowongan yang kamu pilih.'),
                  const StatsRow(stats: [('5', 'pertanyaan'), ('3 + 2', 'perilaku + teknis'), ('±10', 'menit')]),
                  const SectionLabel('Pilih lowongan', padding: EdgeInsets.fromLTRB(16, 24, 16, 4)),
                  RadioGroup<String>(
                    groupValue: st.coachJobId,
                    onChanged: (v) => v == null ? null : n.selectCoachJob(v),
                    child: Column(
                      children: [
                        for (final s in st.ranked)
                          InkWell(
                            onTap: () => n.selectCoachJob(s.job.id),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 64),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                                child: Row(
                                  children: [
                                    Radio<String>(value: s.job.id),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.job.title, style: KText.bodyLarge),
                                          Text(s.job.company, style: KText.bodyMediumVariant),
                                        ],
                                      ),
                                    ),
                                    Tag(fmt(s.result.total), bg: s.result.category.bg, fg: s.result.category.fg, height: 28),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SectionLabel('Cara menjawab', padding: EdgeInsets.fromLTRB(16, 20, 16, 12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Ketik'), icon: Icon(Icons.keyboard_outlined)),
                        ButtonSegment(value: true, label: Text('Suara'), icon: Icon(Icons.mic_none_rounded)),
                      ],
                      selected: {st.voiceMode},
                      onSelectionChanged: (s) => n.setVoiceMode(s.first),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Setiap jawaban dinilai dari 4 aspek (0–25): relevansi, struktur STAR, kejelasan bahasa, dan bukti konkret.',
                      style: KText.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: PrimaryButton(label: 'Mulai latihan', icon: Icons.play_arrow_rounded, onPressed: () => context.push(Routes.session)),
            ),
          ],
        ),
      ),
    );
  }
}
