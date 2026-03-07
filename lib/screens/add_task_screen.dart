import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/task_service.dart';
import '../services/ai_service.dart';
import '../services/project_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String projectId;

  final String? taskId;
  final String? initialTitle;
  final String? initialDescription;
  final int? initialPriority;
  final DateTime? initialDueDate;

  // ✅ yeni
  final String? initialAssigneeId;
  final String? initialAssigneeEmail;

  const AddTaskScreen({
    super.key,
    required this.projectId,
    this.taskId,
    this.initialTitle,
    this.initialDescription,
    this.initialPriority,
    this.initialDueDate,
    this.initialAssigneeId,
    this.initialAssigneeEmail,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int _priority = 2;
  DateTime? _dueDate;

  bool _loading = false;
  bool _aiLoading = false;

  final _service = TaskService();
  final _ai = AIService();
  final _projectService = ProjectService();

  // ✅ seçilen üye
  String? _assigneeId;
  String? _assigneeEmail;

  bool get _isEdit => widget.taskId != null;

  @override
  void initState() {
    super.initState();

    if (_isEdit) {
      _titleCtrl.text = widget.initialTitle ?? '';
      _descCtrl.text = widget.initialDescription ?? '';
      _priority = widget.initialPriority ?? 2;
      _dueDate = widget.initialDueDate;

      _assigneeId = widget.initialAssigneeId;
      _assigneeEmail = widget.initialAssigneeEmail;
    }
  }

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

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir bitiş tarihi seç')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      if (_isEdit) {
        await _service.updateTask(
          projectId: widget.projectId,
          taskId: widget.taskId!,
          title: title,
          description: desc,
          priority: _priority,
          dueDate: _dueDate!,
          assigneeId: _assigneeId,
          assigneeEmail: _assigneeEmail,
        );
      } else {
        await _service.addTask(
          projectId: widget.projectId,
          title: title,
          description: desc,
          priority: _priority,
          dueDate: _dueDate!,
          assigneeId: _assigneeId,
          assigneeEmail: _assigneeEmail,
        );
      }

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

  // ---------------- AI kısmı (Öner -> Seç -> Ekle) ----------------

  String _cleanupTr(String s) {
    var x = s;
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();

    final map = <String, String>{
      'avtorizasyon': 'yetkilendirme',
      'autorizasyon': 'yetkilendirme',
      'authorization': 'yetkilendirme',
      'token sisteminin geliştirisidir': 'token sistemini geliştirme',
    };

    map.forEach((k, v) {
      x = x.replaceAll(RegExp(k, caseSensitive: false), v);
    });

    return x;
  }

  List<String> _parseTaskTitles(String raw) {
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final out = <String>[];
    final bullet = RegExp(r'^(\s*[-*•]|\s*\d+[.)])\s*');

    for (final l in lines) {
      final cleaned = _cleanupTr(l.replaceFirst(bullet, '').trim());
      if (cleaned.length < 3) continue;

      final short =
          cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;

      out.add(short);
      if (out.length >= 12) break;
    }

    final uniq = <String>{};
    return out.where((t) => uniq.add(t.toLowerCase())).toList();
  }

  String _buildPrompt() {
    final note = _descCtrl.text.trim().isEmpty ? '-' : _descCtrl.text.trim();
    final draft = _titleCtrl.text.trim().isEmpty ? '-' : _titleCtrl.text.trim();

    return '''
Sen Türkçe yazan kıdemli bir yazılım proje asistanısın.

Görev: Aşağıdaki konu için 5-7 adet yapılabilir görev öner.
Kurallar:
- SADECE görev başlıklarını yaz.
- Her satırda 1 görev olsun.
- Türkçe dilbilgisi düzgün olsun. Uydurma kelime üretme.
- Kısa ve net olsun (maks 8-10 kelime).
- İngilizce teknik terim gerekiyorsa parantez içinde ver: (auth), (token), (Firestore) gibi.
- Gereksiz süslü cümle yazma.

Bağlam: Flutter (web) + Firebase Auth + Firestore.

Proje:
- Proje ID: ${widget.projectId}
- Kullanıcı notu: $note
- Konu / taslak başlık: "$draft"
''';
  }

  Future<List<String>> _fetchAiTitles() async {
    final raw = await _ai.generateTaskSuggestions(
      prompt: _buildPrompt(),
      model: 'qwen2.5:3b',
    );
    return _parseTaskTitles(raw);
  }

  Future<void> _aiSuggestTasksAndAdd() async {
    if (_aiLoading || _loading) return;

    setState(() => _aiLoading = true);

    try {
      var titles = await _fetchAiTitles();

      if (!mounted) return;

      if (titles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI görev üretemedi.')),
        );
        return;
      }

      final selected = <int>{};
      bool dialogLoading = false;

      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final allSelected = selected.length == titles.length;

              Future<void> onRefresh() async {
                if (dialogLoading) return;

                setLocal(() => dialogLoading = true);
                try {
                  final newTitles = await _fetchAiTitles();

                  if (newTitles.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Yeni öneri gelmedi. Mevcut liste korunuyor.'),
                      ),
                    );
                  }

                  setLocal(() {
                    if (newTitles.isNotEmpty) titles = newTitles;
                    selected.clear();
                  });
                } catch (_) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Yenileme başarısız. Ollama çalışıyor mu?'),
                    ),
                  );
                } finally {
                  setLocal(() => dialogLoading = false);
                }
              }

              return AlertDialog(
                title: const Text('AI Görev Önerileri'),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Eklemek istediklerini işaretle:',
                          style: TextStyle(color: AppColors.textSoft),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: dialogLoading
                                  ? null
                                  : () {
                                      setLocal(() {
                                        selected.clear();
                                        if (!allSelected) {
                                          for (int i = 0;
                                              i < titles.length;
                                              i++) {
                                            selected.add(i);
                                          }
                                        }
                                      });
                                    },
                              icon: Icon(
                                allSelected
                                    ? Icons.clear_all
                                    : Icons.select_all,
                              ),
                              label:
                                  Text(allSelected ? 'Temizle' : 'Hepsini seç'),
                            ),
                            const Spacer(),
                            Text(
                              '${selected.length}/${titles.length}',
                              style: const TextStyle(color: AppColors.textSoft),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: dialogLoading ? null : onRefresh,
                            icon: dialogLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(
                              dialogLoading
                                  ? 'Yenileniyor...'
                                  : 'Yenile (Yeni öneri al)',
                            ),
                          ),
                        ),
                        const Divider(),
                        ...List.generate(titles.length, (i) {
                          final checked = selected.contains(i);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: dialogLoading
                                ? null
                                : (v) {
                                    setLocal(() {
                                      if (v == true) {
                                        selected.add(i);
                                      } else {
                                        selected.remove(i);
                                      }
                                    });
                                  },
                            title: Text(titles[i]),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    onPressed: (selected.isEmpty || dialogLoading)
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: Text('Ekle (${selected.length})'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true || selected.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İptal edildi')),
        );
        return;
      }

      final now = DateTime.now();
      int k = 0;
      final sorted = selected.toList()..sort();

      for (final i in sorted) {
        final due = now.add(Duration(days: 7 * (k + 1)));
        await _service.addTask(
          projectId: widget.projectId,
          title: titles[i],
          description: null,
          priority: _priority,
          dueDate: due,
          status: 'todo',
          aiGenerated: true,
          assigneeId: _assigneeId,
          assigneeEmail: _assigneeEmail,
        );
        k++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} task eklendi ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI hata: $e\n'
            'Kontrol: Ollama açık mı? (http://127.0.0.1:11434/api/tags)',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
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
        title: Text(_isEdit ? 'Task Düzenle' : 'Yeni Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _projectService.membersStream(widget.projectId),
          builder: (context, memberSnap) {
            final memberDocs = memberSnap.data?.docs ?? [];

            final memberItems = <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Atanmadı'),
              ),
              ...memberDocs.map((doc) {
                final d = doc.data();
                final uid = (d['uid'] ?? doc.id).toString();
                final email = (d['email'] ?? '-').toString();

                return DropdownMenuItem<String?>(
                  value: uid,
                  child: Text(email),
                  onTap: () {
                    _assigneeId = uid;
                    _assigneeEmail = email;
                  },
                );
              }),
            ];

            return Column(
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

                // ✅ Atanan üye
                DropdownButtonFormField<String?>(
                  value: _assigneeId,
                  items: memberItems,
                  onChanged: (value) {
                    setState(() {
                      _assigneeId = value;

                      if (value == null) {
                        _assigneeEmail = null;
                        return;
                      }

                      final matched = memberDocs
                          .map((e) => e.data())
                          .cast<Map<String, dynamic>>()
                          .firstWhere(
                            (m) => (m['uid'] ?? '').toString() == value,
                            orElse: () => <String, dynamic>{},
                          );

                      _assigneeEmail =
                          (matched['email'] ?? '').toString().trim().isEmpty
                              ? null
                              : (matched['email'] as String);
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Atanan üye',
                  ),
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
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: (_isEdit || _aiLoading || _loading)
                        ? null
                        : _aiSuggestTasksAndAdd,
                    icon: _aiLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.smart_toy),
                    label: Text(
                        _aiLoading ? 'AI düşünüyor...' : 'AI’dan Task Öner'),
                  ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Güncelle' : 'Kaydet'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
