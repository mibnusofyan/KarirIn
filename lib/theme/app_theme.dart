import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens from "KarirIn Prototype M3" (ColorScheme light).
abstract final class KColors {
  static const brandNavy = Color(0xFF12305C);
  static const brandTeal = Color(0xFF0E9F8A);
  static const brandYellow = Color(0xFFF5A524);

  static const primary = Color(0xFF2F5A8F);
  static const primaryHover = Color(0xFF3A659B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD6E3FF);
  static const onPrimaryContainer = Color(0xFF12305C);
  static const secondary = Color(0xFF006B5F);
  static const secondaryContainer = Color(0xFFA6F0DF);
  static const onSecondaryContainer = Color(0xFF00201C);
  static const tertiary = Color(0xFF7A5900);
  static const tertiaryContainer = Color(0xFFFFDEA9);
  static const onTertiaryContainer = Color(0xFF271900);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF410002);
  static const surface = Color(0xFFF9F9FF);
  static const onSurface = Color(0xFF191C20);
  static const surfaceContainerLow = Color(0xFFF3F3FA);
  static const surfaceContainer = Color(0xFFEDEDF4);
  static const surfaceContainerHigh = Color(0xFFE7E8EE);
  static const surfaceContainerHighest = Color(0xFFE2E2E9);
  static const onSurfaceVariant = Color(0xFF44474E);
  static const outline = Color(0xFF74777F);
  static const outlineVariant = Color(0xFFC4C6D0);
  static const inverseSurface = Color(0xFF2E3036);
  static const onInverseSurface = Color(0xFFF0F0F7);

  /// Progress-bar colour for the "Cukup Cocok" band (between tertiary and its container).
  static const midBar = Color(0xFF9A6F00);
}

abstract final class AppTheme {
  static const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: KColors.primary,
    onPrimary: KColors.onPrimary,
    primaryContainer: KColors.primaryContainer,
    onPrimaryContainer: KColors.onPrimaryContainer,
    secondary: KColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: KColors.secondaryContainer,
    onSecondaryContainer: KColors.onSecondaryContainer,
    tertiary: KColors.tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: KColors.tertiaryContainer,
    onTertiaryContainer: KColors.onTertiaryContainer,
    error: KColors.error,
    onError: Colors.white,
    errorContainer: KColors.errorContainer,
    onErrorContainer: KColors.onErrorContainer,
    surface: KColors.surface,
    onSurface: KColors.onSurface,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: KColors.surfaceContainerLow,
    surfaceContainer: KColors.surfaceContainer,
    surfaceContainerHigh: KColors.surfaceContainerHigh,
    surfaceContainerHighest: KColors.surfaceContainerHighest,
    onSurfaceVariant: KColors.onSurfaceVariant,
    outline: KColors.outline,
    outlineVariant: KColors.outlineVariant,
    inverseSurface: KColors.inverseSurface,
    onInverseSurface: KColors.onInverseSurface,
    inversePrimary: KColors.primaryContainer,
  );

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme, fontFamily: 'Roboto');
    const pill56 = StadiumBorder();
    return base.copyWith(
      scaffoldBackgroundColor: KColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: KColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 4,
        foregroundColor: KColors.onSurface,
        titleTextStyle: TextStyle(fontFamily: 'Roboto', fontSize: 22, height: 28 / 22, color: KColors.onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 40),
          shape: pill56,
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 40),
          shape: pill56,
          foregroundColor: KColors.primary,
          side: const BorderSide(color: KColors.outline),
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          foregroundColor: KColors.primary,
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? KColors.secondaryContainer : KColors.outlineVariant),
        ),
        color: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KColors.secondaryContainer : Colors.transparent),
        checkmarkColor: KColors.onSecondaryContainer,
        labelStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500, color: KColors.onSurfaceVariant),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: KColors.onSecondaryContainer,
        ),
        showCheckmark: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: KColors.secondaryContainer,
          selectedForegroundColor: KColors.onSecondaryContainer,
          foregroundColor: KColors.onSurface,
          side: const BorderSide(color: KColors.outline),
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: KColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: KColors.primary, width: 2),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: TextStyle(color: KColors.outline),
        labelStyle: TextStyle(color: KColors.onSurfaceVariant),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: KColors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: KColors.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? KColors.onSurface : KColors.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? KColors.onSecondaryContainer : KColors.onSurfaceVariant),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KColors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: KColors.outlineVariant,
        dragHandleSize: Size(32, 4),
        modalBarrierColor: Color(0x52000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: KColors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: KColors.inverseSurface,
        contentTextStyle: TextStyle(fontFamily: 'Roboto', fontSize: 14, height: 20 / 14, color: KColors.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : KColors.outline),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? KColors.primary : KColors.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KColors.primary : KColors.outline),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KColors.primary : KColors.onSurfaceVariant),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KColors.primary : Colors.transparent),
        side: const BorderSide(color: KColors.onSurfaceVariant, width: 2),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KColors.primary,
        linearTrackColor: KColors.primaryContainer,
        linearMinHeight: 4,
      ),
      dividerTheme: const DividerThemeData(color: KColors.outlineVariant, thickness: 1, space: 1),
    );
  }
}

/// M3 type scale used by the design (Roboto).
abstract final class KText {
  static const headlineMedium = TextStyle(fontSize: 28, height: 36 / 28, color: KColors.onSurface);
  static const headlineSmall = TextStyle(fontSize: 24, height: 32 / 24, color: KColors.onSurface);
  static const titleLarge = TextStyle(fontSize: 22, height: 28 / 22, color: KColors.onSurface);
  static const titleMedium = TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: KColors.onSurface);
  static const bodyLarge = TextStyle(fontSize: 16, height: 24 / 16, color: KColors.onSurface);
  static const bodyMedium = TextStyle(fontSize: 14, height: 20 / 14, color: KColors.onSurface);
  static const bodyMediumVariant = TextStyle(fontSize: 14, height: 20 / 14, color: KColors.onSurfaceVariant);
  static const labelLarge = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: KColors.onSurface);
  static const bodySmall = TextStyle(fontSize: 12, height: 16 / 12, color: KColors.onSurfaceVariant);
  static const sectionLabel = TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: KColors.primary);
}
