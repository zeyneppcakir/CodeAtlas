import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../services/project_service.dart';

class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key});

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _nameCtrl = TextEditingController();
  String _language = 'Dart';
  bool _loading = false;

  final _service = ProjectService();

  Future<void> _save() async {
    FocusScope.of(context).unfocus(); // klavyeyi kapat

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proje adı boş olamaz')),
      );
      return;
    }

    // ✅ giriş yapan kullanıcı zorunlu
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bulunamadı. Lütfen tekrar giriş yap.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ userId göndermiyoruz: ProjectService ownerId'yi kendi yazacak
      await _service.addProject(
        name: name,
        primaryLanguage: _language,
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
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Yeni Proje'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'Proje adı',
                hintText: 'Örn: codeatlas-backend',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _save(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _language,
              items: const [
                DropdownMenuItem(value: 'Dart', child: Text('Dart')),
                DropdownMenuItem(value: 'Java', child: Text('Java')),
                DropdownMenuItem(value: 'Python', child: Text('Python')),
                DropdownMenuItem(value: 'C#', child: Text('C#')),
                DropdownMenuItem(
                    value: 'JavaScript', child: Text('JavaScript')),
                DropdownMenuItem(value: 'C/C++', child: Text('C/C++')),
              ],
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _language = v ?? 'Dart'),
              decoration: const InputDecoration(
                labelText: 'Dil (şimdilik manuel)',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
