import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// null = "Semua".
  MatchCategory? _filter;
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _retrying = false);
    ref.read(appProvider.notifier).setOffline(false);
  }

  void _openNotifications() {
    final p = ref.read(appProvider).profile;
    final csScore = fmt(computeMatch(jobById('j4'), p).total);
    showKSheet<void>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Notifikasi', style: KText.titleLarge)),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded), tooltip: 'Tutup'),
            ],
          ),
          const SizedBox(height: 8),
          _NotifItem(
            icon: Icons.work_outline_rounded,
            bg: KColors.secondaryContainer,
            fg: KColors.onSecondaryContainer,
            meta: 'Lowongan baru · 1 jam lalu',
            text: 'Customer Service Officer di BPR Artha Sejahtera cocok $csScore dengan profilmu.',
            onTap: () {
              Navigator.pop(ctx);
              context.push(Routes.job('j4'));
            },
          ),
          const _NotifItem(
            icon: Icons.event_rounded,
            bg: KColors.tertiaryContainer,
            fg: KColors.onTertiaryContainer,
            meta: 'Pengingat · hari ini',
            text: 'Tes online Kasir di Toko Swalayan Mitra besok pukul 10.00.',
          ),
          const _NotifItem(
            icon: Icons.mail_outline_rounded,
            bg: KColors.primaryContainer,
            fg: KColors.onPrimaryContainer,
            meta: 'Tindak lanjut · kemarin',
            text: 'Sudah 7 hari sejak melamar Admin Media Sosial. Pertimbangkan mengirim email tindak lanjut.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(appProvider);
    final ranked = st.ranked;
    final counts = {for (final c in MatchCategory.values) c: ranked.where((s) => s.result.category == c).length};
    final shown = ranked.where((s) => _filter == null || s.result.category == _filter).toList();

    // "Rekomendasi aksi": the best-scoring job (≥50) that still misses a required skill.
    final recSrc = ranked.where((s) => s.result.missingWajib.isNotEmpty && s.result.total >= 50).firstOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                  child: Row(
                    children: [
                      const KarirInMark(size: 32),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Karir',
                            children: [
                              TextSpan(
                                text: 'In',
                                style: TextStyle(color: KColors.secondary),
                              ),
                            ],
                          ),
                          style: TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700, color: KColors.brandNavy),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Notifikasi',
                        onPressed: _openNotifications,
                        icon: const Badge(smallSize: 6, backgroundColor: KColors.error, child: Icon(Icons.notifications_outlined)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Halo, ${st.profile.firstName}', style: KText.headlineMedium),
                    const SizedBox(height: 2),
                    Text('${ranked.length} lowongan diurutkan dari yang paling cocok dengan profilmu.', style: KText.bodyMediumVariant),
                  ],
                ),
              ),
            ),
            if (st.offline)
              SliverToBoxAdapter(
                child: _OfflineCard(retrying: _retrying, onRetry: _retry),
              )
            else ...[
              if (recSrc != null) SliverToBoxAdapter(child: _RecommendationCard(source: recSrc)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      _chip('Semua · ${ranked.length}', _filter == null, () => setState(() => _filter = null)),
                      for (final c in MatchCategory.values)
                        _chip('${c.label} · ${counts[c]}', _filter == c, () => setState(() => _filter = c)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _JobCard(scored: shown[i]),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Text('Match Score adalah alat bantu keputusan, bukan hasil seleksi perusahaan.', style: KText.bodySmall),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({required this.source});
  final ScoredJob source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(appProvider).profile;
    final skill = source.result.missingWajib.first;
    final to = computeMatch(source.job, p.copyWith(skills: [...p.skills, skill])).total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: KColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ref.read(appProvider.notifier).selectGapJob(source.job.id);
            context.go(Routes.gap);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconCircle(Icons.lightbulb_outline_rounded, bg: KColors.primary, fg: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REKOMENDASI AKSI',
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: .5,
                          color: KColors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Kuasai '),
                            TextSpan(
                              text: skill,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' agar skor '),
                            TextSpan(
                              text: source.job.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' naik dari ${fmt(source.result.total)} ke ${fmt(to)}.'),
                          ],
                        ),
                        style: KText.bodyMedium.copyWith(color: KColors.onPrimaryContainer),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Text('Buka Skill Gap', style: KText.sectionLabel),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: KColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.scored});
  final ScoredJob scored;

  @override
  Widget build(BuildContext context) {
    final j = scored.job, r = scored.result;
    final missing = r.missingWajib;
    return FilledCard(
      onTap: () => context.push(Routes.job(j.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreTile(score: r.total),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(j.title, style: KText.titleMedium),
                Text('${j.company} · ${j.city}', style: KText.bodyMediumVariant),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [CategoryTag(r.category), Tag(j.mode.label, outlined: true)]),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      missing.isEmpty ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                      size: 16,
                      color: missing.isEmpty ? KColors.secondary : KColors.error,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        missing.isEmpty ? 'Semua skill wajib terpenuhi' : 'Kurang ${missing.length} skill wajib: ${joinId(missing)}',
                        style: TextStyle(fontSize: 12, height: 16 / 12, color: missing.isEmpty ? KColors.secondary : KColors.error),
                      ),
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
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.retrying, required this.onRetry});
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    decoration: BoxDecoration(color: KColors.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
    child: Column(
      children: [
        const IconCircle(Icons.wifi_off_rounded, bg: KColors.errorContainer, fg: KColors.onErrorContainer, size: 64),
        const SizedBox(height: 12),
        const Text('Koneksi terputus', style: KText.titleLarge),
        const SizedBox(height: 12),
        const Text(
          'Lowongan dan Match Score belum bisa dimuat. Periksa internet kamu, lalu coba lagi.',
          textAlign: TextAlign.center,
          style: KText.bodyMediumVariant,
        ),
        const SizedBox(height: 20),
        TonalButton(
          label: retrying ? 'Memuat ulang…' : 'Coba lagi',
          icon: Icons.refresh_rounded,
          height: 48,
          onPressed: retrying ? null : onRetry,
        ),
      ],
    ),
  );
}

class _NotifItem extends StatelessWidget {
  const _NotifItem({required this.icon, required this.bg, required this.fg, required this.meta, required this.text, this.onTap});
  final IconData icon;
  final Color bg, fg;
  final String meta, text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconCircle(icon, bg: bg, fg: fg),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta, style: KText.bodySmall),
                const SizedBox(height: 2),
                Text(text, style: KText.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
