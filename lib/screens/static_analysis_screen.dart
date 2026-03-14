import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../services/project_import_service.dart';
import '../theme/app_theme.dart';

class StaticAnalysisScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const StaticAnalysisScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<StaticAnalysisScreen> createState() => _StaticAnalysisScreenState();
}

class _StaticAnalysisScreenState extends State<StaticAnalysisScreen> {
  final _importService = ProjectImportService();
  late Future<AnalysisResult?> _future;

  @override
  void initState() {
    super.initState();
    _future = _importService.getProjectAnalysis(widget.projectId);
  }

  void _retry() {
    setState(() {
      _future = _importService.getProjectAnalysis(widget.projectId);
    });
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final formatted =
        unitIndex == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

    return '$formatted ${units[unitIndex]}';
  }

  Widget _metricTile(String label, String value, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.teal),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSoft),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(AnalysisResult analysis) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genel Özet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _metricTile(
              'Toplam dosya',
              '${analysis.totalFiles} (hariç tutulan: ${analysis.ignoredFiles})',
              icon: Icons.insert_drive_file_outlined,
            ),
            const SizedBox(height: 8),
            _metricTile(
              'Toplam boyut',
              _formatBytes(analysis.totalBytes),
              icon: Icons.storage_outlined,
            ),
            const SizedBox(height: 8),
            _metricTile(
              'Toplam satır',
              '${analysis.totalLines}',
              icon: Icons.format_list_numbered,
            ),
            const SizedBox(height: 8),
            _metricTile(
              'Kod satırı / Yorum satırı',
              '${analysis.codeLines} / ${analysis.commentLines}',
              icon: Icons.code,
            ),
            const SizedBox(height: 8),
            _metricTile(
              'TODO / FIXME sayısı',
              '${analysis.todoCount}',
              icon: Icons.checklist,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(List<LanguageStat> topLanguages) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dil Dağılımı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (topLanguages.isEmpty)
              const Text(
                'Dil verisi bulunamadı.',
                style: TextStyle(color: AppColors.textSoft),
              )
            else
              ...topLanguages.map((language) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          language.language,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${language.files} dosya • '
                        '${language.lines} satır • '
                        '${_formatBytes(language.bytes)}',
                        style: const TextStyle(
                          color: AppColors.textSoft,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teknik Bilgiler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Proje kimliği: ${widget.projectId}',
              style: const TextStyle(color: AppColors.textSoft),
            ),
            Text(
              'Proje adı: ${widget.projectName}',
              style: const TextStyle(color: AppColors.textSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisBody(AnalysisResult analysis) {
    final languages = [...analysis.languages]
      ..sort((a, b) => b.bytes.compareTo(a.bytes));

    final topLanguages = languages.take(6).toList();

    return ListView(
      children: [
        _buildSummaryCard(analysis),
        const SizedBox(height: 12),
        _buildLanguageCard(topLanguages),
        const SizedBox(height: 12),
        _buildTechnicalInfoCard(),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return _StateCard(
      title: 'Bir Hata Oluştu',
      subtitle: error.toString(),
      buttonText: 'Tekrar Dene',
      onPressed: _retry,
      icon: Icons.error_outline,
    );
  }

  Widget _buildEmptyState() {
    return _StateCard(
      title: 'Analiz Verisi Bulunamadı',
      subtitle: 'Bu projede analiz verisi bulunamadı.\n'
          'Proje daha eski bir yöntemle eklenmiş olabilir.\n'
          'Projeyi yeniden içe aktarmayı deneyebilirsin.',
      buttonText: 'Yenile',
      onPressed: _retry,
      icon: Icons.info_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text('Statik Analiz • ${widget.projectName}'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<AnalysisResult?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error!);
            }

            final analysis = snapshot.data;
            if (analysis == null) {
              return _buildEmptyState();
            }

            return _buildAnalysisBody(analysis);
          },
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final IconData icon;

  const _StateCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh),
                label: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
