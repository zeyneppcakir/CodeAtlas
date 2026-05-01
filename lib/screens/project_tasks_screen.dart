import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import '../theme/priority_style.dart';
import '../widgets/codeatlas_appbar.dart';
import 'activity_log_screen.dart';
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
  final TaskService _service = TaskService();
  final ProjectService _projectService = ProjectService();

  String _sort = 'dueDate';
  bool _desc = false;
  String _statusFilter = 'all';

  void _handleAiAnalyze() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'AI analiz özelliği bu proje için yakında genişletilecek: ${widget.projectName}',
        ),
      ),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tarih yok';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  bool _isValidEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return false;

    final regex = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    return regex.hasMatch(value);
  }

  Color _progressColor(double ratio) {
    if (ratio >= 0.80) return Colors.green;
    if (ratio >= 0.40) return Colors.orange;
    return Colors.redAccent;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'doing':
        return 'Devam Ediyor';
      case 'done':
        return 'Tamamlandı';
      case 'todo':
      default:
        return 'Yapılacak';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'doing':
        return Colors.orange;
      case 'done':
        return Colors.green;
      case 'todo':
      default:
        return Colors.redAccent;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'doing':
        return Icons.timelapse;
      case 'done':
        return Icons.check_circle_outline;
      case 'todo':
      default:
        return Icons.radio_button_unchecked;
    }
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
              height: MediaQuery.of(ctx).size.height * 0.72,
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
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snap.data!.docs;

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'Henüz üye yok. "Üye Ekle" ile yeni üye davet edebilirsin.',
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
                            final memberStatus =
                                (d['status'] ?? 'active').toString().trim();

                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(email),
                              subtitle: Text('Rol: $role'),
                              trailing: _smallInfoChip(
                                _memberStatusLabel(memberStatus),
                                color: _memberStatusColor(memberStatus),
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
          ),
        );
      },
    );
  }

  String _memberStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Beklemede';
      case 'approved':
        return 'Onaylandı';
      case 'active':
        return 'Aktif';
      default:
        return 'Üye';
    }
  }

  Color _memberStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'active':
        return Colors.green;
      default:
        return AppColors.textSoft;
    }
  }

  Future<void> _showAddMemberDialog() async {
    final ctrl = TextEditingController();
    String? errorText;

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Üye ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı e-posta adresi',
                      hintText: 'ornek@gmail.com',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Not: Davet/posta/onay akışı servis tarafında destekleniyorsa bu üyeye bildirim gönderilebilir.',
                    style: TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = ctrl.text.trim();

                    if (!_isValidEmail(value)) {
                      setDialogState(() {
                        errorText = 'Geçerli bir e-posta adresi gir.';
                      });
                      return;
                    }

                    Navigator.pop(ctx, value);
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
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
        SnackBar(
          content: Text('Üye işlemi başlatıldı: $email'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Üye eklenemedi: $e')),
      );
    }
  }

  Future<void> _editTask({
    required String taskId,
    required String title,
    required String? description,
    required int priority,
    required DateTime? startDate,
    required DateTime? dueDate,
    String? assigneeId,
    String? assigneeEmail,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          projectId: widget.projectId,
          taskId: taskId,
          initialTitle: title,
          initialDescription: description,
          initialPriority: priority,
          initialStartDate: startDate,
          initialDueDate: dueDate,
          initialAssigneeId: assigneeId,
          initialAssigneeEmail: assigneeEmail,
        ),
      ),
    );
  }

  Future<void> _deleteTask({
    required String taskId,
    required String title,
  }) async {
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
  }

  Widget _buildProgressCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final total = docs.length;
    final doneCount = docs.where((doc) {
      final status = _safeStatus(doc.data()['status']);
      return status == 'done';
    }).length;

    final doingCount = docs.where((doc) {
      final status = _safeStatus(doc.data()['status']);
      return status == 'doing';
    }).length;

    final todoCount = docs.where((doc) {
      final status = _safeStatus(doc.data()['status']);
      return status == 'todo';
    }).length;

    final ratio = total == 0 ? 0.0 : doneCount / total;
    final percent = (ratio * 100).round();
    final progressColor = _progressColor(ratio);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 86,
              height: 86,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 86,
                    height: 86,
                    child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 10,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  Text(
                    '%$percent',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proje İlerleme Durumu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toplam görev: $total',
                    style: const TextStyle(color: AppColors.textSoft),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _smallInfoChip(
                        'Tamamlandı: $doneCount',
                        color: Colors.green,
                      ),
                      _smallInfoChip(
                        'Devam ediyor: $doingCount',
                        color: Colors.orange,
                      ),
                      _smallInfoChip(
                        'Yapılacak: $todoCount',
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallInfoChip(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
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
        style: TextStyle(
          color: PriorityStyle.textColor(p),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor(status).withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 14,
            color: _statusColor(status),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: _statusColor(status),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSoft.withOpacity(0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy,
            size: 14,
            color: AppColors.textSoft,
          ),
          SizedBox(width: 6),
          Text(
            'AI',
            style: TextStyle(
              color: AppColors.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskActionText({
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

  Widget _buildTaskCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    final taskId = doc.id;
    final title = (d['title'] ?? '') as String;
    final description = d['description'] as String?;
    final priority = (d['priority'] ?? 2) as int;

    final assigneeId = (d['assigneeId'] as String?)?.trim();
    final assigneeEmail = (d['assigneeEmail'] as String?)?.trim();
    final hasAssignee = assigneeEmail != null && assigneeEmail.isNotEmpty;

    final rawStart = d['startDate'];
    final startDate = (rawStart is Timestamp) ? rawStart.toDate() : null;

    final rawDue = d['dueDate'];
    final dueDate = (rawDue is Timestamp) ? rawDue.toDate() : null;

    final startText = _formatDate(startDate);
    final dueText = _formatDate(dueDate);

    final hasDesc = description != null && description.trim().isNotEmpty;

    final status = _safeStatus(d['status']);
    final isDone = status == 'done';
    final aiGenerated = (d['aiGenerated'] == true);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    decoration: isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                _statusChip(status),
                if (aiGenerated) _aiChip(),
                _priorityChip(priority),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Başlangıç: $startText',
              style: const TextStyle(color: AppColors.textSoft),
            ),
            const SizedBox(height: 4),
            Text(
              'Bitiş: $dueText',
              style: const TextStyle(color: AppColors.textSoft),
            ),
            if (hasAssignee) ...[
              const SizedBox(height: 4),
              Text(
                'Atanan: $assigneeEmail',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSoft),
              ),
            ],
            if (hasDesc) ...[
              const SizedBox(height: 8),
              Text(
                description!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSoft,
                  decoration:
                      isDone ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Transform.scale(
                  scale: 1.0,
                  child: Checkbox(
                    value: isDone,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) async {
                      final next = (v == true) ? 'done' : 'todo';
                      try {
                        await _service.setStatus(
                          projectId: widget.projectId,
                          taskId: taskId,
                          status: next,
                          taskTitle: title,
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Durum güncellenemedi: $e'),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _taskActionText(
                        label: 'Düzenle',
                        onTap: () => _editTask(
                          taskId: taskId,
                          title: title,
                          description: description,
                          priority: priority,
                          startDate: startDate,
                          dueDate: dueDate,
                          assigneeId: assigneeId,
                          assigneeEmail: assigneeEmail,
                        ),
                      ),
                      _taskActionText(
                        label: 'Durum',
                        onTap: () => _showStatusPicker(
                          taskId: taskId,
                          title: title,
                        ),
                      ),
                      _taskActionText(
                        label: 'Sil',
                        color: Colors.redAccent,
                        onTap: () => _deleteTask(
                          taskId: taskId,
                          title: title,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.projectName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Görevleri görüntüle, filtrele, düzenle ve proje ilerlemesini takip et.',
            style: TextStyle(
              color: AppColors.textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              'Henüz task yok. Sağ alttaki + butonuyla ekleyebilirsin.',
              style: TextStyle(color: AppColors.textSoft),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            _buildProgressCard(docs),
            const SizedBox(height: 12),
            ...List.generate(docs.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == docs.length - 1 ? 0 : 10,
                ),
                child: _buildTaskCard(docs[i]),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CodeAtlasAppBar(
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
            _buildPageHeader(),
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
                      DropdownMenuItem(
                        value: 'startDate',
                        child: Text('Başlangıca göre'),
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
                  icon: Icon(
                    _desc ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                  color: AppColors.teal,
                  tooltip: 'Artan / Azalan',
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tümü')),
                DropdownMenuItem(value: 'todo', child: Text('Yapılacak')),
                DropdownMenuItem(
                  value: 'doing',
                  child: Text('Devam Ediyor'),
                ),
                DropdownMenuItem(value: 'done', child: Text('Tamamlandı')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              decoration: const InputDecoration(
                labelText: 'Durum filtresi',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildTaskList()),
          ],
        ),
      ),
    );
  }
}
