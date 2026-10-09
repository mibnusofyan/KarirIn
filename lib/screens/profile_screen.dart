import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../logic/match_score.dart';
import '../data/repositories/auth_repository.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
import '../widgets/common.dart';

/// Profil & Pengaturan: identity and skills first, account settings grouped below (UU No. 27/2022).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static Future<bool> _confirm(BuildContext context, {required String title, required String body, required String action}) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => CareerTheme(
          child: AlertDialog(
            backgroundColor: Colors.white,
            icon: const Icon(Icons.warning_amber_rounded, color: CareerColors.error),
            title: Text(title, style: CareerText.title),
            content: Text(body, style: CareerText.body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: CareerColors.error),
                child: Text(action),
              ),
            ],
          ),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appProvider);
    final n = ref.read(appProvider.notifier);
    final p = st.profile;
    final good = st.ranked.where((s) => s.result.category == MatchCategory.high).length;
    final active = st.applications.where((a) => a.status.isActive).length;
    void edit() => context.push('${Routes.confirm}?edit=1');

    Future<void> deleteCv() async {
      final ok = await _confirm(
        context,
        title: 'Hapus berkas CV?',
        body: 'Berkas CV dihapus dari KarirIn. Profil, keterampilan, dan skor yang sudah kamu periksa tetap tersimpan.',
        action: 'Hapus berkas',
      );
      if (!ok || !context.mounted) return;
      n.deleteCv();
      showToast(context, 'Berkas CV dihapus. Profilmu tetap tersimpan.');
    }

    Future<void> deleteAccount() async {
      final ok = await _confirm(
        context,
        title: 'Hapus akun?',
        body: 'Akun, profil, CV, skor, dan riwayat lamaranmu akan dihapus permanen. Tindakan ini tidak bisa dibatalkan.',
        action: 'Hapus permanen',
      );
      if (!ok || !context.mounted) return;
      try {
        await n.deleteAccount();
      } on AuthFailure catch (e) {
        if (context.mounted) showToast(context, e.message);
        return;
      }
      if (context.mounted) context.go(Routes.auth);
    }

    final cvSubtitle = st.hasCv
        ? 'Profil dan skor tetap tersimpan'
        : p.source == ProfileSource.qa
        ? 'Tidak ada CV; profil dari tanya-jawab'
        : 'Berkas CV sudah dihapus';

    return CareerTheme(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            key: const PageStorageKey('career-profile'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Text('PROFIL', style: CareerText.eyebrow),
              const SizedBox(height: 10),
              _IdentityHero(profile: p, onEdit: edit),
              const SizedBox(height: 12),
              _Stats(stats: [('${p.skills.length}', 'Keterampilan'), ('$good', 'Sangat Cocok'), ('$active', 'Lamaran aktif')]),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Text('Keterampilan', style: CareerText.title)),
                  TextButton(
                    onPressed: edit,
                    child: const Text('Kelola', semanticsLabel: 'Kelola keterampilan'),
                  ),
                ],
              ),
              if (st.learned.isNotEmpty)
                Text('${st.learned.length} dikuasai lewat Rencana Belajar', style: CareerText.small.copyWith(color: CareerColors.teal)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in p.skills)
                    st.learned.contains(s)
                        ? CareerPill(s, icon: Icons.school_outlined, color: CareerColors.teal, background: CareerColors.mint)
                        : CareerPill(s, background: Colors.white),
                ],
              ),
              const SizedBox(height: 28),
              const Text('Preferensi kerja', style: CareerText.title),
              const SizedBox(height: 10),
              _Group(
                children: [
                  _Row(
                    icon: Icons.tune_rounded,
                    title: '${p.city} · ${p.modes.map((m) => m.label).join(', ')}',
                    subtitle: 'Lokasi dan mode kerja menentukan 10% Match Score',
                    onTap: edit,
                    chevron: true,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Pengaturan', style: CareerText.title),
              const SizedBox(height: 14),
              const Text('NOTIFIKASI', style: CareerText.eyebrow),
              const SizedBox(height: 8),
              _Group(
                children: [
                  _Row(
                    icon: Icons.work_outline_rounded,
                    title: 'Lowongan baru yang cocok',
                    onTap: n.toggleNotifyNewJobs,
                    trailing: _toggle(st.notifyNewJobs, n.toggleNotifyNewJobs),
                  ),
                  const Divider(),
                  _Row(
                    icon: Icons.event_note_outlined,
                    title: 'Pengingat tindak lanjut',
                    onTap: n.toggleNotifyReminders,
                    trailing: _toggle(st.notifyReminders, n.toggleNotifyReminders),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('PRIVASI & DATA', style: CareerText.eyebrow),
              const SizedBox(height: 8),
              _Group(
                children: [
                  _Row(icon: Icons.description_outlined, title: 'Hapus berkas CV', subtitle: cvSubtitle, onTap: st.hasCv ? deleteCv : null),
                  const Divider(),
                  _Row(
                    icon: Icons.logout_rounded,
                    title: 'Keluar',
                    onTap: () async {
                      await n.signOut();
                      if (context.mounted) context.go(Routes.auth);
                    },
                  ),
                  const Divider(),
                  _Row(icon: Icons.delete_outline_rounded, title: 'Hapus akun', color: CareerColors.error, onTap: deleteAccount),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Data diproses sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi. Pada demo ini, notifikasi belum dikirim ke perangkat.',
                style: CareerText.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(bool value, VoidCallback onToggle) =>
      Switch(value: value, activeTrackColor: CareerColors.teal, onChanged: (_) => onToggle());
}

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.profile, required this.onEdit});
  final Profile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC4D6E7);
    final p = profile;
    final source = switch (p.source) {
      ProfileSource.qa => 'Dari tanya-jawab',
      ProfileSource.cvPhoto => 'Dari foto CV',
      ProfileSource.cvPdf => 'Dari CV',
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CareerColors.navy, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: CareerColors.yellow,
                child: Text(
                  p.initials,
                  textScaler: TextScaler.noScaling,
                  style: CareerText.title.copyWith(fontSize: 20, color: CareerColors.navy),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: CareerText.title.copyWith(color: Colors.white, fontSize: 22)),
                    const SizedBox(height: 4),
                    Text('${p.level.label} ${p.major}', style: CareerText.body.copyWith(color: const Color(0xFFE3F0F8))),
                    Text(p.city, style: CareerText.small.copyWith(color: light)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CareerPill(source, icon: Icons.auto_awesome_outlined, color: CareerColors.navy, background: const Color(0xFFE8ECF6)),
              OutlinedButton.icon(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  minimumSize: const Size(48, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: CareerText.label,
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit profil'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: CareerColors.line),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (final (i, (value, label)) in stats.indexed) ...[
            if (i > 0) const VerticalDivider(width: 1, color: CareerColors.line),
            Expanded(
              child: Semantics(
                container: true,
                label: '$label $value',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(value, style: CareerText.title.copyWith(color: CareerColors.navy)),
                      Text(label, style: CareerText.small, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: CareerColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: Column(children: children),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.color, this.chevron = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = disabled ? CareerColors.muted : (color ?? CareerColors.ink);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Icon(icon, color: color ?? CareerColors.muted, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CareerText.label.copyWith(color: fg)),
                    if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: CareerText.small)],
                  ],
                ),
              ),
              ?trailing,
              if (chevron) const Icon(Icons.chevron_right_rounded, color: CareerColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
