import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../services/analysis_service.dart';
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
  final ProjectImportService _importService = ProjectImportService();
  final AnalysisService _analysisService = AnalysisService();

  late Future<AnalysisResult?> _futureAnalysis;
  late Future<Map<String, dynamic>> _futureCloc;

  int touchedIndex = -1;

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

  void _retry() {
    setState(() {
      _futureAnalysis = _importService.getProjectAnalysis(widget.projectId);
      _futureCloc = _analysisService.getClocAnalysis();
      touchedIndex = -1;
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

  Widget _buildLanguageCard(List<LanguageStat> topLanguages) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yerel Dil Dağılımı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mevcut AnalysisService sonucu',
              style: TextStyle(color: AppColors.textSoft),
            ),
            const SizedBox(height: 12),
            if (topLanguages.isEmpty)
              const Text(
                'Dil bilgisi bulunamadı.',
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${language.files} dosya • '
                          '${language.lines} satır • '
                          '${_formatBytes(language.bytes)}',
                          style: const TextStyle(
                            color: AppColors.textSoft,
                          ),
                          textAlign: TextAlign.right,
                        ),
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
                    'CLOC Dil Dağılımı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Grafik için uygun CLOC verisi bulunamadı.',
                    style: TextStyle(color: AppColors.textSoft),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CLOC Dil Dağılımı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'En çok kod satırına sahip ilk 6 dil',
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

  Widget _buildAnalysisBody(
    AnalysisResult analysis,
    AsyncSnapshot<Map<String, dynamic>> clocSnapshot,
  ) {
    final languages = [...analysis.languages]
      ..sort((a, b) => b.bytes.compareTo(a.bytes));

    final topLanguages = languages.take(6).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _buildSummaryCard(analysis),
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
                'CLOC grafiği yüklenemedi:\n${clocSnapshot.error}',
                style: const TextStyle(color: AppColors.textSoft),
              ),
            ),
          )
        else if (clocSnapshot.hasData)
          _buildClocChartCard(clocSnapshot.data!),
        const SizedBox(height: 12),
        _buildLanguageCard(topLanguages),
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
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Row(
          children: [
            const _AnimatedLogo(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Statik Analiz • ${widget.projectName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Image.asset(
        'assets/icon/icon_app.png',
        width: 32,
        height: 32,
      ),
    );
  }
}
