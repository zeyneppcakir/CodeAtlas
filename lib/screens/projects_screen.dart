import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:codeatlas/screens/analysis_menu_screen.dart';
import 'package:codeatlas/screens/import_project_screen.dart';
import 'package:codeatlas/screens/project_tasks_screen.dart';
import 'package:codeatlas/services/project_service.dart';
import 'package:codeatlas/theme/app_theme.dart';
import '../widgets/codeatlas_appbar.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectService _service = ProjectService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, Future<bool>> _memberCheckCache = {};
  final Map<String, Future<_ProjectProgressData>> _progressCache = {};

  String? get _uid => _auth.currentUser?.uid;

  String _safeText(dynamic value, String fallback) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

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
        .then((snap) {
      if (!snap.exists) return false;

      final data = snap.data();
      final status = (data?['status'] ?? '').toString().trim().toLowerCase();

      return status == 'active' || status == 'approved';
    }).catchError((_) => false);

    _memberCheckCache[projectId] = future;
    return future;
  }

  Future<_ProjectProgressData> _getProjectProgress(String projectId) {
    final cached = _progressCache[projectId];
    if (cached != null) return cached;

    final future = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .get()
        .then((snap) {
      final docs = snap.docs;

      final total = docs.length;
      int done = 0;
      int doing = 0;
      int todo = 0;

      for (final doc in docs) {
        final status =
            (doc.data()['status'] ?? 'todo').toString().trim().toLowerCase();

        if (status == 'done') {
          done++;
        } else if (status == 'doing') {
          doing++;
        } else {
          todo++;
        }
      }

      return _ProjectProgressData(
        total: total,
        done: done,
        doing: doing,
        todo: todo,
      );
    }).catchError((_) {
      return const _ProjectProgressData(
        total: 0,
        done: 0,
        doing: 0,
        todo: 0,
      );
    });

    _progressCache[projectId] = future;
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

      _progressCache.remove(projectId);
      _memberCheckCache.remove(projectId);

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

  Future<void> _openImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportProjectScreen(),
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

  Widget _roleChip(bool isOwner) {
    return Container(
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

  Color _languageColor(String language) {
    final key = language.trim().toLowerCase();

    switch (key) {
      case 'dart':
        return const Color(0xFF42A5F5);
      case 'python':
        return const Color(0xFF4CAF50);
      case 'javascript':
        return const Color(0xFFFFCA28);
      case 'typescript':
        return const Color(0xFF1E88E5);
      case 'java':
        return const Color(0xFFEF5350);
      case 'kotlin':
        return const Color(0xFFAB47BC);
      case 'c#':
        return const Color(0xFF7E57C2);
      case 'c':
      case 'c/c++':
      case 'c++':
        return const Color(0xFF90A4AE);
      case 'swift':
        return const Color(0xFFFF7043);
      case 'go':
        return const Color(0xFF26C6DA);
      case 'php':
        return const Color(0xFF5C6BC0);
      case 'html':
        return const Color(0xFFFF7043);
      case 'css':
        return const Color(0xFF29B6F6);
      case 'rust':
        return const Color(0xFFA1887F);
      default:
        return AppColors.textSoft;
    }
  }

  Widget _languageChip({
    required String label,
    required Color color,
    String? trailingText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailingText == null ? label : '$label $trailingText',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<_LanguageItem> _extractLanguageItems(
    dynamic rawStats, {
    String? primaryLang,
    int maxItems = 4,
  }) {
    if (rawStats is! Map) return [];

    final items = <_LanguageItem>[];

    rawStats.forEach((key, value) {
      final lang = key?.toString().trim();
      if (lang == null || lang.isEmpty) return;

      int? parsedValue;
      if (value is int) parsedValue = value;
      if (value is double) parsedValue = value.round();
      if (value is String) parsedValue = int.tryParse(value);

      if (parsedValue == null || parsedValue <= 0) return;

      items.add(
        _LanguageItem(
          language: lang,
          percent: parsedValue,
        ),
      );
    });

    items.sort((a, b) => b.percent.compareTo(a.percent));

    if (primaryLang != null && primaryLang.trim().isNotEmpty) {
      items.sort((a, b) {
        if (a.language.toLowerCase() == primaryLang.toLowerCase()) return -1;
        if (b.language.toLowerCase() == primaryLang.toLowerCase()) return 1;
        return b.percent.compareTo(a.percent);
      });
    }

    return items.take(maxItems).toList();
  }

  Widget _buildActionText({
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: color ?? AppColors.teal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(_ProjectProgressData progress) {
    final ratio = progress.ratio;
    final color = progress.progressColor;

    if (progress.total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Görev İlerlemesi',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Henüz task eklenmemiş.',
            style: TextStyle(
              color: AppColors.textSoft,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Görev İlerlemesi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'İlerleme: %${progress.percent}',
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${progress.done}/${progress.total} tamamlandı',
              style: const TextStyle(
                color: AppColors.textSoft,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _smallInfoChip(
              'Tamamlandı: ${progress.done}',
              color: Colors.green,
            ),
            _smallInfoChip(
              'Devam ediyor: ${progress.doing}',
              color: Colors.orange,
            ),
            _smallInfoChip(
              'Yapılacak: ${progress.todo}',
              color: Colors.redAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _smallInfoChip(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProjectCard({
    required String projectId,
    required String name,
    required String primaryLang,
    required dynamic languageStats,
    required bool isOwner,
  }) {
    final languageItems = _extractLanguageItems(
      languageStats,
      primaryLang: primaryLang,
      maxItems: 4,
    );

    final primaryColor = _languageColor(primaryLang);

    return FutureBuilder<_ProjectProgressData>(
      future: _getProjectProgress(projectId),
      builder: (context, progressSnapshot) {
        final progress = progressSnapshot.data ??
            const _ProjectProgressData(
              total: 0,
              done: 0,
              doing: 0,
              todo: 0,
            );

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openProjectTasks(
              projectId: projectId,
              projectName: name,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _languageChip(
                                  label: primaryLang,
                                  color: primaryColor,
                                ),
                                _roleChip(isOwner),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (languageItems.isNotEmpty) ...[
                    const Text(
                      'Dil Dağılımı',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: languageItems.map((item) {
                        return _languageChip(
                          label: item.language,
                          color: _languageColor(item.language),
                          trailingText: '%${item.percent}',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildProgressBar(progress),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _buildActionText(
                        label: 'Kod Analizi',
                        onTap: () => _openAnalysisMenu(
                          projectId: projectId,
                          projectName: name,
                        ),
                      ),
                      _buildActionText(
                        label: 'Task Ekranı',
                        onTap: () => _openProjectTasks(
                          projectId: projectId,
                          projectName: name,
                        ),
                      ),
                      if (isOwner)
                        _buildActionText(
                          label: 'Projeyi Sil',
                          color: Colors.redAccent,
                          onTap: () => _handleDelete(
                            projectId: projectId,
                            projectName: name,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Bir hata oluştu: $error',
          style: const TextStyle(color: AppColors.textSoft),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CodeAtlasAppBar(),
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
            return _buildErrorState(snapshot.error!);
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
            return _buildEmptyState();
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

              final isOwner = ownerId == uid;

              if (isOwner) {
                return _buildProjectCard(
                  projectId: projectId,
                  name: name,
                  primaryLang: primaryLang,
                  languageStats: data['languageStats'],
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
                    languageStats: data['languageStats'],
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

class _LanguageItem {
  final String language;
  final int percent;

  const _LanguageItem({
    required this.language,
    required this.percent,
  });
}

class _ProjectProgressData {
  final int total;
  final int done;
  final int doing;
  final int todo;

  const _ProjectProgressData({
    required this.total,
    required this.done,
    required this.doing,
    required this.todo,
  });

  double get ratio {
    if (total == 0) return 0;
    return done / total;
  }

  int get percent {
    return (ratio * 100).round();
  }

  Color get progressColor {
    if (ratio >= 0.80) return Colors.green;
    if (ratio >= 0.40) return Colors.orange;
    return Colors.redAccent;
  }
}
