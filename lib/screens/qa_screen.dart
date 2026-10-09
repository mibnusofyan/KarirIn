import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// "Profil tanpa CV": 8 short questions for users without a CV (persona Bayu).
class QaScreen extends ConsumerStatefulWidget {
  const QaScreen({super.key});

  @override
  ConsumerState<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends ConsumerState<QaScreen> {
  int _i = 0;
  final Map<int, Object> _ans = {};
  final _text = TextEditingController();

  QaQuestion get _q => qaQuestions[_i];

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

  bool get _answered => switch (_q.kind) {
    QuestionKind.multi => ((_ans[_i] as List<String>?) ?? const []).isNotEmpty,
    _ => ((_ans[_i] as String?) ?? '').trim().isNotEmpty,
  };

  void _toggle(String o) => setState(() {
    if (_q.kind == QuestionKind.multi) {
      final cur = List.of((_ans[_i] as List<String>?) ?? const <String>[]);
      cur.contains(o) ? cur.remove(o) : cur.add(o);
      _ans[_i] = cur;
    } else {
      _ans[_i] = o;
    }
  });

  bool _selected(String o) => _q.kind == QuestionKind.multi ? ((_ans[_i] as List<String>?) ?? const []).contains(o) : _ans[_i] == o;

  void _next() {
    if (_i < qaQuestions.length - 1) {
      _goTo(_i + 1);
    } else {
      ref.read(appProvider.notifier).useQaProfile(_ans);
      context.go('${Routes.processing}?kind=qa');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return Scaffold(
      appBar: topBar(
        title: 'Profil tanpa CV',
        caption: '${_i + 1} dari 8',
        onBack: () => _i > 0 ? _goTo(_i - 1) : context.go(Routes.create),
      ),
      body: Column(
        children: [
          StepProgress((_i + 1) / 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.title, style: KText.headlineSmall),
                  const SizedBox(height: 6),
                  Text(q.help, style: KText.bodyMediumVariant),
                  const SizedBox(height: 20),
                  if (q.options.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in q.options)
                          FilterChip(
                            label: Text(o),
                            selected: _selected(o),
                            onSelected: (_) => _toggle(o),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                      ],
                    ),
                  if (q.kind == QuestionKind.text || q.kind == QuestionKind.area)
                    TextField(
                      key: ValueKey(_i),
                      controller: _text,
                      onChanged: (v) => setState(() => _ans[_i] = v),
                      minLines: q.kind == QuestionKind.area ? 6 : 1,
                      maxLines: q.kind == QuestionKind.area ? 10 : 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: q.kind == QuestionKind.area ? 'Ceritamu' : 'Jurusan',
                        hintText: q.hint,
                        alignLabelWithHint: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(label: _i == 7 ? 'Susun profil saya' : 'Lanjut', onPressed: _answered ? _next : null),
          ),
        ],
      ),
    );
  }
}
