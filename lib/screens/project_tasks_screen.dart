import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import '../theme/priority_style.dart';
import 'add_task_screen.dart';
import 'activity_log_screen.dart';

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
  final _projectService = ProjectService();

  String _sort = 'dueDate';
  bool _desc = false;
  String _statusFilter = 'all';

  void _handleAiAnalyze() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI Analiz (yakında): ${widget.projectName}')),
    );
  }

  void _openActivityLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityLogScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  Future<void> _openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(projectId: widget.projectId),
      ),
    );
  }

  String _safeStatus(dynamic raw) {
    final s = (raw ?? 'todo').toString().toLowerCase().trim();
    if (s == 'todo' || s == 'doing' || s == 'done') return s;
    return 'todo';
  }

  Future<void> _openMembersSheet() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Üyeler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _showAddMemberDialog();
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Üye Ekle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _projectService.membersStream(widget.projectId),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text(
                            'Hata: ${snap.error}',
                            style: const TextStyle(color: AppColors.textSoft),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = snap.data!.docs;

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'Henüz üye yok. "Üye Ekle" ile ekleyebilirsin.',
                              style: TextStyle(color: AppColors.textSoft),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = docs[i].data();
                            final email = (d['email'] ?? '-') as String;
                            final role = (d['role'] ?? 'member') as String;

                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(email),
                              subtitle: Text('Rol: $role'),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddMemberDialog() async {
    final ctrl = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Üye ekle'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı email',
              hintText: 'ornek@gmail.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );

    if (email == null || email.trim().isEmpty) return;

    try {
      await _projectService.addMemberByEmail(
        projectId: widget.projectId,
        email: email.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Üye eklendi ✅ $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Üye eklenemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text(widget.projectName),
        actions: [
          IconButton(
            tooltip: 'Üyeler',
            onPressed: _openMembersSheet,
            icon: const Icon(Icons.group_add_outlined),
          ),
          IconButton(
            tooltip: 'AI Analiz Et',
            onPressed: _handleAiAnalyze,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: 'Aktivite Logu',
            onPressed: _openActivityLog,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.teal,
        onPressed: _openAddTask,
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
                    decoration: const InputDecoration(labelText: 'Sırala'),
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
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tümü')),
                DropdownMenuItem(value: 'todo', child: Text('Yapılacak')),
                DropdownMenuItem(value: 'doing', child: Text('Devam Ediyor')),
                DropdownMenuItem(value: 'done', child: Text('Tamamlandı')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              decoration: const InputDecoration(labelText: 'Durum filtresi'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _service.tasksStream(
                  projectId: widget.projectId,
                  orderByField: _sort,
                  descending: _desc,
                  statusFilter: _statusFilter,
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
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final d = doc.data();

                      final taskId = doc.id;
                      final title = (d['title'] ?? '') as String;
                      final description = d['description'] as String?;
                      final priority = (d['priority'] ?? 2) as int;

                      final assigneeId = (d['assigneeId'] as String?)?.trim();
                      final assigneeEmail =
                          (d['assigneeEmail'] as String?)?.trim();
                      final hasAssignee =
                          assigneeEmail != null && assigneeEmail.isNotEmpty;

                      final due = d['dueDate'];
                      final dueDate = (due is Timestamp) ? due.toDate() : null;

                      final dueText = (dueDate != null)
                          ? '${dueDate.day}.${dueDate.month}.${dueDate.year}'
                          : 'Tarih yok';

                      final hasDesc =
                          description != null && description.trim().isNotEmpty;

                      final status = _safeStatus(d['status']);
                      final isDone = status == 'done';
                      final aiGenerated = (d['aiGenerated'] == true);

                      return Card(
                        child: ListTile(
                          onLongPress: () => _showTaskActions(
                            taskId: taskId,
                            title: title,
                            description: description,
                            priority: priority,
                            dueDate: dueDate,
                            assigneeId: assigneeId,
                            assigneeEmail: assigneeEmail,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusChip(status),
                              if (aiGenerated) ...[
                                const SizedBox(width: 6),
                                _aiChip(),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Bitiş: $dueText'),
                              if (hasAssignee) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Atanan: $assigneeEmail',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSoft,
                                  ),
                                ),
                              ],
                              if (hasDesc) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description!.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSoft,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: isDone
                                    ? 'Yapılacak olarak işaretle'
                                    : 'Tamamlandı olarak işaretle',
                                child: Transform.scale(
                                  scale: 1.05,
                                  child: Checkbox(
                                    value: isDone,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (v) async {
                                      final next =
                                          (v == true) ? 'done' : 'todo';
                                      try {
                                        await _service.setStatus(
                                          projectId: widget.projectId,
                                          taskId: taskId,
                                          status: next,
                                          taskTitle: title,
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Durum güncellenemedi: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
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
                                  assigneeId: assigneeId,
                                  assigneeEmail: assigneeEmail,
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
    String? assigneeId,
    String? assigneeEmail,
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
                        initialAssigneeId: assigneeId,
                        initialAssigneeEmail: assigneeEmail,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Durum değiştir'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showStatusPicker(taskId: taskId, title: title);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirmDelete();
                  if (ok != true) return;

                  try {
                    await _service.deleteTask(
                      projectId: widget.projectId,
                      taskId: taskId,
                      taskTitle: title,
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

  Future<void> _showStatusPicker({
    required String taskId,
    required String title,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Durum seç'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.radio_button_unchecked),
                title: const Text('Yapılacak'),
                onTap: () => Navigator.pop(ctx, 'todo'),
              ),
              ListTile(
                leading: const Icon(Icons.timelapse),
                title: const Text('Devam Ediyor'),
                onTap: () => Navigator.pop(ctx, 'doing'),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Tamamlandı'),
                onTap: () => Navigator.pop(ctx, 'done'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;

    try {
      await _service.setStatus(
        projectId: widget.projectId,
        taskId: taskId,
        status: selected,
        taskTitle: title,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Durum güncellenemedi: $e')),
      );
    }
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

  Widget _statusChip(String status) {
    String label;
    IconData icon;

    switch (status) {
      case 'doing':
        label = 'Devam';
        icon = Icons.timelapse;
        break;
      case 'done':
        label = 'Bitti';
        icon = Icons.check_circle_outline;
        break;
      case 'todo':
      default:
        label = 'Yapılacak';
        icon = Icons.radio_button_unchecked;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _aiChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSoft),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy, size: 14),
          SizedBox(width: 6),
          Text('AI'),
        ],
      ),
    );
  }
}
