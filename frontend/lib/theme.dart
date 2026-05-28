import 'package:flutter/material.dart';

class AmethystTheme {
  // Cores Primárias do Design System "Dark Amethyst"
  static const Color bgPrimary = Color(0xFF080612);
  static const Color bgSecondary = Color(0xFF120E2E);
  static const Color surface = Color(0xFF1B153F);
  static const Color cardBg = Color(0xCC1B153F); // Efeito translúcido para glassmorphism
  
  // Accents & glows
  static const Color accentAmethyst = Color(0xFFA855F7);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonRed = Color(0xFFFF2E63);

  // Cores de Texto
  static const Color textPrimary = Color(0xFFF0E6FF);
  static const Color textSecondary = Color(0xFF9B8EC4);
  static const Color textMuted = Color(0xFF655B8B);

  // Gradiente de Background
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgPrimary, bgSecondary, Color(0xFF160D32)],
  );

  // Gradiente de Accent
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentIndigo, accentAmethyst],
  );

  // Gradiente Rosa-Ametista (Glow Secundário)
  static const LinearGradient energyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentAmethyst, accentPink],
  );

  // Box Shadows para efeitos Glow
  static List<BoxShadow> glowShadow(Color color, {double radius = 8.0, double opacity = 0.5}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: radius,
        spreadRadius: 1,
      ),
    ];
  }

  // Estilo Glassmorphism para decoração de containers
  static BoxDecoration glassDecoration({
    Color borderColor = const Color(0x26A855F7), // Borda ametista semi-transparente
    double borderRadius = 16.0,
    bool showGlow = false,
    Color glowColor = accentAmethyst,
  }) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor,
        width: 1.2,
      ),
      boxShadow: showGlow ? glowShadow(glowColor, radius: 12.0, opacity: 0.2) : [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  // Obter o ThemeData completo da aplicação
  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: accentAmethyst,
      colorScheme: const ColorScheme.dark(
        primary: accentAmethyst,
        secondary: accentIndigo,
        surface: surface,
        error: neonRed,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        displayMedium: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        titleLarge: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.1),
        titleMedium: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14, height: 1.5),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
        bodySmall: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgPrimary.withOpacity(0.5),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x33A855F7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x22A855F7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentAmethyst, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonRed, width: 1.5),
        ),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: accentAmethyst,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: accentAmethyst,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0x44A855F7)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1FA855F7)),
        ),
      ),
    );
  }
}
