import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tema escuro "premium": tons de cinza bem escuro, destaque quase branco.
class AppTheme {
  static const bg = Color(0xFF0B0B0D);
  static const surface = Color(0xFF131316);
  static const surfaceHigh = Color(0xFF1A1A1E);
  static const surfaceHighest = Color(0xFF232328);
  static const line = Color(0xFF26262B);
  static const text = Color(0xFFEDEDEF);
  static const textMuted = Color(0xFF9A9AA2);
  static const accent = Color(0xFFE6E6E9);
  static const outlineStrong = Color(0xFF45454D);
  static const positive = Color(0xFF7FD1A0);
  static const negative = Color(0xFFF08A8A);

  static const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accent,
    onPrimary: Color(0xFF111113),
    primaryContainer: surfaceHighest,
    onPrimaryContainer: text,
    secondary: Color(0xFFB4B4BC),
    onSecondary: Color(0xFF111113),
    secondaryContainer: Color(0xFF2B2B31),
    onSecondaryContainer: text,
    tertiary: Color(0xFFD9C9A3),
    onTertiary: Color(0xFF1A160C),
    tertiaryContainer: Color(0xFF1E1C17),
    onTertiaryContainer: Color(0xFFEDE6D6),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF2B0A08),
    surface: bg,
    onSurface: text,
    onSurfaceVariant: textMuted,
    surfaceContainerLowest: Color(0xFF08080A),
    surfaceContainerLow: Color(0xFF101013),
    surfaceContainer: surface,
    surfaceContainerHigh: surfaceHigh,
    surfaceContainerHighest: surfaceHighest,
    outline: Color(0xFF3A3A41),
    outlineVariant: line,
    inverseSurface: text,
    onInverseSurface: Color(0xFF151518),
    inversePrimary: Color(0xFF3A3A41),
    shadow: Colors.black,
    scrim: Colors.black,
  );

  /// Suaviza as cores de categoria para combinar com o fundo escuro.
  static Color tone(Color c) => Color.lerp(c, const Color(0xFFB8B8C0), 0.35)!;

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
    final t = base.textTheme;
    final r16 = BorderRadius.circular(16);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: t.copyWith(
        headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: r16,
          side: const BorderSide(color: line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: surfaceHighest,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? text : textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? text : textMuted),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: accent,
        labelColor: text,
        unselectedLabelColor: textMuted,
        dividerColor: line,
      ),
      dividerTheme: const DividerThemeData(color: line, space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(iconColor: textMuted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF55555D)),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceHigh,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Color(0xFF111113),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHighest,
        contentTextStyle: const TextStyle(color: text),
        actionTextColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent, linearTrackColor: surfaceHighest),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? const Color(0xFF111113) : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : surfaceHighest),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
