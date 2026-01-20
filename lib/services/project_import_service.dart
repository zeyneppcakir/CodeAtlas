import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class ProjectImportResult {
  final String projectName;
  final String primaryLanguage;

  /// GitHub benzeri istatistik:
  /// Örn: {"Dart": 92, "HTML": 8}
  final Map<String, int> languageStats;

  final int fileCount;
  final int totalBytes;
  final String? archiveUrl;

  ProjectImportResult({
    required this.projectName,
    required this.primaryLanguage,
    required this.languageStats,
    required this.fileCount,
    required this.totalBytes,
    required this.archiveUrl,
  });
}

class ProjectImportService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Oturum yok. Lütfen tekrar giriş yap.');
    return u.uid;
  }

  /// ZIP seçildikten sonra bunu çağıracağız.
  Future<ProjectImportResult> importZipAsProject(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1) En üst klasör adı = proje adı
    final topFolder = _extractTopFolderName(archive) ??
        p.basenameWithoutExtension(zipFile.path);
    final projectName = topFolder.trim().isEmpty ? 'project' : topFolder.trim();

    // 2) GitHub benzeri dil tespiti (Flutter öncelikli + ignore + ağırlık)
    final stats = _detectLanguagePercentsGitHubLike(archive);

    // Flutter tespiti (primaryLanguage kilitlemek için)
    final isFlutter = _isFlutterArchive(archive);

    final primaryLang = _pickPrimaryLanguageFromPercents(
      stats,
      isFlutter: isFlutter,
    );

    // 3) Storage’a ZIP upload (opsiyonel)
    final archiveUrl = await _uploadZip(zipFile, projectName);

    // 4) Firestore’a yaz
    await _db.collection('projects').add({
      'name': projectName,
      'ownerId': _uid,
      'primaryLanguage': primaryLang,
      'languageStats': stats, // {"Dart": 92, "HTML": 8}
      'fileCount': _countFiles(archive),
      'archiveName': p.basename(zipFile.path),
      'archiveUrl': archiveUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'importType': 'zip',
    });

    return ProjectImportResult(
      projectName: projectName,
      primaryLanguage: primaryLang,
      languageStats: stats,
      fileCount: _countFiles(archive),
      totalBytes: bytes.length,
      archiveUrl: archiveUrl,
    );
  }

  int _countFiles(Archive a) => a.files.where((f) => f.isFile).length;

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
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  // -------------------------------
  // ✅ GitHub-benzeri dil tespiti
  // -------------------------------

  bool _isFlutterArchive(Archive a) {
    bool hasFileEnding(String fileName) {
      final target = fileName.toLowerCase();
      return a.files.any((f) {
        if (!f.isFile) return false;
        final n = f.name.replaceAll('\\', '/').toLowerCase();
        return n.endsWith(target);
      });
    }

    // pubspec.yaml en güçlü sinyal
    if (hasFileEnding('pubspec.yaml')) return true;

    // destekleyici sinyaller
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

      // Ignore
      if (_shouldIgnorePath(nameLower)) continue;

      final ext = p.extension(nameLower);
      final lang = extToLang[ext];
      if (lang == null) continue;

      // Ağırlıklar:
      // - lib/ altı: 5x (Flutter projede Dart net çıksın)
      // - diğerleri: 1x
      final inLib = nameLower.startsWith('lib/') || nameLower.contains('/lib/');
      final weight = inLib ? 5.0 : 1.0;

      scores[lang] = (scores[lang] ?? 0) + weight;
      totalScore += weight;
    }

    // Flutter ise ama Dart çıkmadıysa, Dart'ı küçük payla ekle
    if (isFlutter && !scores.containsKey('Dart')) {
      scores['Dart'] = (scores['Dart'] ?? 0) + 1.0;
      totalScore += 1.0;
    }

    if (totalScore <= 0) return {};

    final percents = <String, int>{};
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int sum = 0;
    for (final e in entries) {
      final pct = ((e.value / totalScore) * 100).round();
      percents[e.key] = pct;
      sum += pct;
    }

    // rounding düzeltmesi
    if (percents.isNotEmpty && sum != 100) {
      final topLang = entries.first.key;
      percents[topLang] = (percents[topLang] ?? 0) + (100 - sum);
    }

    return percents;
  }

  bool _shouldIgnorePath(String pathLower) {
    // normalize
    final pth = pathLower.replaceAll('\\', '/');

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

    // ✅ Platform klasörleri: hem "android/..." hem "/android/..." yakala
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

    // ✅ Flutter projelerinde Dart varsa primary her zaman Dart
    if (isFlutter && (percents['Dart'] ?? 0) > 0) {
      return 'Dart';
    }

    final sorted = percents.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Future<String?> _uploadZip(File zipFile, String projectName) async {
    final ref = _storage.ref(
      'uploads/${_uid}/${DateTime.now().millisecondsSinceEpoch}_$projectName.zip',
    );
    final task = await ref.putFile(
      zipFile,
      SettableMetadata(contentType: 'application/zip'),
    );
    return task.ref.getDownloadURL();
  }
}
