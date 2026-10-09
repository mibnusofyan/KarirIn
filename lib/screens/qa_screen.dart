import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';

/// "Profil tanpa CV": 8 short questions for users without a CV (persona Bayu).
class QaScreen extends ConsumerStatefulWidget {
  const QaScreen({super.key});

  @override
  ConsumerState<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends ConsumerState<QaScreen> {
  /// Selecting this clears the other experience options, and vice versa.
  static const _none = 'Belum ada';

  int _i = 0;
  final Map<int, Object> _ans = {};
  final _text = TextEditingController();

  QaQuestion get _q => qaQuestions[_i];
  bool get _last => _i == qaQuestions.length - 1;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    setState(() => _i = i);
    final v = _ans[i];
    _text.text = v is String ? v : '';
  }

  void _back() => _i > 0 ? _goTo(_i - 1) : context.go(Routes.create);

  List<String> get _picked => (_ans[_i] as List<String>?) ?? const [];

  bool get _answered => switch (_q.kind) {
    QuestionKind.multi => _picked.isNotEmpty,
    _ => ((_ans[_i] as String?) ?? '').trim().isNotEmpty,
  };

  bool _selected(String o) => _q.kind == QuestionKind.multi ? _picked.contains(o) : _ans[_i] == o;

  void _toggle(String o) => setState(() {
    if (_q.kind != QuestionKind.multi) {
      _ans[_i] = o;
      return;
    }
    final cur = List.of(_picked);
    if (cur.contains(o)) {
      cur.remove(o);
    } else if (o == _none) {
      cur
        ..clear()
        ..add(o);
    } else {
      cur
        ..remove(_none)
        ..add(o);
    }
    _ans[_i] = cur;
  });

  void _next() {
    if (!_last) {
      _goTo(_i + 1);
      return;
    }
    ref.read(appProvider.notifier).useQaProfile(_ans);
    context.go('${Routes.processing}?kind=qa');
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final total = qaQuestions.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CareerTheme(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(tooltip: 'Kembali', icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: _back),
            title: const Text('Profil tanpa CV'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(28),
              child: CareerStepBar(current: _i + 1, total: total, caption: '${_i + 1} dari $total'),
            ),
          ),
          body: ListView(
            key: ValueKey(_i),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Text('PERTANYAAN ${_i + 1}', style: CareerText.eyebrow),
              const SizedBox(height: 8),
              Text(q.title, style: CareerText.heading.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text(q.help, style: CareerText.muted),
              const SizedBox(height: 22),
              if (q.options.isNotEmpty) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final o in q.options)
                      _Choice(label: o, selected: _selected(o), multi: q.kind == QuestionKind.multi, onTap: () => _toggle(o)),
                  ],
                ),
                if (q.kind == QuestionKind.multi && _picked.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${_picked.length} dipilih',
                    style: CareerText.small.copyWith(color: CareerColors.teal, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
              if (q.kind == QuestionKind.text || q.kind == QuestionKind.area)
                TextField(
                  controller: _text,
                  onChanged: (v) => setState(() => _ans[_i] = v),
                  minLines: q.kind == QuestionKind.area ? 5 : 1,
                  maxLines: q.kind == QuestionKind.area ? 10 : 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: q.kind == QuestionKind.text ? TextInputAction.next : TextInputAction.newline,
                  onSubmitted: q.kind == QuestionKind.text && _answered ? (_) => _next() : null,
                  style: CareerText.body.copyWith(fontSize: 16),
                  decoration: careerInput(label: q.kind == QuestionKind.area ? 'Ceritamu' : 'Jurusan', hint: q.hint),
                ),
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
                    if (_i > 0) ...[
                      OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 52),
                          side: const BorderSide(color: CareerColors.line),
                          foregroundColor: CareerColors.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: CareerText.label,
                        ),
                        child: const Text('Kembali'),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: CareerButton(
                        label: _last ? 'Susun profil saya' : 'Lanjut',
                        icon: _last ? Icons.auto_awesome_outlined : Icons.arrow_forward_rounded,
                        onPressed: _answered ? _next : null,
                      ),
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

/// Selectable pill; a check (multi) or a dot (single) marks the choice, not colour alone.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.multi, required this.onTap});
  final String label;
  final bool selected, multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? CareerColors.mint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? CareerColors.teal : CareerColors.line, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? (multi ? Icons.check_box_rounded : Icons.radio_button_checked_rounded)
                      : (multi ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked_rounded),
                  size: 20,
                  color: selected ? CareerColors.teal : CareerColors.muted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: CareerText.label.copyWith(color: selected ? CareerColors.teal : CareerColors.ink, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
