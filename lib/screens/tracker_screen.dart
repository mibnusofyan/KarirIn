import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/backend.dart';
import '../data/models.dart';
import '../router.dart';
import '../services/reminders.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Pelacak lamaran: summary and agenda first, then every application with its next step.
class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

enum _Filter {
  semua('Semua'),
  aktif('Aktif'),
  selesai('Selesai');

  const _Filter(this.label);
  final String label;

  bool accepts(AppStage s) => switch (this) {
    semua => true,
    aktif => s.isActive,
    selesai => !s.isActive,
  };
}

/// Visual identity per stage: icon + label + colour (never colour alone).
({IconData icon, Color fg, Color bg, String description}) stageStyle(AppStage s) => switch (s) {
  AppStage.dikirim => (
    icon: Icons.send_outlined,
    fg: CareerColors.navy,
    bg: const Color(0xFFE8ECF6),
    description: 'Lamaran sudah terkirim',
  ),
  AppStage.tes => (
    icon: Icons.edit_note_rounded,
    fg: CareerColors.amber,
    bg: CareerColors.amberLight,
    description: 'Ada jadwal tes atau psikotes',
  ),
  AppStage.wawancara => (
    icon: Icons.record_voice_over_outlined,
    fg: CareerColors.amber,
    bg: CareerColors.amberLight,
    description: 'Diundang wawancara',
  ),
  AppStage.diterima => (icon: Icons.verified_outlined, fg: CareerColors.teal, bg: CareerColors.mint, description: 'Mendapat tawaran kerja'),
  AppStage.ditolak => (
    icon: Icons.do_not_disturb_on_outlined,
    fg: CareerColors.muted,
    bg: const Color(0xFFEDEFEC),
    description: 'Proses berhenti di perusahaan ini',
  ),
};

/// The job in the catalogue this application belongs to, when it is one of ours.
Job? jobFor(JobApplication a, List<Job> jobs) => jobs.where((j) => j.title == a.title && j.company == a.company).firstOrNull;

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  _Filter _filter = _Filter.semua;

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(appProvider).applications;
    final active = apps.where((a) => a.status.isActive).toList();
    final agenda = active.where((a) => a.remind != null).toList();
    final shown = apps.where((a) => _filter.accepts(a.status)).toList();

    return CareerTheme(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            key: const PageStorageKey('career-tracker'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Text('PELACAK LAMARAN', style: CareerText.eyebrow),
              const SizedBox(height: 6),
              Text('Pantau setiap\nlangkahmu.', style: CareerText.heading.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              const Text(
                'Status Lamar cepat diperbarui perusahaan. Lamaran di situs perusahaan kamu catat sendiri, KarirIn mengingatkan tindak lanjutnya.',
                style: CareerText.muted,
              ),
              const SizedBox(height: 20),
              _Summary(apps: apps),
              if (agenda.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text('Pengingat aktif', style: CareerText.title),
                const SizedBox(height: 4),
                const Text('Dari lamaran yang masih berjalan.', style: CareerText.small),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CareerColors.line),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final (i, a) in agenda.indexed) ...[if (i > 0) const Divider(), _AgendaItem(app: a)],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Text('Semua lamaran', style: CareerText.title)),
                  Text('${apps.length} lamaran', style: CareerText.small),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final f in _Filter.values) _filterButton(f, apps.where((a) => f.accepts(a.status)).length)],
              ),
              const SizedBox(height: 14),
              for (final a in shown) ...[_ApplicationCard(key: ValueKey(a.id), app: a), const SizedBox(height: 12)],
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 36, color: CareerColors.teal),
                      const SizedBox(height: 10),
                      Text(
                        apps.isEmpty ? 'Belum ada lamaran' : 'Belum ada lamaran ${_filter.label.toLowerCase()}',
                        style: CareerText.cardTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Lamaran yang kamu catat dari Detail Lowongan akan muncul di sini.',
                        style: CareerText.muted,
                        textAlign: TextAlign.center,
                      ),
                      if (apps.isNotEmpty)
                        TextButton(onPressed: () => setState(() => _filter = _Filter.semua), child: const Text('Lihat semua lamaran')),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'KarirIn tidak melamar atas namamu: Lamar cepat hanya terkirim setelah kamu menyetujuinya. '
                '${backend == Backend.mock ? 'Pada demo ini, pengingat disimpan di aplikasi dan belum dikirim sebagai notifikasi.' : 'Pengingat muncul sebagai notifikasi di perangkat ini pukul 09.00.'}',
                style: CareerText.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterButton(_Filter f, int count) {
    final selected = _filter == f;
    return Semantics(
      selected: selected,
      button: true,
      child: TextButton(
        onPressed: () => setState(() => _filter = f),
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : CareerColors.muted,
          backgroundColor: selected ? CareerColors.navy : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? CareerColors.navy : CareerColors.line),
          ),
          textStyle: CareerText.small.copyWith(fontWeight: FontWeight.w600),
        ),
        child: Text('${f.label}  $count'),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.apps});
  final List<JobApplication> apps;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC4D6E7);
    int count(bool Function(AppStage) test) => apps.where((a) => test(a.status)).length;
    final active = count((s) => s.isActive);
    final stats = [
      ('Dikirim', count((s) => s == AppStage.dikirim)),
      ('Tes & wawancara', count((s) => s == AppStage.tes || s == AppStage.wawancara)),
      ('Selesai', count((s) => !s.isActive)),
    ];
    return Semantics(
      label: '$active lamaran aktif. ${stats.map((s) => '${s.$1} ${s.$2}').join(', ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: CareerColors.navy, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LAMARAN AKTIF', style: CareerText.eyebrow.copyWith(color: light)),
            const SizedBox(height: 4),
            Text('$active', style: CareerText.heading.copyWith(fontSize: 36, color: Colors.white)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                for (final (label, n) in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$n', style: CareerText.cardTitle.copyWith(color: CareerColors.yellow)),
                      Text(label, style: CareerText.small.copyWith(color: light)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaItem extends ConsumerWidget {
  const _AgendaItem({required this.app});
  final JobApplication app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = stageStyle(app.status);
    final job = jobFor(app, ref.watch(appProvider).jobs);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.event_outlined, color: style.fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.remind!, style: CareerText.label),
                const SizedBox(height: 2),
                Text('${app.title} · ${app.company}', style: CareerText.small),
                if (app.status == AppStage.wawancara && job != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(appProvider.notifier).selectCoachJob(job.id);
                      context.go(Routes.coach);
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                    icon: const Icon(Icons.record_voice_over_outlined, size: 17),
                    label: const Text('Latihan wawancara'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.stage, {super.key});
  final AppStage stage;

  @override
  Widget build(BuildContext context) {
    final s = stageStyle(stage);
    return CareerPill(stage.label, icon: s.icon, color: s.fg, background: s.bg);
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({super.key, required this.app});
  final JobApplication app;

  String get _nextStep => switch (app.status) {
    AppStage.dikirim when app.quick => 'Tunggu kabar dari perusahaan; perubahan status muncul di sini',
    AppStage.dikirim => 'Tunggu kabar, lalu kirim email tindak lanjut bila perlu',
    AppStage.tes => 'Siapkan diri untuk tes',
    AppStage.wawancara => 'Latih jawabanmu sebelum wawancara',
    AppStage.diterima => 'Pelajari detail tawaran sebelum menjawab',
    AppStage.ditolak => 'Lanjutkan ke peluang lain yang cocok',
  };

  void _open(BuildContext context) =>
      showCareerSheet<void>(context, (_) => app.quick ? _QuickStatusSheet(app: app) : _StatusSheet(app: app));

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: CareerColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyAvatar(company: app.company, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.title, style: CareerText.cardTitle),
                      const SizedBox(height: 2),
                      Text('${app.company} · dikirim ${app.date}', style: CareerText.small),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(app.status),
                if (app.quick) const CareerPill('Lamar cepat', icon: Icons.bolt_rounded, color: CareerColors.teal, background: CareerColors.mint),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            if (app.note != null) ...[
              Text('PESAN PERUSAHAAN', style: CareerText.eyebrow),
              const SizedBox(height: 4),
              Text(app.note!, style: CareerText.body),
              const SizedBox(height: 12),
            ],
            Text('LANGKAH BERIKUTNYA', style: CareerText.eyebrow),
            const SizedBox(height: 4),
            Text(_nextStep, style: CareerText.body),
            if (app.remind != null) ...[
              const SizedBox(height: 6),
              CareerMeta(Icons.notifications_none_rounded, 'Pengingat: ${app.remind}', style: CareerText.small),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _open(context),
                child: app.quick
                    ? Text('Lihat detail', semanticsLabel: 'Lihat detail ${app.title}')
                    : Text('Ubah status', semanticsLabel: 'Ubah status ${app.title}'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A Lamar cepat application: the company sets the status, so the user can only read it or withdraw.
class _QuickStatusSheet extends ConsumerWidget {
  const _QuickStatusSheet({required this.app});
  final JobApplication app;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik lamaran?'),
        content: Text('Lamaranmu ke ${app.company} dibatalkan dan salinan CV yang dikirim ikut dihapus. Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tarik lamaran')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(appProvider.notifier).withdrawApplication(app.id);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    toastVia(messenger, 'Lamaran ke ${app.company} ditarik');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stageStyle(app.status);
    final job = jobFor(app, ref.watch(appProvider).jobs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareerSheetHeader('Status lamaran'),
        Text('${app.title} · ${app.company}', style: CareerText.muted),
        const SizedBox(height: 16),
        Row(
          children: [
            StatusChip(app.status),
            const SizedBox(width: 10),
            Expanded(child: Text(s.description, style: CareerText.small)),
          ],
        ),
        if (app.note != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: CareerColors.background, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pesan dari ${app.company}', style: CareerText.label),
                const SizedBox(height: 4),
                Text(app.note!, style: CareerText.body),
              ],
            ),
          ),
        ],
        if (app.status == AppStage.wawancara && job != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(appProvider.notifier).selectCoachJob(job.id);
                context.go(Routes.coach);
              },
              icon: const Icon(Icons.record_voice_over_outlined, size: 17),
              label: const Text('Latihan wawancara'),
            ),
          ),
        if (app.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Riwayat', style: CareerText.label),
          const SizedBox(height: 8),
          for (final h in app.history.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: CareerMeta(stageStyle(h.status).icon, '${h.status.label} · ${formatShortDateId(h.at)}', style: CareerText.body),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          'Status diperbarui oleh ${app.company}.${app.cvSize == null ? '' : ' CV terkirim: PDF, ${formatFileSize(app.cvSize!)}.'}',
          style: CareerText.small,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _withdraw(context, ref),
          style: TextButton.styleFrom(foregroundColor: CareerColors.error),
          child: const Text('Tarik lamaran'),
        ),
      ],
    );
  }
}

class _StatusSheet extends ConsumerStatefulWidget {
  const _StatusSheet({required this.app});
  final JobApplication app;

  @override
  ConsumerState<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends ConsumerState<_StatusSheet> {
  late AppStage _status = widget.app.status;
  late bool _remind = widget.app.remind != null;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CareerSheetHeader('Perbarui status'),
      Text('${widget.app.title} · ${widget.app.company}', style: CareerText.muted),
      const SizedBox(height: 16),
      for (final s in AppStage.values) _StageOption(stage: s, selected: _status == s, onTap: () => setState(() => _status = s)),
      const SizedBox(height: 8),
      if (_status.isActive)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          decoration: BoxDecoration(color: CareerColors.background, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Ingatkan tindak lanjut', style: CareerText.label)),
                  Switch(value: _remind, activeTrackColor: CareerColors.teal, onChanged: (v) => setState(() => _remind = v)),
                ],
              ),
              Text(
                _remind
                    ? 'Pengingat: ${followUpReminder(_status, at: backend == Backend.firebase ? followUpAt(DateTime.now()) : null)} (7 hari lagi)'
                    : 'Tidak ada pengingat untuk lamaran ini.',
                style: CareerText.small,
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      CareerButton(
        label: 'Simpan status',
        icon: Icons.check_rounded,
        onPressed: () {
          ref.read(appProvider.notifier).updateApplication(widget.app.id, _status, _status.isActive && _remind);
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          toastVia(messenger, 'Status ${widget.app.title}: ${_status.label}');
        },
      ),
    ],
  );
}

class _StageOption extends StatelessWidget {
  const _StageOption({required this.stage, required this.selected, required this.onTap});
  final AppStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = stageStyle(stage);
    return Semantics(
      button: true,
      selected: selected,
      label: '${stage.label}. ${s.description}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? s.bg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? s.fg : CareerColors.line, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(s.icon, color: s.fg, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stage.label, style: CareerText.label),
                        Text(s.description, style: CareerText.small),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? s.fg : CareerColors.line,
                    size: 20,
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
