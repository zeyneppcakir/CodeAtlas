import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/task_service.dart';
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
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final title = (d['title'] ?? '') as String;
                      final priority = (d['priority'] ?? 2) as int;

                      final due = d['dueDate'];
                      final dueText = (due is Timestamp)
                          ? '${due.toDate().day}.${due.toDate().month}.${due.toDate().year}'
                          : 'Tarih yok';

                      return Card(
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text('Bitiş: $dueText'),
                          trailing: _priorityChip(priority),
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

  Widget _priorityChip(int p) {
    final text =
        switch (p) { 1 => 'Düşük', 2 => 'Orta', 3 => 'Yüksek', _ => 'Orta' };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withOpacity(0.6)),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.text)),
    );
  }
}
