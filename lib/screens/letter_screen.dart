import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backend.dart';
import '../data/repositories/providers.dart';
import '../logic/cover_letter.dart';
import '../services/ai/ai_service.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Surat lamaran: compact controls above a document-like preview, then copy or share.
/// Firebase builds ask Gemini for each tone and variant (cached), falling back to the template when AI is unavailable.
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

  /// Generated letters by tone and variant, so switching tone back does not call the AI again.
  final _letters = <(LetterTone, int), GeneratedLetter>{};

  @override
  void initState() {
    super.initState();
    if (backend == Backend.firebase) _generate();
  }

  Future<void> _generate() async {
    final key = (_tone, _seed);
    if (_letters.containsKey(key)) return;
    setState(() => _busy = true);
    final st = ref.read(appProvider);
    final letter = await ref
        .read(aiServiceProvider)
        .generateLetter(job: st.job(widget.jobId), profile: st.profile, tone: _tone, variant: _seed);
    if (!mounted) return;
    setState(() {
      _letters[key] = letter;
      _busy = _letters[(_tone, _seed)] == null;
    });
  }

  void _setTone(LetterTone t) {
    setState(() => _tone = t);
    if (backend == Backend.firebase) _generate();
  }

  Future<void> _regenerate() async {
    if (backend == Backend.firebase) {
      setState(() => _seed++);
      return _generate();
    }
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
    final job = ref.watch(appProvider).job(widget.jobId);
    final profile = ref.watch(appProvider).profile;
    final generated = _letters[(_tone, _seed)];
    final text = backend == Backend.mock
        ? coverLetter(job, profile, _tone, _seed)
        : generated?.text ?? _letters.values.lastOrNull?.text ?? 'Menyusun surat lamaran untukmu…';
    final note = backend == Backend.mock
        ? 'Pada demo ini, surat disusun dari templat berdasarkan profil dan lowongan. Baca ulang dan sesuaikan sebelum dikirim.'
        : generated?.offline ?? false
        ? 'AI sedang tidak tersedia, jadi surat ini disusun dari templat. Baca ulang dan sesuaikan sebelum dikirim.'
        : 'Disusun AI dari profil dan lowongan ini. Baca ulang dan sesuaikan sebelum dikirim.';
    final highlights = letterHighlights(job, profile);
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return CareerTheme(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => context.back(Routes.job(job.id)),
          ),
          title: const Text('Surat lamaran'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                CompanyAvatar(company: job.company, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SURAT UNTUK', style: CareerText.eyebrow),
                      const SizedBox(height: 2),
                      Text(job.title, style: CareerText.label),
                      Text(job.company, style: CareerText.small),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ToneSwitch(tone: _tone, onChanged: _setTone),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Buat ulang',
                  onPressed: _busy ? null : _regenerate,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    side: const BorderSide(color: CareerColors.line),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.autorenew_rounded, color: CareerColors.teal),
                ),
              ],
            ),
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Menyorot:', style: CareerText.small),
                  for (final s in highlights)
                    CareerPill(s, icon: Icons.check_rounded, color: CareerColors.teal, background: CareerColors.mint),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Semantics(
              label: 'Pratinjau surat lamaran',
              child: AnimatedOpacity(
                opacity: _busy ? .35 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CareerColors.line),
                    boxShadow: const [BoxShadow(color: Color(0x14172B3A), blurRadius: 18, offset: Offset(0, 6))],
                  ),
                  child: SelectableText(text, style: CareerText.body.copyWith(fontSize: 14.5, height: 1.75)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('$words kata · ${_tone == LetterTone.formal ? 'Formal lengkap' : 'Ringkas'}', style: CareerText.small),
            const SizedBox(height: 16),
            CareerMeta(Icons.info_outline_rounded, note, style: CareerText.small),
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
              child: Row(
                children: [
                  Expanded(
                    child: CareerButton(
                      label: 'Salin surat',
                      icon: Icons.content_copy_rounded,
                      onPressed: _busy
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: text));
                              if (context.mounted) showToast(context, 'Surat lamaran disalin');
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Bagikan surat',
                    onPressed: _busy
                        ? null
                        : () => SharePlus.instance.share(ShareParams(text: text, subject: 'Lamaran ${job.title} - ${profile.name}')),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      side: const BorderSide(color: CareerColors.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.share_outlined, color: CareerColors.teal),
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

class _ToneSwitch extends StatelessWidget {
  const _ToneSwitch({required this.tone, required this.onChanged});
  final LetterTone tone;
  final ValueChanged<LetterTone> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, LetterTone value) {
      final selected = tone == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: TextButton(
            onPressed: () => onChanged(value),
            style: TextButton.styleFrom(
              backgroundColor: selected ? CareerColors.navy : Colors.transparent,
              foregroundColor: selected ? Colors.white : CareerColors.muted,
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: CareerText.label,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CareerColors.line),
      ),
      child: Row(children: [option('Formal lengkap', LetterTone.formal), const SizedBox(width: 4), option('Ringkas', LetterTone.ringkas)]),
    );
  }
}
