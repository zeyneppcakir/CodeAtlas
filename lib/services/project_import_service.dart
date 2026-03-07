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

  /// GitHub benzeri yüzdeler:
  /// Örn: {"Dart": 92, "HTML": 8}
  final Map<String, int> languageStats;

  final int fileCount;
  final int totalBytes;
  final String? archiveUrl;

  /// ✅ Kod analiz sonucu (LOC, TODO, comment vs.)
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
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  final AnalysisService _analysisService;
  final FileFilterService _filter;

  ProjectImportService({
    AnalysisService? analysisService,
    FileFilterService? filter,
  })  : _filter = filter ?? FileFilterService(),
        _analysisService = analysisService ??
            AnalysisService(filter: filter ?? FileFilterService());

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Oturum yok. Lütfen tekrar giriş yap.');
    return u.uid;
  }

  /// ✅ Statik analiz ekranı için: projects/{projectId}.analysis alanını okur.
  Future<AnalysisResult?> getProjectAnalysis(String projectId) async {
    final snap = await _db.collection('projects').doc(projectId).get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final raw = data['analysis'];
    if (raw is Map<String, dynamic>) {
      return AnalysisResult.fromMap(raw);
    }
    if (raw is Map) {
      return AnalysisResult.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  /// ✅ WEB-uyumlu import: zip bytes -> analiz -> firestore (+opsiyonel storage upload)
  Future<ProjectImportResult> importZipBytesAsProject({
    required Uint8List bytes,
    required String originalFileName,
  }) async {
    print(
        'IMPORT DEBUG -> START file=$originalFileName bytes=${bytes.length} uid=$_uid');

    // 0) Decode
    print('IMPORT DEBUG -> zip decode start');
    final archive = ZipDecoder().decodeBytes(bytes);
    print('IMPORT DEBUG -> zip decode done files=${archive.files.length}');

    // 1) Proje adı
    final topFolder = _extractTopFolderName(archive) ??
        p.basenameWithoutExtension(originalFileName);
    final projectName = topFolder.trim().isEmpty ? 'project' : topFolder.trim();

    // 2) Dil yüzdeleri
    final stats = _detectLanguagePercentsGitHubLike(archive);
    final isFlutter = _isFlutterArchive(archive);
    final primaryLang =
        _pickPrimaryLanguageFromPercents(stats, isFlutter: isFlutter);

    // 3) Zip içinden path -> bytes map çıkar
    final filesByPath = <String, List<int>>{};
    int skippedIgnored = 0;
    int skippedNoContent = 0;

    for (final f in archive.files) {
      if (!f.isFile) continue;

      final raw = f.name.replaceAll('\\', '/');
      final lower = raw.toLowerCase();

      if (_shouldIgnorePath(lower)) {
        skippedIgnored++;
        continue;
      }

      final content = f.content;
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
          // ignore unknown
        }
      }
    }

    print(
        'IMPORT DEBUG -> extracted files=${filesByPath.length} skippedIgnored=$skippedIgnored skippedNoContent=$skippedNoContent');

    // 4) Kod analizi
    print('IMPORT DEBUG -> analysis start');
    final analysis = _analysisService.analyzeFiles(filesByPath);
    print(
        'IMPORT DEBUG -> analysis done totalFiles=${analysis.totalFiles} totalLines=${analysis.totalLines} langs=${analysis.languages.length}');

    // 5) Storage upload (OPSİYONEL + TIMEOUT)
    String? archiveUrl;
    try {
      print('IMPORT DEBUG -> upload start (timeout 20s)');
      archiveUrl = await _uploadZipBytes(bytes, projectName, originalFileName)
          .timeout(const Duration(seconds: 20));
      print('IMPORT DEBUG -> upload done url=${archiveUrl ?? "NULL"}');
    } catch (e) {
      // upload patlasa bile import devam edecek
      print('IMPORT DEBUG -> upload FAILED (continuing) error=$e');
      archiveUrl = null;
    }

    // 6) Firestore’a yaz
    print('IMPORT DEBUG -> firestore add start');
    final ref = await _db.collection('projects').add({
      'name': projectName,
      'ownerId': _uid,
      'primaryLanguage': primaryLang,
      'languageStats': stats,
      'analysis': analysis.toMap(),
      'fileCount': analysis.totalFiles,
      'ignoredFiles': analysis.ignoredFiles,
      'totalBytes': bytes.length,
      'archiveName': originalFileName,
      'archiveUrl': archiveUrl, // null olabilir
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'importType': 'zip',
    });
    print('IMPORT DEBUG -> firestore add done projectId=${ref.id}');

    return ProjectImportResult(
      projectName: projectName,
      primaryLanguage: primaryLang,
      languageStats: stats,
      fileCount: analysis.totalFiles,
      totalBytes: bytes.length,
      archiveUrl: archiveUrl,
      analysis: analysis,
    );
  }

  // -------------------------------
  // ✅ GitHub-benzeri dil tespiti
  // -------------------------------

  String? _extractTopFolderName(Archive a) {
    final paths =
        a.files.map((f) => f.name).where((n) => n.contains('/')).toList();
    if (paths.isEmpty) return null;

    final counts = <String, int>{};
    for (final path in paths) {
      final first = path.split('/').first.trim();
      if (first.isEmpty) continue;
      counts[first] = (counts[first] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    final sorted = counts.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    return sorted.first.key;
  }

  bool _isFlutterArchive(Archive a) {
    bool hasFileEnding(String fileName) {
      final target = fileName.toLowerCase();
      return a.files.any((f) {
        if (!f.isFile) return false;
        final n = f.name.replaceAll('\\', '/').toLowerCase();
        return n.endsWith(target);
      });
    }

    if (hasFileEnding('pubspec.yaml')) return true;

    final hasMainDart = a.files.any((f) {
      if (!f.isFile) return false;
      final n = f.name.replaceAll('\\', '/').toLowerCase();
      return n.endsWith('lib/main.dart') || n.contains('/lib/main.dart');
    });

    final hasAnalysisOptions = hasFileEnding('analysis_options.yaml');

    final hasAnyDart = a.files.any((f) {
      if (!f.isFile) return false;
      final n = f.name.replaceAll('\\', '/').toLowerCase();
      return n.endsWith('.dart');
    });

    return hasMainDart || hasAnalysisOptions || hasAnyDart;
  }

  Map<String, int> _detectLanguagePercentsGitHubLike(Archive a) {
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

    final isFlutter = _isFlutterArchive(a);

    final scores = <String, double>{};
    double totalScore = 0;

    for (final f in a.files) {
      if (!f.isFile) continue;

      final raw = f.name.replaceAll('\\', '/');
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
      ..sort((x, y) => y.value.compareTo(x.value));

    int sum = 0;
    for (final e in entries) {
      final pct = ((e.value / totalScore) * 100).round();
      percents[e.key] = pct;
      sum += pct;
    }

    if (percents.isNotEmpty && sum != 100) {
      final topLang = entries.first.key;
      percents[topLang] = (percents[topLang] ?? 0) + (100 - sum);
    }

    return percents;
  }

  bool _shouldIgnorePath(String pathLower) {
    final pth = pathLower.replaceAll('\\', '/');

    if (pth.endsWith('/.ds_store') || pth.endsWith('thumbs.db')) return true;

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
      if (pth.contains(token)) return true;
    }

    bool isPlatformFolder(String folder) {
      return pth.startsWith('$folder/') || pth.contains('/$folder/');
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
    if (percents.isEmpty) return 'Unknown';
    if (isFlutter && (percents['Dart'] ?? 0) > 0) return 'Dart';

    final sorted = percents.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
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
