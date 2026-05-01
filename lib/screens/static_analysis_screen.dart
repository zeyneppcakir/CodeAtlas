import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../services/ai_service.dart';
import '../services/analysis_service.dart';
import '../services/project_import_service.dart';
import '../theme/app_theme.dart';
import '../widgets/codeatlas_appbar.dart';

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
  final ProjectImportService _importService = ProjectImportService();
  final AnalysisService _analysisService = AnalysisService();
  final AIService _aiService = AIService();

  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultsSectionKey = GlobalKey();

  late Future<AnalysisResult?> _futureAnalysis;
  late Future<Map<String, dynamic>> _futureCloc;

  int touchedIndex = -1;

  bool _isGeneratingAI = false;
  String? _aiError;

  String _selectedProvider = AIService.ollamaProvider;
  String _selectedModel = AIService.defaultOllamaModel;

  final Map<String, String> _aiResults = {};
  final Map<String, bool> _expandedStates = {};

  final List<Color> _chartColors = const [
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFFE57373),
    Color(0xFFA1887F),
    Color(0xFF64B5F6),
    Color(0xFFFF8A65),
  ];

  @override
  void initState() {
    super.initState();
    _futureAnalysis = _importService.getProjectAnalysis(widget.projectId);
    _futureCloc = _analysisService.getClocAnalysis();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _futureAnalysis = _importService.getProjectAnalysis(widget.projectId);
      _futureCloc = _analysisService.getClocAnalysis();
      touchedIndex = -1;
      _isGeneratingAI = false;
      _aiError = null;
      _aiResults.clear();
      _expandedStates.clear();
    });
  }

  String _resultKey(String provider, String model) => '$provider::$model';

  String _providerText(String provider) {
    switch (provider.toLowerCase()) {
      case 'gemini':
        return 'Gemini';
      case 'ollama':
        return 'Ollama';
      default:
        return provider;
    }
  }

  String _cleanAiText(String text) {
    var cleaned = text.trim();

    cleaned = cleaned.replaceAll('```', '');
    cleaned = cleaned.replaceAll('---', '');
    cleaned = cleaned.replaceAll('**', '');
    cleaned = cleaned.replaceAll('##', '');
    cleaned = cleaned.replaceAll('#', '');

    final rawLines = cleaned.split('\n');
    final normalizedLines = <String>[];
    bool previousWasEmpty = false;

    for (var line in rawLines) {
      line = line.trim();

      if (line.startsWith('- ')) {
        line = '• ${line.substring(2).trim()}';
      }

      final isEmpty = line.isEmpty;

      if (isEmpty) {
        if (!previousWasEmpty) {
          normalizedLines.add('');
        }
        previousWasEmpty = true;
      } else {
        normalizedLines.add(line);
        previousWasEmpty = false;
      }
    }

    cleaned = normalizedLines.join('\n');

    while (cleaned.contains('\n\n\n')) {
      cleaned = cleaned.replaceAll('\n\n\n', '\n\n');
    }

    return cleaned.trim();
  }

  String _previewText(String text, {int maxLength = 220}) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength).trim()}...';
  }

  Future<void> _scrollToResultsSection() async {
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    final targetContext = _resultsSectionKey.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
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

  String _formatCompactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _percentText(int value, int total) {
    if (total == 0) return '0%';
    final percent = (value / total) * 100;
    return '${percent.toStringAsFixed(1)}%';
  }

  double _percentValue(int value, int total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  Future<void> _generateAIAnalysis(
    AnalysisResult analysis,
    Map<String, dynamic> clocData,
  ) async {
    setState(() {
      _isGeneratingAI = true;
      _aiError = null;
    });

    final currentKey = _resultKey(_selectedProvider, _selectedModel);

    try {
      final languages = _analysisService.extractTopLanguagesFromCloc(
        clocData,
        limit: 20,
      );

      final sortedLanguages = [...languages]
        ..sort((a, b) => b.value.compareTo(a.value));

      final totalLines =
          sortedLanguages.fold<int>(0, (sum, item) => sum + item.value);

      final languageDistribution = <String, dynamic>{
        for (final lang in sortedLanguages)
          lang.key: {
            'satir_sayisi': lang.value,
          }
      };

      final result = await _aiService.analyzeProjectSummary(
        projectName: widget.projectName,
        primaryLanguage: sortedLanguages.isNotEmpty
            ? sortedLanguages.first.key
            : 'Bilinmiyor',
        totalFiles: analysis.totalFiles,
        totalLines: totalLines,
        nonEmptyLines: totalLines,
        languageDistribution: languageDistribution,
        todoCount: analysis.todoCount,
        provider: _selectedProvider,
        model: _selectedModel,
      );

      if (!mounted) return;

      setState(() {
        _aiResults[currentKey] = _cleanAiText(result);
        _expandedStates[currentKey] = false;
      });

      await _scrollToResultsSection();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _aiError = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isGeneratingAI = false;
      });
    }
  }

  Future<void> _generateCustomPrompt() async {
    final prompt = _promptController.text.trim();

    if (prompt.isEmpty) {
      setState(() {
        _aiError = 'Lütfen önce bir istem gir.';
      });
      return;
    }

    setState(() {
      _isGeneratingAI = true;
      _aiError = null;
    });

    final currentKey = _resultKey(_selectedProvider, _selectedModel);

    try {
      final result = await _aiService.generate(
        prompt: prompt,
        provider: _selectedProvider,
        model: _selectedModel,
      );

      if (!mounted) return;

      setState(() {
        _aiResults[currentKey] = _cleanAiText(result);
        _expandedStates[currentKey] = false;
      });

      await _scrollToResultsSection();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _aiError = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isGeneratingAI = false;
      });
    }
  }

  Widget _metricTile(
    String label,
    String value, {
    IconData? icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
            textAlign: TextAlign.right,
          ),
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
              'Kod satırı / yorum satırı',
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

  Widget _buildClocBarRow({
    required String language,
    required int codeLines,
    required int totalCode,
    required Color color,
  }) {
    final percent = _percentValue(codeLines, totalCode);
    final widthFactor = totalCode == 0 ? 0.0 : codeLines / totalCode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  language,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$codeLines satır',
                style: const TextStyle(
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: widthFactor.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.navySoft.withOpacity(0.6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClocChartCard(Map<String, dynamic> clocResponse) {
    final languages = _analysisService.extractTopLanguagesFromCloc(
      clocResponse,
      limit: 6,
    );

    final totalCode = languages.fold<int>(0, (sum, item) => sum + item.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: languages.isEmpty
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dil Dağılımı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Grafik için uygun dil verisi bulunamadı.',
                    style: TextStyle(color: AppColors.textSoft),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dil Dağılımı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yüklenen projenin tespit edilen dil dağılımı',
                    style: TextStyle(color: AppColors.textSoft),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 62,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      response == null ||
                                      response.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = response
                                      .touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            sections: List.generate(languages.length, (index) {
                              final item = languages[index];
                              final isTouched = index == touchedIndex;
                              final percent =
                                  _percentValue(item.value, totalCode);

                              return PieChartSectionData(
                                color:
                                    _chartColors[index % _chartColors.length],
                                value: item.value.toDouble(),
                                radius: isTouched ? 78 : 66,
                                title: percent >= 4
                                    ? _percentText(item.value, totalCode)
                                    : '',
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Toplam Kod',
                              style: TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCompactNumber(totalCode),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'satır',
                              style: TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Dil yüzdeleri',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(languages.length, (index) {
                    final item = languages[index];
                    return _buildClocBarRow(
                      language: item.key,
                      codeLines: item.value,
                      totalCode: totalCode,
                      color: _chartColors[index % _chartColors.length],
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildAISonucKartlari() {
    if (_aiResults.isEmpty) {
      return Container(
        key: _resultsSectionKey,
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.navySoft.withOpacity(0.20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.teal.withOpacity(0.10),
          ),
        ),
        child: const Text(
          'Henüz yapay zekâ analizi oluşturulmadı. Bir sağlayıcı ve model seçip analiz üretebilirsin.',
          style: TextStyle(
            color: AppColors.textSoft,
            height: 1.5,
          ),
        ),
      );
    }

    final entries = _aiResults.entries.toList().reversed.toList();

    return Column(
      key: _resultsSectionKey,
      children: entries.map((entry) {
        final key = entry.key;
        final result = entry.value;
        final parts = key.split('::');
        final provider = parts.isNotEmpty ? parts.first : '';
        final model = parts.length > 1 ? parts.last : '';
        final isExpanded = _expandedStates[key] ?? false;
        final preview = _previewText(result);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.navySoft.withOpacity(0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.teal.withOpacity(0.12),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedStates[key] = expanded;
                });
              },
              leading: const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.teal,
              ),
              title: Text(
                _providerText(provider),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                model,
                style: const TextStyle(
                  color: AppColors.textSoft,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Divider(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isExpanded ? result : preview,
                    style: TextStyle(
                      height: 1.4,
                      fontSize: isExpanded ? 14 : 13,
                      color: isExpanded ? AppColors.text : AppColors.textSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAIAnalysisCard(
    AnalysisResult analysis,
    Map<String, dynamic>? clocData,
  ) {
    final ollamaModels = AIService.supportedOllamaModels;
    final modelItems = _selectedProvider == AIService.geminiProvider
        ? [AIService.defaultGeminiModel]
        : ollamaModels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Yapay Zekâ Analizi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Statik analiz sonuçlarına göre yapay zekâ destekli yorum ve geliştirme önerileri üret.',
              style: TextStyle(color: AppColors.textSoft),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Sağlayıcı',
                border: OutlineInputBorder(),
              ),
              items: AIService.supportedProviders.map((provider) {
                return DropdownMenuItem<String>(
                  value: provider,
                  child: Text(_providerText(provider)),
                );
              }).toList(),
              onChanged: _isGeneratingAI
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedProvider = value;
                        _selectedModel = value == AIService.geminiProvider
                            ? AIService.defaultGeminiModel
                            : AIService.defaultOllamaModel;
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: modelItems.contains(_selectedModel)
                  ? _selectedModel
                  : modelItems.first,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
              items: modelItems.map((model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: _isGeneratingAI
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedModel = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'İsteğe bağlı özel istem',
                hintText:
                    'İstersen burada kendi sorunu ya da özel istemini yazabilirsin. Boş bırakırsan proje özeti üzerinden otomatik analiz yapılır.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGeneratingAI
                    ? null
                    : () {
                        if (clocData == null) {
                          setState(() {
                            _aiError =
                                'Dil dağılımı verisi henüz hazır değil. Lütfen biraz bekleyip tekrar dene.';
                          });
                          return;
                        }

                        _generateAIAnalysis(analysis, clocData);
                      },
                icon: _isGeneratingAI
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_alt_outlined),
                label: const Text('Otomatik analiz oluştur'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGeneratingAI ? null : _generateCustomPrompt,
                icon: const Icon(Icons.edit_note),
                label: const Text('Özel istemi çalıştır'),
              ),
            ),
            if (_aiError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Text(
                  _aiError!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Oluşturulan Sonuçlar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _buildAISonucKartlari(),
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
            const SizedBox(height: 4),
            Text(
              'Proje adı: ${widget.projectName}',
              style: const TextStyle(color: AppColors.textSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statik Analiz • ${widget.projectName}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Projenin statik analiz sonuçlarını, dil dağılımını ve yapay zekâ destekli yorumları burada inceleyebilirsin.',
            style: TextStyle(
              color: AppColors.textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisBody(
    AnalysisResult analysis,
    AsyncSnapshot<Map<String, dynamic>> clocSnapshot,
  ) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _buildPageHeader(),
        _buildSummaryCard(analysis),
        const SizedBox(height: 12),
        _buildAIAnalysisCard(
          analysis,
          clocSnapshot.hasData ? clocSnapshot.data : null,
        ),
        const SizedBox(height: 12),
        if (clocSnapshot.connectionState == ConnectionState.waiting)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (clocSnapshot.hasError)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Dil dağılımı yüklenemedi:\n${clocSnapshot.error}',
                style: const TextStyle(color: AppColors.textSoft),
              ),
            ),
          )
        else if (clocSnapshot.hasData)
          _buildClocChartCard(clocSnapshot.data!),
        const SizedBox(height: 12),
        _buildTechnicalInfoCard(),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return _StateCard(
      title: 'Bir hata oluştu',
      subtitle: error.toString(),
      buttonText: 'Tekrar dene',
      onPressed: _retry,
      icon: Icons.error_outline,
    );
  }

  Widget _buildEmptyState() {
    return _StateCard(
      title: 'Analiz verisi bulunamadı',
      subtitle: 'Bu proje için analiz verisi bulunamadı.\n'
          'Proje daha eski bir yöntemle eklenmiş olabilir.\n'
          'Projeyi yeniden içe aktarmayı deneyebilirsin.',
      buttonText: 'Yenile',
      onPressed: _retry,
      icon: Icons.info_outline,
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
            'Statik analiz verileri yükleniyor...',
            style: TextStyle(color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CodeAtlasAppBar(
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
          future: _futureAnalysis,
          builder: (context, analysisSnapshot) {
            if (analysisSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (analysisSnapshot.hasError) {
              return _buildErrorState(analysisSnapshot.error!);
            }

            final analysis = analysisSnapshot.data;
            if (analysis == null) {
              return _buildEmptyState();
            }

            return FutureBuilder<Map<String, dynamic>>(
              future: _futureCloc,
              builder: (context, clocSnapshot) {
                return _buildAnalysisBody(analysis, clocSnapshot);
              },
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
