import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/backend.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/providers.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Masuk / Daftar. The form scrolls, so it stays usable with the keyboard open.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _daftar = false;
  bool _showPw = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Map<String, String> _errs = {};

  /// Firebase builds: what is in progress (`email` or `google`) and an error that belongs to no single field.
  String? _busy;
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool daftar) => setState(() {
    _daftar = daftar;
    _errs = {};
    _formError = null;
  });

  /// Clears a field's error as soon as the user edits it.
  void _clear(String key) {
    if (_errs.containsKey(key)) setState(() => _errs = {..._errs}..remove(key));
  }

  void _submit() {
    if (_busy != null) return;
    final er = <String, String>{};
    if (_daftar && _name.text.trim().isEmpty) er['name'] = 'Nama wajib diisi.';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text.trim())) er['email'] = 'Masukkan email yang valid, mis. nama@email.com.';
    if (_password.text.length < 8) er['password'] = 'Kata sandi minimal 8 karakter.';
    setState(() {
      _errs = er;
      _formError = null;
    });
    if (er.isNotEmpty) return;
    TextInput.finishAutofillContext();
    ref.read(appProvider.notifier).setSignupName(_daftar ? _name.text : '');
    if (backend == Backend.mock) {
      context.go(Routes.create);
      return;
    }
    final auth = ref.read(authRepositoryProvider);
    _run(
      'email',
      () => _daftar
          ? auth.register(name: _name.text, email: _email.text, password: _password.text)
          : auth.signIn(email: _email.text, password: _password.text),
    );
  }

  /// Signs in on Firebase builds. On success the router moves on by itself once the user's data is loaded, so the
  /// button keeps its progress state until then.
  Future<void> _run(String what, Future<Object?> Function() action) async {
    setState(() {
      _busy = what;
      _formError = null;
    });
    try {
      final result = await action();
      if (result == false && mounted) setState(() => _busy = null); // Google account picker closed.
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        if (e.field != null) {
          _errs = {..._errs, e.field!: e.message};
        } else {
          _formError = e.message;
        }
      });
    }
  }

  void _google() {
    if (_busy != null) return;
    if (backend == Backend.mock) {
      context.go(Routes.create);
      return;
    }
    _run('google', ref.read(authRepositoryProvider).signInWithGoogle);
  }

  Future<void> _forgotPassword() async {
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text.trim())) {
      setState(() => _errs = {..._errs, 'email': 'Tulis email akunmu dulu, lalu ketuk Lupa kata sandi.'});
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) showToast(context, 'Tautan atur ulang kata sandi dikirim ke ${_email.text.trim()}.');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _formError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => CareerTheme(
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 36),
              child: IntrinsicHeight(
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          KarirInMark(size: 36),
                          SizedBox(width: 10),
                          Text.rich(
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
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.8,
                              color: CareerColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(_daftar ? 'Mulai perjalanan\nkariermu.' : 'Selamat datang\nkembali.', style: CareerText.heading),
                      const SizedBox(height: 8),
                      Text(
                        _daftar ? 'Gratis. Profilmu siap dalam hitungan menit.' : 'Masuk untuk melanjutkan rencana kariermu.',
                        style: CareerText.muted,
                      ),
                      const SizedBox(height: 24),
                      _ModeSwitch(daftar: _daftar, onChanged: _setMode),
                      const SizedBox(height: 24),
                      if (_daftar) ...[
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onChanged: (_) => _clear('name'),
                          style: CareerText.body.copyWith(fontSize: 16),
                          decoration: careerInput(label: 'Nama lengkap', hint: 'Nama sesuai KTP', error: _errs['name']),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => _clear('email'),
                        style: CareerText.body.copyWith(fontSize: 16),
                        decoration: careerInput(label: 'Email', hint: 'nama@email.com', error: _errs['email']),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: !_showPw,
                        textInputAction: TextInputAction.done,
                        autofillHints: [_daftar ? AutofillHints.newPassword : AutofillHints.password],
                        onChanged: (_) => _clear('password'),
                        onSubmitted: (_) => _submit(),
                        style: CareerText.body.copyWith(fontSize: 16),
                        decoration: careerInput(
                          label: 'Kata sandi',
                          error: _errs['password'],
                          helper: _daftar ? 'Minimal 8 karakter.' : null,
                          suffix: IconButton(
                            tooltip: _showPw ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi',
                            onPressed: () => setState(() => _showPw = !_showPw),
                            icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: CareerColors.muted),
                          ),
                        ),
                      ),
                      if (!_daftar)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _busy == null ? _forgotPassword : null, child: const Text('Lupa kata sandi?')),
                        )
                      else
                        const SizedBox(height: 12),
                      if (_formError != null) ...[
                        Text(_formError!, style: CareerText.small.copyWith(color: CareerColors.error)),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      CareerButton(
                        label: _busy == 'email'
                            ? 'Memproses…'
                            : _daftar
                            ? 'Buat akun'
                            : 'Masuk',
                        onPressed: _busy == null ? _submit : null,
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('atau', style: CareerText.small),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _busy == null ? _google : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: CareerColors.ink,
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: CareerColors.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: CareerText.label,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: CareerColors.background,
                                shape: BoxShape.circle,
                                border: Border.all(color: CareerColors.line),
                              ),
                              child: const Text(
                                'G',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CareerColors.ink),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(child: Text(_busy == 'google' ? 'Menghubungkan…' : 'Lanjutkan dengan Google')),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      const Text(
                        'Dengan melanjutkan, kamu menyetujui Syarat Layanan dan Kebijakan Privasi KarirIn.'
                        '${backend == Backend.mock ? ' Pada demo ini, akun belum tersambung ke server.' : ''}',
                        style: CareerText.small,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Two-option switch: Masuk / Daftar.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.daftar, required this.onChanged});
  final bool daftar;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final selected = daftar == value;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: CareerText.label,
            ),
            child: Text(label),
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
      child: Row(children: [option('Masuk', false), const SizedBox(width: 4), option('Daftar', true)]),
    );
  }
}
