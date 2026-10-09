import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// "Periksa profil": the user reviews and corrects AI extraction before scores are computed.
class ConfirmProfileScreen extends ConsumerStatefulWidget {
  const ConfirmProfileScreen({super.key, this.editing = false});

  /// Opened from Profil → "Edit profil & keterampilan" instead of onboarding.
  final bool editing;

  @override
  ConsumerState<ConfirmProfileScreen> createState() => _ConfirmProfileScreenState();
}

class _ConfirmProfileScreenState extends ConsumerState<ConfirmProfileScreen> {
  final _newSkill = TextEditingController();

  @override
  void dispose() {
    _newSkill.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(appProvider.notifier).addSkill(_newSkill.text);
    _newSkill.clear();
  }

  void _done() => widget.editing ? context.back(Routes.profile) : context.go(Routes.home);

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(appProvider).profile;
    final n = ref.read(appProvider.notifier);
    final source = switch (p.source) {
      ProfileSource.qa => 'jawaban tanya-jawabmu',
      ProfileSource.cvPhoto => 'foto CV-mu',
      ProfileSource.cvPdf => 'CV-mu',
    };
    return Scaffold(
      appBar: topBar(
        title: widget.editing ? 'Edit profil' : 'Periksa profil',
        caption: widget.editing ? null : 'Langkah 2 dari 2',
        onBack: () => widget.editing ? context.back(Routes.profile) : context.go(Routes.create),
      ),
      body: Column(
        children: [
          const StepProgress(1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InfoBanner(
                  icon: Icons.auto_awesome_rounded,
                  child: Text('AI mengisi data ini dari $source. Ubah jika ada yang keliru sebelum skor dihitung.'),
                ),
                const SizedBox(height: 12),
                OutlinedBox(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: KColors.primary,
                        child: Text(
                          p.initials,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: KText.titleMedium),
                            Text('${p.level.label} ${p.major}${p.school == '-' ? '' : ' · ${p.school}'}', style: KText.bodyMediumVariant),
                            Text(p.city, style: KText.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: KColors.onSurfaceVariant),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Keterampilan · ${p.skills.length}', style: KText.sectionLabel),
                          const Text(
                            'Dinormalisasi AI',
                            style: TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500, color: KColors.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in p.skills)
                            InputChip(
                              label: Text(s),
                              onDeleted: () => n.removeSkill(s),
                              deleteIcon: const Icon(Icons.close_rounded, size: 18),
                              deleteButtonTooltipMessage: 'Hapus',
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newSkill,
                              onSubmitted: (_) => _add(),
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Tambah keterampilan',
                                hintText: 'mis. MS Excel',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TonalButton(label: 'Tambah', icon: Icons.add_rounded, height: 48, onPressed: _add),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Ejaan dibakukan otomatis, mis. “MS Excel” → Microsoft Excel.', style: KText.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedBox(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Pengalaman', style: KText.sectionLabel),
                      ),
                      for (final e in p.exps)
                        SizedBox(
                          height: 64,
                          child: Row(
                            children: [
                              IconCircle(switch (e.type) {
                                ExperienceType.organisasi => Icons.groups_rounded,
                                ExperienceType.kerja => Icons.work_rounded,
                                ExperienceType.magang => Icons.badge_rounded,
                              }),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title, style: KText.bodyLarge, overflow: TextOverflow.ellipsis),
                                    Text('${e.org} · ${e.months} bulan', style: KText.bodyMediumVariant),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (p.exps.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Belum ada pengalaman. Banyak lowongan tidak mensyaratkannya.', style: KText.bodyMediumVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mode kerja yang diinginkan', style: KText.sectionLabel),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in WorkMode.values)
                            FilterChip(
                              label: Text(m.label),
                              selected: p.modes.contains(m),
                              onSelected: (_) => n.toggleMode(m),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(label: widget.editing ? 'Simpan perubahan' : 'Simpan & lihat lowongan', onPressed: _done),
          ),
        ],
      ),
    );
  }
}
