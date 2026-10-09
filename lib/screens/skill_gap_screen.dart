import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Skill Gap & Jalur Belajar: turns a low score into a measurable action plan.
class SkillGapScreen extends ConsumerWidget {
  const SkillGapScreen({super.key});

  static IconData resourceIcon(ResourceType t) => switch (t) {
    ResourceType.kursus => Icons.school_outlined,
    ResourceType.video => Icons.play_circle_outline_rounded,
    ResourceType.modul => Icons.menu_book_outlined,
  };

  /// Marks [skill] as mastered and announces the recomputed score.
  /// Takes the messenger and notifier (not a context) so it is safe to call after a sheet closes.
  static void master(ScaffoldMessengerState messenger, AppNotifier notifier, String skill) {
    final r = notifier.master(skill);
    if (r != null) toastVia(messenger, 'Match Score ${r.jobTitle} diperbarui: ${fmt(r.before)} → ${fmt(r.after)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    final job = jobById(st.gapJobId);
    final r = computeMatch(job, st.profile);
    final items = skillGap(job, r);
    final potential = computeMatch(job, st.profile.copyWith(skills: [...st.profile.skills, ...items.map((i) => i.skill)])).total;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            const PageHeader(
              title: 'Skill Gap',
              subtitle: 'Keterampilan yang belum kamu miliki, diurutkan dari yang paling menaikkan skor.',
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final s in st.ranked)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: s.job.id == job.id,
                        onSelected: (_) => n.selectGapJob(s.job.id),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text.rich(
                          TextSpan(
                            text: '${s.job.title}  ',
                            children: [
                              TextSpan(
                                text: fmt(s.result.total),
                                style: const TextStyle(fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: KColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: r.total),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, now, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Skor sekarang', style: KText.bodySmall),
                              Text(fmt(now), style: const TextStyle(fontSize: 36, height: 44 / 36)),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Icon(Icons.arrow_forward_rounded, color: KColors.onSurfaceVariant),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Potensi skor', style: KText.bodySmall),
                              Text(
                                fmt(potential),
                                style: const TextStyle(fontSize: 36, height: 44 / 36, color: KColors.secondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 8,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Bar(value: potential / 100, color: KColors.secondaryContainer, height: 8),
                          Bar(value: now / 100, color: MatchCategory.of(now).bar, height: 8, track: Colors.transparent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CategoryTag(r.category),
                        Text('${items.length} keterampilan lagi', style: KText.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final it in items) ...[_GapCard(item: it), const SizedBox(height: 12)],
                  if (items.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: KColors.secondaryContainer, borderRadius: BorderRadius.circular(28)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_rounded, size: 32, color: KColors.onSecondaryContainer),
                          const SizedBox(height: 8),
                          const Text(
                            'Semua keterampilan terpenuhi',
                            style: TextStyle(fontSize: 22, height: 28 / 22, color: KColors.onSecondaryContainer),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Saatnya menyiapkan surat lamaran dan berlatih wawancara.',
                            style: TextStyle(fontSize: 14, height: 20 / 14, color: KColors.onSecondaryContainer),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: KColors.secondary),
                            onPressed: () {
                              n.selectCoachJob(job.id);
                              context.go(Routes.coach);
                            },
                            child: const Text('Latihan wawancara'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (st.learned.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 12),
                      child: Text('Dikuasai lewat KarirIn', style: KText.sectionLabel),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final l in st.learned)
                          Chip(
                            avatar: const Icon(Icons.check_rounded, size: 18, color: KColors.onSecondaryContainer),
                            label: Text(l, style: const TextStyle(color: KColors.onSecondaryContainer)),
                            backgroundColor: KColors.secondaryContainer,
                            color: const WidgetStatePropertyAll(KColors.secondaryContainer),
                            side: BorderSide.none,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GapCard extends ConsumerWidget {
  const _GapCard({required this.item});
  final GapItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = resourceFor(item.skill);
    return OutlinedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.skill, style: KText.titleMedium),
                    const SizedBox(height: 4),
                    item.wajib
                        ? const Tag('Wajib', bg: KColors.errorContainer, fg: KColors.onErrorContainer)
                        : const Tag('Tambahan', bg: KColors.surfaceContainerHighest),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${fmt(item.gain)}',
                    style: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w500, color: KColors.secondary),
                  ),
                  const Text('poin', style: KText.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: KColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showKSheet<void>(context, (_) => _ResourceSheet(item: item)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconCircle(SkillGapScreen.resourceIcon(res.type)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(res.title, style: KText.labelLarge),
                          Text('${res.type.label} · ${res.duration} · Gratis', style: KText.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: KColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TonalButton(
            label: 'Sudah saya kuasai',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () => SkillGapScreen.master(ScaffoldMessenger.of(context), ref.read(appProvider.notifier), item.skill),
          ),
        ],
      ),
    );
  }
}

class _ResourceSheet extends ConsumerWidget {
  const _ResourceSheet({required this.item});
  final GapItem item;

  static const _modules = [
    ('Modul 1 · Konsep dasar', '25 mnt'),
    ('Modul 2 · Praktik dengan contoh kasus', '60 mnt'),
    ('Modul 3 · Kuis dan sertifikat', '15 mnt'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = resourceFor(item.skill);
    final job = jobById(ref.watch(appProvider).gapJobId);
    void masterAndClose({bool proof = false}) {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(appProvider.notifier);
      Navigator.pop(context);
      if (proof) toastVia(messenger, 'Bukti belajar diunggah');
      SkillGapScreen.master(messenger, notifier, item.skill);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${res.type.label} · ${res.duration} · Gratis', style: KText.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(res.title, style: KText.titleLarge),
                ],
              ),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), tooltip: 'Tutup'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              for (var i = 0; i < _modules.length; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    border: i < _modules.length - 1 ? const Border(bottom: BorderSide(color: KColors.surfaceContainerHighest)) : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(_modules[i].$1, style: KText.bodyMedium)),
                      Text(_modules[i].$2, style: KText.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            text: 'Menguasai ${item.skill} menaikkan skor ${job.title} sebesar ',
            children: [
              TextSpan(
                text: '+${fmt(item.gain)} poin',
                style: const TextStyle(color: KColors.secondary, fontWeight: FontWeight.w500),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: KText.bodyMediumVariant,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Buka materi',
          icon: Icons.open_in_new_rounded,
          onPressed: () => showToast(context, 'Membuka materi di browser…'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => masterAndClose(proof: true),
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Unggah bukti'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: masterAndClose,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Tandai dikuasai'),
                style: FilledButton.styleFrom(
                  backgroundColor: KColors.secondaryContainer,
                  foregroundColor: KColors.onSecondaryContainer,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
