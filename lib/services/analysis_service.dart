import 'dart:convert';

import '../models/analysis_result.dart';
import 'file_filter_service.dart';

class AnalysisService {
  final FileFilterService filter;

  AnalysisService({FileFilterService? filter})
      : filter = filter ?? FileFilterService();

  static const Map<String, String> _uzantiDilHaritasi = {
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
    '.h': 'C/C++ Başlık',
    '.cpp': 'C++',
    '.go': 'Go',
    '.rs': 'Rust',
    '.php': 'PHP',
    '.sql': 'SQL',
  };

  String detectLanguage(String path) {
    final lower = path.toLowerCase();

    for (final entry in _uzantiDilHaritasi.entries) {
      if (lower.endsWith(entry.key)) {
        return entry.value;
      }
    }

    return 'Diğer';
  }

  AnalysisResult analyzeFiles(Map<String, List<int>> filesByPath) {
    int totalFiles = 0;
    int ignoredFiles = 0;
    int totalBytes = 0;
    int totalLines = 0;
    int codeLines = 0;
    int commentLines = 0;
    int todoCount = 0;

    // Dil bazlı toplu istatistik
    final Map<String, ({int files, int bytes, int lines})> languageAggregates =
        {};

    for (final entry in filesByPath.entries) {
      final path = entry.key;
      final bytes = entry.value;

      if (filter.shouldIgnorePath(path)) {
        ignoredFiles++;
        continue;
      }

      totalFiles++;
      totalBytes += bytes.length;

      // Binary dosyalarda satır bazlı analiz yapılmaz
      if (filter.looksBinary(bytes)) {
        const language = 'Binary';
        final previous = languageAggregates[language];

        languageAggregates[language] = (
          files: (previous?.files ?? 0) + 1,
          bytes: (previous?.bytes ?? 0) + bytes.length,
          lines: (previous?.lines ?? 0),
        );
        continue;
      }

      final text = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(text);

      final language = detectLanguage(path);
      final previous = languageAggregates[language];

      languageAggregates[language] = (
        files: (previous?.files ?? 0) + 1,
        bytes: (previous?.bytes ?? 0) + bytes.length,
        lines: (previous?.lines ?? 0) + lines.length,
      );

      totalLines += lines.length;

      for (final line in lines) {
        final trimmed = line.trim();

        if (trimmed.isEmpty) continue;

        final isComment = trimmed.startsWith('//') ||
            trimmed.startsWith('#') ||
            trimmed.startsWith('/*') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('--');

        if (isComment) {
          commentLines++;
        } else {
          codeLines++;
        }

        final upper = trimmed.toUpperCase();

        if (upper.contains('TODO') || upper.contains('FIXME')) {
          todoCount++;
        }
      }
    }

    final languageStats = languageAggregates.entries
        .map(
          (entry) => LanguageStat(
            language: entry.key,
            files: entry.value.files,
            bytes: entry.value.bytes,
            lines: entry.value.lines,
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
