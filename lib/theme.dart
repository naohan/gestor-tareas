import 'package:flutter/material.dart';

/// Paleta y tema de Foco. Tono calmado, foco en lo importante,
/// nada de ruido visual que sume ansiedad.
class FocoTheme {
  static const seed = Color(0xFF5B8DEF);
  static const fondo = Color(0xFF101728);
  static const superficie = Color(0xFF18213A);
  static const superficie2 = Color(0xFF1F2A47);
  static const acento = Color(0xFF6FE3B0);
  static const peligro = Color(0xFFE3617E);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: superficie,
      secondary: acento,
    );

    return base.copyWith(
      scaffoldBackgroundColor: fondo,
      colorScheme: scheme,
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: superficie2,
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficie2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
