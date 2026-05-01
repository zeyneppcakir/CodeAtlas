import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/codeatlas_appbar.dart';

class AnalysisHistoryScreen extends StatelessWidget {
  const AnalysisHistoryScreen({super.key});

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception('Oturum yok.');
    return u.uid;
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('analysis_results')
        .where('ownerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: CodeAtlasAppBar(
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Hata: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Henüz analiz kaydı yok.\nProjelerim ekranından analiz başlatınca burada görünecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSoft),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data();

              final projectName =
                  (d['projectName'] ?? d['project'] ?? 'Proje').toString();
              final method = (d['method'] ?? 'unknown').toString();
              final summary = (d['summary'] ?? '').toString();
              final score = d['score'];

              return Card(
                child: ListTile(
                  title: Text(
                    projectName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Yöntem: $method',
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                      if (score != null)
                        Text(
                          'Skor: $score',
                          style: const TextStyle(color: AppColors.textSoft),
                        ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSoft),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // İleride detay ekranı: analysis_detail_screen.dart
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Detay ekranını bir sonraki adımda ekleyeceğiz.'),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
