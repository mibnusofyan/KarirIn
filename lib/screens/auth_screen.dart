import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final er = <String, String>{};
    if (_daftar && _name.text.trim().isEmpty) er['name'] = 'Nama wajib diisi.';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text)) er['email'] = 'Masukkan email yang valid.';
    if (_password.text.length < 8) er['password'] = 'Kata sandi minimal 8 karakter.';
    setState(() => _errs = er);
    if (er.isEmpty) {
      ref.read(appProvider.notifier).setSignupName(_daftar ? _name.text : '');
      context.go(Routes.create);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 48),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: KarirInMark(size: 56)),
                  const SizedBox(height: 24),
                  Text(_daftar ? 'Buat akun KarirIn' : 'Masuk ke KarirIn', style: KText.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    _daftar ? 'Gratis. Profilmu siap dalam hitungan menit.' : 'Lanjutkan perjalanan kariermu.',
                    style: KText.bodyMediumVariant,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Masuk')),
                      ButtonSegment(value: true, label: Text('Daftar')),
                    ],
                    selected: {_daftar},
                    onSelectionChanged: (s) => setState(() {
                      _daftar = s.first;
                      _errs = {};
                    }),
                  ),
                  const SizedBox(height: 24),
                  if (_daftar) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(labelText: 'Nama lengkap', hintText: 'Nama sesuai KTP', errorText: _errs['name']),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: 'Email', hintText: 'nama@email.com', errorText: _errs['email']),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: !_showPw,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Kata sandi',
                      hintText: 'Minimal 8 karakter',
                      errorText: _errs['password'],
                      suffixIcon: IconButton(
                        tooltip: 'Tampilkan kata sandi',
                        onPressed: () => setState(() => _showPw = !_showPw),
                        icon: Icon(_showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(label: _daftar ? 'Daftar' : 'Masuk', onPressed: _submit),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go(Routes.create),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: KColors.outlineVariant),
                          ),
                          child: const Text(
                            'G',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KColors.onSurface),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Lanjutkan dengan Google'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  const Text('Dengan melanjutkan, kamu menyetujui Syarat Layanan dan Kebijakan Privasi KarirIn.', style: KText.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
