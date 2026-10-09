import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/match_score.dart';
import '../theme/app_theme.dart';

/// The KarirIn "K" mark (logo icon), drawn as a vector so it stays crisp at any size.
class KarirInMark extends StatelessWidget {
  const KarirInMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MarkPainter(), size: Size.square(size)),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.22));
    canvas.drawRRect(rect, Paint()..color = KColors.brandNavy);
    Paint stroke(Color c) => Paint()
      ..color = c
      ..strokeWidth = s * 0.137
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Offset at(double x, double y) => Offset(x * s, y * s);
    // Lower arm (teal) = skill growth, drawn first so the upper arm overlaps the joint.
    canvas.drawLine(at(0.46, 0.55), at(0.67, 0.78), stroke(KColors.brandTeal));
    canvas.drawLine(at(0.31, 0.30), at(0.31, 0.70), stroke(Colors.white));
    canvas.drawLine(at(0.45, 0.51), at(0.68, 0.30), stroke(Colors.white));
    // Yellow dot = career goal.
    canvas.drawCircle(at(0.785, 0.195), s * 0.072, Paint()..color = KColors.brandYellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Circular gauge used for Match Score, AI processing and interview results.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.value,
    required this.size,
    required this.thickness,
    required this.color,
    required this.trackColor,
    required this.child,
  });

  /// 0–1.
  final double value;
  final double size;
  final double thickness;
  final Color color;
  final Color trackColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(value.clamp(0, 1), thickness, color, trackColor),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.thickness, this.color, this.track);
  final double value, thickness;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(thickness / 2, thickness / 2, size.width - thickness, size.height - thickness);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

/// Thin rounded progress bar.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, required this.color, this.height = 4, this.track = KColors.surfaceContainerHighest});
  final double value;
  final Color color;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: Container(
      height: height,
      color: track,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
        ),
      ),
    ),
  );
}

/// 56×56 score tile shown on job cards.
class ScoreTile extends StatelessWidget {
  const ScoreTile({super.key, required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final c = MatchCategory.of(score);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fmt(score),
            style: TextStyle(fontSize: 20, height: 24 / 20, fontWeight: FontWeight.w700, color: c.fg),
          ),
          Text(
            'MATCH',
            style: TextStyle(fontSize: 10, height: 12 / 10, fontWeight: FontWeight.w500, letterSpacing: .5, color: c.fg),
          ),
        ],
      ),
    );
  }
}

/// Small 24dp label (category, status, work mode).
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.bg, this.fg = KColors.onSurfaceVariant, this.outlined = false, this.height = 24});
  final String label;
  final Color? bg;
  final Color fg;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.symmetric(horizontal: height > 24 ? 12 : 8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      border: outlined ? Border.all(color: KColors.outlineVariant) : null,
    ),
    // widthFactor keeps the tag as wide as its label instead of filling the parent.
    child: Align(
      widthFactor: 1,
      child: Text(
        label,
        style: TextStyle(fontSize: height > 24 ? 13 : 12, fontWeight: FontWeight.w500, color: fg),
      ),
    ),
  );
}

class CategoryTag extends StatelessWidget {
  const CategoryTag(this.category, {super.key, this.height = 24});
  final MatchCategory category;
  final double height;

  @override
  Widget build(BuildContext context) => Tag(category.label, bg: category.bg, fg: category.fg, height: height);
}

/// 40dp circle avatar holding an icon.
class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.bg = KColors.primaryContainer, this.fg = KColors.onPrimaryContainer, this.size = 40});
  final IconData icon;
  final Color bg, fg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Icon(icon, size: size / 2, color: fg),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 8)});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text, style: KText.sectionLabel),
  );
}

/// Page title block used by the tab screens (Skill Gap, Latihan, Lamaran).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: KText.headlineMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: KText.bodyMediumVariant),
      ],
    ),
  );
}

/// Grey stats strip with vertical dividers (Latihan, Profil).
class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.stats});
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: KColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stats[i].$1, style: KText.titleLarge),
                    Text(stats[i].$2, style: KText.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Full-width 56dp primary action ("one main action per screen, in thumb reach").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w500),
    );
    return icon == null
        ? FilledButton(style: style, onPressed: onPressed, child: Text(label))
        : FilledButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label));
  }
}

/// Tonal (secondary container) button used for "Sudah saya kuasai", "Tambah", "Coba lagi".
class TonalButton extends StatelessWidget {
  const TonalButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 40});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: KColors.secondaryContainer,
      foregroundColor: KColors.onSecondaryContainer,
      minimumSize: Size(48, height),
      padding: EdgeInsets.fromLTRB(16, 0, icon == null ? 16 : 24, 0),
    );
    return icon == null
        ? FilledButton(style: style, onPressed: onPressed, child: Text(label))
        : FilledButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label));
  }
}

/// Bottom action area with surface-container background.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.color = KColors.surfaceContainer});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    child: SafeArea(
      top: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: child),
    ),
  );
}

/// Info banner: icon + text on a tinted container.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.child,
    this.bg = KColors.primaryContainer,
    this.fg = KColors.onPrimaryContainer,
  });
  final IconData icon;
  final Widget child;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: 12),
        Expanded(
          child: DefaultTextStyle(
            style: KText.bodyMedium.copyWith(color: fg),
            child: child,
          ),
        ),
      ],
    ),
  );
}

/// Outlined 12dp card.
class OutlinedBox extends StatelessWidget {
  const OutlinedBox({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: KColors.outlineVariant),
    ),
    child: child,
  );
}

/// Tappable filled card (surfaceContainerLow) used for job and application cards.
class FilledCard extends StatelessWidget {
  const FilledCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: KColors.surfaceContainerLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: KColors.surfaceContainerHighest),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Single-line "toast" (M3 snackbar).
void showToast(BuildContext context, String text) => toastVia(ScaffoldMessenger.of(context), text);

/// Same as [showToast], for callers that already captured the messenger (e.g. after closing a sheet).
void toastVia(ScaffoldMessengerState messenger, String text) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 2800)));

/// Back button used in the top app bars.
class BackBtn extends StatelessWidget {
  const BackBtn({super.key, required this.onPressed, this.icon = Icons.arrow_back_rounded, this.tooltip = 'Kembali'});
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(onPressed: onPressed, icon: Icon(icon), tooltip: tooltip);
}

/// Top app bar with back button, title and an optional trailing caption/actions.
PreferredSizeWidget topBar({
  required String title,
  required VoidCallback onBack,
  String? caption,
  List<Widget>? actions,
  IconData backIcon = Icons.arrow_back_rounded,
}) => AppBar(
  leading: BackBtn(onPressed: onBack, icon: backIcon),
  title: Text(title),
  actions: [
    if (caption != null)
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(child: Text(caption, style: KText.bodySmall)),
      ),
    ...?actions,
  ],
);

/// 4dp step progress shown under the top bar.
class StepProgress extends StatelessWidget {
  const StepProgress(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 250),
      builder: (_, v, _) => Bar(value: v, color: KColors.primary, track: KColors.primaryContainer),
    ),
  );
}

/// Bottom-sheet helper matching the design (28dp top radius, drag handle).
Future<T?> showKSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  // Root navigator so the scrim also covers the bottom navigation bar.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => SafeArea(
    top: false,
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), child: builder(ctx)),
  ),
);
