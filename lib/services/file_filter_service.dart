class FileFilterService {
  /// Analiz dışında bırakılacak klasör parçaları
  /// Hem kökte hem alt klasörlerde kontrol edilir.
  static const List<String> _ignoreTokens = [
    '/node_modules/',
    '/build/',
    '/dist/',
    '/.git/',
    '/.dart_tool/',
    '/.idea/',
    '/.vscode/',
    '/.gradle/',
    '/pods/',
    '/deriveddata/',
  ];

  /// Flutter ve benzeri projelerde çoğunlukla analiz dışında bırakılan
  /// platform klasörleri
  static const List<String> _platformFolders = [
    'android',
    'ios',
    'windows',
    'linux',
    'macos',
    'web',
  ];

  /// Verilen dosya yolunun analiz dışında bırakılıp bırakılmayacağını belirler.
  bool shouldIgnorePath(String path) {
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();

    for (final token in _ignoreTokens) {
      if (normalizedPath.contains(token)) {
        return true;
      }
    }

    // Platform klasörü kontrolü:
    // Örn: "android/..." veya ".../android/..."
    for (final folder in _platformFolders) {
      if (normalizedPath.startsWith('$folder/') ||
          normalizedPath.contains('/$folder/')) {
        return true;
      }
    }

    return false;
  }

  /// Basit binary dosya tespiti yapar.
  ///
  /// Kurallar:
  /// - Null byte varsa binary kabul edilir.
  /// - İlk 512 bayt içinde şüpheli kontrol karakteri oranı yüksekse
  ///   binary kabul edilir.
  bool looksBinary(List<int> bytes) {
    if (bytes.isEmpty) return false;

    final sampleLength = bytes.length < 512 ? bytes.length : 512;
    int suspiciousCount = 0;

    for (int i = 0; i < sampleLength; i++) {
      final byte = bytes[i];

      // Null byte çoğunlukla binary dosyayı işaret eder
      if (byte == 0) return true;

      final isAllowedControl = byte == 9 || byte == 10 || byte == 13;
      final isPrintableAscii = byte >= 32 && byte <= 126;

      if (!isPrintableAscii && !isAllowedControl) {
        suspiciousCount++;
      }
    }

    // Şüpheli karakter oranı %20'den fazlaysa binary kabul edilir
    return suspiciousCount / sampleLength > 0.20;
  }
}
