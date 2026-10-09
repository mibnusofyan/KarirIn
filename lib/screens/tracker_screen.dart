import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Pelacak lamaran: status per application plus follow-up reminders.
class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

(Color, Color) stageColors(AppStage s) => switch (s) {
  AppStage.dikirim => (KColors.primaryContainer, KColors.onPrimaryContainer),
  AppStage.tes || AppStage.wawancara => (KColors.tertiaryContainer, KColors.onTertiaryContainer),
  AppStage.diterima => (KColors.secondaryContainer, KColors.onSecondaryContainer),
  AppStage.ditolak => (KColors.errorContainer, KColors.onErrorContainer),
};

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  /// null = "Semua".
  AppStage? _filter;

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(appProvider).applications;
    final shown = apps.where((a) => _filter == null || a.status == _filter).toList();
    final active = apps.where((a) => a.status.isActive).length;

    Widget chip(String label, int count, AppStage? stage) {
      final on = _filter == stage;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          selected: on,
          onSelected: (_) => setState(() => _filter = stage),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 8),
              Badge(
                label: Text('$count'),
                backgroundColor: on ? KColors.secondary : KColors.surfaceContainerHighest,
                textColor: on ? Colors.white : KColors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                largeSize: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            PageHeader(title: 'Lamaran', subtitle: '$active lamaran aktif'),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  chip('Semua', apps.length, null),
                  for (final s in AppStage.values) chip(s.label, apps.where((a) => a.status == s).length, s),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final a in shown) ...[_AppCard(app: a), const SizedBox(height: 8)],
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                      child: Text('Belum ada lamaran di tahap ini.', textAlign: TextAlign.center, style: KText.bodyMediumVariant),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Text(
                'Lamaran dikirim lewat kanal resmi perusahaan. Catat statusnya di sini agar pengingat tindak lanjut terjadwal.',
                style: KText.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.app});
  final JobApplication app;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = stageColors(app.status);
    return FilledCard(
      onTap: () => showKSheet<void>(context, (_) => _StatusSheet(app: app)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(app.title, style: KText.titleMedium)),
              const SizedBox(width: 8),
              Tag(app.status.label, bg: bg, fg: fg),
            ],
          ),
          const SizedBox(height: 4),
          Text('${app.company} · dikirim ${app.date}', style: KText.bodyMediumVariant),
          if (app.remind != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, size: 16, color: KColors.tertiary),
                const SizedBox(width: 8),
                Text(
                  app.remind!,
                  style: const TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusSheet extends ConsumerStatefulWidget {
  const _StatusSheet({required this.app});
  final JobApplication app;

  @override
  ConsumerState<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends ConsumerState<_StatusSheet> {
  late AppStage _status = widget.app.status;
  late bool _remind = widget.app.remind != null;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(widget.app.title, style: KText.titleLarge),
      Text(widget.app.company, style: KText.bodyMediumVariant),
      const SectionLabel('Ubah status', padding: EdgeInsets.only(top: 16, bottom: 4)),
      RadioGroup<AppStage>(
        groupValue: _status,
        onChanged: (v) => setState(() => _status = v ?? _status),
        child: Column(
          children: [
            for (final s in AppStage.values)
              InkWell(
                onTap: () => setState(() => _status = s),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Radio<AppStage>(value: s),
                      const SizedBox(width: 4),
                      Text(s.label, style: KText.bodyLarge),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      SizedBox(
        height: 56,
        child: Row(
          children: [
            const Expanded(child: Text('Ingatkan tindak lanjut dalam 7 hari', style: KText.bodyMedium)),
            Switch(value: _remind, onChanged: (v) => setState(() => _remind = v)),
          ],
        ),
      ),
      const SizedBox(height: 4),
      PrimaryButton(
        label: 'Simpan status',
        onPressed: () {
          ref.read(appProvider.notifier).updateApplication(widget.app.id, _status, _remind);
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          toastVia(messenger, 'Status lamaran disimpan');
        },
      ),
    ],
  );
}
