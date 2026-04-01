import 'package:flutter/material.dart';

import '../services/ai_service.dart';
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
  final AIService _aiService = AIService();

  late Future<_LlmAnalysisViewData> _futureAnalysis;

  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedProvider = 'gemini';
  String _selectedModel = 'qwen2.5-coder:3b';

  bool _isGenerating = false;
  String _generatedResult = '';
  String _generatedError = '';
  String _lastUsedProvider = '';
  String _lastUsedModel = '';

  static const List<Map<String, String>> _ollamaModels = [
    {
      'value': 'qwen2.5-coder:3b',
      'label': 'Qwen 2.5 Coder (3B)',
    },
    {
      'value': 'qwen2.5:3b',
      'label': 'Qwen 2.5 (3B)',
    },
    {
      'value': 'qwen3b-cpu:latest',
      'label': 'Qwen 3B CPU',
    },
  ];

  @override
  void initState() {
    super.initState();
    _futureAnalysis = _loadAnalysis();
    _promptController.text = _buildDefaultPrompt();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  String _buildDefaultPrompt() {
    return '''
Aşağıdaki proje için kısa ve anlaşılır bir yazılım analizi yap.

Proje adı: ${widget.projectName}

Lütfen şu başlıklarda cevap ver:
1. Projenin olası amacı
2. Güçlü yönler
3. Riskler / eksikler
4. Geliştirme önerileri
5. Öncelikli yapılacaklar

Cevabı sade, düzenli ve okunabilir şekilde ver.
''';
  }

  Future<void> _generateNewAnalysis() async {
    final prompt = _promptController.text.trim();

    if (prompt.isEmpty) {
      setState(() {
        _generatedError = 'Prompt boş olamaz.';
        _generatedResult = '';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedError = '';
      _generatedResult = '';
    });

    try {
      final result = await _aiService.generate(
        prompt: prompt,
        provider: _selectedProvider,
        model: _selectedProvider == 'ollama' ? _selectedModel : null,
      );

      setState(() {
        _generatedResult = result;
        _lastUsedProvider = _selectedProvider;
        _lastUsedModel =
            _selectedProvider == 'ollama' ? _selectedModel : 'gemini-2.5-flash';
      });

      await Future.delayed(const Duration(milliseconds: 150));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() {
        _generatedError = e.toString();
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _clearGeneratedResult() {
    setState(() {
      _generatedResult = '';
      _generatedError = '';
      _lastUsedProvider = '';
      _lastUsedModel = '';
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

  String _providerLabel(String provider) {
    switch (provider) {
      case 'gemini':
        return 'Gemini';
      case 'ollama':
        return 'Ollama';
      default:
        return provider;
    }
  }

  String _modelLabel(String model) {
    for (final item in _ollamaModels) {
      if (item['value'] == model) {
        return item['label'] ?? model;
      }
    }
    return model;
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
              'Aşağıdan Gemini veya Ollama seçerek yeni analiz üretebilirsin. '
              'Alttaki kayıtlı analiz ise daha önce projeye kaydedilmiş eski sonuçtur.',
              style: TextStyle(
                color: AppColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yeni LLM Analizi Üret',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'gemini',
                  child: Text('Gemini'),
                ),
                DropdownMenuItem(
                  value: 'ollama',
                  child: Text('Ollama'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedProvider = value;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_selectedProvider == 'ollama')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration: const InputDecoration(
                    labelText: 'Ollama Model',
                    border: OutlineInputBorder(),
                  ),
                  items: _ollamaModels.map((model) {
                    return DropdownMenuItem<String>(
                      value: model['value'],
                      child: Text(model['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedModel = value;
                    });
                  },
                ),
              ),
            TextField(
              controller: _promptController,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                alignLabelWithHint: true,
                hintText: 'LLM için prompt yaz...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isGenerating ? null : _generateNewAnalysis,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      _isGenerating ? 'Analiz üretiliyor...' : 'Analiz Üret',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isGenerating
                      ? null
                      : () {
                          setState(() {
                            _promptController.text = _buildDefaultPrompt();
                          });
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Prompt Sıfırla'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard({
    required String title,
    required String analysisText,
    IconData icon = Icons.description_outlined,
    Widget? topRight,
  }) {
    final sections = _splitAnalysisSections(analysisText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: sections.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (topRight != null) topRight,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    analysisText,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (topRight != null) topRight,
                    ],
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

  Widget _buildGeneratedResultCard() {
    if (_generatedError.isNotEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Yeni analiz oluşturulamadı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _generatedError,
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

    if (_generatedResult.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final providerText = _providerLabel(_lastUsedProvider);
    final modelText = _lastUsedProvider == 'ollama'
        ? _modelLabel(_lastUsedModel)
        : _lastUsedModel;

    return _buildAnalysisCard(
      title: 'Yeni Üretilen LLM Analizi • $providerText'
          '${modelText.isNotEmpty ? ' • $modelText' : ''}',
      analysisText: _generatedResult,
      icon: Icons.smart_toy_outlined,
      topRight: TextButton.icon(
        onPressed: _clearGeneratedResult,
        icon: const Icon(Icons.close),
        label: const Text('Temizle'),
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
    final hasGenerated = _generatedResult.trim().isNotEmpty;

    return ListView(
      controller: _scrollController,
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 12),
        _buildGeneratorCard(),
        const SizedBox(height: 12),
        _buildGeneratedResultCard(),
        if (_generatedResult.trim().isNotEmpty || _generatedError.isNotEmpty)
          const SizedBox(height: 12),
        if (hasGenerated)
          Card(
            color: Colors.orange.withOpacity(0.08),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Yukarıdaki kart yeni üretilen sonuçtur. '
                      'Aşağıdaki “Kayıtlı LLM Analizi” ise projeye daha önce kaydedilmiş eski sonuç olabilir.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasGenerated && (hasAnalysis || hasError))
          const SizedBox(height: 12),
        if (hasAnalysis)
          _buildAnalysisCard(
            title: 'Kayıtlı LLM Analizi',
            analysisText: data.llmAnalysis!,
            icon: Icons.storage_outlined,
          ),
        if (hasAnalysis && hasError) const SizedBox(height: 12),
        if (hasError) _buildErrorCard(data.llmError!),
        if (!hasAnalysis && !hasError && !hasGenerated) _buildEmptyState(),
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
