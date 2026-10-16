import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/activity_repository.dart';
import '../data/repositories/providers.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MatchCategory? _filter;
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    if (backend == Backend.mock) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _retrying = false);
      ref.read(appProvider.notifier).setOffline(false);
      return;
    }
    final offline = await ref.read(networkStatusProvider).isOffline();
    if (!mounted) return;
    setState(() => _retrying = false);
    ref.read(appProvider.notifier).setOffline(offline);
    if (offline) showToast(context, 'Masih belum ada koneksi. Periksa Wi-Fi atau data seluler.');
  }

  void _openNotifications() {
    if (backend == Backend.firebase) {
      showCareerSheet<void>(context, (_) => const _NotificationList());
      return;
    }
    final score = fmt(
      computeMatch(ref.read(appProvider).job('j4'), ref.read(appProvider).profile).total,
    );
    showCareerSheet<void>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CareerSheetHeader('Notifikasi'),
          _Notification(
            icon: Icons.work_outline_rounded,
            label: 'Lowongan baru · 1 jam lalu',
            text:
                'Customer Service Officer di BPR Artha Sejahtera cocok $score dengan profilmu.',
            onTap: () {
              Navigator.pop(ctx);
              context.push(Routes.job('j4'));
            },
          ),
          const Divider(),
          const _Notification(
            icon: Icons.event_outlined,
            label: 'Pengingat · hari ini',
            text: 'Tes online Kasir di Toko Swalayan Mitra besok pukul 10.00.',
          ),
          const Divider(),
          const _Notification(
            icon: Icons.mail_outline_rounded,
            label: 'Tindak lanjut · kemarin',
            text:
                'Sudah 7 hari sejak melamar Admin Media Sosial. Pertimbangkan mengirim email tindak lanjut.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final ranked = state.ranked;
    final shown = ranked
        .where((s) => _filter == null || s.result.category == _filter)
        .toList();
    final recommendation = ranked
        .where((s) => s.result.missingWajib.isNotEmpty && s.result.total >= 50)
        .firstOrNull;

    return CareerTheme(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const PageStorageKey('career-home'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Row(
                    children: [
                      const KarirInMark(size: 30),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Karir',
                            children: [
                              TextSpan(
                                text: 'In',
                                style: TextStyle(color: CareerColors.teal),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.8,
                            color: CareerColors.navy,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Notifikasi',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: CareerColors.ink,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _openNotifications,
                        icon: const Badge(
                          smallSize: 6,
                          backgroundColor: CareerColors.teal,
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 23,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Halo, ${state.profile.firstName}',
                              style: CareerText.muted,
                            ),
                          ),
                          const Icon(
                            Icons.wb_sunny_outlined,
                            color: CareerColors.amber,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Langkah baru,\npeluang baru.',
                        style: CareerText.heading,
                      ),
                    ],
                  ),
                ),
              ),
              if (state.offline)
                SliverToBoxAdapter(
                  child: _OfflineCard(retrying: _retrying, onRetry: _retry),
                )
              else ...[
                if (recommendation != null)
                  SliverToBoxAdapter(
                    child: _RecommendationCard(source: recommendation),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Peluang untukmu',
                            style: CareerText.title,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${ranked.length} lowongan',
                          style: CareerText.small,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Row(
                      children: [
                        _filterChip('Semua', ranked.length, null),
                        for (final category in MatchCategory.values)
                          _filterChip(
                            category.label,
                            ranked
                                .where((s) => s.result.category == category)
                                .length,
                            category,
                          ),
                      ],
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.manage_search_rounded,
                            size: 36,
                            color: CareerColors.teal,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum ada di kategori ini',
                            style: CareerText.cardTitle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Coba kategori lain untuk melihat peluang yang tersedia.',
                            style: CareerText.muted,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => setState(() => _filter = null),
                            child: const Text('Lihat semua lowongan'),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _JobCard(
                      key: ValueKey(shown[i].job.id),
                      scored: shown[i],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 22, 24, 28),
                    child: Text(
                      'Diurutkan berdasarkan kecocokan profilmu. Match Score membantu kamu memilih, bukan keputusan perusahaan.',
                      style: CareerText.small,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, int count, MatchCategory? category) {
    final selected = _filter == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: TextButton(
          onPressed: () => setState(() => _filter = category),
          style: TextButton.styleFrom(
            foregroundColor: selected ? Colors.white : CareerColors.muted,
            backgroundColor: selected ? CareerColors.navy : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected ? CareerColors.navy : CareerColors.line,
              ),
            ),
            textStyle: CareerText.small.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Text('$label  $count'),
        ),
      ),
    );
  }
}

class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({required this.source});
  final ScoredJob source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appProvider).profile;
    final skill = source.result.missingWajib.first;
    final potential = computeMatch(
      source.job,
      profile.copyWith(skills: [...profile.skills, skill]),
    ).total;
    final gain = potential - source.result.total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: CareerColors.navy,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LANGKAH PILIHANMU',
                style: CareerText.small.copyWith(
                  color: const Color(0xFFC4D6E7),
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Satu skill lagi.\nSelangkah lebih siap.',
                      style: CareerText.title.copyWith(
                        color: Colors.white,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  if (MediaQuery.textScalerOf(context).scale(14) < 20) ...[
                    const SizedBox(width: 8),
                    const CareerSteps(),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$skill · +${fmt(gain)} poin',
                style: CareerText.small.copyWith(
                  color: const Color(0xFFE3F0F8),
                ),
              ),
              const SizedBox(height: 2),
              TextButton(
                onPressed: () {
                  ref.read(appProvider.notifier).selectGapJob(source.job.id);
                  context.go(Routes.gap);
                },
                style: TextButton.styleFrom(
                  foregroundColor: CareerColors.yellow,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text('Lihat rencana belajar')),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 18),
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

class _JobCard extends ConsumerWidget {
  const _JobCard({super.key, required this.scored});
  final ScoredJob scored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = scored.job;
    final result = scored.result;
    final saved = ref.watch(
      appProvider.select((s) => s.savedJobIds.contains(job.id)),
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: CareerColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.job(job.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CompanyAvatar(company: job.company, size: 40),
                  const SizedBox(width: 10),
                  Expanded(child: Text(job.company, style: CareerText.small)),
                  IconButton(
                    tooltip: saved
                        ? 'Hapus ${job.title} dari simpanan'
                        : 'Simpan ${job.title}',
                    isSelected: saved,
                    onPressed: () {
                      ref.read(appProvider.notifier).toggleSaved(job.id);
                      showToast(
                        context,
                        saved
                            ? 'Lowongan dihapus dari simpanan'
                            : 'Lowongan disimpan',
                      );
                    },
                    icon: const Icon(Icons.bookmark_border_rounded, size: 21),
                    selectedIcon: const Icon(Icons.bookmark_rounded, size: 21),
                    color: saved ? CareerColors.teal : CareerColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(job.title, style: CareerText.cardTitle),
              const SizedBox(height: 7),
              CareerMeta(
                Icons.location_on_outlined,
                '${job.city} · ${job.mode.label}',
                style: CareerText.small,
              ),
              const SizedBox(height: 5),
              Text(job.salary, style: CareerText.label.copyWith(fontSize: 14)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(),
              ),
              MatchBadge(result: result),
              const SizedBox(height: 7),
              Text(
                result.missingWajib.isEmpty
                    ? 'Semua skill wajib sudah sesuai'
                    : '${result.matchedWajib.length} dari ${job.wajib.length} skill wajib sesuai',
                style: CareerText.small,
              ),
            ],
          ),
        ),
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
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.wifi_off_rounded, color: CareerColors.teal, size: 40),
        const SizedBox(height: 16),
        const Text(
          'Koneksi terputus',
          style: CareerText.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Peluangmu tetap menunggu. Periksa koneksi internet, lalu coba lagi.',
          style: CareerText.muted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        CareerButton(
          label: retrying ? 'Memuat ulang…' : 'Coba lagi',
          icon: Icons.refresh_rounded,
          onPressed: retrying ? null : onRetry,
        ),
      ],
    ),
  );
}

class _Notification extends StatelessWidget {
  const _Notification({
    required this.icon,
    required this.label,
    required this.text,
    this.onTap,
  });
  final IconData icon;
  final String label, text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CareerColors.teal, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CareerText.small),
                const SizedBox(height: 6),
                Text(text, style: CareerText.body),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: CareerColors.muted,
            ),
        ],
      ),
    ),
  );
}

/// Firebase builds: notifications from the team's scripts (new jobs, Lamar cepat status) plus the upcoming follow-up
/// reminders.
class _NotificationList extends ConsumerStatefulWidget {
  const _NotificationList();

  @override
  ConsumerState<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends ConsumerState<_NotificationList> {
  late final Future<List<AppNotification>> _notifications = () async {
    final uid = ref.read(authRepositoryProvider).currentUid;
    if (uid == null) return const <AppNotification>[];
    try {
      return await ref.read(activityRepositoryProvider).fetchNotifications(uid);
    } catch (_) {
      return const <AppNotification>[];
    }
  }();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final reminders = [
      for (final a in ref.watch(appProvider).applications)
        if (a.status.isActive && a.remind != null && a.reminderAt != null && a.reminderAt!.isAfter(now)) a,
    ]..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
    return FutureBuilder(
      future: _notifications,
      builder: (context, snap) {
        final items = <Widget>[
          for (final n in snap.data ?? const <AppNotification>[])
            _Notification(
              icon: n.applicationId != null ? Icons.assignment_turned_in_outlined : Icons.work_outline_rounded,
              label: '${n.title}${n.createdAt == null ? '' : ' · ${formatShortDateId(n.createdAt!)}'}',
              text: n.body,
              onTap: n.jobId != null
                  ? () {
                      Navigator.pop(context);
                      context.push(Routes.job(n.jobId!));
                    }
                  : n.applicationId != null
                  ? () {
                      Navigator.pop(context);
                      context.go(Routes.tracker);
                    }
                  : null,
            ),
          for (final a in reminders)
            _Notification(
              icon: Icons.event_outlined,
              label: 'Pengingat · ${formatShortDateId(a.reminderAt!)}',
              text: '${a.remind}: ${a.title} di ${a.company}.',
              onTap: () {
                Navigator.pop(context);
                context.go(Routes.tracker);
              },
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CareerSheetHeader('Notifikasi'),
            if (snap.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: CareerColors.teal)),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Belum ada notifikasi. Lowongan baru yang cocok, kabar Lamar cepat, dan pengingat lamaranmu akan muncul di sini.',
                  style: CareerText.muted,
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final (i, w) in items.indexed) ...[if (i > 0) const Divider(), w],
          ],
        );
      },
    );
  }
}
