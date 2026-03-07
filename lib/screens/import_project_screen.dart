import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/project_import_service.dart';
import 'projects_screen.dart';

class ImportProjectScreen extends StatefulWidget {
  const ImportProjectScreen({super.key});

  @override
  State<ImportProjectScreen> createState() => _ImportProjectScreenState();
}

class _ImportProjectScreenState extends State<ImportProjectScreen> {
  bool _loading = false;

  String? _projectName;
  String? _primaryLanguage;
  int? _fileCount;
  Map<String, int>? _languageStats;

  final _importService = ProjectImportService();

  /// WEB: bytes kesin lazım (withData:true)
  /// Diğer platformlarda bytes null gelirse readStream'den topla
  Future<Uint8List> _readZipBytes(PlatformFile picked) async {
    final b = picked.bytes;
    if (b != null) return b;

    final stream = picked.readStream;
    if (stream != null) {
      final chunks = <int>[];
      await for (final data in stream) {
        chunks.addAll(data);
      }
      return Uint8List.fromList(chunks);
    }

    throw Exception(
      'ZIP okunamadı.\n'
      'Web: pickFiles(withData:true) şart.\n'
      'Diğer: pickFiles(withReadStream:true) ile dene.',
    );
  }

  Future<void> _importFromZipBytes({
    required Uint8List zipBytes,
    required String originalFileName,
  }) async {
    final result = await _importService.importZipBytesAsProject(
      bytes: zipBytes,
      originalFileName: originalFileName,
    );

    if (!mounted) return;

    setState(() {
      _projectName = result.projectName;
      _primaryLanguage = result.primaryLanguage;
      _fileCount = result.fileCount;
      _languageStats = result.languageStats;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Import tamam ✅ ${result.projectName} (${result.primaryLanguage})'),
      ),
    );
  }

  Future<void> _pickZipAndImport() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],

        // ✅ WEB’de en stabil kombinasyon:
        // bytes al, stream açma (bazı tarayıcılarda takılıyor)
        withData: true,
        withReadStream: !kIsWeb,
      );

      if (res == null || res.files.isEmpty) return;

      final picked = res.files.single;

      // küçük kontrol: boş dosya / yanlış seçim
      if (!picked.name.toLowerCase().endsWith('.zip')) {
        throw Exception('Lütfen .zip dosyası seç.');
      }

      final zipBytes = await _readZipBytes(picked);

      // ekstra güvenlik: sıfır byte ise
      if (zipBytes.isEmpty) {
        throw Exception('ZIP boş görünüyor. Farklı bir ZIP seç.');
      }

      await _importFromZipBytes(
        zipBytes: zipBytes,
        originalFileName: picked.name,
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

  void _folderDisabledHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Web’de klasör seçip ZIP’leme kapalı. ZIP dosyası seçerek import et.'),
      ),
    );
  }

  String _formatLanguageBreakdown(Map<String, int>? stats, {int maxItems = 4}) {
    if (stats == null || stats.isEmpty) return '-';

    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(maxItems);
    return top.map((e) => '${e.key} %${e.value}').join(' • ');
  }

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
            // Klasör seçme: web’de kapalı
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.black,
                ),
                onPressed: _loading ? null : _folderDisabledHint,
                icon: const Icon(Icons.folder_open),
                label: Text(
                  _loading ? 'Yükleniyor...' : 'Klasör Seç (Web’de kapalı)',
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ZIP seç
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _pickZipAndImport,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label:
                    Text(_loading ? 'Import ediliyor...' : 'ZIP Seç (Import)'),
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
