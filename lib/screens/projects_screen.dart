import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:codeatlas/theme/app_theme.dart';
import 'package:codeatlas/services/project_service.dart';
import 'package:codeatlas/screens/analysis_menu_screen.dart';
import 'package:codeatlas/screens/import_project_screen.dart';
import 'package:codeatlas/screens/project_tasks_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _service = ProjectService();

  String _safeText(dynamic v, String fallback) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Future<bool> _confirmDelete(BuildContext context, String projectName) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Projeyi sil?'),
            content: Text(
              '"$projectName" projesini siliyorsun.\nBu işlem geri alınamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleDelete({
    required String projectId,
    required String projectName,
  }) async {
    final ok = await _confirmDelete(context, projectName);
    if (!ok) return;

    try {
      await _service.deleteProject(projectId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$projectName" silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
    }
  }

  String _formatLanguageBreakdown(
    dynamic rawStats, {
    String? primaryLang,
    int maxItems = 3,
  }) {
    if (rawStats is! Map) return '';

    final entries = <MapEntry<String, int>>[];
    rawStats.forEach((k, v) {
      final key = k?.toString().trim();
      if (key == null || key.isEmpty) return;

      int? val;
      if (v is int) val = v;
      if (v is double) val = v.round();
      if (v is String) val = int.tryParse(v);

      if (val == null || val <= 0) return;
      entries.add(MapEntry(key, val));
    });

    if (entries.isEmpty) return '';
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (primaryLang != null && primaryLang.trim().isNotEmpty) {
      entries.removeWhere(
        (e) => e.key.toLowerCase() == primaryLang.toLowerCase(),
      );
    }

    if (entries.isEmpty) return '';

    final top = entries.take(maxItems).toList();
    return top.map((e) => '${e.key} %${e.value}').join(' • ');
  }

  Future<void> _openImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportProjectScreen()),
    );
  }

  void _handleAiAnalyze({
    required String projectId,
    required String projectName,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI Analiz (yakında): $projectName')),
    );
  }

  Future<void> _openProjectTasks({
    required String projectId,
    required String projectName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectTasksScreen(
          projectId: projectId,
          projectName: projectName,
        ),
      ),
    );
  }

  Future<void> _openAnalysisMenu({
    required String projectId,
    required String projectName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisMenuScreen(
          projectId: projectId,
          projectName: projectName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('>>> ProjectsScreen BUILD (NEW TEST)');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Projelerim (NEW)'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.teal,
        onPressed: _openImport,
        child: const Icon(Icons.upload_file, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.myProjectsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Hata: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.textSoft),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Veri alınamadı. Lütfen giriş yaptığından emin ol.',
                style: TextStyle(color: AppColors.textSoft),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          final seen = <String>{};
          final filteredDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (final d in docs) {
            final data = d.data();
            final name = _safeText(data['name'], 'Adsız Proje');
            final lang = _safeText(data['primaryLanguage'], '-');
            final key = '${name.toLowerCase()}|${lang.toLowerCase()}';
            if (seen.add(key)) filteredDocs.add(d);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filteredDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = filteredDocs[i];
              final data = doc.data();

              final projectId = doc.id;
              final name = _safeText(data['name'], 'Adsız Proje');
              final primaryLang = _safeText(data['primaryLanguage'], '-');

              final breakdown = _formatLanguageBreakdown(
                data['languageStats'],
                primaryLang: primaryLang,
                maxItems: 3,
              );

              return Card(
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dil: $primaryLang'),
                      if (breakdown.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            breakdown,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSoft),
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Seçenekler',
                        onSelected: (value) async {
                          if (value == 'analysis') {
                            await _openAnalysisMenu(
                                projectId: projectId, projectName: name);
                            return;
                          }
                          if (value == 'ai') {
                            _handleAiAnalyze(
                                projectId: projectId, projectName: name);
                            return;
                          }
                          if (value == 'delete') {
                            await _handleDelete(
                                projectId: projectId, projectName: name);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'analysis',
                            child: Row(
                              children: [
                                Icon(Icons.manage_search),
                                SizedBox(width: 10),
                                Text('Kod Analizi'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'ai',
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome_outlined),
                                SizedBox(width: 10),
                                Text('AI Analiz Et'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline),
                                SizedBox(width: 10),
                                Text('Sil'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _openProjectTasks(
                      projectId: projectId, projectName: name),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
