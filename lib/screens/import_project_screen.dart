import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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

      // ✅ ZIP bytes oku (bytes/path/stream fallback)
      final Uint8List zipBytes = await _readZipBytes(picked);

      // zip aç
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // en üst klasör adı
      final projectName =
          _extractTopFolderName(archive) ?? _fallbackName(picked.name);

      // dil tespiti + istatistik
      final stats = _languageStatsFromArchive(archive);
      final primary = _pickPrimaryLanguage(stats);

      // firestore proje oluştur
      await _projectService.addProject(
        name: projectName,
        primaryLanguage: primary,
      );

      // ekranda göster
      final totalFiles = _countFiles(archive);

      setState(() {
        _projectName = projectName;
        _primaryLanguage = primary;
        _fileCount = totalFiles;
        _languageStats = stats;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proje oluşturuldu: $projectName ($primary)'),
        ),
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

  int _countFiles(Archive archive) {
    int c = 0;
    for (final f in archive) {
      final name = f.name.toLowerCase();
      if (!name.endsWith('/')) c++;
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
        title: const Text('Proje Yükle (ZIP)'),
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
                onPressed: _loading ? null : _pickZipAndImport,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                    _loading ? 'Yükleniyor...' : 'ZIP Seç ve Proje Oluştur'),
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
                      Text('Dil: ${_primaryLanguage ?? '-'}',
                          style: const TextStyle(color: AppColors.textSoft)),
                      Text('Dosya sayısı: ${_fileCount ?? 0}',
                          style: const TextStyle(color: AppColors.textSoft)),
                      const SizedBox(height: 10),
                      Text('Dil dağılımı: ${_languageStats ?? {}}',
                          style: const TextStyle(color: AppColors.textSoft)),
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
                      MaterialPageRoute(builder: (_) => ProjectsScreen()),
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
