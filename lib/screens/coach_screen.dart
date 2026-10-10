import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/backend.dart';

import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';

/// Persiapan latihan: the selected job, the answer mode and the start button fit on the first screen.
class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    final ranked = st.ranked;
    final target = ranked.firstWhere((s) => s.job.id == st.coachJobId);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;

    Future<void> changeJob() async {
      final id = await showJobPicker(context, title: 'Berlatih untuk lowongan', ranked: ranked, selectedId: target.job.id);
      if (id != null) n.selectCoachJob(id);
    }

    final modes = [
      _ModeOption(
        icon: Icons.keyboard_outlined,
        title: 'Ketik',
        subtitle: 'Tulis jawabanmu',
        selected: !st.voiceMode,
        onTap: () => n.setVoiceMode(false),
      ),
      _ModeOption(
        icon: Icons.mic_none_rounded,
        title: 'Suara',
        subtitle: 'Rekam, lalu cek transkrip',
        selected: st.voiceMode,
        onTap: () => n.setVoiceMode(true),
      ),
    ];

    return CareerTheme(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const PageStorageKey('career-coach'),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    const Text('LATIHAN WAWANCARA', style: CareerText.eyebrow),
                    const SizedBox(height: 6),
                    Text('Berlatih dulu,\ntampil lebih yakin.', style: CareerText.heading.copyWith(fontSize: 26)),
                    const SizedBox(height: 8),
                    const Text('Ruang latihan pribadi. Jawabanmu tidak dikirim ke perusahaan.', style: CareerText.muted),
                    const SizedBox(height: 20),
                    SelectedJobCard(eyebrow: 'BERLATIH UNTUK', scored: target, onChange: changeJob),
                    const SizedBox(height: 24),
                    const Text('Cara menjawab', style: CareerText.label),
                    const SizedBox(height: 10),
                    if (largeText)
                      Column(children: [modes[0], const SizedBox(height: 10), modes[1]])
                    else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: modes[0]),
                            const SizedBox(width: 10),
                            Expanded(child: modes[1]),
                          ],
                        ),
                      ),
                    if (st.voiceMode) ...[
                      const SizedBox(height: 10),
                      Text(
                        backend == Backend.mock
                            ? 'Pada demo ini, rekaman suara masih simulasi. Transkrip tetap bisa kamu edit.'
                            : 'Butuh izin mikrofon. Transkrip tetap bisa kamu periksa dan edit sebelum dikirim.',
                        style: CareerText.small,
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text('Sesi ini', style: CareerText.label),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CareerPill('5 pertanyaan', icon: Icons.format_list_numbered_rounded, background: Colors.white),
                        CareerPill('3 perilaku + 2 teknis', icon: Icons.forum_outlined, background: Colors.white),
                        CareerPill('±10 menit', icon: Icons.schedule_rounded, background: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Setiap jawaban mendapat umpan balik dari empat aspek: relevansi, struktur STAR, kejelasan, dan bukti konkret.',
                      style: CareerText.small,
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
                  child: CareerButton(
                    label: 'Mulai latihan',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => context.push(Routes.session),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Jawab dengan $title. $subtitle',
    excludeSemantics: true,
    child: Material(
      color: selected ? CareerColors.mint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? CareerColors.teal : CareerColors.line, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? CareerColors.teal : CareerColors.muted, size: 22),
                  const Spacer(),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? CareerColors.teal : CareerColors.line,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: CareerText.label),
              const SizedBox(height: 2),
              Text(subtitle, style: CareerText.small),
            ],
          ),
        ),
      ),
    ),
  );
}
