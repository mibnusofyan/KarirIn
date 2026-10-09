import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Profil & Pengaturan, including data deletion (UU No. 27/2022).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: KColors.error),
        title: const Text('Hapus akun?'),
        content: const Text('Akun, profil, CV, skor, dan riwayat lamaranmu akan dihapus permanen. Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(appProvider.notifier).deleteAccount();
    context.go(Routes.auth);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    final p = st.profile;
    final good = st.ranked.where((s) => s.result.category == MatchCategory.high).length;

    Widget section(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(t, style: KText.sectionLabel),
    );
    Widget tile(IconData ic, String title, {String? sub, VoidCallback? onTap, Widget? trailing, Color? color}) => ListTile(
      minTileHeight: sub == null ? 56 : 72,
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 24, 0),
      leading: Icon(ic, color: color ?? KColors.onSurfaceVariant),
      title: Text(
        title,
        style: KText.bodyLarge.copyWith(color: color, fontWeight: color != null ? FontWeight.w500 : null),
      ),
      subtitle: sub == null ? null : Text(sub, style: KText.bodyMediumVariant),
      trailing: trailing,
      onTap: onTap,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: KColors.primary,
                    child: Text(
                      p.initials,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: KText.titleLarge),
                        Text('${p.level.label} ${p.major} · ${p.city}', style: KText.bodyMediumVariant),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            StatsRow(stats: [('${p.skills.length}', 'keterampilan'), ('$good', 'lowongan Sangat Cocok')]),
            const SizedBox(height: 16),
            tile(
              Icons.person_outline_rounded,
              'Edit profil & keterampilan',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('${Routes.confirm}?edit=1'),
            ),
            tile(
              Icons.tune_rounded,
              'Preferensi kerja',
              sub: '${p.city} · ${p.modes.map((m) => m.label).join(', ')}',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('${Routes.confirm}?edit=1'),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Divider()),
            section('Notifikasi'),
            tile(
              Icons.work_outline_rounded,
              'Lowongan baru yang cocok',
              trailing: Switch(value: st.notifyNewJobs, onChanged: (_) => n.toggleNotifyNewJobs()),
              onTap: n.toggleNotifyNewJobs,
            ),
            tile(
              Icons.event_note_outlined,
              'Pengingat tindak lanjut',
              trailing: Switch(value: st.notifyReminders, onChanged: (_) => n.toggleNotifyReminders()),
              onTap: n.toggleNotifyReminders,
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Divider()),
            section('Privasi & data'),
            tile(
              Icons.description_outlined,
              'Hapus berkas CV',
              onTap: () => showToast(context, 'Berkas CV dihapus. Profilmu tetap tersimpan.'),
            ),
            tile(Icons.logout_rounded, 'Keluar', onTap: () => context.go(Routes.auth)),
            tile(Icons.delete_outline_rounded, 'Hapus akun', color: KColors.error, onTap: () => _confirmDelete(context, ref)),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Text('Data diproses sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.', style: KText.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
