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

/// Detail lowongan & Match Score: every number comes with its reason.
class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  Future<void> _apply(BuildContext context, WidgetRef ref, Job job) async {
    final ok = await showKSheet<bool>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Lamar lewat situs resmi', style: KText.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Kamu akan dibawa ke halaman karier resmi ${job.company}. KarirIn tidak mengirim lamaran atas namamu. '
            'Setelah melamar, lamaran ini otomatis dicatat di Pelacak Lamaran.',
            style: KText.bodyMediumVariant,
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Buka situs & catat lamaran', icon: Icons.open_in_new_rounded, onPressed: () => Navigator.pop(ctx, true)),
          const SizedBox(height: 8),
          Center(
            child: TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti saja')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(appProvider.notifier).recordApplication(job);
    context.go(Routes.tracker);
    showToast(context, 'Lamaran dicatat. Pengingat tindak lanjut: 15 Okt');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    final job = jobById(jobId);
    final p = st.profile;
    final r = computeMatch(job, p);
    final c = r.category;
    final saved = st.savedJobIds.contains(job.id);

    void toGap() {
      n.selectGapJob(job.id);
      context.go(Routes.gap);
    }

    final eduVerdict = r.sp == 1
        ? 'Sesuai.'
        : r.sp == 0.5
        ? (r.levelOk ? 'Jenjang sesuai, bidang berbeda.' : 'Bidang sesuai, jenjang belum.')
        : 'Belum memenuhi.';
    final eduTxt =
        '${p.level.label} ${p.major} · syarat ${job.eduMin.label} ${job.anyMajor ? 'semua jurusan' : job.eduFields.join('/')}. $eduVerdict';
    final expTxt = job.expYears == 0
        ? 'Lowongan tidak mensyaratkan pengalaman kerja.'
        : 'Diminta ${job.expYears} tahun. Pengalaman relevan dihitung ${fmt(r.relevantMonths)} bulan (magang & organisasi dihitung ½).';
    final locVerdict = r.sl == 1
        ? 'Sesuai preferensi lokasi dan mode kerja.'
        : r.sl == 0.5
        ? (r.cityOk ? 'Lokasi sesuai, mode kerja di luar preferensi.' : 'Mode kerja sesuai, lokasi di luar preferensi.')
        : 'Tidak sesuai preferensi.';
    final locTxt = '${job.city} · ${job.mode.label}. $locVerdict';
    String owned(List<String> have, List<String> all, List<String> miss) =>
        '${have.length} dari ${all.length} dimiliki${miss.isEmpty ? '.' : '. Belum: ${joinId(miss)}.'}';

    final rows = [
      ('Keterampilan wajib', '50%', r.sw, 50, owned(r.matchedWajib, job.wajib, r.missingWajib)),
      ('Keterampilan tambahan', '15%', r.st, 15, owned(r.matchedTambahan, job.tambahan, r.missingTambahan)),
      ('Pendidikan', '15%', r.sp, 15, eduTxt),
      ('Pengalaman', '10%', r.se, 10, expTxt),
      ('Lokasi & preferensi', '10%', r.sl, 10, locTxt),
    ];
    final segs = [('Wajib', 50, r.sw), ('Tamb.', 15, r.st), ('Pend.', 15, r.sp), ('Peng.', 10, r.se), ('Lok.', 10, r.sl)];
    final missGain = r.missingWajib.isEmpty ? 0.0 : 50 / job.wajib.length * r.missingWajib.length;

    return Scaffold(
      appBar: topBar(
        title: 'Detail lowongan',
        onBack: () => context.back(Routes.home),
        actions: [
          IconButton(
            tooltip: 'Simpan',
            onPressed: () {
              n.toggleSaved(job.id);
              showToast(context, saved ? 'Lowongan dihapus dari simpanan' : 'Lowongan disimpan');
            },
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: KColors.onSurfaceVariant),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.company, style: KText.labelLarge.copyWith(color: KColors.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(job.title, style: KText.headlineSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          _meta(Icons.location_on_outlined, '${job.city} · ${job.mode.label}'),
                          _meta(Icons.payments_outlined, job.salary),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: KColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: r.total),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => RingGauge(
                              value: v / 100,
                              size: 104,
                              thickness: 10,
                              color: c.bar,
                              trackColor: KColors.surfaceContainerHighest,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fmt(r.total),
                                    style: const TextStyle(fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w500),
                                  ),
                                  const Text(
                                    'dari 100',
                                    style: TextStyle(fontSize: 11, height: 16 / 11, color: KColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CategoryTag(c, height: 28),
                                const SizedBox(height: 8),
                                Text(
                                  r.missingWajib.isEmpty
                                      ? 'Semua keterampilan wajib sudah kamu miliki.'
                                      : '${r.matchedWajib.length} dari ${job.wajib.length} keterampilan wajib sudah kamu miliki. Kurang: ${joinId(r.missingWajib)}.',
                                  style: KText.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (var i = 0; i < segs.length; i++) ...[
                            if (i > 0) const SizedBox(width: 3),
                            Expanded(
                              flex: segs[i].$2,
                              child: Bar(value: segs[i].$3, color: KColors.secondary, height: 12),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 0; i < segs.length; i++) ...[
                            if (i > 0) const SizedBox(width: 3),
                            Expanded(
                              flex: segs[i].$2,
                              child: Text(
                                segs[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 16 / 11,
                                  fontWeight: FontWeight.w500,
                                  color: KColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Rincian skor'),
                for (final (name, weight, v, max, note) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: '$name ',
                                  children: [TextSpan(text: '· $weight', style: KText.bodyMediumVariant)],
                                ),
                                style: KText.bodyLarge,
                              ),
                            ),
                            Text.rich(
                              TextSpan(
                                text: fmt(v * max),
                                children: [
                                  TextSpan(
                                    text: ' / $max',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: KColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              style: KText.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Bar(value: v, color: barColor(v)),
                        const SizedBox(height: 8),
                        Text(note, style: KText.bodyMediumVariant),
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: KColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Score = 100 × (0,50·Sw + 0,15·St + 0,15·Sp + 0,10·Se + 0,10·Sl)',
                        style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Dihitung dengan rumus tetap, bukan tebakan AI. Skor membantu kamu memilih, bukan keputusan perusahaan.',
                        style: KText.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Keterampilan yang diminta', padding: EdgeInsets.fromLTRB(16, 24, 16, 12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in job.wajib) _SkillChip(name: s, kind: 'WAJIB', owned: p.skills.contains(s)),
                      for (final s in job.tambahan) _SkillChip(name: s, kind: 'TAMBAHAN', owned: p.skills.contains(s)),
                    ],
                  ),
                ),
                const SectionLabel('Tentang lowongan'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(job.desc, style: KText.bodyMedium),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                r.missingWajib.isNotEmpty
                    ? PrimaryButton(label: 'Tutup Skill Gap · +${fmt(missGain)} poin', icon: Icons.trending_up_rounded, onPressed: toGap)
                    : PrimaryButton(
                        label: 'Lamar di situs resmi',
                        icon: Icons.open_in_new_rounded,
                        onPressed: () => _apply(context, ref, job),
                      ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SmallOutlined(
                        icon: Icons.record_voice_over_outlined,
                        label: 'Latihan',
                        onPressed: () {
                          n.selectCoachJob(job.id);
                          context.go(Routes.coach);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallOutlined(
                        icon: Icons.description_outlined,
                        label: 'Surat',
                        onPressed: () => context.push('${Routes.letter}?job=${job.id}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: r.missingWajib.isNotEmpty
                          ? _SmallOutlined(icon: Icons.open_in_new_rounded, label: 'Lamar', onPressed: () => _apply(context, ref, job))
                          : _SmallOutlined(icon: Icons.school_outlined, label: 'Belajar', onPressed: toGap),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData ic, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(ic, size: 18, color: KColors.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(t, style: KText.bodyMediumVariant),
    ],
  );
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.name, required this.kind, required this.owned});
  final String name, kind;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final fg = owned ? KColors.onSecondaryContainer : KColors.error;
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      decoration: BoxDecoration(
        color: owned ? KColors.secondaryContainer : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: owned ? KColors.secondaryContainer : KColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(owned ? Icons.check_rounded : Icons.close_rounded, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(name, style: KText.labelLarge.copyWith(color: fg)),
          const SizedBox(width: 6),
          Text(
            kind,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: fg.withValues(alpha: .8)),
          ),
        ],
      ),
    );
  }
}

class _SmallOutlined extends StatelessWidget {
  const _SmallOutlined({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size.fromHeight(40)),
  );
}
