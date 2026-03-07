import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/analysis_result.dart';
import '../services/project_import_service.dart';

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

  String _fmtBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final s = (i == 0) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s ${units[i]}';
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
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return _StateCard(
                title: 'Hata',
                subtitle: snap.error.toString(),
                buttonText: 'Tekrar dene',
                onPressed: _retry,
                icon: Icons.error_outline,
              );
            }

            final analysis = snap.data;
            if (analysis == null) {
              return _StateCard(
                title: 'Analiz bulunamadı',
                subtitle:
                    'Bu projede "analysis" verisi yok. Muhtemelen eski import ile eklendi.\nProjeyi yeniden import etmeyi dene.',
                buttonText: 'Yenile',
                onPressed: _retry,
                icon: Icons.info_outline,
              );
            }

            final langs = [...analysis.languages]
              ..sort((a, b) => b.bytes.compareTo(a.bytes));
            final topLangs = langs.take(6).toList();

            return ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Özet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _metricTile(
                          'Dosyalar',
                          '${analysis.totalFiles} (ignore: ${analysis.ignoredFiles})',
                          icon: Icons.insert_drive_file_outlined,
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
                          'TODO/FIXME',
                          '${analysis.todoCount}',
                          icon: Icons.checklist,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dil dağılımı (top)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (topLangs.isEmpty)
                          const Text(
                            'Dil verisi yok.',
                            style: TextStyle(color: AppColors.textSoft),
                          )
                        else
                          ...topLangs.map((l) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l.language,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${l.files} dosya • ${l.lines} satır • ${_fmtBytes(l.bytes)}',
                                    style: const TextStyle(
                                      color: AppColors.textSoft,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Debug',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'projectId: ${widget.projectId}',
                          style: const TextStyle(color: AppColors.textSoft),
                        ),
                        Text(
                          'projectName: ${widget.projectName}',
                          style: const TextStyle(color: AppColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
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
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
