import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Home-specific surfaces built on the application's shared reference palette.
abstract final class HomeTheme {
  static const border = AppColors.border;
  static const accentInk = AppColors.accentInk;
  static const primary = AppColors.primary;
  static const mint = AppColors.secondaryContainer;
  static const background = AppColors.background;
  static const field = AppColors.surfaceLow;
  static const timing = Color(0xfff5f8fa);
  static const text = AppColors.onSurface;
  static const muted = AppColors.onSurfaceVariant;
  static const positive = Color(0xff16c997);
  static const positiveSurface = Color(0xffeafbf4);
  static const advisory = Color(0xfffff6ed);

  static ThemeData from(ThemeData base) => base.copyWith(
    scaffoldBackgroundColor: background,
    colorScheme: base.colorScheme.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: mint,
      onPrimaryContainer: primary,
      onSurface: text,
      onSurfaceVariant: muted,
    ),
    textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primary,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? accentInk : muted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : const Color(0xffcdd7d4),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
