import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

import '../models/analysis_result.dart';
import 'analysis_service.dart';
import 'file_filter_service.dart';

class ProjectImportResult {
  final String projectName;
  final String primaryLanguage;

  /// GitHub benzeri yüzdelik dil dağılımı
  /// Örnek: {"Dart": 92, "HTML": 8}
  final Map<String, int> languageStats;

  final int fileCount;
  final int totalBytes;
  final String? archiveUrl;

  /// Kod analiz sonucu
  final AnalysisResult analysis;

  ProjectImportResult({
    required this.projectName,
    required this.primaryLanguage,
    required this.languageStats,
    required this.fileCount,
    required this.totalBytes,
    required this.archiveUrl,
    required this.analysis,
  });
}

class ProjectImportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final AnalysisService _analysisService;
  final FileFilterService _filter;

  ProjectImportService({
    AnalysisService? analysisService,
    FileFilterService? filter,
  })  : _filter = filter ?? FileFilterService(),
        _analysisService = analysisService ??
            AnalysisService(filter: filter ?? FileFilterService());

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
    }
    return user.uid;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _firstAvailableInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        final value = _toInt(map[key]);
        if (value != 0) return value;
      }
    }

    for (final key in keys) {
      if (map.containsKey(key)) {
        return _toInt(map[key]);
      }
    }

    return 0;
  }

  /// Statik analiz ekranı için projects/{projectId}.analysis alanını okur.
  Future<AnalysisResult?> getProjectAnalysis(String projectId) async {
    final snap = await _db.collection('projects').doc(projectId).get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final raw = data['analysis'];
    if (raw == null) return null;

    Map<String, dynamic>? analysisMap;
    if (raw is Map<String, dynamic>) {
      analysisMap = raw;
    } else if (raw is Map) {
      analysisMap = Map<String, dynamic>.from(raw);
    }

    if (analysisMap == null) return null;

    var analysis = AnalysisResult.fromMap(analysisMap);

    final topLevelTotalBytes =
        _toInt(data['totalBytes'] ?? data['total_bytes']);
    final topLevelIgnoredFiles =
        _toInt(data['ignoredFiles'] ?? data['ignored_files']);
    final topLevelFileCount = _toInt(data['fileCount'] ?? data['file_count']);

    if (analysis.totalBytes == 0 && topLevelTotalBytes > 0) {
      analysis = analysis.copyWith(totalBytes: topLevelTotalBytes);
    }

    if (analysis.ignoredFiles == 0 && topLevelIgnoredFiles > 0) {
      analysis = analysis.copyWith(ignoredFiles: topLevelIgnoredFiles);
    }

    if (analysis.totalFiles == 0 && topLevelFileCount > 0) {
      analysis = analysis.copyWith(totalFiles: topLevelFileCount);
    }

    return analysis;
  }

  /// GitHub analizine ait ham backend çıktısını okur.
  /// Özellikle llm_analysis, llm_error ve file_summaries gibi alanlar için kullanılır.
  Future<Map<String, dynamic>?> getProjectRawGithubAnalysis(
      String projectId) async {
    final snap = await _db.collection('projects').doc(projectId).get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final raw = data['rawGithubAnalysis'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  /// Sadece LLM analiz metnini döndürür.
  Future<String?> getProjectLlmAnalysis(String projectId) async {
    final raw = await getProjectRawGithubAnalysis(projectId);
    if (raw == null) return null;

    final llmAnalysis = raw['llm_analysis'];
    if (llmAnalysis == null) return null;

    return llmAnalysis.toString().trim().isEmpty
        ? null
        : llmAnalysis.toString();
  }

  /// LLM analiz hatası varsa döndürür.
  Future<String?> getProjectLlmError(String projectId) async {
    final raw = await getProjectRawGithubAnalysis(projectId);
    if (raw == null) return null;

    final llmError = raw['llm_error'];
    if (llmError == null) return null;

    return llmError.toString().trim().isEmpty ? null : llmError.toString();
  }

  /// Web uyumlu içe aktarma:
  /// ZIP bytes -> analiz -> Firestore (+ isteğe bağlı Storage yükleme)
  Future<ProjectImportResult> importZipBytesAsProject({
    required Uint8List bytes,
    required String originalFileName,
  }) async {
    print(
      'İÇE AKTAR DEBUG -> BAŞLANGIÇ dosya=$originalFileName bytes=${bytes.length} uid=$_uid',
    );

    // 1) ZIP çözme
    print('İÇE AKTAR DEBUG -> zip çözme başladı');
    final archive = ZipDecoder().decodeBytes(bytes);
    print(
      'İÇE AKTAR DEBUG -> zip çözme bitti dosyaSayısı=${archive.files.length}',
    );

    // 2) Proje adı belirleme
    final topFolder = _extractTopFolderName(archive) ??
        p.basenameWithoutExtension(originalFileName);

    final projectName = topFolder.trim().isEmpty ? 'proje' : topFolder.trim();

    // 3) Dil yüzdelerini hesaplama
    final stats = _detectLanguagePercentsGitHubLike(archive);
    final isFlutter = _isFlutterArchive(archive);
    final primaryLang = _pickPrimaryLanguageFromPercents(
      stats,
      isFlutter: isFlutter,
    );

    // 4) ZIP içinden path -> bytes map oluşturma
    final filesByPath = <String, List<int>>{};
    int skippedIgnored = 0;
    int skippedNoContent = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;

      final raw = file.name.replaceAll('\\', '/');
      final lower = raw.toLowerCase();

      if (_shouldIgnorePath(lower)) {
        skippedIgnored++;
        continue;
      }

      final content = file.content;
      if (content == null) {
        skippedNoContent++;
        continue;
      }

      if (content is List<int>) {
        filesByPath[raw] = content;
      } else if (content is Uint8List) {
        filesByPath[raw] = content.toList();
      } else {
        try {
          filesByPath[raw] =
              Uint8List.fromList(List<int>.from(content as dynamic)).toList();
        } catch (_) {
          // Tanınmayan içerik biçimleri atlanır.
        }
      }
    }

    print(
      'İÇE AKTAR DEBUG -> çıkarılanDosya=${filesByPath.length} '
      'atlananYokSayilan=$skippedIgnored atlananIcerikYok=$skippedNoContent',
    );

    // 5) Kod analizi
    print('İÇE AKTAR DEBUG -> analiz başladı');
    final analysis = _analysisService.analyzeFiles(filesByPath);
    print(
      'İÇE AKTAR DEBUG -> analiz bitti '
      'toplamDosya=${analysis.totalFiles} '
      'toplamSatir=${analysis.totalLines} '
      'toplamByte=${analysis.totalBytes} '
      'dilSayisi=${analysis.languages.length}',
    );

    // 6) Storage yükleme (isteğe bağlı + zaman aşımı kontrollü)
    String? archiveUrl;
    try {
      print('İÇE AKTAR DEBUG -> yükleme başladı (20 sn zaman aşımı)');
      archiveUrl = await _uploadZipBytes(bytes, projectName, originalFileName)
          .timeout(const Duration(seconds: 20));
      print('İÇE AKTAR DEBUG -> yükleme bitti url=${archiveUrl ?? "YOK"}');
    } catch (e) {
      // Yükleme başarısız olsa bile içe aktarma devam eder.
      print('İÇE AKTAR DEBUG -> yükleme BAŞARISIZ (devam ediliyor) hata=$e');
      archiveUrl = null;
    }

    // 7) Firestore'a yazma
    print('İÇE AKTAR DEBUG -> firestore ekleme başladı');
    await _db.collection('projects').add({
      'name': projectName,
      'ownerId': _uid,
      'primaryLanguage': primaryLang,
      'languageStats': stats,
      'analysis': analysis.toMap(),
      'fileCount': analysis.totalFiles,
      'ignoredFiles': analysis.ignoredFiles,
      'totalBytes':
          analysis.totalBytes > 0 ? analysis.totalBytes : bytes.length,
      'archiveName': originalFileName,
      'archiveUrl': archiveUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'importType': 'zip',
    });
    print('İÇE AKTAR DEBUG -> firestore ekleme tamamlandı');

    return ProjectImportResult(
      projectName: projectName,
      primaryLanguage: primaryLang,
      languageStats: stats,
      fileCount: analysis.totalFiles,
      totalBytes: analysis.totalBytes > 0 ? analysis.totalBytes : bytes.length,
      archiveUrl: archiveUrl,
      analysis: analysis.copyWith(
        totalBytes:
            analysis.totalBytes > 0 ? analysis.totalBytes : bytes.length,
      ),
    );
  }

  /// GitHub üzerinden analiz edilen projeyi Firestore'a kaydeder
  /// ve ekranda kullanılabilecek ortak sonuç yapısını döndürür.
  Future<ProjectImportResult> importGithubProject({
    required String githubUrl,
    required Map<String, dynamic> importData,
    required Map<String, dynamic> analyzeData,
  }) async {
    final languageDistributionRaw = analyzeData['language_distribution'];

    final Map<String, int> languageDistribution = languageDistributionRaw is Map
        ? Map<String, int>.from(
            languageDistributionRaw.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num).toInt(),
              ),
            ),
          )
        : <String, int>{};

    final projectName =
        (importData['name'] ?? importData['full_name'] ?? 'İsimsiz Proje')
            .toString();

    final primaryLanguage = _findPrimaryLanguageFromMap(languageDistribution);

    final analysis = _buildAnalysisResultFromGithubData(
      analyzeData: analyzeData,
      languageDistribution: languageDistribution,
    );

    await _db.collection('projects').add({
      'name': projectName,
      'ownerId': _uid,
      'primaryLanguage': primaryLanguage,
      'languageStats': languageDistribution,
      'analysis': analysis.toMap(),
      'fileCount': analysis.totalFiles,
      'ignoredFiles': analysis.ignoredFiles,
      'totalBytes': analysis.totalBytes,
      'archiveName': null,
      'archiveUrl': null,
      'githubUrl': githubUrl,
      'githubRepoFullName': importData['full_name'],
      'githubDefaultBranch': importData['default_branch'],
      'importType': 'github',
      'rawGithubAnalysis': analyzeData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ProjectImportResult(
      projectName: projectName,
      primaryLanguage: primaryLanguage,
      languageStats: languageDistribution,
      fileCount: analysis.totalFiles,
      totalBytes: analysis.totalBytes,
      archiveUrl: null,
      analysis: analysis,
    );
  }

  AnalysisResult _buildAnalysisResultFromGithubData({
    required Map<String, dynamic> analyzeData,
    required Map<String, int> languageDistribution,
  }) {
    final totalCodeFilesFound = _firstAvailableInt(
        analyzeData, ['total_code_files_found', 'file_count']);
    final totalLines = _firstAvailableInt(
      analyzeData,
      ['total_lines', 'line_count'],
    );
    final nonEmptyLines = _firstAvailableInt(
      analyzeData,
      ['non_empty_lines', 'code_lines'],
    );
    final todoCount = _firstAvailableInt(analyzeData, ['todo_count']);
    final fixmeCount = _firstAvailableInt(analyzeData, ['fixme_count']);
    final totalBytes = _firstAvailableInt(
      analyzeData,
      [
        'total_bytes',
        'total_size',
        'bytes',
        'repository_size',
        'analyzed_bytes',
      ],
    );

    final languages = languageDistribution.entries
        .map(
          (entry) => LanguageStat(
            language: entry.key,
            files: 0,
            bytes: 0,
            lines: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.files.compareTo(a.files));

    return AnalysisResult(
      totalFiles: totalCodeFilesFound,
      ignoredFiles: 0,
      totalBytes: totalBytes,
      totalLines: totalLines,
      codeLines: nonEmptyLines,
      commentLines:
          (totalLines - nonEmptyLines) < 0 ? 0 : (totalLines - nonEmptyLines),
      todoCount: todoCount + fixmeCount,
      languages: languages,
    );
  }

  String _findPrimaryLanguageFromMap(Map<String, int> stats) {
    if (stats.isEmpty) return 'Bilinmiyor';

    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.first.key;
  }

  String? _extractTopFolderName(Archive archive) {
    final paths = archive.files
        .map((file) => file.name)
        .where((name) => name.contains('/'))
        .toList();

    if (paths.isEmpty) return null;

    final counts = <String, int>{};
    for (final path in paths) {
      final first = path.split('/').first.trim();
      if (first.isEmpty) continue;
      counts[first] = (counts[first] ?? 0) + 1;
    }

    if (counts.isEmpty) return null;

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  bool _isFlutterArchive(Archive archive) {
    bool hasFileEnding(String fileName) {
      final target = fileName.toLowerCase();
      return archive.files.any((file) {
        if (!file.isFile) return false;
        final name = file.name.replaceAll('\\', '/').toLowerCase();
        return name.endsWith(target);
      });
    }

    if (hasFileEnding('pubspec.yaml')) return true;

    final hasMainDart = archive.files.any((file) {
      if (!file.isFile) return false;
      final name = file.name.replaceAll('\\', '/').toLowerCase();
      return name.endsWith('lib/main.dart') || name.contains('/lib/main.dart');
    });

    final hasAnalysisOptions = hasFileEnding('analysis_options.yaml');

    final hasAnyDart = archive.files.any((file) {
      if (!file.isFile) return false;
      final name = file.name.replaceAll('\\', '/').toLowerCase();
      return name.endsWith('.dart');
    });

    return hasMainDart || hasAnalysisOptions || hasAnyDart;
  }

  Map<String, int> _detectLanguagePercentsGitHubLike(Archive archive) {
    final extToLang = <String, String>{
      '.dart': 'Dart',
      '.java': 'Java',
      '.kt': 'Kotlin',
      '.py': 'Python',
      '.cs': 'C#',
      '.js': 'JavaScript',
      '.ts': 'TypeScript',
      '.cpp': 'C/C++',
      '.c': 'C/C++',
      '.h': 'C/C++',
      '.hpp': 'C/C++',
      '.swift': 'Swift',
      '.php': 'PHP',
      '.go': 'Go',
      '.rs': 'Rust',
      '.html': 'HTML',
      '.css': 'CSS',
    };

    final isFlutter = _isFlutterArchive(archive);

    final scores = <String, double>{};
    double totalScore = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;

      final raw = file.name.replaceAll('\\', '/');
      final nameLower = raw.toLowerCase();

      if (_shouldIgnorePath(nameLower)) continue;

      final ext = p.extension(nameLower);
      final lang = extToLang[ext];
      if (lang == null) continue;

      final inLib = nameLower.startsWith('lib/') || nameLower.contains('/lib/');
      final weight = inLib ? 5.0 : 1.0;

      scores[lang] = (scores[lang] ?? 0) + weight;
      totalScore += weight;
    }

    if (isFlutter && !scores.containsKey('Dart')) {
      scores['Dart'] = (scores['Dart'] ?? 0) + 1.0;
      totalScore += 1.0;
    }

    if (totalScore <= 0) return {};

    final percents = <String, int>{};
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int sum = 0;
    for (final entry in entries) {
      final pct = ((entry.value / totalScore) * 100).round();
      percents[entry.key] = pct;
      sum += pct;
    }

    if (percents.isNotEmpty && sum != 100) {
      final topLang = entries.first.key;
      percents[topLang] = (percents[topLang] ?? 0) + (100 - sum);
    }

    return percents;
  }

  bool _shouldIgnorePath(String pathLower) {
    final normalized = pathLower.replaceAll('\\', '/');

    if (normalized.endsWith('/.ds_store') || normalized.endsWith('thumbs.db')) {
      return true;
    }

    const ignoreContains = [
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

    for (final token in ignoreContains) {
      if (normalized.contains(token)) return true;
    }

    bool isPlatformFolder(String folder) {
      return normalized.startsWith('$folder/') ||
          normalized.contains('/$folder/');
    }

    if (isPlatformFolder('android') ||
        isPlatformFolder('ios') ||
        isPlatformFolder('windows') ||
        isPlatformFolder('linux') ||
        isPlatformFolder('macos')) {
      return true;
    }

    return false;
  }

  String _pickPrimaryLanguageFromPercents(
    Map<String, int> percents, {
    required bool isFlutter,
  }) {
    if (percents.isEmpty) return 'Bilinmiyor';
    if (isFlutter && (percents['Dart'] ?? 0) > 0) return 'Dart';

    final sorted = percents.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  Future<String?> _uploadZipBytes(
    Uint8List zipBytes,
    String projectName,
    String originalFileName,
  ) async {
    final safeName = p.basenameWithoutExtension(originalFileName);

    final ref = _storage.ref(
      'uploads/$_uid/${DateTime.now().millisecondsSinceEpoch}_${safeName}_$projectName.zip',
    );

    final task = await ref.putData(
      zipBytes,
      SettableMetadata(contentType: 'application/zip'),
    );

    return task.ref.getDownloadURL();
  }
}
