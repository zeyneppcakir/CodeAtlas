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

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt(); // double/num -> int
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory LanguageStat.fromMap(Map<String, dynamic> m) => LanguageStat(
        language: (m['language'] ?? '').toString(),
        files: _toInt(m['files']),
        bytes: _toInt(m['bytes']),
        lines: _toInt(m['lines']),
      );
}

class AnalysisResult {
  final int totalFiles;
  final int ignoredFiles;
  final int totalBytes;
  final int totalLines;
  final int codeLines;
  final int commentLines;
  final int todoCount;
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

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory AnalysisResult.fromMap(Map<String, dynamic> m) {
    final rawLangs = (m['languages'] ?? []);

    final langs = <LanguageStat>[];
    if (rawLangs is List) {
      for (final e in rawLangs) {
        if (e is Map) {
          langs.add(LanguageStat.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    return AnalysisResult(
      totalFiles: _toInt(m['totalFiles']),
      ignoredFiles: _toInt(m['ignoredFiles']),
      totalBytes: _toInt(m['totalBytes']),
      totalLines: _toInt(m['totalLines']),
      codeLines: _toInt(m['codeLines']),
      commentLines: _toInt(m['commentLines']),
      todoCount: _toInt(m['todoCount']),
      languages: langs,
    );
  }
}
