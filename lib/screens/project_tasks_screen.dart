import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/task_service.dart';
import '../theme/app_theme.dart';
import '../theme/priority_style.dart';
import 'add_task_screen.dart';

class ProjectTasksScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectTasksScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends State<ProjectTasksScreen> {
  final _service = TaskService();

  String _sort = 'dueDate'; // 'dueDate' | 'priority'
  bool _desc = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text(widget.projectName),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.teal,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTaskScreen(projectId: widget.projectId),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(
                        value: 'dueDate',
                        child: Text('Tarihe göre'),
                      ),
                      DropdownMenuItem(
                        value: 'priority',
                        child: Text('Önceliğe göre'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? 'dueDate'),
                    decoration: const InputDecoration(
                      labelText: 'Sırala',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => setState(() => _desc = !_desc),
                  icon: Icon(_desc ? Icons.arrow_downward : Icons.arrow_upward),
                  color: AppColors.teal,
                  tooltip: 'Artan/Azalan',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _service.tasksStream(
                  projectId: widget.projectId,
                  orderByField: _sort,
                  descending: _desc,
                ),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      'Hata: ${snap.error}',
                      style: const TextStyle(color: AppColors.textSoft),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz task yok. + ile ekleyebilirsin.',
                        style: TextStyle(color: AppColors.textSoft),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90), // ✅ eklendi
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final d = doc.data();

                      final taskId = doc.id; // ✅ edit/delete için lazım
                      final title = (d['title'] ?? '') as String;
                      final description = d['description'] as String?;
                      final priority = (d['priority'] ?? 2) as int;

                      final due = d['dueDate'];
                      final dueDate = (due is Timestamp) ? due.toDate() : null;

                      final dueText = (dueDate != null)
                          ? '${dueDate.day}.${dueDate.month}.${dueDate.year}'
                          : 'Tarih yok';

                      return Card(
                        child: ListTile(
                          onLongPress: () => _showTaskActions(
                            taskId: taskId,
                            title: title,
                            description: description,
                            priority: priority,
                            dueDate: dueDate,
                          ),
                          title: Text(title),
                          subtitle: Text('Bitiş: $dueText'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _priorityChip(priority),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _showTaskActions(
                                  taskId: taskId,
                                  title: title,
                                  description: description,
                                  priority: priority,
                                  dueDate: dueDate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTaskActions({
    required String taskId,
    required String title,
    required String? description,
    required int priority,
    required DateTime? dueDate,
  }) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Düzenle'),
                onTap: () async {
                  Navigator.pop(ctx);

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTaskScreen(
                        projectId: widget.projectId,
                        taskId: taskId,
                        initialTitle: title,
                        initialDescription: description,
                        initialPriority: priority,
                        initialDueDate: dueDate,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Sil',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirmDelete();
                  if (ok != true) return;

                  try {
                    await _service.deleteTask(
                      projectId: widget.projectId,
                      taskId: taskId,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Silinemedi: $e')),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Task silinsin mi?'),
          content: const Text('Bu işlem geri alınamaz.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }

  Widget _priorityChip(int p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PriorityStyle.backgroundColor(p),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PriorityStyle.borderColor(p)),
      ),
      child: Text(
        PriorityStyle.label(p),
        style: TextStyle(color: PriorityStyle.textColor(p)),
      ),
    );
  }
}
