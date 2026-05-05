import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  String get _backendBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  String detectLanguage(String path) {
    final lower = path.toLowerCase();

    for (final entry in _uzantiDilHaritasi.entries) {
      if (lower.endsWith(entry.key)) {
        return entry.value;
      }
    }

    return 'Diğer';
  }

  Future<Map<String, dynamic>> getClocAnalysis() async {
    final response = await http.get(
      Uri.parse('$_backendBaseUrl/cloc/analyze'),
    );

    if (response.statusCode != 200) {
      throw Exception('CLOC verisi alınamadı: ${response.body}');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Beklenmeyen CLOC cevabı alındı.');
    }

    return data;
  }

  List<MapEntry<String, int>> extractTopLanguagesFromCloc(
    Map<String, dynamic> clocResponse, {
    int limit = 6,
  }) {
    final rawData = clocResponse['data'];

    if (rawData is! Map<String, dynamic>) {
      return [];
    }

    final result = <MapEntry<String, int>>[];

    rawData.forEach((key, value) {
      if (key == 'header' || key == 'SUM') return;

      if (value is Map<String, dynamic>) {
        final code = value['code'];
        if (code is num && code > 0) {
          result.add(MapEntry(key, code.toInt()));
        }
      }
    });

    result.sort((a, b) => b.value.compareTo(a.value));

    return result.take(limit).toList();
  }

  AnalysisResult analyzeFiles(Map<String, List<int>> filesByPath) {
    int totalFiles = 0;
    int ignoredFiles = 0;
    int totalBytes = 0;
    int totalLines = 0;
    int codeLines = 0;
    int commentLines = 0;
    int todoCount = 0;

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


