import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';
import 'import_project_screen.dart';
import 'projects_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<bool> _confirmLogout(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.navySoft,
          title: const Text(
            'Çıkış yap?',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Oturumun kapatılacak ve tekrar giriş yapman gerekecek.',
            style: TextStyle(color: AppColors.textSoft),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'İptal',
                style: TextStyle(color: AppColors.textSoft),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Çıkış'),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await _confirmLogout(context);
    if (!ok) return;

    try {
      // Google ile giriş yaptıysan (özellikle web) signOut mantıklı.
      // Email/Password girişinde zaten sadece FirebaseAuth.signOut yeter.
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {}

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    // ✅ AuthGate otomatik LoginScreen'e döndürecek.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Çıkış yapıldı')),
    );
  }

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.teal,
                  child: Icon(Icons.person, color: Colors.black),
                ),
                title: Text(user?.displayName ?? 'Kullanıcı'),
                subtitle: Text(user?.email ?? ''),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _HomeCard(
                    title: 'Proje Yükle',
                    subtitle: 'ZIP seç → proje oluştur',
                    icon: Icons.upload_file,
                    onTap: () => _goTo(context, const ImportProjectScreen()),
                  ),
                  _HomeCard(
                    title: 'Projelerim',
                    subtitle: 'Proje seç / dil tespiti',
                    icon: Icons.folder_open,
                    onTap: () => _goTo(context, const ProjectsScreen()),
                  ),
                  _HomeCard(
                    title: 'Görevler',
                    subtitle: 'Task ekle / öncelik / bitiş',
                    icon: Icons.task_alt,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Görevler ekranını projeye bağlı olarak yapacağız.',
                          ),
                        ),
                      );
                    },
                  ),
                  _HomeCard(
                    title: 'Sıralama',
                    subtitle: 'Zaman / öncelik filtreleri',
                    icon: Icons.sort,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sıralama özelliği task listesinde olacak.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: AppColors.teal),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
