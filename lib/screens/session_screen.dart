import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/providers.dart';
import '../logic/interview.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
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
  List<double> _wave = List.filled(28, 4);
  final List<AnsweredQuestion> _results = [];
  Timer? _waveTimer;

  late final _job = ref.read(appProvider).job(ref.read(appProvider).coachJobId);

  /// The job's reviewed AI question set from Firestore, else the built-in template. Null while loading.
  List<InterviewQuestion>? _loaded;
  List<InterviewQuestion> get _questions => _loaded!;

  final _speech = SpeechToText();
  bool _speechReady = false;

  @override
  void initState() {
    super.initState();
    _answer.addListener(() => setState(() {}));
    if (backend == Backend.mock) {
      _loaded = questionsFor(_job);
    } else {
      ref
          .read(jobRepositoryProvider)
          .fetchQuestions(_job.id)
          .timeout(const Duration(seconds: 6))
          .then<List<InterviewQuestion>?>((qs) => qs, onError: (Object _) => null)
          .then((qs) {
            if (mounted) setState(() => _loaded = qs ?? questionsFor(_job));
          });
    }
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _speech.cancel();
    _answer.dispose();
    super.dispose();
  }

  int get _words => _answer.text.trim().isEmpty ? 0 : _answer.text.trim().split(RegExp(r'\s+')).length;
  bool get _last => _q >= _questions.length - 1;
  bool get _hasProgress => _results.isNotEmpty || _answer.text.trim().isNotEmpty;

  void _startWave() => _waveTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
    setState(() => _wave = List.generate(28, (_) => 6 + _rnd.nextInt(43).toDouble()));
  });

  void _stopWave() {
    _waveTimer?.cancel();
    if (mounted) {
      setState(() {
        _listening = false;
        _wave = List.filled(28, 4);
      });
    }
  }

  /// Voice mode with the device's speech recogniser (Bahasa Indonesia). The transcript stays editable.
  Future<void> _toggleMic() async {
    if (backend == Backend.mock) return _toggleSimulatedMic();
    if (_listening) {
      await _speech.stop();
      _stopWave();
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) _stopWave();
        },
        onError: (_) => _stopWave(),
      );
      if (!_speechReady) {
        if (mounted) showToast(context, 'Pengenalan suara tidak tersedia atau izin mikrofon ditolak. Ketik jawabanmu.');
        ref.read(appProvider.notifier).setVoiceMode(false);
        return;
      }
    }
    _answer.clear();
    setState(() => _listening = true);
    _startWave();
    await _speech.listen(
      onResult: (r) => _answer.text = r.recognizedWords,
      listenOptions: SpeechListenOptions(
        localeId: 'id_ID',
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  /// Mock builds: the transcript is filled with the demo answer on stop.
  void _toggleSimulatedMic() {
    if (_listening) {
      _waveTimer?.cancel();
      setState(() {
        _listening = false;
        _wave = List.filled(28, 4);
      });
      _answer.text = _questions[_q].demo;
    } else {
      _answer.clear();
      setState(() => _listening = true);
      _startWave();
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _evaluating = true);
    final answer = _answer.text.trim();
    final AnswerScore fb;
    if (backend == Backend.mock) {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      fb = gradeAnswer(answer);
    } else {
      fb = await ref.read(aiServiceProvider).gradeAnswer(job: _job, question: _questions[_q], answer: answer);
    }
    if (!mounted) return;
    setState(() {
      _evaluating = false;
      _fb = fb;
      _results.add(AnsweredQuestion(_questions[_q], fb, answer: answer));
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

  /// Leaving mid-session discards answers, so ask first.
  Future<void> _exit() async {
    if (_hasProgress) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => CareerTheme(
          child: AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Akhiri latihan?', style: CareerText.title),
            content: Text('Jawaban di sesi ini (${_results.length} dari 5 dinilai) tidak akan disimpan.', style: CareerText.body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Lanjut berlatih')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: CareerColors.amber),
                child: const Text('Akhiri'),
              ),
            ],
          ),
        ),
      );
      if (leave != true || !mounted) return;
    }
    _waveTimer?.cancel();
    await _speech.cancel();
    if (mounted) context.back(Routes.coach);
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(appProvider).voiceMode;
    if (_loaded == null) {
      return const CareerTheme(
        child: Scaffold(body: Center(child: CircularProgressIndicator(color: CareerColors.teal))),
      );
    }
    final q = _questions[_q];
    final fb = _fb;
    final answering = fb == null && !_evaluating;
    final disabled = _evaluating || (fb == null && _words < 3) || _listening;
    return PopScope(
      canPop: !_hasProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: CareerTheme(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(tooltip: 'Tutup sesi', icon: const Icon(Icons.close_rounded), onPressed: _exit),
            title: Text('Pertanyaan ${_q + 1} dari 5'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(12),
              child: _SegmentProgress(current: _q, done: _results.length),
            ),
          ),
          body: ListView(
            // A fresh list per question/state: starts scrolled to the top and avoids
            // stale layers on web when the children change shape.
            key: ValueKey((_q, fb != null)),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CareerPill(
                    q.type,
                    icon: q.type == 'Teknis' ? Icons.build_outlined : Icons.forum_outlined,
                    color: CareerColors.navy,
                    background: Colors.white,
                  ),
                  Text(_job.title, style: CareerText.small),
                ],
              ),
              const SizedBox(height: 14),
              Text(q.text, style: CareerText.title.copyWith(fontSize: 22, height: 1.4)),
              const SizedBox(height: 18),
              if (answering) ...[const _StarHelp(), const SizedBox(height: 16), if (voice) ..._voiceInput() else ..._typeInput(q.demo)],
              if (_evaluating) const _Evaluating(),
              if (fb != null) _Feedback(fb: fb, better: fb.better ?? q.better, showEx: _showEx, onToggleEx: () => setState(() => _showEx = !_showEx)),
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
                child: CareerButton(
                  label: fb != null
                      ? (_last ? 'Lihat hasil latihan' : 'Pertanyaan berikutnya')
                      : _evaluating
                      ? 'Menilai…'
                      : 'Kirim jawaban',
                  icon: fb != null && _last ? Icons.insights_rounded : Icons.arrow_forward_rounded,
                  onPressed: disabled ? null : (fb != null ? _next : _submit),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _typeInput(String demo) => [
    TextField(
      controller: _answer,
      minLines: 6,
      maxLines: 14,
      textCapitalization: TextCapitalization.sentences,
      style: CareerText.body.copyWith(fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Tulis jawabanmu di sini…',
        hintStyle: CareerText.muted,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CareerColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CareerColors.teal, width: 2),
        ),
      ),
    ),
    const SizedBox(height: 4),
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(_words < 3 ? '$_words kata · minimal 3 kata' : '$_words kata', style: CareerText.small),
        ),
        if (demo.isNotEmpty) TextButton(onPressed: () => _answer.text = demo, child: const Text('Isi contoh (demo)')),
      ],
    ),
  ];

  List<Widget> _voiceInput() => [
    Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _listening ? CareerColors.teal : CareerColors.line, width: _listening ? 2 : 1),
      ),
      child: Column(
        children: [
          if (backend == Backend.mock) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: CareerPill('Simulasi', icon: Icons.science_outlined, background: CareerColors.background),
            ),
            const SizedBox(height: 8),
          ],
          ExcludeSemantics(
            child: SizedBox(
              height: 52,
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
                            color: _listening ? CareerColors.teal : CareerColors.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox.square(
            dimension: 80,
            child: FilledButton(
              onPressed: _toggleMic,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: _listening ? CareerColors.amber : CareerColors.teal,
              ),
              child: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                size: 34,
                semanticLabel: _listening ? 'Berhenti merekam' : 'Mulai merekam',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _listening
                ? 'Mendengarkan… ketuk untuk berhenti'
                : _answer.text.isNotEmpty
                ? 'Rekaman selesai. Ketuk untuk merekam ulang.'
                : 'Ketuk mikrofon, lalu jawab dengan suara',
            textAlign: TextAlign.center,
            style: CareerText.label,
          ),
        ],
      ),
    ),
    if (!_listening && _answer.text.isNotEmpty) ...[
      const SizedBox(height: 18),
      const Text('Transkrip', style: CareerText.label),
      const SizedBox(height: 4),
      const Text('Periksa dan perbaiki sebelum dikirim.', style: CareerText.small),
      const SizedBox(height: 10),
      TextField(
        controller: _answer,
        minLines: 4,
        maxLines: 10,
        style: CareerText.body.copyWith(fontSize: 15),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: CareerColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: CareerColors.teal, width: 2),
          ),
        ),
      ),
    ],
  ];
}

/// Five segments: answered (teal), current (navy), upcoming (line).
class _SegmentProgress extends StatelessWidget {
  const _SegmentProgress({required this.current, required this.done});
  final int current, done;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$done dari 5 pertanyaan dinilai',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: i < done
                      ? CareerColors.teal
                      : i == current
                      ? CareerColors.navy
                      : CareerColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Collapsible STAR reminder, closed by default so the question stays in focus.
class _StarHelp extends StatelessWidget {
  const _StarHelp();

  static const _steps = [
    ('S', 'Situasi', 'Konteks singkat: di mana dan kapan.'),
    ('T', 'Tugas', 'Tanggung jawab atau masalah yang kamu hadapi.'),
    ('A', 'Aksi', 'Langkah yang kamu ambil sendiri.'),
    ('R', 'Hasil', 'Dampaknya, sebaiknya dengan angka.'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: CareerColors.amberLight, borderRadius: BorderRadius.circular(16)),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: CareerColors.amber,
        collapsedIconColor: CareerColors.amber,
        leading: const Icon(Icons.lightbulb_outline_rounded, color: CareerColors.amber),
        title: Text('Bantuan: pola STAR', style: CareerText.label.copyWith(color: CareerColors.amber)),
        children: [
          for (final (letter, name, hint) in _steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(letter, style: CareerText.label.copyWith(color: CareerColors.amber)),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '$name — ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        children: [
                          TextSpan(
                            text: hint,
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                      style: CareerText.body,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Evaluating extends StatelessWidget {
  const _Evaluating();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Menilai jawabanmu…', style: CareerText.cardTitle),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          builder: (_, v, _) => Bar(value: v, color: CareerColors.teal, track: CareerColors.mint, height: 6),
        ),
        const SizedBox(height: 12),
        const Text('Dicocokkan dengan rubrik 4 aspek: relevansi, STAR, kejelasan, bukti konkret.', style: CareerText.small),
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
  Widget build(BuildContext context) {
    final good = fb.total >= 75;
    final color = good ? CareerColors.teal : CareerColors.amber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: good ? CareerColors.mint : CareerColors.amberLight, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('UMPAN BALIK', style: CareerText.eyebrow.copyWith(color: color)),
                  if (fb.offline) Text('· dinilai offline karena AI tidak tersedia', style: CareerText.small.copyWith(color: color)),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text('${fb.total}', style: CareerText.heading.copyWith(fontSize: 40, color: color)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('/ 100 untuk jawaban ini', style: CareerText.muted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final (name, v) in fb.aspects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RubricRow(name: name, value: v, track: Colors.white),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InsightTile(positive: true, title: 'Yang sudah baik', body: fb.good),
        const SizedBox(height: 10),
        InsightTile(positive: false, title: 'Coba tingkatkan', body: fb.improve),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onToggleEx,
            iconAlignment: IconAlignment.end,
            icon: Icon(showEx ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
            label: Text(showEx ? 'Sembunyikan contoh jawaban' : 'Lihat contoh jawaban yang lebih baik'),
          ),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: showEx
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CareerColors.line),
                  ),
                  child: Text(better, style: CareerText.body.copyWith(height: 1.65)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
