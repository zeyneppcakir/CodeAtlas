import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'llm_analysis_screen.dart';
import 'static_analysis_screen.dart';
import '../widgets/codeatlas_appbar.dart';

class AnalysisMenuScreen extends StatelessWidget {
  final String? projectId;
  final String? projectName;

  const AnalysisMenuScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  bool get _hasProject {
    return (projectId ?? '').trim().isNotEmpty &&
        (projectName ?? '').trim().isNotEmpty;
  }

  void _goBackOrShowProjectsHint(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Proje seçebilmek için önce "Projelerim" ekranına gitmelisin.',
        ),
      ),
    );
  }

  void _openStaticAnalysis(BuildContext context) {
    if (!_hasProject) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analiz başlatmadan önce bir proje seçmelisin.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaticAnalysisScreen(
          projectId: projectId!.trim(),
          projectName: projectName!.trim(),
        ),
      ),
    );
  }

  void _openLlmAnalysis(BuildContext context) {
    if (!_hasProject) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LLM analizini başlatmadan önce bir proje seçmelisin.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LlmAnalysisScreen(
          projectId: projectId!.trim(),
          projectName: projectName!.trim(),
        ),
      ),
    );
  }

  void _showComingSoonMessage(
    BuildContext context, {
    required String featureName,
    required String selectedProjectName,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$featureName özelliği, "$selectedProjectName" projesi için yakında eklenecek.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectName =
        _hasProject ? projectName!.trim() : 'Proje seçilmedi';

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
        child: _hasProject
            ? _MethodsBody(
                projectName: projectName!.trim(),
                onStaticAnalysis: () => _openStaticAnalysis(context),
                onQualityRules: () => _showComingSoonMessage(
                  context,
                  featureName: 'Kod kalitesi analizi',
                  selectedProjectName: selectedProjectName,
                ),
                onLlm: () => _openLlmAnalysis(context),
              )
            : _NoProjectBody(
                onSelectProject: () => _goBackOrShowProjectsHint(context),
              ),
      ),
    );
  }
}

class _NoProjectBody extends StatelessWidget {
  final VoidCallback onSelectProject;

  const _NoProjectBody({
    required this.onSelectProject,
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
              const Icon(Icons.info_outline, size: 34),
              const SizedBox(height: 10),
              const Text(
                'Önce bir proje seçmelisin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Kod analizi başlatabilmek için önce analiz etmek istediğin projeyi seçmen gerekiyor.',
                style: TextStyle(color: AppColors.textSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onSelectProject,
                icon: const Icon(Icons.folder_open),
                label: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodsBody extends StatelessWidget {
  final String projectName;
  final VoidCallback onStaticAnalysis;
  final VoidCallback onQualityRules;
  final VoidCallback onLlm;

  const _MethodsBody({
    required this.projectName,
    required this.onStaticAnalysis,
    required this.onQualityRules,
    required this.onLlm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analiz yöntemi seç',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Seçili proje: $projectName',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        const SizedBox(height: 14),
        _MethodCard(
          title: 'Statik Analiz',
          subtitle:
              'Dosya sayısı, dil dağılımı ve temel kod metriklerini gösterir.',
          icon: Icons.analytics_outlined,
          onTap: onStaticAnalysis,
        ),
        const SizedBox(height: 12),
        _MethodCard(
          title: 'Kod Kalitesi Analizi',
          subtitle:
              'Kod kokuları, temel kurallar ve iyileştirme önerilerini sunar.',
          icon: Icons.rule_folder_outlined,
          onTap: onQualityRules,
        ),
        const SizedBox(height: 12),
        _MethodCard(
          title: 'LLM Destekli Analiz',
          subtitle: 'Kod özeti, riskler ve geliştirme önerileri sunar.',
          icon: Icons.auto_awesome,
          onTap: onLlm,
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.navySoft,
          child: Icon(
            icon,
            color: AppColors.teal,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSoft),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
