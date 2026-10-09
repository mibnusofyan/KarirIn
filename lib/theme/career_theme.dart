import 'package:flutter/material.dart';

/// The refreshed visual language, adopted screen by screen.
abstract final class CareerColors {
  static const navy = Color(0xFF12305C);
  static const teal = Color(0xFF087F70);
  static const mint = Color(0xFFDDF5EB);
  static const yellow = Color(0xFFF5C65D);
  static const background = Color(0xFFF7F8F5);
  static const ink = Color(0xFF172B3A);
  static const muted = Color(0xFF586773);
  static const line = Color(0xFFE2E7E4);
  static const amber = Color(0xFF805B13);
  static const amberLight = Color(0xFFFFF3D9);

  /// Form errors only; status and scores use teal/amber instead of red.
  static const error = Color(0xFFB42318);
}

abstract final class CareerText {
  static const heading = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 28,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -.9,
    color: CareerColors.ink,
  );
  static const title = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 20,
    height: 1.35,
    fontWeight: FontWeight.w700,
    letterSpacing: -.5,
    color: CareerColors.ink,
  );
  static const cardTitle = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 17,
    height: 1.4,
    fontWeight: FontWeight.w700,
    letterSpacing: -.3,
    color: CareerColors.ink,
  );
  static const body = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, height: 1.55, color: CareerColors.ink);
  static const muted = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, height: 1.5, color: CareerColors.muted);
  static const small = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: CareerColors.muted,
  );

  /// Small uppercase section marker ("KECOCOKAN PROFIL").
  static const eyebrow = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 10,
    height: 1.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: CareerColors.muted,
  );
  static const label = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: CareerColors.ink,
  );
}

class CareerTheme extends StatelessWidget {
  const CareerTheme({super.key, required this.child});
  final Widget child;

  static ThemeData of(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: base.colorScheme.copyWith(
        primary: CareerColors.teal,
        onPrimary: Colors.white,
        primaryContainer: CareerColors.mint,
        onPrimaryContainer: CareerColors.teal,
        surface: CareerColors.background,
        onSurface: CareerColors.ink,
        onSurfaceVariant: CareerColors.muted,
        outlineVariant: CareerColors.line,
      ),
      scaffoldBackgroundColor: CareerColors.background,
      textTheme: base.textTheme.apply(fontFamily: 'PlusJakartaSans', bodyColor: CareerColors.ink, displayColor: CareerColors.ink),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: CareerColors.background,
        foregroundColor: CareerColors.ink,
        titleTextStyle: CareerText.label,
        centerTitle: true,
        titleSpacing: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CareerColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: CareerText.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: CareerColors.teal, minimumSize: const Size(48, 48), textStyle: CareerText.label),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(backgroundColor: Colors.white),
      dividerTheme: const DividerThemeData(color: CareerColors.line, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: CareerColors.mint,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => CareerText.small.copyWith(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? CareerColors.teal : CareerColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(size: 23, color: states.contains(WidgetState.selected) ? CareerColors.teal : CareerColors.muted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(data: of(context), child: child);
}
