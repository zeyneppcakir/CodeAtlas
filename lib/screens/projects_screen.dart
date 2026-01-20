import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/project_service.dart';
import 'add_project_screen.dart';
import 'project_tasks_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _service = ProjectService();

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

  /// Firestore’dan gelen languageStats (Map) içinden
  /// GitHub benzeri kısa özet üretir: "Dart %92 • HTML %8"
  /// - primary dil zaten üstte gösterildiği için, burada istersek primary'i çıkarabiliriz.
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

    // büyükten küçüğe
    entries.sort((a, b) => b.value.compareTo(a.value));

    // primary dili breakdown'dan çıkar (tekrarı azaltmak için)
    if (primaryLang != null && primaryLang.trim().isNotEmpty) {
      entries
          .removeWhere((e) => e.key.toLowerCase() == primaryLang.toLowerCase());
    }

    if (entries.isEmpty) return '';

    final top = entries.take(maxItems).toList();
    return top.map((e) => '${e.key} %${e.value}').join(' • ');
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
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProjectScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
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

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Henüz proje yok. + ile ekle.',
                style: TextStyle(color: AppColors.textSoft),
              ),
            );
          }

          // ✅ Opsiyonel: aynı isim + dil kombinasyonunu tek göster
          final seen = <String>{};
          final filteredDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (final d in docs) {
            final data = d.data();
            final name = (data['name'] ?? '') as String;
            final lang = (data['primaryLanguage'] ?? '-') as String;
            final key =
                '${name.trim().toLowerCase()}|${lang.trim().toLowerCase()}';
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
              final name = (data['name'] ?? '') as String;

              final primaryLang = (data['primaryLanguage'] ?? '-') as String;

              final breakdown = _formatLanguageBreakdown(
                data['languageStats'],
                primaryLang: primaryLang,
                maxItems: 3,
              );

              return Card(
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
                              fontSize: 12,
                              color: AppColors.textSoft,
                            ),
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
                          if (value == 'delete') {
                            await _handleDelete(
                              projectId: projectId,
                              projectName: name,
                            );
                          }
                        },
                        itemBuilder: (context) => const [
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectTasksScreen(
                          projectId: projectId,
                          projectName: name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
