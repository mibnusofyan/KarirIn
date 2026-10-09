import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../logic/interview.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// One interview practice session: 5 questions, each graded on the 4-aspect rubric.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _answer = TextEditingController();
  final _rnd = Random();
  int _q = 0;
  bool _evaluating = false;
  AnswerScore? _fb;
  bool _showEx = false;
  bool _listening = false;
  List<double> _wave = List.filled(24, 4);
  final List<AnsweredQuestion> _results = [];
  Timer? _waveTimer;

  late final _job = jobById(ref.read(appProvider).coachJobId);
  late final _questions = questionsFor(_job);

  @override
  void initState() {
    super.initState();
    _answer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _answer.dispose();
    super.dispose();
  }

  int get _words => _answer.text.trim().isEmpty ? 0 : _answer.text.trim().split(RegExp(r'\s+')).length;
  bool get _last => _q >= _questions.length - 1;

  /// Voice mode (simulated speech-to-text): the transcript is filled with the demo answer on stop.
  void _toggleMic() {
    if (_listening) {
      _waveTimer?.cancel();
      setState(() {
        _listening = false;
        _wave = List.filled(24, 4);
      });
      _answer.text = _questions[_q].demo;
    } else {
      _answer.clear();
      setState(() => _listening = true);
      _waveTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        setState(() => _wave = List.generate(24, (_) => 6 + _rnd.nextInt(47).toDouble()));
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _evaluating = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    final fb = gradeAnswer(_answer.text);
    setState(() {
      _evaluating = false;
      _fb = fb;
      _results.add(AnsweredQuestion(_questions[_q], fb));
    });
  }

  void _next() {
    if (_last) {
      ref.read(appProvider.notifier).saveInterviewResults(List.of(_results));
      context.pushReplacement(Routes.result);
      return;
    }
    _answer.clear();
    setState(() {
      _q++;
      _fb = null;
      _showEx = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(appProvider).voiceMode;
    final q = _questions[_q];
    final fb = _fb;
    final disabled = _evaluating || (fb == null && _words < 3) || _listening;
    return Scaffold(
      appBar: AppBar(
        leading: BackBtn(onPressed: () => context.back(Routes.coach), icon: Icons.close_rounded, tooltip: 'Tutup sesi'),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pertanyaan ${_q + 1} dari 5', style: KText.titleMedium),
            Text(_job.title, style: KText.bodySmall, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: Column(
        children: [
          StepProgress((_q + (fb != null ? 1 : 0)) / 5),
          Expanded(
            child: ListView(
              // A fresh list per question/state: starts scrolled to the top and avoids
              // stale layers on web when the children change shape.
              key: ValueKey((_q, fb != null)),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tag(q.type, bg: KColors.primaryContainer, fg: KColors.onPrimaryContainer, height: 28),
                ),
                const SizedBox(height: 16),
                Text(q.text, style: KText.titleLarge),
                const SizedBox(height: 16),
                if (fb == null && !_evaluating) ...[
                  const InfoBanner(
                    icon: Icons.lightbulb_outline_rounded,
                    bg: KColors.tertiaryContainer,
                    fg: KColors.onTertiaryContainer,
                    child: Text('Gunakan pola STAR: Situasi, Tugas, Aksi, lalu Hasil yang terukur.'),
                  ),
                  const SizedBox(height: 16),
                  if (!voice) ..._typeInput(q.demo) else ..._voiceInput(),
                ],
                if (_evaluating) const _Evaluating(),
                if (fb != null) _Feedback(fb: fb, better: q.better, showEx: _showEx, onToggleEx: () => setState(() => _showEx = !_showEx)),
              ],
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(
              label: fb != null
                  ? (_last ? 'Lihat hasil wawancara' : 'Pertanyaan berikutnya')
                  : _evaluating
                  ? 'Menilai…'
                  : 'Kirim jawaban',
              onPressed: disabled ? null : (fb != null ? _next : _submit),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _typeInput(String demo) => [
    const SizedBox(height: 4),
    TextField(
      controller: _answer,
      minLines: 7,
      maxLines: 14,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(labelText: 'Jawabanmu', hintText: 'Tulis jawabanmu di sini…', alignLabelWithHint: true),
    ),
    Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Expanded(child: Text('$_words kata', style: KText.bodySmall)),
          TextButton(onPressed: () => _answer.text = demo, child: const Text('Isi contoh (demo)')),
        ],
      ),
    ),
  ];

  List<Widget> _voiceInput() => [
    SizedBox(
      height: 56,
      child: Row(
        children: [
          for (var i = 0; i < _wave.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  height: _wave[i],
                  decoration: BoxDecoration(
                    color: _listening ? KColors.primary : KColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 16),
    Center(
      child: SizedBox.square(
        dimension: 96,
        child: FloatingActionButton.large(
          heroTag: null,
          elevation: 3,
          tooltip: 'Rekam',
          backgroundColor: _listening ? KColors.errorContainer : KColors.primaryContainer,
          foregroundColor: _listening ? KColors.onErrorContainer : KColors.onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          onPressed: _toggleMic,
          child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, size: 36),
        ),
      ),
    ),
    const SizedBox(height: 16),
    Text(
      _listening
          ? 'Mendengarkan… ketuk untuk berhenti'
          : _answer.text.isNotEmpty
          ? 'Rekaman selesai. Ketuk untuk merekam ulang.'
          : 'Ketuk mikrofon, lalu jawab dengan suara',
      textAlign: TextAlign.center,
      style: KText.labelLarge,
    ),
    if (!_listening && _answer.text.isNotEmpty) ...[
      const SizedBox(height: 24),
      TextField(
        controller: _answer,
        minLines: 5,
        maxLines: 10,
        style: const TextStyle(fontSize: 15, height: 22 / 15),
        decoration: const InputDecoration(labelText: 'Transkrip (bisa diedit)', alignLabelWithHint: true),
      ),
    ],
  ];
}

class _Evaluating extends StatelessWidget {
  const _Evaluating();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Menilai jawabanmu…', style: KText.titleMedium),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          builder: (_, v, _) => Bar(value: v, color: KColors.primary, track: KColors.primaryContainer),
        ),
        const SizedBox(height: 12),
        const Text('Mencocokkan dengan rubrik 4 aspek', style: KText.bodySmall),
      ],
    ),
  );
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.fb, required this.better, required this.showEx, required this.onToggleEx});
  final AnswerScore fb;
  final String better;
  final bool showEx;
  final VoidCallback onToggleEx;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: KColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${fb.total}', style: const TextStyle(fontSize: 45, height: 52 / 45)),
            const SizedBox(width: 8),
            const Flexible(child: Text('/ 100 untuk jawaban ini', style: KText.bodyMediumVariant)),
          ],
        ),
        const SizedBox(height: 16),
        AspectGrid(aspects: fb.aspects, compact: true),
        const SizedBox(height: 16),
        _line(Icons.thumb_up_outlined, KColors.secondary, fb.good),
        const SizedBox(height: 16),
        _line(Icons.trending_up_rounded, KColors.error, fb.improve),
        const SizedBox(height: 8),
        Transform.translate(
          offset: const Offset(-12, 0),
          child: TextButton.icon(
            onPressed: onToggleEx,
            iconAlignment: IconAlignment.end,
            icon: Icon(showEx ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
            label: Text(showEx ? 'Sembunyikan contoh jawaban' : 'Lihat contoh jawaban yang lebih baik'),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: showEx
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: KColors.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(better, style: KText.bodyMedium.copyWith(color: KColors.onSecondaryContainer)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );

  Widget _line(IconData ic, Color c, String t) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(ic, size: 20, color: c),
      const SizedBox(width: 12),
      Expanded(child: Text(t, style: KText.bodyMedium)),
    ],
  );
}

/// 2×2 grid of rubric aspects (0–25 each).
class AspectGrid extends StatelessWidget {
  const AspectGrid({super.key, required this.aspects, this.compact = false});
  final List<(String, int)> aspects;

  /// Compact = inline bars (session feedback); otherwise tiles (result screen).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget cell((String, int) a) {
      final v = a.$2 / 25;
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(a.$1, style: KText.bodySmall)),
                Text(
                  '${a.$2}/25',
                  style: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Bar(value: v, color: barColor(v)),
          ],
        );
      }
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: KColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.$1, style: KText.bodySmall),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                text: '${a.$2}',
                children: const [TextSpan(text: ' / 25', style: KText.bodyMediumVariant)],
              ),
              style: KText.headlineSmall,
            ),
            const SizedBox(height: 8),
            Bar(value: v, color: barColor(v)),
          ],
        ),
      );
    }

    final gap = compact ? 16.0 : 8.0;
    return Column(
      children: [
        for (var r = 0; r < aspects.length; r += 2) ...[
          if (r > 0) SizedBox(height: compact ? 12 : 8),
          Row(
            children: [
              Expanded(child: cell(aspects[r])),
              SizedBox(width: gap),
              Expanded(child: r + 1 < aspects.length ? cell(aspects[r + 1]) : const SizedBox()),
            ],
          ),
        ],
      ],
    );
  }
}
