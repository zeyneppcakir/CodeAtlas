import 'dart:convert';

import '../models/analysis_result.dart';
import 'file_filter_service.dart';

class AnalysisService {
  final FileFilterService filter;

  AnalysisService({FileFilterService? filter})
      : filter = filter ?? FileFilterService();

  static const Map<String, String> _extToLang = {
    '.dart': 'Dart',
    '.java': 'Java',
    '.kt': 'Kotlin',
    '.py': 'Python',
    '.js': 'JavaScript',
    '.ts': 'TypeScript',
    '.html': 'HTML',
    '.css': 'CSS',
    '.json': 'JSON',
    '.yml': 'YAML',
    '.yaml': 'YAML',
    '.xml': 'XML',
    '.md': 'Markdown',
    '.cs': 'C#',
    '.c': 'C',
    '.h': 'C/C++ Header',
    '.cpp': 'C++',
    '.go': 'Go',
    '.rs': 'Rust',
    '.php': 'PHP',
    '.sql': 'SQL',
  };

  String detectLanguage(String path) {
    final lower = path.toLowerCase();
    for (final e in _extToLang.entries) {
      if (lower.endsWith(e.key)) return e.value;
    }
    return 'Other';
  }

  AnalysisResult analyzeFiles(Map<String, List<int>> filesByPath) {
    int totalFiles = 0;
    int ignoredFiles = 0;

    int totalBytes = 0;
    int totalLines = 0;
    int codeLines = 0;
    int commentLines = 0;
    int todoCount = 0;

    // Dart 3 record: dil bazında aggregate
    final Map<String, ({int files, int bytes, int lines})> langAgg = {};

    for (final entry in filesByPath.entries) {
      final path = entry.key;
      final bytes = entry.value;

      if (filter.shouldIgnorePath(path)) {
        ignoredFiles++;
        continue;
      }

      totalFiles++;
      totalBytes += bytes.length;

      // Binary ise satır sayımı yapma
      if (filter.looksBinary(bytes)) {
        const lang = 'Binary';
        final prev = langAgg[lang];
        langAgg[lang] = (
          files: (prev?.files ?? 0) + 1,
          bytes: (prev?.bytes ?? 0) + bytes.length,
          lines: (prev?.lines ?? 0),
        );
        continue;
      }

      final text = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(text);

      final lang = detectLanguage(path);
      final prev = langAgg[lang];
      langAgg[lang] = (
        files: (prev?.files ?? 0) + 1,
        bytes: (prev?.bytes ?? 0) + bytes.length,
        lines: (prev?.lines ?? 0) + lines.length,
      );

      totalLines += lines.length;

      for (final line in lines) {
        final t = line.trim();
        if (t.isEmpty) continue;

        // Basit comment tespiti (dil bağımsız, kaba)
        final isComment = t.startsWith('//') ||
            t.startsWith('#') ||
            t.startsWith('/*') ||
            t.startsWith('*') ||
            t.startsWith('--'); // SQL

        if (isComment) {
          commentLines++;
        } else {
          codeLines++;
        }

        final up = t.toUpperCase();
        if (up.contains('TODO') || up.contains('FIXME')) todoCount++;
      }
    }

    final languageStats = langAgg.entries
        .map(
          (e) => LanguageStat(
            language: e.key,
            files: e.value.files,
            bytes: e.value.bytes,
            lines: e.value.lines,
          ),
        )
        .toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));

    return AnalysisResult(
      totalFiles: totalFiles,
      ignoredFiles: ignoredFiles,
      totalBytes: totalBytes,
      totalLines: totalLines,
      codeLines: codeLines,
      commentLines: commentLines,
      todoCount: todoCount,
      languages: languageStats,
    );
  }
}
