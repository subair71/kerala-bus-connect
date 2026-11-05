import 'package:flutter/material.dart';

/// Tokens from the supplied home-screen reference; scoped to the passenger tab.
abstract final class HomeTheme {
  static const primary = Color(0xff00594b);
  static const mint = Color(0xff9cf1e5);
  static const background = Color(0xfff8f9ff);
  static const field = Color(0xfff0f4f8);
  static const timing = Color(0xfff5f8fa);
  static const text = Color(0xff071018);
  static const muted = Color(0xff63716d);
  static const positive = Color(0xff16c997);
  static const positiveSurface = Color(0xffeafbf4);
  static const advisory = Color(0xffeff2ff);

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
          color: states.contains(WidgetState.selected) ? primary : text,
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
