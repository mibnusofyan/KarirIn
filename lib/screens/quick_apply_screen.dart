import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/repositories/application_repository.dart' show maxQuickCvBytes;
import '../data/repositories/providers.dart';
import '../logic/cover_letter.dart';
import '../router.dart';
import '../services/cv_storage.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Lamar cepat: the application to a KarirIn partner company is sent inside the app, with the CV stored on this
/// device (or a PDF picked here), an optional cover letter and explicit consent to share them with that company.
class QuickApplyScreen extends ConsumerStatefulWidget {
  const QuickApplyScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<QuickApplyScreen> createState() => _QuickApplyScreenState();
}

/// The consent sentence shown next to the checkbox and stored with the application.
String quickApplyConsent(Job job) =>
    'Saya setuju profil, CV, dan surat lamaran ini dikirim ke ${job.company} untuk proses rekrutmen ${job.title}.';

class _QuickApplyScreenState extends ConsumerState<QuickApplyScreen> {
  late final Future<StoredCv?> _stored = _loadStored();
  final _letter = TextEditingController();

  /// A PDF picked on this screen; sent with this application only, the stored CV stays as it is.
  ({Uint8List bytes, String name})? _picked;
  bool _consent = false;
  bool _sending = false;
  bool _writing = false;

  Future<StoredCv?> _loadStored() async {
    if (!ref.read(appProvider).hasCv) return null;
    try {
      return await ref.read(cvStorageProvider).load();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _letter.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf'], withData: true);
    final file = res?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    if (bytes.length > maxQuickCvBytes) {
      showToast(context, 'Ukuran CV maksimal 5 MB. Perkecil berkasnya, lalu coba lagi.');
      return;
    }
    setState(() => _picked = (bytes: bytes, name: file.name));
  }

  Future<void> _writeLetter(Job job) async {
    setState(() => _writing = true);
    try {
      final letter = await ref
          .read(aiServiceProvider)
          .generateLetter(job: job, profile: ref.read(appProvider).profile, tone: LetterTone.ringkas, variant: 0);
      if (mounted) _letter.text = letter.text;
    } catch (_) {
      if (mounted) showToast(context, 'Surat belum bisa dibuat. Tulis sendiri atau coba lagi.');
    }
    if (mounted) setState(() => _writing = false);
  }

  Future<void> _send(Job job, Uint8List cv) async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final confirmed = await ref
          .read(appProvider.notifier)
          .sendQuickApplication(job, cv: cv, letter: _letter.text, consent: quickApplyConsent(job));
      if (!mounted) return;
      context.go(Routes.tracker);
      toastVia(
        messenger,
        confirmed ? 'Lamaran terkirim ke ${job.company}' : 'Koneksi lambat. Lamaran terkirim otomatis begitu koneksi membaik.',
      );
    } on QuickApplyFailure catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(appProvider);
    final job = st.job(widget.jobId);
    final applied = !_sending && st.applicationFor(job) != null;

    return CareerTheme(
      child: FutureBuilder<StoredCv?>(
        future: _stored,
        builder: (context, snap) {
          final stored = snap.data;
          final cv = _picked?.bytes ?? (stored != null && stored.isPdf ? stored.bytes : null);
          final canSend = job.quickApply && !applied && cv != null && _consent && !_sending;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                onPressed: () => context.back(Routes.job(job.id)),
              ),
              title: const Text('Lamar cepat'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _JobHeader(job: job),
                const SizedBox(height: 16),
                if (!job.quickApply || applied)
                  Text(
                    applied
                        ? 'Kamu sudah melamar lowongan ini. Pantau statusnya di Pelacak.'
                        : 'Lowongan ini dilamar lewat situs resmi perusahaan.',
                    style: CareerText.body,
                  )
                else ...[
                  Text(
                    'Lamaranmu dikirim ke ${job.company} lewat KarirIn. Statusnya diperbarui perusahaan dan muncul di Pelacak.',
                    style: CareerText.muted,
                  ),
                  const SizedBox(height: 28),
                  const Text('CV', style: CareerText.title),
                  const SizedBox(height: 10),
                  _CvCard(
                    loading: snap.connectionState != ConnectionState.done,
                    stored: stored,
                    picked: _picked,
                    onPick: _sending ? null : _pickPdf,
                  ),
                  const SizedBox(height: 28),
                  const Text('Surat lamaran', style: CareerText.title),
                  const SizedBox(height: 4),
                  const Text('Opsional. Tulis sendiri atau buat dari profilmu.', style: CareerText.muted),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _letter,
                    enabled: !_sending,
                    minLines: 5,
                    maxLines: 12,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Dengan hormat, …', alignLabelWithHint: true),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _writing || _sending ? null : () => _writeLetter(job),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(_writing ? 'Menyusun surat…' : 'Buat dari profil'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Received(company: job.company),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: _sending ? null : (v) => setState(() => _consent = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: CareerColors.teal,
                    title: Text(quickApplyConsent(job), style: CareerText.body),
                  ),
                ],
              ],
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: CareerColors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: applied
                      ? CareerButton(label: 'Lihat di Pelacak', icon: Icons.checklist_rounded, onPressed: () => context.go(Routes.tracker))
                      : CareerButton(
                          label: _sending ? 'Mengirim…' : 'Kirim lamaran',
                          icon: Icons.send_rounded,
                          onPressed: canSend ? () => _send(job, cv) : null,
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          CompanyAvatar(company: job.company, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: CareerText.cardTitle),
                const SizedBox(height: 2),
                Text('${job.company} · ${job.city}', style: CareerText.small),
              ],
            ),
          ),
        ],
      ),
      if (job.quickApply) ...[const SizedBox(height: 12), const PartnerPill()],
    ],
  );
}

class _CvCard extends StatelessWidget {
  const _CvCard({required this.loading, required this.stored, required this.picked, required this.onPick});
  final bool loading;
  final StoredCv? stored;
  final ({Uint8List bytes, String name})? picked;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final stored = this.stored;
    final picked = this.picked;
    final Widget content;
    if (loading) {
      content = const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: CareerColors.teal)),
          SizedBox(width: 12),
          Expanded(child: Text('Memeriksa CV di perangkat…', style: CareerText.muted)),
        ],
      );
    } else if (picked != null || (stored != null && stored.isPdf)) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: CareerColors.teal, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(picked?.name ?? 'CV kamu (PDF)', style: CareerText.label),
                    const SizedBox(height: 2),
                    Text(
                      picked != null
                          ? '${formatFileSize(picked.bytes.length)} · dipilih untuk lamaran ini'
                          : '${formatFileSize(stored!.bytes.length)} · tersimpan di perangkat sejak ${formatShortDateId(stored.savedAt)}',
                      style: CareerText.small,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onPick, child: const Text('Ganti')),
            ],
          ),
          if (picked != null) ...[
            const SizedBox(height: 8),
            const Text('Berkas ini hanya dikirim bersama lamaran ini; CV di profilmu tidak berubah.', style: CareerText.small),
          ],
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stored != null
                ? 'CV di perangkat ini berupa foto. Perusahaan menerima CV dalam bentuk PDF.'
                : 'Belum ada CV di perangkat ini. Pilih berkas PDF untuk dikirim.',
            style: CareerText.body,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onPick, icon: const Icon(Icons.upload_file_rounded, size: 19), label: const Text('Pilih CV (PDF)')),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CareerColors.line),
      ),
      child: content,
    );
  }
}

class _Received extends StatelessWidget {
  const _Received({required this.company});
  final String company;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Yang diterima $company', style: CareerText.label),
        const SizedBox(height: 10),
        for (final item in const [
          'Profil KarirIn: nama, pendidikan, keterampilan, dan pengalaman',
          'CV dalam bentuk PDF',
          'Surat lamaran, bila diisi',
          'Email akunmu, agar perusahaan dapat menghubungimu',
        ]) ...[CareerMeta(Icons.check_rounded, item, style: CareerText.body), const SizedBox(height: 6)],
        const SizedBox(height: 4),
        const Text('Kamu bisa menarik lamaran dari Pelacak kapan saja; salinan CV ikut terhapus.', style: CareerText.small),
      ],
    ),
  );
}
