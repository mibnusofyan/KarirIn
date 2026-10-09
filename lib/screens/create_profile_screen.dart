import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';

/// Buat profil: one recommended path (CV PDF) with the alternatives in plain sight.
class CreateProfileScreen extends ConsumerWidget {
  const CreateProfileScreen({super.key});

  Future<void> _askConsent(BuildContext context, WidgetRef ref, ProfileSource source) async {
    final ok = await showCareerSheet<bool>(context, (_) => _ConsentSheet(photo: source == ProfileSource.cvPhoto));
    if (ok != true || !context.mounted) return;
    ref.read(appProvider.notifier).useCvProfile(source);
    context.go('${Routes.processing}?kind=${source == ProfileSource.cvPhoto ? 'photo' : 'pdf'}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => CareerTheme(
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => context.go(Routes.auth),
        ),
        title: const Text('Buat profil'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: CareerStepBar(current: 1, total: 2, caption: 'Langkah 1 dari 2'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text('Bagaimana kamu ingin memulai?', style: CareerText.heading),
          const SizedBox(height: 8),
          const Text(
            'AI menyusun profil dari pilihanmu. Kamu tetap memeriksa dan mengubah hasilnya sebelum skor dihitung.',
            style: CareerText.muted,
          ),
          const SizedBox(height: 22),
          _Recommended(onTap: () => _askConsent(context, ref, ProfileSource.cvPdf)),
          const SizedBox(height: 28),
          const Text('Cara lain', style: CareerText.title),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CareerColors.line),
            ),
            child: Column(
              children: [
                _Alternative(
                  icon: Icons.photo_camera_outlined,
                  title: 'Foto CV',
                  subtitle: 'Potret CV cetak dengan kamera',
                  meta: '±1 menit',
                  onTap: () => _askConsent(context, ref, ProfileSource.cvPhoto),
                ),
                const Divider(),
                _Alternative(
                  icon: Icons.forum_outlined,
                  title: 'Belum punya CV?',
                  subtitle: 'Jawab 8 pertanyaan singkat, AI menyusun profilmu',
                  meta: '±3 menit',
                  onTap: () => context.go(Routes.qa),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const CareerMeta(
            Icons.lock_outline_rounded,
            'CV hanya diproses setelah kamu memberi izin dan bisa dihapus kapan saja dari Pengaturan.',
            style: CareerText.small,
          ),
        ],
      ),
    ),
  );
}

class _Recommended extends StatelessWidget {
  const _Recommended({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC4D6E7);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CareerColors.navy, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.upload_file_outlined, color: Colors.white, size: 24),
              ),
              const Spacer(),
              const CareerPill('Disarankan', icon: Icons.star_outline_rounded, color: CareerColors.navy, background: CareerColors.yellow),
            ],
          ),
          const SizedBox(height: 16),
          Text('Unggah CV (PDF)', style: CareerText.title.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Paling cepat dan paling lengkap: skill, pendidikan, dan pengalaman langsung terbaca.',
            style: CareerText.body.copyWith(color: const Color(0xFFE3F0F8)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final t in ['±15 detik', 'Maks. 5 MB']) Text('• $t', style: CareerText.small.copyWith(color: light)),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(backgroundColor: CareerColors.teal),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text('Pilih berkas PDF', textAlign: TextAlign.center)),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Alternative extends StatelessWidget {
  const _Alternative({required this.icon, required this.title, required this.subtitle, required this.meta, required this.onTap});
  final IconData icon;
  final String title, subtitle, meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: CareerColors.teal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CareerText.label),
                const SizedBox(height: 2),
                Text(subtitle, style: CareerText.small),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: CareerText.small.copyWith(color: CareerColors.teal, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: CareerColors.muted, size: 20),
        ],
      ),
    ),
  );
}

/// Explicit consent before the CV is processed by AI (UU No. 27/2022, proposal 3.1.4).
class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet({required this.photo});
  final bool photo;

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _ok = false;

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: CareerColors.teal),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: CareerText.body)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareerSheetHeader('Izinkan KarirIn memproses CV-mu?'),
        const SizedBox(height: 8),
        point(Icons.check_circle_outline_rounded, 'Hanya dipakai untuk menyusun profil dan menghitung kecocokan.'),
        point(Icons.lock_outline_rounded, 'Disimpan terenkripsi dan hanya bisa diakses olehmu.'),
        point(Icons.delete_outline_rounded, 'Bisa kamu hapus kapan saja dari Pengaturan.'),
        const SizedBox(height: 4),
        Semantics(
          checked: _ok,
          child: Material(
            color: _ok ? CareerColors.mint : CareerColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _ok ? CareerColors.teal : CareerColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _ok = !_ok),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
                child: Row(
                  children: [
                    Checkbox(value: _ok, activeColor: CareerColors.teal, onChanged: (v) => setState(() => _ok = v ?? false)),
                    const Expanded(
                      child: Text(
                        'Saya setuju data CV diproses sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.',
                        style: CareerText.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Demo: berkas tidak benar-benar diunggah. KarirIn memakai CV contoh (Rani) untuk menyusun profil.',
          style: CareerText.small,
        ),
        const SizedBox(height: 18),
        CareerButton(
          label: widget.photo ? 'Setuju & buka kamera' : 'Setuju & pilih berkas',
          icon: widget.photo ? Icons.photo_camera_outlined : Icons.upload_file_outlined,
          onPressed: _ok ? () => Navigator.pop(context, true) : null,
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
      ],
    );
  }
}
