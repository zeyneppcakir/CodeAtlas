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
  Map<String, int>? _languageStats;

  final _projectService = ProjectService();

  // ---------------- ZIP okuma ----------------

  Future<Uint8List> _readZipBytes(PlatformFile picked) async {
    // 1) bytes varsa direkt
    if (picked.bytes != null) return picked.bytes!;

    // 2) path varsa dosyadan oku
    if (picked.path != null) {
      final file = File(picked.path!);
      return await file.readAsBytes();
    }

    // 3) stream varsa oku
    if (picked.readStream != null) {
      final chunks = <int>[];
      await for (final data in picked.readStream!) {
        chunks.addAll(data);
      }
      return Uint8List.fromList(chunks);
    }

    throw Exception(
      'ZIP okunamadı: dosya yolu (path) ve bytes/stream alınamadı.\n'
      'Not: Drive/Recent yerine Downloads içinden seçmeyi dene.',
    );
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

    // recursive dosya gez
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      // root'a göre relative path üret
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
    final outFile = File('${tempDir.path}/$zipName.zip');
    await outFile.writeAsBytes(zipped, flush: true);

    return outFile;
  }

  // ---------------- import işlemi (zip bytes -> analiz -> firestore) ----------------

  Future<void> _importFromZipBytes({
    required Uint8List zipBytes,
    required String fallbackName,
  }) async {
    // zip aç
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // en üst klasör adı
    final projectName =
        _extractTopFolderName(archive) ?? _fallbackName(fallbackName);

    // ✅ filtreli dil tespiti + istatistik
    final stats = _languageStatsFromArchive(archive);
    final primary = _pickPrimaryLanguage(stats);

    // firestore proje oluştur
    await _projectService.addProject(
      name: projectName,
      primaryLanguage: primary,
      // Eğer ProjectService destekliyorsa:
      // languageStats: _normalizePercents(stats),
    );

    // ekranda göster (✅ filtreli dosya sayısı)
    final totalFiles = _countFiles(archive);

    setState(() {
      _projectName = projectName;
      _primaryLanguage = primary;
      _fileCount = totalFiles;
      _languageStats = stats;
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
        withData: true, // ✅ bytes gelsin
        withReadStream: true, // ✅ stream yedek olsun
      );

      if (res == null || res.files.isEmpty) return;

      final picked = res.files.single;
      final zipBytes = await _readZipBytes(picked);

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
      // ✅ klasör seç
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null || dirPath.trim().isEmpty) return;

      final folderName = Directory(dirPath).uri.pathSegments.isNotEmpty
          ? Directory(dirPath).uri.pathSegments.lastWhere((e) => e.isNotEmpty)
          : 'project';

      // ✅ klasörü zipleyip temp'e yaz
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

  Map<String, int> _languageStatsFromArchive(Archive archive) {
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
      final name = f.name.toLowerCase();
      if (name.endsWith('/')) continue;
      if (_shouldIgnorePath(name)) continue;

      if (name.endsWith('.dart')) {
        stats['Dart'] = stats['Dart']! + 1;
      } else if (name.endsWith('.java')) {
        stats['Java'] = stats['Java']! + 1;
      } else if (name.endsWith('.kt')) {
        stats['Kotlin'] = stats['Kotlin']! + 1;
      } else if (name.endsWith('.py')) {
        stats['Python'] = stats['Python']! + 1;
      } else if (name.endsWith('.cs')) {
        stats['C#'] = stats['C#']! + 1;
      } else if (name.endsWith('.js')) {
        stats['JavaScript'] = stats['JavaScript']! + 1;
      } else if (name.endsWith('.ts')) {
        stats['TypeScript'] = stats['TypeScript']! + 1;
      } else if (name.endsWith('.c') ||
          name.endsWith('.cpp') ||
          name.endsWith('.h') ||
          name.endsWith('.hpp')) {
        stats['C/C++'] = stats['C/C++']! + 1;
      } else if (name.endsWith('.html')) {
        stats['HTML'] = stats['HTML']! + 1;
      } else if (name.endsWith('.css')) {
        stats['CSS'] = stats['CSS']! + 1;
      }
    }

    stats.removeWhere((k, v) => v == 0);
    return stats;
  }

  String _pickPrimaryLanguage(Map<String, int> stats) {
    if (stats.isEmpty) return 'Bilinmiyor';

    String best = stats.keys.first;
    int bestVal = stats[best] ?? 0;

    stats.forEach((k, v) {
      if (v > bestVal) {
        best = k;
        bestVal = v;
      }
    });

    return bestVal == 0 ? 'Bilinmiyor' : best;
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
                        'Dil: ${_primaryLanguage ?? '-'}',
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                      Text(
                        'Dosya sayısı: ${_fileCount ?? 0}',
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dil dağılımı: ${_languageStats ?? {}}',
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
