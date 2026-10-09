import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CreateProfileScreen extends ConsumerWidget {
  const CreateProfileScreen({super.key});

  Future<void> _askConsent(BuildContext context, WidgetRef ref, ProfileSource source) async {
    final ok = await showKSheet<bool>(context, (_) => _ConsentSheet(photo: source == ProfileSource.cvPhoto));
    if (ok != true || !context.mounted) return;
    ref.read(appProvider.notifier).useCvProfile(source);
    context.go('${Routes.processing}?kind=${source == ProfileSource.cvPhoto ? 'photo' : 'pdf'}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: topBar(title: 'Buat profil', caption: 'Langkah 1 dari 2', onBack: () => context.go(Routes.auth)),
    body: LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StepProgress(.5),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bagaimana kamu ingin membuat profil?', style: KText.headlineSmall),
                      SizedBox(height: 8),
                      Text(
                        'AI menyusun profil dari pilihanmu. Kamu tetap bisa memeriksa dan mengubah hasilnya.',
                        style: KText.bodyMediumVariant,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _Option(
                        icon: Icons.upload_file_rounded,
                        title: 'Unggah CV (PDF)',
                        subtitle: 'Maksimal 5 MB · paling cepat',
                        onTap: () => _askConsent(context, ref, ProfileSource.cvPdf),
                      ),
                      const SizedBox(height: 12),
                      _Option(
                        icon: Icons.photo_camera_rounded,
                        title: 'Foto CV',
                        subtitle: 'Potret CV cetak dengan kamera',
                        onTap: () => _askConsent(context, ref, ProfileSource.cvPhoto),
                      ),
                      const SizedBox(height: 12),
                      _Option(
                        icon: Icons.forum_rounded,
                        title: 'Belum punya CV?',
                        subtitle: 'Jawab 8 pertanyaan singkat · ±3 menit',
                        highlighted: true,
                        onTap: () => context.go(Routes.qa),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_rounded, size: 18, color: KColors.onSurfaceVariant),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'CV hanya diproses setelah kamu memberi izin dan bisa dihapus kapan saja dari Pengaturan.',
                          style: KText.bodySmall,
                        ),
                      ),
                    ],
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

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.subtitle, required this.onTap, this.highlighted = false});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? KColors.onSecondaryContainer : KColors.onSurface;
    return Material(
      color: highlighted ? KColors.secondaryContainer : KColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlighted ? BorderSide.none : const BorderSide(color: KColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: highlighted ? KColors.secondary : KColors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: highlighted ? Colors.white : KColors.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KText.titleMedium.copyWith(color: fg)),
                    Text(subtitle, style: KText.bodyMedium.copyWith(color: highlighted ? fg : KColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: highlighted ? fg : KColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
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
    Widget point(IconData ic, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ic, size: 20, color: KColors.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(t, style: KText.bodyMediumVariant)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Izinkan KarirIn memproses CV-mu?', style: KText.headlineSmall),
        const SizedBox(height: 16),
        point(Icons.check_circle_outline_rounded, 'Hanya dipakai untuk menyusun profil dan menghitung kecocokan.'),
        point(Icons.lock_outline_rounded, 'Disimpan terenkripsi dan hanya bisa diakses olehmu.'),
        point(Icons.delete_outline_rounded, 'Bisa kamu hapus kapan saja dari Pengaturan.'),
        const SizedBox(height: 4),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _ok = !_ok),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  Checkbox(value: _ok, onChanged: (v) => setState(() => _ok = v ?? false)),
                  const Expanded(
                    child: Text(
                      'Saya setuju data CV diproses sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.',
                      style: KText.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.photo ? 'Setuju & buka kamera' : 'Setuju & pilih berkas PDF',
          onPressed: _ok ? () => Navigator.pop(context, true) : null,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        ),
      ],
    );
  }
}
