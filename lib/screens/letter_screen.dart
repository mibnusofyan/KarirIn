import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../logic/cover_letter.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Surat lamaran otomatis, personalised from the profile and the selected job.
class LetterScreen extends ConsumerStatefulWidget {
  const LetterScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends ConsumerState<LetterScreen> {
  LetterTone _tone = LetterTone.formal;
  int _seed = 0;
  bool _busy = false;

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _busy = false;
        _seed++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = jobById(widget.jobId);
    final text = coverLetter(job, ref.watch(appProvider).profile, _tone, _seed);
    return Scaffold(
      appBar: topBar(
        title: 'Surat lamaran',
        onBack: () => context.back(Routes.job(job.id)),
        actions: [
          IconButton(
            tooltip: 'Buat ulang',
            onPressed: _busy ? null : _regenerate,
            icon: const Icon(Icons.autorenew_rounded, color: KColors.onSurfaceVariant),
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
                      Text(job.title, style: KText.titleLarge),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SegmentedButton<LetterTone>(
                    segments: const [
                      ButtonSegment(value: LetterTone.formal, label: Text('Formal lengkap')),
                      ButtonSegment(value: LetterTone.ringkas, label: Text('Ringkas')),
                    ],
                    selected: {_tone},
                    onSelectionChanged: (s) => setState(() => _tone = s.first),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _busy ? .3 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KColors.outlineVariant),
                    ),
                    child: SelectableText(
                      text,
                      style: const TextStyle(fontSize: 14, height: 22 / 14, color: KColors.onSurface),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: KColors.onSurfaceVariant),
                      SizedBox(width: 8),
                      Expanded(child: Text('Disusun AI dari profil dan lowongan ini. Baca ulang sebelum dikirim.', style: KText.bodySmall)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showToast(context, 'Membuka menu bagikan…'),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    label: const Text('Bagikan'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: 'Salin',
                    icon: Icons.content_copy_rounded,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) showToast(context, 'Surat lamaran disalin');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
