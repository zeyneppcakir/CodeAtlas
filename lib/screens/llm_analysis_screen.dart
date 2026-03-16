import 'package:flutter/material.dart';

import '../services/project_import_service.dart';
import '../theme/app_theme.dart';

class LlmAnalysisScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const LlmAnalysisScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<LlmAnalysisScreen> createState() => _LlmAnalysisScreenState();
}

class _LlmAnalysisScreenState extends State<LlmAnalysisScreen> {
  final ProjectImportService _projectImportService = ProjectImportService();

  late Future<_LlmAnalysisViewData> _futureAnalysis;

  @override
  void initState() {
    super.initState();
    _futureAnalysis = _loadAnalysis();
  }

  Future<_LlmAnalysisViewData> _loadAnalysis() async {
    final llmAnalysis =
        await _projectImportService.getProjectLlmAnalysis(widget.projectId);
    final llmError =
        await _projectImportService.getProjectLlmError(widget.projectId);

    return _LlmAnalysisViewData(
      llmAnalysis: llmAnalysis,
      llmError: llmError,
    );
  }

  void _retry() {
    setState(() {
      _futureAnalysis = _loadAnalysis();
    });
  }

  List<String> _splitAnalysisSections(String text) {
    final normalized =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    if (normalized.isEmpty) return [];

    final lines = normalized.split('\n');
    final sections = <String>[];
    final buffer = StringBuffer();

    bool isSectionStart(String line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;

      final startsWithNumber = RegExp(r'^\d+[\).\-\:]').hasMatch(trimmed);
      final markdownTitle = trimmed.startsWith('##') || trimmed.startsWith('#');
      final bulletTitle = RegExp(r'^[-•]\s+[A-ZÇĞİÖŞÜ]').hasMatch(trimmed);

      return startsWithNumber || markdownTitle || bulletTitle;
    }

    for (final line in lines) {
      if (isSectionStart(line) && buffer.isNotEmpty) {
        sections.add(buffer.toString().trim());
        buffer.clear();
      }

      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.write(line);
    }

    if (buffer.isNotEmpty) {
      sections.add(buffer.toString().trim());
    }

    return sections.where((e) => e.trim().isNotEmpty).toList();
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.navySoft,
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'LLM Destekli Kod Analizi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Seçili proje: ${widget.projectName}',
              style: const TextStyle(
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu ekran, proje için oluşturulmuş yapay zekâ destekli analiz özetini gösterir. '
              'Burada kodun amacı, riskleri ve geliştirme önerileri yer alır.',
              style: TextStyle(
                color: AppColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(String analysisText) {
    final sections = _splitAnalysisSections(analysisText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: sections.isEmpty
            ? Text(
                analysisText,
                style: const TextStyle(height: 1.5),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analiz Sonucu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final section = entry.value;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == sections.length - 1 ? 0 : 12,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.navySoft.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.navySoft,
                          ),
                        ),
                        child: Text(
                          section,
                          style: const TextStyle(
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorCard(String errorText) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                ),
                SizedBox(width: 8),
                Text(
                  'LLM Analizi Alınamadı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              errorText,
              style: const TextStyle(
                color: AppColors.textSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _StateCard(
      title: 'LLM analizi bulunamadı',
      subtitle:
          'Bu proje için henüz yapay zekâ destekli analiz verisi bulunmuyor.\n'
          'Proje GitHub üzerinden analiz edilmemiş olabilir ya da analiz kaydı eksik olabilir.',
      buttonText: 'Yenile',
      onPressed: _retry,
      icon: Icons.auto_awesome_outlined,
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'LLM analizi yükleniyor...',
            style: TextStyle(color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(_LlmAnalysisViewData data) {
    final hasAnalysis =
        data.llmAnalysis != null && data.llmAnalysis!.trim().isNotEmpty;
    final hasError = data.llmError != null && data.llmError!.trim().isNotEmpty;

    if (!hasAnalysis && !hasError) {
      return _buildEmptyState();
    }

    return ListView(
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 12),
        if (hasAnalysis) _buildAnalysisCard(data.llmAnalysis!),
        if (hasAnalysis && hasError) const SizedBox(height: 12),
        if (hasError) _buildErrorCard(data.llmError!),
      ],
    );
  }

  Widget _buildFatalErrorState(Object error) {
    return _StateCard(
      title: 'Bir hata oluştu',
      subtitle: error.toString(),
      buttonText: 'Tekrar dene',
      onPressed: _retry,
      icon: Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text('LLM Analizi • ${widget.projectName}'),
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
        child: FutureBuilder<_LlmAnalysisViewData>(
          future: _futureAnalysis,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildFatalErrorState(snapshot.error!);
            }

            final data = snapshot.data;
            if (data == null) {
              return _buildEmptyState();
            }

            return _buildBody(data);
          },
        ),
      ),
    );
  }
}

class _LlmAnalysisViewData {
  final String? llmAnalysis;
  final String? llmError;

  const _LlmAnalysisViewData({
    required this.llmAnalysis,
    required this.llmError,
  });
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
