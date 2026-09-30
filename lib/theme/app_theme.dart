import 'package:flutter/material.dart';

class PlanazoColors {
  static const Color fondoPrimario = Color(0xFFF7F4EE);
  static const Color fondoSecundario = Color(0xFFEDE4D3);
  static const Color loginFondo = Color(0xFF101010);
  static const Color amarillo = Color(0xFFF5C94C);
  static const Color amarilloClaro = Color(0xFFFFE7A8);
  static const Color amarilloOscuro = Color(0xFFE0AD1A);
  static const Color negro = Color(0xFF1A1A1A);
  static const Color negroSuave = Color.fromARGB(255, 113, 113, 113);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color borde = Color(0xFFE6D9C3);
  static const Color textoPrimario = Color(0xFF1F1F1F);
  static const Color textoSecundario = Color(0xFFE0AD1A);
  static const Color textoTerciario = Color(0xFF8A8A8A);
  static const Color exito = Color(0xFF2E9D62);
  static const Color error = Color(0xFFCD3D3D);
  static const Color info = Color(0xFF3366FF);
}

class PlanazoTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: PlanazoColors.fondoPrimario,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PlanazoColors.amarillo,
        primary: PlanazoColors.amarillo,
        secondary: PlanazoColors.amarilloOscuro,
        surface: PlanazoColors.blanco,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: PlanazoColors.blanco,
        foregroundColor: PlanazoColors.negro,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PlanazoColors.amarillo,
          foregroundColor: PlanazoColors.negro,
        ),
      ),
      cardTheme: CardThemeData(
        color: PlanazoColors.blanco,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PlanazoColors.borde),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PlanazoColors.negro,
        selectedItemColor: PlanazoColors.amarillo,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PlanazoColors.blanco,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PlanazoColors.borde),
        ),
      ),
    );
  }
}
