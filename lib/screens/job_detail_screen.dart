import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  Future<void> _apply(BuildContext context, WidgetRef ref, Job job) async {
    final ok = await showCareerSheet<bool>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CareerSheetHeader('Siap mengambil langkah?'),
          const SizedBox(height: 12),
          Text(
            'Lamaran untuk ${job.title} di ${job.company} dikirim melalui kanal resmi perusahaan.',
            style: CareerText.body,
          ),
          const SizedBox(height: 12),
          const Text(
            'Pada demo ini, KarirIn mencatat lamaran ke pelacak. Belum ada lamaran yang dikirim atau situs perusahaan yang dibuka.',
            style: CareerText.muted,
          ),
          const SizedBox(height: 24),
          CareerButton(
            label: 'Catat lamaran (demo)',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.pop(ctx, true),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti saja'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(appProvider.notifier).recordApplication(job);
    context.go(Routes.tracker);
    showToast(context, 'Lamaran dicatat di pelacak');
  }

  void _prepare(BuildContext context, WidgetRef ref, Job job) {
    showCareerSheet<void>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CareerSheetHeader('Persiapkan langkahmu'),
          const SizedBox(height: 4),
          Text(job.title, style: CareerText.muted),
          const SizedBox(height: 18),
          _PreparationOption(
            icon: Icons.record_voice_over_outlined,
            title: 'Latihan wawancara',
            subtitle: 'Berlatih untuk posisi ini',
            onTap: () {
              Navigator.pop(ctx);
              ref.read(appProvider.notifier).selectCoachJob(job.id);
              context.go(Routes.coach);
            },
          ),
          const Divider(),
          _PreparationOption(
            icon: Icons.description_outlined,
            title: 'Buat surat lamaran',
            subtitle: 'Susun surat sesuai profilmu',
            onTap: () {
              Navigator.pop(ctx);
              context.push('${Routes.letter}?job=${job.id}');
            },
          ),
          const Divider(),
          _PreparationOption(
            icon: Icons.school_outlined,
            title: 'Lihat rencana belajar',
            subtitle: 'Kenali skill yang bisa ditingkatkan',
            onTap: () {
              Navigator.pop(ctx);
              ref.read(appProvider.notifier).selectGapJob(job.id);
              context.go(Routes.gap);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final job = state.job(jobId);
    final result = computeMatch(job, state.profile);
    final saved = state.savedJobIds.contains(jobId);
    final missing = result.missingWajib;
    final gain = missing.isEmpty
        ? 0.0
        : computeMatch(
                job,
                state.profile.copyWith(
                  skills: [...state.profile.skills, ...missing],
                ),
              ).total -
              result.total;

    void toGap() {
      ref.read(appProvider.notifier).selectGapJob(jobId);
      context.go(Routes.gap);
    }

    return CareerTheme(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => context.back(Routes.home),
          ),
          title: const Text('Detail lowongan'),
          actions: [
            IconButton(
              tooltip: saved ? 'Hapus dari simpanan' : 'Simpan lowongan',
              isSelected: saved,
              onPressed: () {
                ref.read(appProvider.notifier).toggleSaved(jobId);
                showToast(
                  context,
                  saved
                      ? 'Lowongan dihapus dari simpanan'
                      : 'Lowongan disimpan',
                );
              },
              icon: const Icon(Icons.bookmark_border_rounded),
              selectedIcon: const Icon(
                Icons.bookmark_rounded,
                color: CareerColors.teal,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          key: PageStorageKey('job-detail-$jobId'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                CompanyAvatar(company: job.company, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KENALI PELUANGMU',
                        style: CareerText.small.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(job.company, style: CareerText.label),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(job.title, style: CareerText.heading.copyWith(fontSize: 27)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CareerPill(
                  job.city,
                  icon: Icons.location_on_outlined,
                  background: Colors.white,
                ),
                CareerPill(
                  job.mode.label,
                  icon: Icons.work_outline_rounded,
                  background: Colors.white,
                ),
                if (job.expYears == 0)
                  const CareerPill(
                    'Lulusan baru',
                    icon: Icons.school_outlined,
                    background: Colors.white,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            CareerMeta(
              Icons.payments_outlined,
              job.salary,
              style: CareerText.cardTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _MatchSummary(job: job, profile: state.profile, result: result),
            const SizedBox(height: 28),
            const Text('Tentang peran ini', style: CareerText.title),
            const SizedBox(height: 10),
            Text(
              job.desc,
              style: CareerText.body.copyWith(fontSize: 15, height: 1.7),
            ),
            const SizedBox(height: 20),
            _Requirement(
              icon: Icons.school_outlined,
              label: 'Pendidikan',
              value:
                  '${job.eduMin.label} · ${job.anyMajor ? 'Semua jurusan' : job.eduFields.join(' / ')}',
            ),
            const SizedBox(height: 12),
            _Requirement(
              icon: Icons.work_history_outlined,
              label: 'Pengalaman',
              value: job.expYears == 0
                  ? 'Terbuka tanpa pengalaman kerja'
                  : 'Minimal ${job.expYears} tahun di bidang ${job.field}',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Divider(),
            ),
            const Text('Skill yang dibutuhkan', style: CareerText.title),
            const SizedBox(height: 8),
            const Text(
              'Lihat bekal yang sudah kamu punya dan yang bisa kamu pelajari berikutnya.',
              style: CareerText.muted,
            ),
            const SizedBox(height: 18),
            _SkillGroup(
              label: 'WAJIB',
              skills: job.wajib,
              owned: state.profile.skills,
            ),
            const SizedBox(height: 20),
            _SkillGroup(
              label: 'TAMBAHAN',
              skills: job.tambahan,
              owned: state.profile.skills,
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 24),
              Material(
                color: CareerColors.amberLight,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: toGap,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: CareerColors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ada +${fmt(gain)} poin untukmu',
                                style: CareerText.label.copyWith(
                                  color: CareerColors.amber,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pelajari ${joinId(missing)} untuk melengkapi skill wajib.',
                                style: CareerText.body.copyWith(
                                  color: CareerColors.amber,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Lihat rencana belajar →',
                                style: CareerText.label.copyWith(
                                  color: CareerColors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: Builder(
          builder: (ctx) => Container(
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
                    CareerButton(
                      label: missing.isEmpty
                          ? 'Lamar di situs resmi'
                          : 'Tingkatkan kecocokan',
                      icon: missing.isEmpty
                          ? Icons.open_in_new_rounded
                          : Icons.trending_up_rounded,
                      onPressed: missing.isEmpty
                          ? () => _apply(ctx, ref, job)
                          : toGap,
                    ),
                    const SizedBox(height: 4),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final actions = [
                          if (missing.isNotEmpty)
                            TextButton(
                              onPressed: () => _apply(ctx, ref, job),
                              child: const Text('Lamar sekarang'),
                            ),
                          TextButton.icon(
                            onPressed: () => _prepare(ctx, ref, job),
                            icon: const Icon(Icons.tune_rounded, size: 17),
                            label: const Text('Persiapan'),
                          ),
                        ];
                        return MediaQuery.textScalerOf(context).scale(14) > 21
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: actions,
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  for (final action in actions)
                                    Flexible(child: action),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchSummary extends StatelessWidget {
  const _MatchSummary({
    required this.job,
    required this.profile,
    required this.result,
  });
  final Job job;
  final Profile profile;
  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    final high = result.category == MatchCategory.high;
    final color = high ? CareerColors.teal : CareerColors.amber;
    final ring = Semantics(
      label: 'Match Score ${fmt(result.total)} dari 100',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: result.total),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, value, _) => RingGauge(
          value: value / 100,
          size: 86,
          thickness: 7,
          color: color,
          trackColor: Colors.white.withValues(alpha: .8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmt(result.total),
                textScaler: TextScaler.noScaling,
                style: CareerText.heading.copyWith(fontSize: 25, color: color),
              ),
              const Text(
                'dari 100',
                textScaler: TextScaler.noScaling,
                style: CareerText.small,
              ),
            ],
          ),
        ),
      ),
    );
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KECOCOKAN PROFIL',
          style: CareerText.small.copyWith(
            fontSize: 10,
            letterSpacing: 1.2,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          result.category.label,
          style: CareerText.cardTitle.copyWith(color: color),
        ),
        const SizedBox(height: 6),
        Text(
          result.missingWajib.isEmpty
              ? 'Semua skill wajib sudah kamu miliki.'
              : '${result.matchedWajib.length} dari ${job.wajib.length} skill wajib sudah sesuai.',
          style: CareerText.body,
        ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: high ? CareerColors.mint : CareerColors.amberLight,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.textScalerOf(context).scale(14) > 21)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ring, const SizedBox(height: 16), description],
            )
          else
            Row(
              children: [
                ring,
                const SizedBox(width: 16),
                Expanded(child: description),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            'Skor kecocokan profil, bukan peluang diterima.',
            style: CareerText.small.copyWith(color: CareerColors.muted),
          ),
          const SizedBox(height: 14),
          Divider(color: color.withValues(alpha: .15)),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('score-breakdown-${job.id}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 14),
              iconColor: color,
              collapsedIconColor: color,
              title: Text(
                'Rincian Match Score',
                style: CareerText.label.copyWith(color: color),
              ),
              children: [
                _ScoreBreakdown(job: job, profile: profile, result: result),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({
    required this.job,
    required this.profile,
    required this.result,
  });
  final Job job;
  final Profile profile;
  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final p = profile;
    final eduVerdict = r.sp == 1
        ? 'Sesuai.'
        : r.sp == 0.5
        ? (r.levelOk
              ? 'Jenjang sesuai, bidang berbeda.'
              : 'Bidang sesuai, jenjang belum.')
        : 'Belum memenuhi.';
    final eduTxt =
        '${p.level.label} ${p.major} · syarat ${job.eduMin.label} ${job.anyMajor ? 'semua jurusan' : job.eduFields.join('/')}. $eduVerdict';
    final expTxt = job.expYears == 0
        ? 'Lowongan tidak mensyaratkan pengalaman kerja.'
        : 'Diminta ${job.expYears} tahun. Pengalaman relevan dihitung ${fmt(r.relevantMonths)} bulan (magang & organisasi dihitung ½).';
    final locVerdict = r.sl == 1
        ? 'Sesuai preferensi lokasi dan mode kerja.'
        : r.sl == 0.5
        ? (r.cityOk
              ? 'Lokasi sesuai, mode kerja di luar preferensi.'
              : 'Mode kerja sesuai, lokasi di luar preferensi.')
        : 'Tidak sesuai preferensi.';
    final locTxt = '${job.city} · ${job.mode.label}. $locVerdict';
    String owned(List<String> have, List<String> all, List<String> miss) =>
        '${have.length} dari ${all.length} dimiliki${miss.isEmpty ? '.' : '. Belum: ${joinId(miss)}.'}';

    final rows = [
      (
        'Keterampilan wajib',
        '50%',
        r.sw,
        50,
        owned(r.matchedWajib, job.wajib, r.missingWajib),
      ),
      (
        'Keterampilan tambahan',
        '15%',
        r.st,
        15,
        owned(r.matchedTambahan, job.tambahan, r.missingTambahan),
      ),
      ('Pendidikan', '15%', r.sp, 15, eduTxt),
      ('Pengalaman', '10%', r.se, 10, expTxt),
      ('Lokasi & preferensi', '10%', r.sl, 10, locTxt),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (name, weight, value, max, note) in rows)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('$name · $weight', style: CareerText.label),
                    Text('${fmt(value * max)} / $max', style: CareerText.label),
                  ],
                ),
                const SizedBox(height: 8),
                Bar(
                  value: value,
                  color: value >= .75 ? CareerColors.teal : CareerColors.amber,
                  track: Colors.white,
                  height: 5,
                ),
                const SizedBox(height: 8),
                Text(note, style: CareerText.body),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dihitung secara transparan', style: CareerText.label),
              SizedBox(height: 8),
              Text(
                'Match Score = 100 × (0,50·Sw + 0,15·St + 0,15·Sp + 0,10·Se + 0,10·Sl)',
                style: CareerText.small,
              ),
              SizedBox(height: 8),
              Text(
                'Sw: skill wajib · St: skill tambahan · Sp: pendidikan · Se: pengalaman · Sl: lokasi. Rumus tetap, bukan tebakan AI.',
                style: CareerText.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 21, color: CareerColors.muted),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: CareerText.small),
            const SizedBox(height: 3),
            Text(value, style: CareerText.body),
          ],
        ),
      ),
    ],
  );
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup({
    required this.label,
    required this.skills,
    required this.owned,
  });
  final String label;
  final List<String> skills, owned;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: CareerText.small.copyWith(
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final skill in skills)
            Semantics(
              label:
                  '$skill, ${owned.contains(skill) ? 'sudah dimiliki' : 'belum dimiliki'}, $label',
              excludeSemantics: true,
              child: CareerPill(
                skill,
                icon: owned.contains(skill)
                    ? Icons.check_rounded
                    : Icons.add_rounded,
                color: owned.contains(skill)
                    ? CareerColors.teal
                    : CareerColors.amber,
                background: owned.contains(skill)
                    ? CareerColors.mint
                    : CareerColors.amberLight,
              ),
            ),
        ],
      ),
    ],
  );
}

class _PreparationOption extends StatelessWidget {
  const _PreparationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CareerColors.mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: CareerColors.teal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CareerText.label),
                const SizedBox(height: 4),
                Text(subtitle, style: CareerText.small),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: CareerColors.muted,
            size: 20,
          ),
        ],
      ),
    ),
  );
}
