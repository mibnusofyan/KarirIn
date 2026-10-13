import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/providers.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';
import 'video_lesson_screen.dart';

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
    if (r != null) toastVia(messenger, 'Match Score ${r.jobTitle}: ${fmt(r.before)} → ${fmt(r.after)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    final ranked = st.ranked;
    final target = ranked.firstWhere((s) => s.job.id == st.gapJobId);
    final job = target.job;
    final items = skillGap(job, target.result);
    final potential = computeMatch(job, st.profile.copyWith(skills: [...st.profile.skills, ...items.map((i) => i.skill)])).total;
    final mastered = st.learned.where((s) => job.wajib.contains(s) || job.tambahan.contains(s)).toList();

    Future<void> changeTarget() async {
      final id = await showJobPicker(context, title: 'Pilih target belajar', ranked: ranked, selectedId: job.id);
      if (id != null) n.selectGapJob(id);
    }

    return CareerTheme(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            key: const PageStorageKey('career-learning'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Text('RENCANA BELAJAR', style: CareerText.eyebrow),
              const SizedBox(height: 6),
              Text('Selangkah demi\nselangkah lebih siap.', style: CareerText.heading.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              const Text('Mulai dari skill yang paling menaikkan kecocokan. Urutannya saran, kamu bebas memilih.', style: CareerText.muted),
              const SizedBox(height: 20),
              SelectedJobCard(eyebrow: 'TARGET LOWONGAN', scored: target, onChange: changeTarget),
              const SizedBox(height: 14),
              _ProgressHero(now: target.result.total, potential: potential, remaining: items.length),
              const SizedBox(height: 28),
              if (items.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(child: Text('Langkah belajar', style: CareerText.title)),
                    Text('${items.length} skill', style: CareerText.small),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Diurutkan dari dampak terbesar ke skormu.', style: CareerText.small),
                const SizedBox(height: 18),
                for (final (i, item) in items.indexed)
                  _LearningStep(
                    key: ValueKey('step-${item.skill}'),
                    number: i + 1,
                    item: item,
                    jobTitle: job.title,
                    last: i == items.length - 1,
                  ),
              ] else
                _AllDone(job: job),
              if (mastered.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text('Sudah kamu kuasai', style: CareerText.title),
                const SizedBox(height: 12),
                for (final (i, skill) in mastered.indexed) _MasteredStep(skill: skill, last: i == mastered.length - 1),
              ],
              const SizedBox(height: 24),
              const Text(
                'Materi gratis dikurasi tim KarirIn. Tandai dikuasai setelah kamu yakin; skor dihitung ulang dengan rumus Match Score yang sama.',
                style: CareerText.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navy summary: current score → potential, with the potential band behind the current bar.
class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.now, required this.potential, required this.remaining});
  final double now, potential;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC4D6E7);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Skor sekarang ${fmt(now)}, potensi ${fmt(potential)} dari 100',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(color: CareerColors.navy, borderRadius: BorderRadius.circular(24)),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: now),
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                runSpacing: 8,
                children: [
                  _score('SKOR SEKARANG', fmt(value), Colors.white, light),
                  _score('POTENSI', fmt(potential), CareerColors.yellow, light, end: true),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Bar(value: potential / 100, color: const Color(0xFF5D8B98), track: const Color(0xFF2B4A72), height: 8),
                    Bar(value: value / 100, color: const Color(0xFFB5E5D4), track: Colors.transparent, height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                remaining == 0 ? 'Semua skill yang diminta sudah kamu kuasai.' : '$remaining skill lagi menuju potensi ${fmt(potential)}.',
                style: CareerText.label.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Potensi dihitung jika semua skill di bawah dikuasai. Skor kecocokan profil, bukan peluang diterima.',
                style: CareerText.small.copyWith(color: light),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _score(String label, String value, Color color, Color labelColor, {bool end = false}) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: CareerText.eyebrow.copyWith(color: labelColor)),
      Text(value, style: CareerText.heading.copyWith(fontSize: 34, color: color)),
    ],
  );
}

/// Timeline rail: a step marker with a line running down to the next step.
class _Rail extends StatelessWidget {
  const _Rail({required this.marker, required this.last, required this.lineColor, required this.child});
  final Widget marker;
  final bool last;
  final Color lineColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              marker,
              if (!last)
                Expanded(
                  child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: lineColor),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 24),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class _LearningStep extends ConsumerWidget {
  const _LearningStep({super.key, required this.number, required this.item, required this.jobTitle, required this.last});
  final int number;
  final GapItem item;
  final String jobTitle;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(appProvider).resourceForSkill(item.skill);
    final first = number == 1;
    return _Rail(
      last: last,
      lineColor: CareerColors.line,
      marker: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: first ? CareerColors.navy : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: first ? CareerColors.navy : CareerColors.line, width: 2),
        ),
        child: Text(
          '$number',
          textScaler: TextScaler.noScaling,
          style: CareerText.label.copyWith(color: first ? Colors.white : CareerColors.ink),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.skill, style: CareerText.cardTitle)),
              const SizedBox(width: 8),
              Text('+${fmt(item.gain)} poin', style: CareerText.label.copyWith(color: CareerColors.teal)),
            ],
          ),
          const SizedBox(height: 6),
          item.wajib
              ? const CareerPill('Skill wajib', color: CareerColors.amber, background: CareerColors.amberLight)
              : const CareerPill('Skill tambahan', background: Colors.white),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: CareerColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showCareerSheet<void>(context, (_) => _ResourceSheet(item: item, jobTitle: jobTitle)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(12)),
                      child: Icon(SkillGapScreen.resourceIcon(res.type), color: CareerColors.teal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(res.title, style: CareerText.label),
                          const SizedBox(height: 2),
                          Text('${res.type.label} · ${res.duration} · Gratis', style: CareerText.small),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: CareerColors.muted, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => SkillGapScreen.master(ScaffoldMessenger.of(context), ref.read(appProvider.notifier), item.skill),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
            label: Text('Sudah saya kuasai', semanticsLabel: 'Tandai ${item.skill} sudah saya kuasai'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
          ),
        ],
      ),
    );
  }
}

class _MasteredStep extends StatelessWidget {
  const _MasteredStep({required this.skill, required this.last});
  final String skill;
  final bool last;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$skill, sudah dikuasai',
    excludeSemantics: true,
    child: _Rail(
      last: last,
      lineColor: CareerColors.mint,
      marker: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: CareerColors.teal, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(skill, style: CareerText.label),
            const CareerPill('Dikuasai', icon: Icons.check_rounded, color: CareerColors.teal, background: CareerColors.mint),
          ],
        ),
      ),
    ),
  );
}

class _AllDone extends ConsumerWidget {
  const _AllDone({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(24)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_outlined, color: CareerColors.teal, size: 32),
        const SizedBox(height: 12),
        const Text('Skill untuk lowongan ini lengkap', style: CareerText.title),
        const SizedBox(height: 6),
        const Text('Langkah berikutnya: berlatih wawancara untuk posisi ini.', style: CareerText.body),
        const SizedBox(height: 18),
        CareerButton(
          label: 'Latihan wawancara',
          icon: Icons.record_voice_over_outlined,
          onPressed: () {
            ref.read(appProvider.notifier).selectCoachJob(job.id);
            context.go(Routes.coach);
          },
        ),
        TextButton(onPressed: () => context.push('${Routes.letter}?job=${job.id}'), child: const Text('Buat surat lamaran')),
      ],
    ),
  );
}

class _ResourceSheet extends ConsumerWidget {
  const _ResourceSheet({required this.item, required this.jobTitle});
  final GapItem item;
  final String jobTitle;

  static const _modules = [('Konsep dasar', '25 mnt'), ('Praktik dengan contoh kasus', '60 mnt'), ('Kuis dan sertifikat', '15 mnt')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(appProvider).resourceForSkill(item.skill);
    void masterAndClose({String? proof}) {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(appProvider.notifier);
      Navigator.pop(context);
      if (proof != null) {
        notifier.recordLearningProof(item.skill, proof);
        toastVia(messenger, backend == Backend.mock ? 'Bukti belajar dicatat (demo)' : 'Bukti belajar disimpan');
      }
      SkillGapScreen.master(messenger, notifier, item.skill);
    }

    final videoId = backend == Backend.mock ? null : res.youtubeId;

    // Videos play inside KarirIn; any other link opens in an in-app browser tab.
    Future<void> openMaterial() async {
      final u = Uri.tryParse(res.url?.trim() ?? '');
      final url = u != null && u.scheme.startsWith('http') && u.host.isNotEmpty ? u : null;
      if (backend == Backend.mock || url == null) {
        showToast(context, 'Demo: tautan materi belum tersambung ke penyedia');
        return;
      }
      if (await ref.read(networkStatusProvider).isOffline()) {
        if (context.mounted) showToast(context, 'Tidak ada koneksi internet. Video butuh internet untuk diputar.');
        return;
      }
      if (!context.mounted) return;
      if (videoId != null) return VideoLessonScreen.open(context, skill: item.skill, resource: res);
      if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView) && context.mounted) {
        showToast(context, 'Tautan materi tidak dapat dibuka.');
      }
    }

    Future<void> addProof() async {
      if (backend == Backend.mock) return masterAndClose(proof: 'demo');
      final proof = await showDialog<String>(context: context, builder: (_) => const _ProofDialog());
      if (proof != null && context.mounted) masterAndClose(proof: proof);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareerSheetHeader(res.title),
        Text('${res.type.label} · ${res.duration} · Gratis'.toUpperCase(), style: CareerText.eyebrow),
        const SizedBox(height: 16),
        if (videoId != null) _VideoPreview(videoId: videoId, provider: res.provider, onTap: openMaterial),
        if (videoId == null)
          for (final (i, (title, duration)) in _modules.indexed) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text('${i + 1}', style: CareerText.label.copyWith(color: CareerColors.teal)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: CareerText.body)),
                  const SizedBox(width: 8),
                  Text(duration, style: CareerText.small),
                ],
              ),
            ),
          ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(14)),
          child: Text(
            'Menguasai ${item.skill} menaikkan skor $jobTitle sebesar +${fmt(item.gain)} poin.',
            style: CareerText.body.copyWith(color: CareerColors.teal),
          ),
        ),
        const SizedBox(height: 20),
        CareerButton(label: 'Tandai dikuasai', icon: Icons.check_rounded, onPressed: masterAndClose),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              onPressed: openMaterial,
              icon: Icon(videoId != null ? Icons.play_circle_outline_rounded : Icons.open_in_new_rounded, size: 17),
              label: Text(videoId != null ? 'Putar video' : 'Buka materi'),
            ),
            TextButton.icon(onPressed: addProof, icon: const Icon(Icons.upload_rounded, size: 17), label: const Text('Unggah bukti')),
          ],
        ),
      ],
    );
  }
}

/// Thumbnail of the lesson video with a play button; tapping opens the in-app player.
class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.videoId, required this.provider, required this.onTap});
  final String videoId;
  final String? provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Putar video materi',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Material(
              color: CareerColors.navy,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    const ColoredBox(color: Color(0x33000000)),
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, size: 34, color: CareerColors.navy),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (provider != null) ...[const SizedBox(height: 8), Text('Video oleh $provider · diputar di KarirIn', style: CareerText.small)],
      ],
    ),
  );
}

/// Proof of learning: a certificate link or a short note on what was learned.
class _ProofDialog extends StatefulWidget {
  const _ProofDialog();

  @override
  State<_ProofDialog> createState() => _ProofDialogState();
}

class _ProofDialogState extends State<_ProofDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CareerTheme(
    child: AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Unggah bukti belajar', style: CareerText.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Tempel tautan sertifikat atau tulis singkat apa yang sudah kamu pelajari.', style: CareerText.body),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            maxLength: 300,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: careerInput(label: 'Tautan atau catatan', hint: 'https://…'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        TextButton(onPressed: _c.text.trim().isEmpty ? null : () => Navigator.pop(context, _c.text.trim()), child: const Text('Simpan')),
      ],
    ),
  );
}
