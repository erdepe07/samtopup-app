import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warna mengikuti tema web (terang & gelap).
class Palette {
  final Color bg, surface, surface2, ink, muted, border, primary, primarySoft, accent;

  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.accent,
  });

  static const light = Palette(
    bg: Color(0xFFF3F7FF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF6F9FF),
    ink: Color(0xFF0B1B3A),
    muted: Color(0xFF5B6B8A),
    border: Color(0xFFE0E8F6),
    primary: Color(0xFF1D4ED8),
    primarySoft: Color(0xFFDBE7FF),
    accent: Color(0xFFD97706),
  );

  static const dark = Palette(
    bg: Color(0xFF071327),
    surface: Color(0xFF0E2142),
    surface2: Color(0xFF112A52),
    ink: Color(0xFFEAF1FF),
    muted: Color(0xFF93A6C9),
    border: Color(0xFF1B3560),
    primary: Color(0xFF3B82F6),
    primarySoft: Color(0xFF14305C),
    accent: Color(0xFFF59E0B),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
    ).copyWith(
      primary: p.primary,
      surface: p.surface,
      onSurface: p.ink,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: p.ink, displayColor: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primarySoft,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: p.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.primary, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
      ),
    ),
    dividerColor: p.border,
  );
}
