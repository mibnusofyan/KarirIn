import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../logic/match_score.dart';
import '../router.dart';
import '../state/app_state.dart';
import '../theme/career_theme.dart';
import '../widgets/career_widgets.dart';
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
  String? _skillNote;

  @override
  void dispose() {
    _newSkill.dispose();
    super.dispose();
  }

  void _add() {
    final raw = _newSkill.text.trim();
    if (raw.isEmpty) return;
    final normalized = normalizeSkill(raw, ref.read(appProvider).skills);
    final added = ref.read(appProvider.notifier).addSkill(raw);
    setState(() {
      _skillNote = !added
          ? '$normalized sudah ada di profilmu.'
          : normalized != raw
          ? '“$raw” dibakukan menjadi $normalized.'
          : null;
    });
    _newSkill.clear();
  }

  void _done() {
    if (widget.editing) return context.back(Routes.profile);
    ref.read(appProvider.notifier).confirmProfile();
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(appProvider).profile;
    final n = ref.read(appProvider.notifier);
    final source = switch (p.source) {
      ProfileSource.qa => 'jawaban tanya-jawabmu',
      ProfileSource.cvPhoto => 'foto CV-mu',
      ProfileSource.cvPdf => 'CV-mu',
    };
    final blocker = p.skills.isEmpty
        ? 'Tambahkan minimal satu keterampilan.'
        : p.modes.isEmpty
        ? 'Pilih minimal satu mode kerja.'
        : p.city.trim().isEmpty || p.name.trim().isEmpty
        ? 'Lengkapi nama dan kota lewat tombol Ubah.'
        : null;

    return CareerTheme(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => widget.editing ? context.back(Routes.profile) : context.go(Routes.create),
          ),
          title: Text(widget.editing ? 'Edit profil' : 'Periksa profil'),
          bottom: widget.editing
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(28),
                  child: CareerStepBar(current: 2, total: 2, caption: 'Langkah 2 dari 2'),
                ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            if (!widget.editing) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(16)),
                child: CareerMeta(
                  Icons.auto_awesome_outlined,
                  'AI mengisi data ini dari $source. Periksa dan ubah bila ada yang keliru sebelum skor dihitung.',
                  style: CareerText.body.copyWith(color: CareerColors.teal),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _IdentityCard(
              profile: p,
              onEdit: () => showCareerSheet<void>(context, (_) => _IdentitySheet(profile: p)),
            ),
            const SizedBox(height: 28),
            _Section(
              title: 'Keterampilan',
              trailing: const CareerPill(
                'Dinormalisasi AI',
                icon: Icons.auto_awesome_outlined,
                color: CareerColors.teal,
                background: CareerColors.mint,
              ),
              caption: 'Dipakai untuk menghitung skill wajib dan tambahan. Hapus yang tidak sesuai.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (p.skills.isEmpty)
                    const Text('Belum ada keterampilan.', style: CareerText.muted)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final s in p.skills) _SkillChip(skill: s, onRemove: () => n.removeSkill(s))],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSkill,
                          onSubmitted: (_) => _add(),
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.words,
                          style: CareerText.body.copyWith(fontSize: 16),
                          decoration: careerInput(label: 'Tambah keterampilan', hint: 'mis. MS Excel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: _add,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(56, 56),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Icon(Icons.add_rounded, semanticLabel: 'Tambah keterampilan'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_skillNote ?? 'Ejaan dibakukan otomatis, mis. “MS Excel” → Microsoft Excel.', style: CareerText.small),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _Section(
              title: 'Pengalaman',
              caption: 'Magang dan organisasi dihitung setengah untuk syarat pengalaman.',
              child: p.exps.isEmpty
                  ? const Text('Belum ada pengalaman. Banyak lowongan tidak mensyaratkannya.', style: CareerText.muted)
                  : Column(
                      children: [
                        for (final (i, e) in p.exps.indexed) ...[if (i > 0) const Divider(), _ExperienceRow(exp: e)],
                      ],
                    ),
            ),
            const SizedBox(height: 28),
            _Section(
              title: 'Preferensi kerja',
              caption: 'Lokasi dan mode kerja menentukan 10% skor.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CareerMeta(Icons.location_on_outlined, 'Kota: ${p.city}', style: CareerText.body),
                  const SizedBox(height: 14),
                  const Text('Mode kerja yang kamu terima', style: CareerText.label),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in WorkMode.values) _ModeToggle(mode: m, selected: p.modes.contains(m), onTap: () => n.toggleMode(m)),
                    ],
                  ),
                ],
              ),
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    blocker ?? '${p.skills.length} keterampilan · ${p.exps.length} pengalaman · ${p.modes.map((m) => m.label).join(', ')}',
                    style: CareerText.small.copyWith(
                      color: blocker != null ? CareerColors.error : CareerColors.muted,
                      fontWeight: blocker != null ? FontWeight.w600 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  CareerButton(
                    label: widget.editing ? 'Simpan perubahan' : 'Simpan & lihat lowongan',
                    icon: widget.editing ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    onPressed: blocker == null ? _done : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.caption, required this.child, this.trailing});
  final String title, caption;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: [
          Text(title, style: CareerText.title),
          ?trailing,
        ],
      ),
      const SizedBox(height: 4),
      Text(caption, style: CareerText.small),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CareerColors.line),
        ),
        child: child,
      ),
    ],
  );
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.onEdit});
  final Profile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC4D6E7);
    final p = profile;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
      decoration: BoxDecoration(color: CareerColors.navy, borderRadius: BorderRadius.circular(24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: CareerColors.yellow,
            child: Text(
              p.initials,
              textScaler: TextScaler.noScaling,
              style: CareerText.title.copyWith(fontSize: 18, color: CareerColors.navy),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: CareerText.title.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '${p.level.label} ${p.major}${p.school == '-' ? '' : ' · ${p.school}'}',
                  style: CareerText.body.copyWith(color: const Color(0xFFE3F0F8)),
                ),
                const SizedBox(height: 2),
                Text(p.city, style: CareerText.small.copyWith(color: light)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            style: TextButton.styleFrom(foregroundColor: CareerColors.yellow),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Ubah', semanticsLabel: 'Ubah identitas'),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill, required this.onRemove});
  final String skill;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(
      color: CareerColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: CareerColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(skill, style: CareerText.body.copyWith(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          tooltip: 'Hapus $skill',
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, size: 18, color: CareerColors.muted),
        ),
      ],
    ),
  );
}

class _ExperienceRow extends StatelessWidget {
  const _ExperienceRow({required this.exp});
  final Experience exp;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (exp.type) {
      ExperienceType.organisasi => (Icons.groups_outlined, 'Organisasi'),
      ExperienceType.kerja => (Icons.work_outline_rounded, 'Kerja'),
      ExperienceType.magang => (Icons.badge_outlined, 'Magang'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: CareerColors.mint, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: CareerColors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exp.title, style: CareerText.label),
                const SizedBox(height: 2),
                Text('${exp.org} · ${exp.months} bulan', style: CareerText.small),
                const SizedBox(height: 6),
                CareerPill(label, background: CareerColors.background),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.selected, required this.onTap});
  final WorkMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: mode.label,
    excludeSemantics: true,
    child: TextButton.icon(
      onPressed: onTap,
      icon: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 18),
      label: Text(mode.label),
      style: TextButton.styleFrom(
        foregroundColor: selected ? CareerColors.teal : CareerColors.muted,
        backgroundColor: selected ? CareerColors.mint : Colors.white,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? CareerColors.teal : CareerColors.line),
        ),
        textStyle: CareerText.label,
      ),
    ),
  );
}

/// Edit name, education and city (these feed the education and location components).
class _IdentitySheet extends ConsumerStatefulWidget {
  const _IdentitySheet({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_IdentitySheet> createState() => _IdentitySheetState();
}

class _IdentitySheetState extends ConsumerState<_IdentitySheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _major = TextEditingController(text: widget.profile.major == '-' ? '' : widget.profile.major);
  late final _city = TextEditingController(text: widget.profile.city);
  late EduLevel _level = widget.profile.level;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _major.dispose();
    _city.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Nama wajib diisi.');
      return;
    }
    ref
        .read(appProvider.notifier)
        .updateIdentity(
          name: _name.text,
          level: _level,
          major: _major.text.trim().isEmpty ? '-' : _major.text,
          city: _city.text.trim().isEmpty ? widget.profile.city : _city.text,
        );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    toastVia(messenger, 'Identitas diperbarui');
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CareerSheetHeader('Ubah identitas'),
        const Text('Jenjang, jurusan, dan kota ikut menentukan Match Score.', style: CareerText.small),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _nameError == null ? null : setState(() => _nameError = null),
          style: CareerText.body.copyWith(fontSize: 16),
          decoration: careerInput(label: 'Nama lengkap', error: _nameError),
        ),
        const SizedBox(height: 16),
        const Text('Pendidikan terakhir', style: CareerText.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in EduLevel.values)
              Semantics(
                button: true,
                selected: _level == l,
                child: TextButton(
                  onPressed: () => setState(() => _level = l),
                  style: TextButton.styleFrom(
                    foregroundColor: _level == l ? Colors.white : CareerColors.muted,
                    backgroundColor: _level == l ? CareerColors.navy : Colors.white,
                    minimumSize: const Size(56, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _level == l ? CareerColors.navy : CareerColors.line),
                    ),
                    textStyle: CareerText.label,
                  ),
                  child: Text(l.label),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _major,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: CareerText.body.copyWith(fontSize: 16),
          decoration: careerInput(label: 'Jurusan', hint: 'mis. Manajemen'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _city,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          style: CareerText.body.copyWith(fontSize: 16),
          decoration: careerInput(label: 'Kota', hint: 'mis. Purwokerto'),
        ),
        const SizedBox(height: 20),
        CareerButton(label: 'Simpan', icon: Icons.check_rounded, onPressed: _save),
      ],
    ),
  );
}
