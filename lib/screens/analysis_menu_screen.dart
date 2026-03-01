import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnalysisMenuScreen extends StatelessWidget {
  final String? projectId;
  final String? projectName;

  const AnalysisMenuScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  bool get _hasProject =>
      projectId != null &&
      projectId!.trim().isNotEmpty &&
      projectName != null &&
      projectName!.trim().isNotEmpty;

  void _goToProjects(BuildContext context) {
    // ProjectsScreen'e push yapmak yerine geri dön.
    // (Döngüsel importu engeller)
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    // Eğer buraya "direkt" girildiyse ve geri dönülemiyorsa:
    Navigator.of(context).pushNamed('/projects');
    // Not: named route kullanmıyorsan bu satırı silebilirsin.
  }

  @override
  Widget build(BuildContext context) {
    final name = _hasProject ? projectName! : 'Proje seç';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text('Kod Analizi • $name'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _hasProject
            ? _MethodsBody(projectName: projectName!)
            : _NoProjectBody(onSelectProject: () => _goToProjects(context)),
      ),
    );
  }
}

class _NoProjectBody extends StatelessWidget {
  final VoidCallback onSelectProject;

  const _NoProjectBody({required this.onSelectProject});

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
                'Önce proje seçmelisin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Kod analizi başlatmak için bir proje seçmemiz gerekiyor.',
                style: TextStyle(color: AppColors.textSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onSelectProject,
                icon: const Icon(Icons.folder_open),
                label: const Text('Projelerim’e git'),
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

  const _MethodsBody({required this.projectName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yöntem seç',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Seçili proje: $projectName',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        const SizedBox(height: 14),
        _MethodCard(
          title: 'Statik Analiz (Temel)',
          subtitle: 'Dosya sayısı, dil dağılımı, basit metrikler',
          icon: Icons.analytics_outlined,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Statik analiz başlatılacak: $projectName'),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _MethodCard(
          title: 'Kod Kalitesi (Kurallar)',
          subtitle: 'Smell tespiti, basit kurallar, öneriler',
          icon: Icons.rule_folder_outlined,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Kod kalitesi analizi başlatılacak: $projectName'),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _MethodCard(
          title: 'LLM Destekli Analiz',
          subtitle: 'Özet, riskler, refactor önerileri',
          icon: Icons.auto_awesome,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('LLM analizi başlatılacak: $projectName'),
              ),
            );
          },
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
          child: Icon(icon, color: AppColors.teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle:
            Text(subtitle, style: const TextStyle(color: AppColors.textSoft)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
