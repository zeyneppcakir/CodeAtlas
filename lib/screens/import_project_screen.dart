import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/project_import_service.dart';
import '../theme/app_theme.dart';
import 'projects_screen.dart';
import '../widgets/codeatlas_appbar.dart';

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

  int? _analyzedFiles;
  int? _todoCount;
  int? _fixmeCount;
  int? _hackCount;
  int? _bugCount;
  int? _totalLines;
  int? _nonEmptyLines;

  final _importService = ProjectImportService();
  final _githubUrlCtrl = TextEditingController();

  @override
  void dispose() {
    _githubUrlCtrl.dispose();
    super.dispose();
  }

  String get _backendBaseUrl => 'http://127.0.0.1:8000';

  Future<Uint8List> _readZipBytes(PlatformFile picked) async {
    final bytes = picked.bytes;
    if (bytes != null) return bytes;

    final stream = picked.readStream;
    if (stream != null) {
      final chunks = <int>[];
      await for (final data in stream) {
        chunks.addAll(data);
      }
      return Uint8List.fromList(chunks);
    }

    throw Exception(
      'ZIP dosyası okunamadı.\n'
      'Web sürümünde withData:true zorunludur.',
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

      _analyzedFiles = null;
      _todoCount = null;
      _fixmeCount = null;
      _hackCount = null;
      _bugCount = null;
      _totalLines = null;
      _nonEmptyLines = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'İçe aktarma tamamlandı ✅ ${result.projectName} (${result.primaryLanguage})',
        ),
      ),
    );
  }

  Future<void> _pickZipAndImport() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;

      if (!picked.name.toLowerCase().endsWith('.zip')) {
        throw Exception('Lütfen .zip uzantılı bir dosya seçin.');
      }

      final zipBytes = await _readZipBytes(picked);

      if (zipBytes.isEmpty) {
        throw Exception(
          'ZIP dosyası boş görünüyor. Lütfen başka bir dosya seçin.',
        );
      }

      await _importFromZipBytes(
        zipBytes: zipBytes,
        originalFileName: picked.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatLanguageBreakdown(Map<String, int>? stats, {int maxItems = 4}) {
    if (stats == null || stats.isEmpty) return '-';

    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(maxItems);
    return top.map((e) => '${e.key}: ${e.value}').join(' • ');
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$_backendBaseUrl$path');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return <String, dynamic>{};
    }

    String message = 'İstek başarısız oldu.';

    if (decoded is Map<String, dynamic>) {
      if (decoded['detail'] is String) {
        message = decoded['detail'] as String;
      } else if (decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      if (map['detail'] is String) {
        message = map['detail'] as String;
      } else if (map['message'] is String) {
        message = map['message'] as String;
      }
    }

    throw Exception(message);
  }

  Future<void> _importFromGithubUrl() async {
    if (_loading) return;

    final url = _githubUrlCtrl.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen GitHub repo bağlantısını girin.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final importData = await _postJson(
        path: '/github/import',
        body: {'repo_url': url},
      );

      final analyzeData = await _postJson(
        path: '/github/analyze',
        body: {'repo_url': url},
      );

      final result = await _importService.importGithubProject(
        githubUrl: url,
        importData: importData,
        analyzeData: analyzeData,
      );

      if (!mounted) return;

      setState(() {
        _projectName = result.projectName;
        _primaryLanguage = result.primaryLanguage;
        _fileCount = result.fileCount;
        _languageStats = result.languageStats;

        _totalLines = result.analysis.totalLines;
        _nonEmptyLines = result.analysis.codeLines;
        _todoCount = result.analysis.todoCount;

        _analyzedFiles = (analyzeData['analyzed_files'] as num?)?.toInt() ??
            result.analysis.totalFiles;

        _fixmeCount = (analyzeData['fixme_count'] as num?)?.toInt();
        _hackCount = (analyzeData['hack_count'] as num?)?.toInt();
        _bugCount = (analyzeData['bug_count'] as num?)?.toInt();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'GitHub projesi analiz edildi ve projelere kaydedildi ✅',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GitHub analizi sırasında hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSoft,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (_projectName == null) return const SizedBox.shrink();

    return Card(
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
            const SizedBox(height: 12),
            _buildInfoRow('Baskın dil', _primaryLanguage ?? '-'),
            _buildInfoRow('Toplam kod dosyası', '${_fileCount ?? 0}'),
            _buildInfoRow(
              'Analiz edilen dosya',
              _analyzedFiles != null ? '$_analyzedFiles' : '-',
            ),
            _buildInfoRow(
              'Toplam satır',
              _totalLines != null ? '$_totalLines' : '-',
            ),
            _buildInfoRow(
              'Boş olmayan satır',
              _nonEmptyLines != null ? '$_nonEmptyLines' : '-',
            ),
            _buildInfoRow(
              'Dil dağılımı',
              _formatLanguageBreakdown(_languageStats),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('TODO sayısı', '${_todoCount ?? 0}'),
            _buildInfoRow('FIXME sayısı', '${_fixmeCount ?? 0}'),
            _buildInfoRow('HACK sayısı', '${_hackCount ?? 0}'),
            _buildInfoRow('BUG sayısı', '${_bugCount ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CodeAtlasAppBar(
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSectionTitle('ZIP Dosyası ile İçe Aktarma'),
              const SizedBox(height: 10),
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
                  label: Text(
                    _loading ? 'ZIP içe aktarılıyor...' : 'ZIP Dosyası Seç',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildSectionTitle('GitHub Bağlantısı ile Analiz'),
              const SizedBox(height: 10),
              TextField(
                controller: _githubUrlCtrl,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'GitHub Repo Bağlantısı',
                  hintText: 'https://github.com/kullanici/proje',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading ? null : _importFromGithubUrl,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    _loading
                        ? 'GitHub analizi yapılıyor...'
                        : 'GitHub ile Analiz Et',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildResultCard(),
              if (_projectName != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProjectsScreen(),
                        ),
                        (_) => false,
                      );
                    },
                    child: const Text('Projelerim Sayfasına Git'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
