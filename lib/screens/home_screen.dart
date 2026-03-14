import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'analysis_history_screen.dart';
import 'import_project_screen.dart';
import 'projects_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<bool> _confirmLogout(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
      ),
    );
    return res ?? false;
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await _confirmLogout(context);
    if (!ok) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Çıkış yapıldı')),
    );
  }

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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

                  // ✅ Kod Analizi: Proje seçmeden menü açılmasın
                  _HomeCard(
                    title: 'Kod Analizi',
                    subtitle: 'Önce proje seç → yöntem seç',
                    icon: Icons.manage_search,
                    onTap: () => _goTo(context, const ProjectsScreen()),
                  ),
                  _HomeCard(
                    title: 'Analiz Geçmişi',
                    subtitle: 'Kaydedilen sonuçlar',
                    icon: Icons.history,
                    onTap: () => _goTo(context, const AnalysisHistoryScreen()),
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
