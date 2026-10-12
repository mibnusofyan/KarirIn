import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../logic/match_score.dart';
import '../theme/career_theme.dart';
import 'common.dart';

Future<T?> showCareerSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  builder: (ctx) => CareerTheme(
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Builder(builder: builder),
      ),
    ),
  ),
);

class CareerSheetHeader extends StatelessWidget {
  const CareerSheetHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: CareerText.title)),
      IconButton(tooltip: 'Tutup', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
    ],
  );
}

/// Deterministic monogram fallback until real company assets are available.
/// Logo files in assets/images/logos/ (made by tool/make_company_logos.py) for the curated companies.
const companyLogos = <String, String>{
  'PT Sinar Mandiri Abadi': 'sinar-mandiri-abadi',
  'Kopi Lereng Slamet': 'kopi-lereng-slamet',
  'Tani Digital Nusantara': 'tani-digital-nusantara',
  'BPR Artha Sejahtera': 'bpr-artha-sejahtera',
  'KAP Wijaya & Rekan': 'kap-wijaya-rekan',
  'CV Berkah Logistik': 'berkah-logistik',
  'PT Banyumas Net Media': 'banyumas-net-media',
  'CV Mitra Komputindo': 'mitra-komputindo',
  'Toko Swalayan Mitra': 'toko-swalayan-mitra',
  'PT Graha Niaga': 'graha-niaga',
  'Batik Lumbon Banyumas': 'batik-lumbon-banyumas',
  'PT Agro Serayu Lestari': 'agro-serayu-lestari',
  'Lapak Kriya Nusantara': 'lapak-kriya-nusantara',
  'PT Serayu Logistik Mandiri': 'serayu-logistik-mandiri',
};

/// The company's logo, or its initials on a tinted tile for a company without one.
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({super.key, required this.company, this.size = 44});
  final String company;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .3);
    final logo = companyLogos[company];
    if (logo != null) {
      return ExcludeSemantics(
        child: ClipRRect(
          borderRadius: radius,
          child: SvgPicture.asset('assets/images/logos/$logo.svg', width: size, height: size),
        ),
      );
    }
    final words = company.split(' ').where((w) => !['PT', 'CV', 'BPR', 'KAP', '&'].contains(w) && w.isNotEmpty);
    final initials = words.take(2).map((w) => w[0]).join();
    const palettes = [
      (CareerColors.mint, CareerColors.teal),
      (Color(0xFFE8ECF6), CareerColors.navy),
      (CareerColors.amberLight, CareerColors.amber),
      (Color(0xFFF1E8E0), Color(0xFF79563D)),
    ];
    final palette = palettes[company.codeUnits.fold(0, (sum, n) => sum + n) % palettes.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: palette.$1, borderRadius: radius),
        child: Text(
          initials,
          textScaler: TextScaler.noScaling,
          style: CareerText.title.copyWith(fontSize: size * .34, color: palette.$2),
        ),
      ),
    );
  }
}

class CareerPill extends StatelessWidget {
  const CareerPill(this.label, {super.key, this.icon, this.color = CareerColors.muted, this.background = CareerColors.background});
  final String label;
  final IconData? icon;
  final Color color, background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)],
        Flexible(
          child: Text(label, style: CareerText.small.copyWith(color: color)),
        ),
      ],
    ),
  );
}

class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.result});
  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    final high = result.category == MatchCategory.high;
    return Semantics(
      label: 'Match Score ${fmt(result.total)} dari 100. ${result.category.label}',
      excludeSemantics: true,
      child: CareerPill(
        '${fmt(result.total)} / 100 · ${result.category.label}',
        icon: high ? Icons.check_circle_outline_rounded : Icons.trending_up_rounded,
        color: high ? CareerColors.teal : CareerColors.amber,
        background: high ? CareerColors.mint : CareerColors.amberLight,
      ),
    );
  }
}

class CareerMeta extends StatelessWidget {
  const CareerMeta(this.icon, this.text, {super.key, this.style});
  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Icon(icon, size: 17, color: CareerColors.muted),
      ),
      const SizedBox(width: 7),
      Flexible(child: Text(text, style: style ?? CareerText.muted)),
    ],
  );
}

class CareerButton extends StatelessWidget {
  const CareerButton({super.key, required this.label, required this.onPressed, this.icon = Icons.arrow_forward_rounded});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        const SizedBox(width: 10),
        Icon(icon, size: 19),
      ],
    ),
  );
}

/// Decorative steps echo the rising arm and destination dot of the K mark.
class CareerSteps extends StatelessWidget {
  const CareerSteps({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(width: 88, height: 84, child: CustomPaint(painter: _StepsPainter())),
  );
}

class _StepsPainter extends CustomPainter {
  const _StepsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 3; i++) {
      paint.color = [const Color(0xFF3B597E), const Color(0xFF5D8B98), const Color(0xFFB5E5D4)][i];
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(i * 27, 61 - i * 18, 22, 23 + i * 18), const Radius.circular(5)), paint);
    }
    canvas.drawCircle(const Offset(65, 11), 7, paint..color = CareerColors.yellow);
  }

  @override
  bool shouldRepaint(_StepsPainter oldDelegate) => false;
}

/// The job a screen works towards, with a "Ganti" action instead of a long list.
class SelectedJobCard extends StatelessWidget {
  const SelectedJobCard({super.key, required this.eyebrow, required this.scored, required this.onChange});
  final String eyebrow;
  final ScoredJob scored;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final job = scored.job;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CareerColors.line),
      ),
      child: Row(
        children: [
          CompanyAvatar(company: job.company, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: CareerText.eyebrow),
                const SizedBox(height: 3),
                Text(job.title, style: CareerText.label),
                Text(job.company, style: CareerText.small),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text('Ganti', semanticsLabel: 'Ganti lowongan, saat ini ${job.title}'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to pick a target job; returns the chosen job id.
Future<String?> showJobPicker(BuildContext context, {required String title, required List<ScoredJob> ranked, required String selectedId}) =>
    showCareerSheet<String>(
      context,
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CareerSheetHeader(title),
          const Text('Diurutkan dari yang paling cocok dengan profilmu.', style: CareerText.muted),
          const SizedBox(height: 8),
          for (final (i, s) in ranked.indexed) ...[
            if (i > 0) const Divider(),
            Semantics(
              selected: s.job.id == selectedId,
              child: InkWell(
                onTap: () => Navigator.pop(ctx, s.job.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      CompanyAvatar(company: s.job.company, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.job.title, style: CareerText.label),
                            const SizedBox(height: 2),
                            Text(s.job.company, style: CareerText.small),
                            const SizedBox(height: 8),
                            MatchBadge(result: s.result),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        s.job.id == selectedId ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: s.job.id == selectedId ? CareerColors.teal : CareerColors.line,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

/// One rubric aspect (0–25) as a labelled bar.
class RubricRow extends StatelessWidget {
  const RubricRow({super.key, required this.name, required this.value, this.track = CareerColors.background});
  final String name;
  final int value;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final v = value / 25;
    return Semantics(
      label: '$name $value dari 25',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: CareerText.body)),
              Text('$value / 25', style: CareerText.label),
            ],
          ),
          const SizedBox(height: 6),
          Bar(value: v, color: v >= .75 ? CareerColors.teal : CareerColors.amber, track: track, height: 6),
        ],
      ),
    );
  }
}

/// Highlighted insight row: a strength (mint) or the next priority (amber).
class InsightTile extends StatelessWidget {
  const InsightTile({super.key, required this.positive, required this.title, required this.body});
  final bool positive;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final color = positive ? CareerColors.teal : CareerColors.amber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: positive ? CareerColors.mint : CareerColors.amberLight, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(positive ? Icons.thumb_up_alt_outlined : Icons.flag_outlined, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CareerText.label.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(body, style: CareerText.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White, rounded input with the label inside the field and the error right below it.
InputDecoration careerInput({required String label, String? hint, String? error, String? helper, Widget? suffix}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    helperText: helper,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    labelStyle: CareerText.muted,
    floatingLabelStyle: CareerText.small.copyWith(color: CareerColors.teal, fontWeight: FontWeight.w600),
    hintStyle: CareerText.muted,
    helperStyle: CareerText.small,
    helperMaxLines: 2,
    errorStyle: CareerText.small.copyWith(color: CareerColors.error, fontWeight: FontWeight.w600),
    errorMaxLines: 2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: border(CareerColors.line),
    focusedBorder: border(CareerColors.teal, 2),
    errorBorder: border(CareerColors.error),
    focusedErrorBorder: border(CareerColors.error, 2),
  );
}

/// Segmented step progress with a caption, e.g. "Langkah 1 dari 2".
class CareerStepBar extends StatelessWidget {
  const CareerStepBar({super.key, required this.current, required this.total, required this.caption});
  final int current, total;
  final String caption;

  @override
  Widget build(BuildContext context) => Semantics(
    label: caption,
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          for (var i = 1; i <= total; i++) ...[
            if (i > 1) SizedBox(width: total > 4 ? 4 : 6),
            Expanded(
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current ? CareerColors.teal : CareerColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Text(caption, style: CareerText.small),
        ],
      ),
    ),
  );
}
