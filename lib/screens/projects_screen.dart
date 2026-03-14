import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _auth = FirebaseAuth.instance;

  final Map<String, Future<bool>> _memberCheckCache = {};

  String _safeText(dynamic value, String fallback) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String? get _uid => _auth.currentUser?.uid;

  Future<bool> _isMemberOfProject(String projectId) {
    final cached = _memberCheckCache[projectId];
    if (cached != null) return cached;

    final uid = _uid;
    if (uid == null) {
      return Future.value(false);
    }

    final future = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('members')
        .doc(uid)
        .get()
        .then((snap) => snap.exists)
        .catchError((_) => false);

    _memberCheckCache[projectId] = future;
    return future;
  }

  Future<bool> _confirmDelete(BuildContext context, String projectName) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Projeyi silmek istiyor musun?'),
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
    final approved = await _confirmDelete(context, projectName);
    if (!approved) return;

    try {
      await _service.deleteProject(projectId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$projectName" silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proje silinemedi: $e')),
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

    rawStats.forEach((key, value) {
      final lang = key?.toString().trim();
      if (lang == null || lang.isEmpty) return;

      int? parsedValue;
      if (value is int) parsedValue = value;
      if (value is double) parsedValue = value.round();
      if (value is String) parsedValue = int.tryParse(value);

      if (parsedValue == null || parsedValue <= 0) return;

      entries.add(MapEntry(lang, parsedValue));
    });

    if (entries.isEmpty) return '';

    entries.sort((a, b) => b.value.compareTo(a.value));

    if (primaryLang != null && primaryLang.trim().isNotEmpty) {
      entries.removeWhere(
        (entry) => entry.key.toLowerCase() == primaryLang.toLowerCase(),
      );
    }

    if (entries.isEmpty) return '';

    final top = entries.take(maxItems).toList();
    return top.map((e) => '${e.key} %${e.value}').join(' • ');
  }

  Future<void> _openImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportProjectScreen(),
      ),
    );
  }

  void _handleAiAnalyze({
    required String projectId,
    required String projectName,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('LLM destekli analiz yakında eklenecek: $projectName'),
      ),
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

  void _afterMenuClosed(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  Widget _roleChip(bool isOwner) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOwner ? AppColors.teal : AppColors.textSoft,
        ),
      ),
      child: Text(
        isOwner ? 'Sahip' : 'Üye',
        style: TextStyle(
          fontSize: 12,
          color: isOwner ? AppColors.teal : AppColors.textSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProjectCard({
    required String projectId,
    required String name,
    required String primaryLang,
    required String breakdown,
    required bool isOwner,
  }) {
    return Card(
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Baskın dil: $primaryLang'),
            if (breakdown.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  breakdown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
            _roleChip(isOwner),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Seçenekler',
              onSelected: (value) {
                if (value == 'analysis') {
                  _afterMenuClosed(() async {
                    await _openAnalysisMenu(
                      projectId: projectId,
                      projectName: name,
                    );
                  });
                  return;
                }

                if (value == 'ai') {
                  _afterMenuClosed(() {
                    _handleAiAnalyze(
                      projectId: projectId,
                      projectName: name,
                    );
                  });
                  return;
                }

                if (value == 'delete') {
                  _afterMenuClosed(() async {
                    await _handleDelete(
                      projectId: projectId,
                      projectName: name,
                    );
                  });
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'analysis',
                  child: Row(
                    children: [
                      Icon(Icons.manage_search),
                      SizedBox(width: 10),
                      Text('Kod Analizi'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'ai',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined),
                      SizedBox(width: 10),
                      Text('LLM Destekli Analiz'),
                    ],
                  ),
                ),
                if (isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 10),
                        Text('Projeyi Sil'),
                      ],
                    ),
                  ),
              ],
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openProjectTasks(
          projectId: projectId,
          projectName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Projelerim'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.teal,
        onPressed: _openImport,
        child: const Icon(Icons.upload_file, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.allProjectsStreamForDebug(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Bir hata oluştu: ${snapshot.error}',
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
          final uid = _uid;

          if (uid == null) {
            return const Center(
              child: Text(
                'Oturum bulunamadı.',
                style: TextStyle(color: AppColors.textSoft),
              ),
            );
          }

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Henüz hiç proje bulunmuyor.\nSağ alttaki buton ile proje ekleyebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSoft),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final projectId = doc.id;
              final name = _safeText(data['name'], 'Adsız Proje');
              final primaryLang = _safeText(data['primaryLanguage'], '-');
              final ownerId = _safeText(data['ownerId'], '');

              final breakdown = _formatLanguageBreakdown(
                data['languageStats'],
                primaryLang: primaryLang,
                maxItems: 3,
              );

              final isOwner = ownerId == uid;

              if (isOwner) {
                return _buildProjectCard(
                  projectId: projectId,
                  name: name,
                  primaryLang: primaryLang,
                  breakdown: breakdown,
                  isOwner: true,
                );
              }

              return FutureBuilder<bool>(
                future: _isMemberOfProject(projectId),
                builder: (context, memberSnapshot) {
                  if (memberSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  final isMember = memberSnapshot.data == true;
                  if (!isMember) {
                    return const SizedBox.shrink();
                  }

                  return _buildProjectCard(
                    projectId: projectId,
                    name: name,
                    primaryLang: primaryLang,
                    breakdown: breakdown,
                    isOwner: false,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
