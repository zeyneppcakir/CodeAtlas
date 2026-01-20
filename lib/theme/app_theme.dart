import 'package:flutter/material.dart';

class AppColors {
  // Senin seçtiğin palet: Koyu mavi + teal + açık gri
  static const Color navy = Color(0xFF0B1B2B);
  static const Color navySoft = Color(0xFF12263A);
  static const Color teal = Color(0xFF2DD4BF);
  static const Color bg = Color(0xFF071523);

  static const Color text = Color(0xFFE6EDF3);
  static const Color textSoft = Color(0xFFA9B4C0);
  static const Color danger = Color(0xFFE53935);
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark();

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.teal,
        secondary: AppColors.teal,
        surface: AppColors.navySoft,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.text,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.navySoft,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navySoft,
        hintStyle: const TextStyle(color: AppColors.textSoft),
        labelStyle: const TextStyle(color: AppColors.textSoft),
        prefixIconColor: AppColors.textSoft,
        suffixIconColor: AppColors.textSoft,
        errorStyle: const TextStyle(color: AppColors.danger),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
    );
  }
}
