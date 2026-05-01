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

  static String _toStr(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  factory LanguageStat.fromMap(Map<String, dynamic> map) {
    return LanguageStat(
      language: _toStr(map['language']),
      files: _toInt(map['files'] ?? map['file_count']),
      bytes: _toInt(map['bytes'] ?? map['total_bytes']),
      lines: _toInt(map['lines'] ?? map['line_count']),
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
    final rawLanguages = map['languages'] ?? map['language_distribution'];
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
    } else if (rawLanguages is Map) {
      rawLanguages.forEach((key, value) {
        if (value is Map) {
          languages.add(
            LanguageStat(
              language: key.toString(),
              files: _toInt(value['files'] ?? value['file_count']),
              bytes: _toInt(value['bytes'] ?? value['total_bytes']),
              lines: _toInt(value['lines'] ?? value['line_count']),
            ),
          );
        }
      });
    }

    return AnalysisResult(
      totalFiles: _toInt(map['totalFiles'] ?? map['total_files']),
      ignoredFiles: _toInt(map['ignoredFiles'] ?? map['ignored_files']),
      totalBytes: _toInt(map['totalBytes'] ?? map['total_bytes']),
      totalLines: _toInt(map['totalLines'] ?? map['total_lines']),
      codeLines: _toInt(map['codeLines'] ?? map['code_lines']),
      commentLines: _toInt(map['commentLines'] ?? map['comment_lines']),
      todoCount: _toInt(map['todoCount'] ?? map['todo_count']),
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
