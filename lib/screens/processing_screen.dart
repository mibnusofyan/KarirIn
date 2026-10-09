import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// AI extraction status (simulated). Production: upload to Cloud Storage → `extractProfile` Cloud Function → Gemini.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.fromQa});
  final bool fromQa;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..addStatusListener((s) async {
      if (s != AnimationStatus.completed) return;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) context.go(Routes.confirm);
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Mengunggah ${widget.fromQa ? 'jawaban' : 'CV'}',
      widget.fromQa ? 'Memahami jawabanmu' : 'Membaca dokumen',
      'Mengenali keterampilan & pengalaman',
      'Menyusun profil terstruktur',
    ];
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final pct = (_c.value * 100).round();
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  children: [
                    RingGauge(
                      value: _c.value,
                      size: 160,
                      thickness: 12,
                      color: KColors.primary,
                      trackColor: KColors.primaryContainer,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$pct%', style: const TextStyle(fontSize: 36, height: 44 / 36)),
                          const Text('±15 detik', style: KText.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'DIPROSES AI',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .5,
                        color: KColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.fromQa ? 'Menyusun profil dari jawabanmu' : 'Membaca CV dan menyusun profilmu',
                      textAlign: TextAlign.center,
                      style: KText.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: KColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [for (var i = 0; i < steps.length; i++) _step(steps[i], pct >= (i + 1) * 25, pct >= i * 25)]),
                    ),
                    const Spacer(),
                    const Text(
                      'Jika koneksi terputus, proses dilanjutkan otomatis. Data CV dikirim terenkripsi.',
                      textAlign: TextAlign.center,
                      style: KText.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _step(String label, bool done, bool reached) {
    final active = !done && reached;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : active
                ? Icons.pending_outlined
                : Icons.radio_button_unchecked_rounded,
            color: done
                ? KColors.secondary
                : active
                ? KColors.primary
                : KColors.outlineVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: done || active ? KColors.onSurface : KColors.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
