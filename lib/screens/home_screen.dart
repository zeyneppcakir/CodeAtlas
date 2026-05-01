import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/codeatlas_appbar.dart';
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
          'Çıkış yapmak istiyor musun?',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Oturumun kapatılacak ve yeniden giriş yapman gerekecek.',
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
            child: const Text('Çıkış Yap'),
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
      const SnackBar(content: Text('Çıkış yapıldı.')),
    );
  }

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: CodeAtlasAppBar(
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _PageSectionHeader(
              title: 'Ana Sayfa',
              subtitle:
                  'Projelerini yönet, analizleri görüntüle ve içe aktarma işlemlerini başlat.',
            ),
            const SizedBox(height: 14),
            _WelcomeCard(
              userName: user?.displayName,
              userEmail: user?.email,
            ),
            const SizedBox(height: 14),
            const _AIFeatureCard(),
            const SizedBox(height: 14),
            const _InviteSection(),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.08,
                children: [
                  _HomeCard(
                    title: 'Proje İçe Aktar',
                    subtitle:
                        'ZIP yükle veya GitHub bağlantısıyla yeni proje ekle',
                    icon: Icons.upload_file_outlined,
                    onTap: () => _goTo(context, const ImportProjectScreen()),
                  ),
                  _HomeCard(
                    title: 'Projelerim',
                    subtitle: 'Projelerini görüntüle, aç ve yönet',
                    icon: Icons.folder_open_outlined,
                    onTap: () => _goTo(context, const ProjectsScreen()),
                  ),
                  _HomeCard(
                    title: 'Kod Analizi',
                    subtitle:
                        'Bir proje seçerek statik analiz ve yapay zekâ yorumunu görüntüle',
                    icon: Icons.manage_search_outlined,
                    onTap: () => _goTo(context, const ProjectsScreen()),
                  ),
                  _HomeCard(
                    title: 'Analiz Geçmişi',
                    subtitle:
                        'Daha önce oluşturduğun analiz kayıtlarını incele',
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

class AnimatedBrandText extends StatefulWidget {
  const AnimatedBrandText({super.key});

  @override
  State<AnimatedBrandText> createState() => _AnimatedBrandTextState();
}

class _AnimatedBrandTextState extends State<AnimatedBrandText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 4, end: 18).animate(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Text(
            'CodeAtlas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: AppColors.text,
              shadows: [
                Shadow(
                  color: AppColors.teal.withOpacity(0.85),
                  blurRadius: _glowAnimation.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
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
      child: SizedBox(
        width: 82,
        height: 82,
        child: ClipOval(
          child: Image.asset(
            'assets/icon/icon_foreground.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _PageSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageSectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String? userName;
  final String? userEmail;

  const _WelcomeCard({
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.teal,
          child: Icon(Icons.person, color: Colors.black),
        ),
        title: Text(
          (userName != null && userName!.trim().isNotEmpty)
              ? userName!.trim()
              : 'Kullanıcı',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          (userEmail != null && userEmail!.trim().isNotEmpty)
              ? userEmail!.trim()
              : 'E-posta bilgisi bulunamadı',
        ),
      ),
    );
  }
}

class _AIFeatureCard extends StatelessWidget {
  const _AIFeatureCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withOpacity(0.16),
            AppColors.navySoft.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.teal.withOpacity(0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.teal,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yapay Zekâ Destekli Analiz',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Projelerini yalnızca statik olarak incelemekle kalma. Kod metriklerini farklı modellerle yorumla, geliştirme önerileri al ve özel istemlerle analiz üret.',
                    style: TextStyle(
                      color: AppColors.textSoft,
                      height: 1.45,
                    ),
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
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Aç',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.teal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
