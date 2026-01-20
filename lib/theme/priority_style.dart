import 'package:flutter/material.dart';

/// Task öncelik seviyeleri:
/// 1 = Düşük, 2 = Orta, 3 = Yüksek
///
/// Bu dosya: UI'da priority renk/etiket standardını tek yerde toplar.
/// Böylece her ekranda aynı görünüm kullanılır.
class PriorityStyle {
  static const int low = 1;
  static const int medium = 2;
  static const int high = 3;

  /// Öncelik etiketi (UI'da görünecek yazı)
  static String label(int p) {
    switch (p) {
      case low:
        return 'Düşük';
      case medium:
        return 'Orta';
      case high:
        return 'Yüksek';
      default:
        return 'Orta';
    }
  }

  /// Chip'in border rengi (ve istersen yazı rengi için de kullanabilirsin)
  /// Not: Aşağıdaki renkler "soft" seçildi ki dark temada göz yormasın.
  static Color borderColor(int p) {
    switch (p) {
      case low:
        return const Color(0xFFFFD54F); // soft sarı/amber
      case medium:
        return const Color(0xFFFFA726); // turuncu
      case high:
        return const Color(0xFFEF5350); // soft kırmızı
      default:
        return const Color(0xFFFFA726);
    }
  }

  /// Chip'in arkaplan rengi (soft/pastel)
  static Color backgroundColor(int p) {
    switch (p) {
      case low:
        return const Color(0x33FFD54F); // sarı %20 civarı şeffaf
      case medium:
        return const Color(0x33FFA726); // turuncu %20 civarı şeffaf
      case high:
        return const Color(0x33EF5350); // kırmızı %20 civarı şeffaf
      default:
        return const Color(0x33FFA726);
    }
  }

  /// Chip yazı rengi
  /// Dark temada okunaklı olması için açık yazı yerine border rengine yakın ama net bir ton veriyoruz.
  static Color textColor(int p) {
    switch (p) {
      case low:
        return const Color(0xFFFFF3C2); // açık sarımsı
      case medium:
        return const Color(0xFFFFE0B2); // açık turuncumsu
      case high:
        return const Color(0xFFFFCDD2); // açık kırmızımsı
      default:
        return const Color(0xFFFFE0B2);
    }
  }
}
