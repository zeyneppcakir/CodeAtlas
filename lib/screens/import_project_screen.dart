import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../services/project_service.dart';
import 'projects_screen.dart';

class ImportProjectScreen extends StatefulWidget {
  const ImportProjectScreen({super.key});

  @override
  State<ImportProjectScreen> createState() => _ImportProjectScreenState();
}

class _ImportProjectScreenState extends State<ImportProjectScreen> {
  bool _loading = false;

  // ekranda göstermek için
  String? _projectName;
  String? _primaryLanguage;
  int? _fileCount;

  /// GitHub benzeri yüzde dağılımı: {'Dart': 92, 'HTML': 8}
  Map<String, int>? _languageStats;

  final _projectService = ProjectService();

  // ---------------- ZIP okuma ----------------

  /// ✅ En stabil okuma: path üzerinden oku.
  /// (withData=true kullanınca büyük ziplerde RAM patlayıp app kapanabiliyor)
  Future<Uint8List> _readZipBytesFromPath(PlatformFile picked) async {
    final path = picked.path;
    if (path == null || path.trim().isEmpty) {
      throw Exception(
        'Dosya yolu alınamadı.\n'
        'ZIP’i mümkünse Downloads içinden seçmeyi dene (Drive/Recent bazen path vermez).',
      );
    }
    return File(path).readAsBytes();
  }

  // ---------------- Hoca isteği: klasör seç -> ZIP oluştur ----------------

  Future<File> _zipDirectoryToTemp({
    required String dirPath,
    required String zipName,
  }) async {
    final root = Directory(dirPath);
    if (!await root.exists()) {
      throw Exception('Klasör bulunamadı: $dirPath');
    }

    final archive = Archive();

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final rel = entity.path
          .substring(dirPath.length)
          .replaceFirst(RegExp(r'^[\\/]+'), '')
          .replaceAll('\\', '/');

      if (rel.isEmpty) continue;
      if (_shouldIgnorePath(rel)) continue;

      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }

    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) throw Exception('ZIP oluşturulamadı');

    final tempDir = await getTemporaryDirectory();
    final safeName = zipName.trim().isEmpty ? 'project' : zipName.trim();
    final outFile = File('${tempDir.path}/$safeName.zip');
    await outFile.writeAsBytes(zipped, flush: true);

    return outFile;
  }

  // ---------------- import işlemi (zip bytes -> analiz -> firestore) ----------------

  Future<void> _importFromZipBytes({
    required Uint8List zipBytes,
    required String fallbackName,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final projectName =
        _extractTopFolderName(archive) ?? _fallbackName(fallbackName);

    // ✅ GitHub’a daha yakın: bytes bazlı dil yüzdesi
    final statsBytes = _languageBytesFromArchive(archive);
    final statsPercents = _bytesToPercents(statsBytes);

    // ✅ Flutter heuristics: pubspec.yaml varsa Dart diyebiliriz (çok mantıklı)
    final isFlutter = _looksLikeFlutterProject(archive);

    final primary = isFlutter ? 'Dart' : _pickPrimaryLanguage(statsPercents);

    final totalFiles = _countFiles(archive);

    await _projectService.addProject(
      name: projectName,
      primaryLanguage: primary,
    );

    setState(() {
      _projectName = projectName;
      _primaryLanguage = primary;
      _fileCount = totalFiles;
      _languageStats = statsPercents;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Proje oluşturuldu: $projectName ($primary)')),
    );
  }

  // ---------------- UI actions ----------------

  Future<void> _pickZipAndImport() async {
    setState(() => _loading = true);

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: false, // ✅ RAM'e alma
      );

      if (res == null || res.files.isEmpty) return;

      final picked = res.files.single;
      final zipBytes = await _readZipBytesFromPath(picked);

      await _importFromZipBytes(
        zipBytes: zipBytes,
        fallbackName: picked.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFolderAndImport() async {
    setState(() => _loading = true);

    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null || dirPath.trim().isEmpty) return;

      final folderName = _safeFolderNameFromPath(dirPath);

      final zipFile = await _zipDirectoryToTemp(
        dirPath: dirPath,
        zipName: folderName,
      );

      final zipBytes = await zipFile.readAsBytes();

      await _importFromZipBytes(
        zipBytes: zipBytes,
        fallbackName: folderName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- helpers ----------------

  String _safeFolderNameFromPath(String dirPath) {
    final segments = Directory(dirPath).uri.pathSegments;
    final last = segments.isNotEmpty
        ? segments.lastWhere((e) => e.isNotEmpty, orElse: () => 'project')
        : 'project';
    final cleaned = last.trim();
    return cleaned.isEmpty ? 'project' : cleaned;
  }

  String _fallbackName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.zip')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
  }

  String? _extractTopFolderName(Archive archive) {
    for (final f in archive) {
      final n = f.name;
      if (n.contains('/')) {
        final top = n.split('/').first.trim();
        if (top.isNotEmpty) return top;
      }
    }
    return null;
  }

  // ✅ Dil tespitinde SADECE gerçek kaynak kod klasörlerine bak
  bool _isRelevantForLanguageDetection(String path) {
    final p = path.replaceAll('\\', '/').toLowerCase();

    if (p.startsWith('lib/')) return true;
    if (p.startsWith('test/')) return true;
    if (p.startsWith('tool/')) return true;
    if (p.startsWith('bin/')) return true;
    if (p.startsWith('web/')) return true;

    return false; // android/ios/windows/macos/linux dahil değil
  }

  // ✅ Flutter tespiti (pubspec.yaml -> Dart ağırlıklı kabul)
  bool _looksLikeFlutterProject(Archive archive) {
    for (final f in archive) {
      final name = f.name.replaceAll('\\', '/').toLowerCase();
      if (name.endsWith('pubspec.yaml')) return true;
    }
    return false;
  }

  // ✅ "git/build/node_modules vs" filtre
  bool _shouldIgnorePath(String path) {
    final p = path.replaceAll('\\', '/').toLowerCase();

    const ignoreFolderStarts = <String>[
      '.git/',
      '.github/',
      '.idea/',
      '.vscode/',
      '.dart_tool/',
      '.gradle/',
      'node_modules/',
      'pods/',
      'build/',
      'dist/',
      'target/',
      'coverage/',
      '__pycache__/',
    ];

    for (final s in ignoreFolderStarts) {
      if (p.startsWith(s)) return true;
    }

    const ignoreFolders = <String>[
      '/.git/',
      '/.github/',
      '/.idea/',
      '/.vscode/',
      '/.dart_tool/',
      '/.gradle/',
      '/.svn/',
      '/.hg/',
      '/.vs/',
      '/.settings/',
      '/.terraform/',
      '/.next/',
      '/.nuxt/',
      '/.angular/',
      '/.expo/',
      '/.pytest_cache/',
      '/__pycache__/',
      '/node_modules/',
      '/packages/',
      '/vendor/',
      '/pods/',
      '/carthage/',
      '/build/',
      '/dist/',
      '/target/',
      '/out/',
      '/bin/',
      '/obj/',
      '/coverage/',
      '/.firebase/',
      '/.venv/',
      '/venv/',
    ];

    for (final s in ignoreFolders) {
      if (p.contains(s)) return true;
    }

    const ignoreFiles = <String>[
      '.ds_store',
      'thumbs.db',
      'pubspec.lock',
      'package-lock.json',
      'yarn.lock',
      'pnpm-lock.yaml',
      'podfile.lock',
    ];

    final base = p.split('/').last;
    if (ignoreFiles.contains(base)) return true;

    return false;
  }

  int _countFiles(Archive archive) {
    int c = 0;
    for (final f in archive) {
      final name = f.name;
      if (name.toLowerCase().endsWith('/')) continue;
      if (_shouldIgnorePath(name)) continue;
      c++;
    }
    return c;
  }

  /// ✅ Dil tespiti: bytes bazlı (GitHub benzeri)
  /// 🔥 Burada en kritik şey: android/ios/windows gibi klasörleri SAYMAMAK
  Map<String, int> _languageBytesFromArchive(Archive archive) {
    final stats = <String, int>{
      'Dart': 0,
      'Java': 0,
      'Kotlin': 0,
      'Python': 0,
      'C#': 0,
      'JavaScript': 0,
      'TypeScript': 0,
      'C/C++': 0,
      'HTML': 0,
      'CSS': 0,
    };

    for (final f in archive) {
      final name = f.name.replaceAll('\\', '/').toLowerCase();
      if (name.endsWith('/')) continue;
      if (_shouldIgnorePath(name)) continue;

      // ✅ kritik filtre: sadece kaynak kod klasörleri
      if (!_isRelevantForLanguageDetection(name)) continue;

      final size = f.size;

      if (name.endsWith('.dart')) {
        stats['Dart'] = stats['Dart']! + size;
      } else if (name.endsWith('.java')) {
        stats['Java'] = stats['Java']! + size;
      } else if (name.endsWith('.kt')) {
        stats['Kotlin'] = stats['Kotlin']! + size;
      } else if (name.endsWith('.py')) {
        stats['Python'] = stats['Python']! + size;
      } else if (name.endsWith('.cs')) {
        stats['C#'] = stats['C#']! + size;
      } else if (name.endsWith('.js')) {
        stats['JavaScript'] = stats['JavaScript']! + size;
      } else if (name.endsWith('.ts')) {
        stats['TypeScript'] = stats['TypeScript']! + size;
      } else if (name.endsWith('.c') ||
          name.endsWith('.cpp') ||
          name.endsWith('.h') ||
          name.endsWith('.hpp')) {
        stats['C/C++'] = stats['C/C++']! + size;
      } else if (name.endsWith('.html')) {
        stats['HTML'] = stats['HTML']! + size;
      } else if (name.endsWith('.css')) {
        stats['CSS'] = stats['CSS']! + size;
      }
    }

    stats.removeWhere((k, v) => v <= 0);
    return stats;
  }

  /// Bytes -> yüzde (0..100). GitHub benzeri görünüm için.
  Map<String, int> _bytesToPercents(Map<String, int> bytes) {
    if (bytes.isEmpty) return {};

    final total = bytes.values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return {};

    final entries = bytes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final percents = <String, int>{};
    int sum = 0;

    for (final e in entries) {
      final p = ((e.value / total) * 100).round();
      percents[e.key] = p;
      sum += p;
    }

    if (percents.isNotEmpty && sum != 100) {
      final topKey = entries.first.key;
      percents[topKey] = (percents[topKey] ?? 0) + (100 - sum);
      if ((percents[topKey] ?? 0) < 0) percents[topKey] = 0;
    }

    percents.removeWhere((k, v) => v <= 0);
    return percents;
  }

  String _pickPrimaryLanguage(Map<String, int> percents) {
    if (percents.isEmpty) return 'Bilinmiyor';

    String best = percents.keys.first;
    int bestVal = percents[best] ?? 0;

    percents.forEach((k, v) {
      if (v > bestVal) {
        best = k;
        bestVal = v;
      }
    });

    return bestVal <= 0 ? 'Bilinmiyor' : best;
  }

  String _formatLanguageBreakdown(Map<String, int>? stats, {int maxItems = 4}) {
    if (stats == null || stats.isEmpty) return '-';

    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(maxItems);
    return top.map((e) => '${e.key} %${e.value}').join(' • ');
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Proje İçe Aktar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.black,
                ),
                onPressed: _loading ? null : _pickFolderAndImport,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(
                  _loading
                      ? 'Yükleniyor...'
                      : 'Klasör Seç (Uygulama ZIP’lesin)',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _pickZipAndImport,
                icon: const Icon(Icons.upload_file),
                label: const Text('ZIP Seç (Eski yöntem)'),
              ),
            ),
            const SizedBox(height: 16),
            if (_projectName != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _projectName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Primary: ${_primaryLanguage ?? '-'}',
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                      Text(
                        'Dosya sayısı: ${_fileCount ?? 0}',
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dil dağılımı: ${_formatLanguageBreakdown(_languageStats)}',
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const ProjectsScreen()),
                      (_) => false,
                    );
                  },
                  child: const Text('Projelerim’e Git'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
