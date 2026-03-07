class FileFilterService {
  // İstenmeyen klasörler (hem kökte hem içte)
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

  // Platform klasörleri (Flutter proje yapısında genelde analiz dışı)
  static const List<String> _platformFolders = [
    'android',
    'ios',
    'windows',
    'linux',
    'macos',
    'web',
  ];

  bool shouldIgnorePath(String path) {
    final p = path.replaceAll('\\', '/').toLowerCase();

    for (final token in _ignoreTokens) {
      if (p.contains(token)) return true;
    }

    // platform folder kontrolü (kökten başlıyorsa veya içerde "/android/" gibi geçiyorsa)
    for (final folder in _platformFolders) {
      if (p.startsWith('$folder/') || p.contains('/$folder/')) return true;
    }

    return false;
  }

  /// Çok kaba binary tespiti:
  /// - null byte varsa binary kabul
  /// - ilk 512 baytta "garip" kontrol karakteri oranı yüksekse binary kabul
  bool looksBinary(List<int> bytes) {
    if (bytes.isEmpty) return false;

    final len = bytes.length < 512 ? bytes.length : 512;

    int suspicious = 0;
    for (int i = 0; i < len; i++) {
      final b = bytes[i];

      if (b == 0) return true; // null byte => binary

      final isAllowedControl = (b == 9 || b == 10 || b == 13); // \t \n \r
      final isPrintableAscii = (b >= 32 && b <= 126);

      if (!isPrintableAscii && !isAllowedControl) {
        suspicious++;
      }
    }

    // %20'den fazlaysa binary say
    return suspicious / len > 0.20;
  }
}
