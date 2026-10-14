import 'package:flutter/material.dart';

/// Shared accent for register quantities in charts and reading lists.
Color registerAccent(String direction, BuildContext context) =>
    direction == 'EXPORT'
    ? AppColors.of(context).exportAccent
    : Theme.of(context).colorScheme.primary;

ThemeData meteryaTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final colors = AppColors(dark);
  final surface = dark ? const Color(0xff18232f) : Colors.white;
  final primary = dark ? const Color(0xff7bd8ca) : const Color(0xff0f766e);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff0f766e),
      brightness: brightness,
      primary: primary,
      onPrimary: dark ? const Color(0xff073b35) : Colors.white,
      surface: surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.muted,
      outlineVariant: colors.border,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xff101820)
        : const Color(0xfff6f8fb),
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: colors.muted,
        height: 1.5,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: colors.border)),
      titleTextStyle: TextStyle(
        color: primary,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      indicatorColor: colors.selectedPanel,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: colors.muted),
      selectedLabelTextStyle: TextStyle(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: colors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
  );
}

/// Semantic colors shared by charts, table bands and informational cards.
/// The fixed dark virtual-meter card retains its white foreground in both modes.
class AppColors {
  final bool dark;
  const AppColors(this.dark);
  static AppColors of(BuildContext context) =>
      AppColors(Theme.of(context).brightness == Brightness.dark);
  Color get ink => dark ? const Color(0xffe2e8f0) : const Color(0xff182b3a);
  Color get muted => dark ? const Color(0xffa5b4c5) : const Color(0xff64748b);
  Color get border => dark ? const Color(0xff354455) : const Color(0xffe2e8f0);
  Color get panel => dark ? const Color(0xff202f43) : const Color(0xffeff4ff);
  Color get table => dark ? const Color(0xff293b52) : const Color(0xffe6edf9);
  Color get exportPanel =>
      dark ? const Color(0xff3c301d) : const Color(0xfffff4df);
  Color get selectedPanel =>
      dark ? const Color(0xff173c38) : const Color(0xffdcefeb);
  Color get exportAccent =>
      dark ? const Color(0xfff1b65b) : const Color(0xffc07812);
  Color get water => dark ? const Color(0xff7cc8f4) : const Color(0xff0369a1);
  Color get heatAccent =>
      dark ? const Color(0xff7bd8ca) : const Color(0xff005f59);
  Color get grid => dark ? const Color(0xffffa46c) : const Color(0xffb34c13);
  Color get pv => dark ? const Color(0xff65d6a4) : const Color(0xff008b5b);
  Color get successPanel =>
      dark ? const Color(0xff173c2b) : const Color(0xffdcfce7);
  Color get onSuccess =>
      dark ? const Color(0xff8ce4b2) : const Color(0xff166534);
}
