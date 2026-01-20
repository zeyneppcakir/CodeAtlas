import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/task_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String projectId;
  const AddTaskScreen({super.key, required this.projectId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _priority = 2;
  DateTime? _dueDate;
  bool _loading = false;

  final _service = TaskService();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _dueDate ?? now,
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task başlığı boş olamaz')),
      );
      return;
    }

    // İlk sürümde index/ordering derdi çıkmasın diye dueDate boş bırakma:
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir bitiş tarihi seç')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.addTask(
        projectId: widget.projectId,
        title: title,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        priority: _priority,
        dueDate: _dueDate!, // zaten null kontrolünü yapıyorsun
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _dueDate == null
        ? 'Tarih seç'
        : '${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Yeni Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration:
                  const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _priority,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 - Düşük')),
                DropdownMenuItem(value: 2, child: Text('2 - Orta')),
                DropdownMenuItem(value: 3, child: Text('3 - Yüksek')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 2),
              decoration: const InputDecoration(labelText: 'Öncelik'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.date_range),
                label: Text(dueText),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
