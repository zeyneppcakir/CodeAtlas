/// Dil istatistiklerini temsil eden model.
/// Örneğin:
/// Dart -> 120 dosya, 35.000 satır
class LanguageStat {
  final String language;
  final int files;
  final int bytes;
  final int lines;

  const LanguageStat({
    required this.language,
    required this.files,
    required this.bytes,
    required this.lines,
  });

  Map<String, dynamic> toMap() => {
        'language': language,
        'files': files,
        'bytes': bytes,
        'lines': lines,
      };

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory LanguageStat.fromMap(Map<String, dynamic> map) {
    return LanguageStat(
      language: (map['language'] ?? '').toString(),
      files: _toInt(map['files']),
      bytes: _toInt(map['bytes']),
      lines: _toInt(map['lines']),
    );
  }

  LanguageStat copyWith({
    String? language,
    int? files,
    int? bytes,
    int? lines,
  }) {
    return LanguageStat(
      language: language ?? this.language,
      files: files ?? this.files,
      bytes: bytes ?? this.bytes,
      lines: lines ?? this.lines,
    );
  }
}

/// Kod analiz sonucunu temsil eden model.
/// Backend veya lokal analiz servisinden gelen veriyi tutar.
class AnalysisResult {
  final int totalFiles;
  final int ignoredFiles;
  final int totalBytes;

  /// Toplam satır sayısı
  final int totalLines;

  /// Gerçek kod satırları
  final int codeLines;

  /// Yorum satırları
  final int commentLines;

  /// TODO sayısı
  final int todoCount;

  /// Dil istatistikleri
  final List<LanguageStat> languages;

  const AnalysisResult({
    required this.totalFiles,
    required this.ignoredFiles,
    required this.totalBytes,
    required this.totalLines,
    required this.codeLines,
    required this.commentLines,
    required this.todoCount,
    required this.languages,
  });

  Map<String, dynamic> toMap() => {
        'totalFiles': totalFiles,
        'ignoredFiles': ignoredFiles,
        'totalBytes': totalBytes,
        'totalLines': totalLines,
        'codeLines': codeLines,
        'commentLines': commentLines,
        'todoCount': todoCount,
        'languages': languages.map((e) => e.toMap()).toList(),
      };

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    final rawLanguages = map['languages'];
    final languages = <LanguageStat>[];

    if (rawLanguages is List) {
      for (final item in rawLanguages) {
        if (item is Map) {
          languages.add(
            LanguageStat.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return AnalysisResult(
      totalFiles: _toInt(map['totalFiles']),
      ignoredFiles: _toInt(map['ignoredFiles']),
      totalBytes: _toInt(map['totalBytes']),
      totalLines: _toInt(map['totalLines']),
      codeLines: _toInt(map['codeLines']),
      commentLines: _toInt(map['commentLines']),
      todoCount: _toInt(map['todoCount']),
      languages: List.unmodifiable(languages),
    );
  }

  AnalysisResult copyWith({
    int? totalFiles,
    int? ignoredFiles,
    int? totalBytes,
    int? totalLines,
    int? codeLines,
    int? commentLines,
    int? todoCount,
    List<LanguageStat>? languages,
  }) {
    return AnalysisResult(
      totalFiles: totalFiles ?? this.totalFiles,
      ignoredFiles: ignoredFiles ?? this.ignoredFiles,
      totalBytes: totalBytes ?? this.totalBytes,
      totalLines: totalLines ?? this.totalLines,
      codeLines: codeLines ?? this.codeLines,
      commentLines: commentLines ?? this.commentLines,
      todoCount: todoCount ?? this.todoCount,
      languages: languages ?? this.languages,
    );
  }

  bool get hasLanguages => languages.isNotEmpty;
}
