import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';
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
        title: Row(
          children: [
            const _AnimatedLogo(),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ana Sayfa',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
            const _InviteSection(),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _HomeCard(
                    title: 'Proje Yükle',
                    subtitle: 'ZIP seç veya GitHub ile proje oluştur',
                    icon: Icons.upload_file,
                    onTap: () => _goTo(context, const ImportProjectScreen()),
                  ),
                  _HomeCard(
                    title: 'Projelerim',
                    subtitle: 'Projeleri görüntüle ve yönet',
                    icon: Icons.folder_open,
                    onTap: () => _goTo(context, const ProjectsScreen()),
                  ),
                  _HomeCard(
                    title: 'Kod Analizi',
                    subtitle: 'Önce proje seç, sonra analiz yöntemi belirle',
                    icon: Icons.manage_search,
                    onTap: () => _goTo(context, const ProjectsScreen()),
                  ),
                  _HomeCard(
                    title: 'Analiz Geçmişi',
                    subtitle: 'Daha önce kaydedilen analiz sonuçları',
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

class _InviteSection extends StatelessWidget {
  const _InviteSection();

  @override
  Widget build(BuildContext context) {
    final service = ProjectService();

    return StreamBuilder(
      stream: service.myPendingInvitesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Davetler yüklenirken bir hata oluştu: ${snapshot.error}',
                style: const TextStyle(color: AppColors.textSoft),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Proje davetleri yükleniyor...',
                    style: TextStyle(color: AppColors.textSoft),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.textSoft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bekleyen proje davetin bulunmuyor.',
                      style: const TextStyle(color: AppColors.textSoft),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.mail_outline,
                      color: AppColors.teal,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Bekleyen Proje Davetleri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...docs.map((doc) {
                  final data = doc.data();
                  final inviteId =
                      (data['inviteId'] ?? doc.id).toString().trim();
                  final projectName =
                      (data['projectName'] ?? 'Adsız Proje').toString().trim();
                  final role = (data['role'] ?? 'member').toString().trim();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InviteCard(
                      inviteId: inviteId,
                      projectName:
                          projectName.isEmpty ? 'Adsız Proje' : projectName,
                      role: role.isEmpty ? 'member' : role,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InviteCard extends StatefulWidget {
  final String inviteId;
  final String projectName;
  final String role;

  const _InviteCard({
    required this.inviteId,
    required this.projectName,
    required this.role,
  });

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  final ProjectService _service = ProjectService();
  bool _loading = false;

  Future<void> _accept() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _service.acceptInvite(inviteId: widget.inviteId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${widget.projectName}" projesi daveti kabul edildi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet kabul edilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _service.rejectInvite(inviteId: widget.inviteId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${widget.projectName}" projesi daveti reddedildi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet reddedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Yönetici';
      case 'member':
      default:
        return 'Üye';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navySoft.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.navySoft,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.projectName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rol: ${_roleLabel(widget.role)}',
            style: const TextStyle(
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _reject,
                  child: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _accept,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kabul Et'),
                ),
              ),
            ],
          ),
        ],
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

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.10).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Image.asset(
        'assets/icon/icon_app.png',
        width: 36,
        height: 36,
      ),
    );
  }
}
