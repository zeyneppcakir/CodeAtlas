import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ActivityLogScreen extends StatelessWidget {
  final String projectId;
  final String projectName;

  const ActivityLogScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  String _actionLabel(String action) {
    switch (action) {
      case 'created':
        return 'Task oluşturuldu';
      case 'updated':
        return 'Task güncellendi';
      case 'deleted':
        return 'Task silindi';
      case 'status_changed':
        return 'Durum değiştirildi';
      case 'ai_generated':
        return 'AI içerik üretti';
      default:
        return action; // bilinmeyen action gelirse olduğu gibi göster
    }
  }

  IconData _iconDataForAction(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
        return Icons.edit_outlined;
      case 'deleted':
        return Icons.delete_outline;
      case 'status_changed':
        return Icons.flag_outlined;
      case 'ai_generated':
        return Icons.smart_toy_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(DateTime time) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(time.day)}.${two(time.month)}.${time.year} '
        '${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final logsQuery = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('activity_logs')
        .orderBy('createdAt', descending: true)
        .limit(80);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text('Aktivite • $projectName'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: logsQuery.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Hata: ${snap.error}',
                style: const TextStyle(color: AppColors.textSoft),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Henüz aktivite yok.',
                style: TextStyle(color: AppColors.textSoft),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final d = docs[i].data();

              final action = (d['action'] ?? '').toString().trim();
              final taskTitle = (d['taskTitle'] ?? '—').toString().trim();

              // createdAt
              DateTime? time;
              final createdAt = d['createdAt'];
              if (createdAt is Timestamp) time = createdAt.toDate();

              // meta (opsiyonel)
              String? metaText;
              final meta = d['meta'];
              if (meta is Map) {
                if (meta['status'] != null) {
                  metaText = 'status: ${meta['status']}';
                } else if (meta['aiUpdated'] == true) {
                  metaText = 'ai: güncellendi';
                }
              }

              return Card(
                child: ListTile(
                  leading: Icon(
                    _iconDataForAction(action),
                    color: AppColors.teal,
                  ),
                  title: Text(
                    taskTitle.isEmpty ? '—' : taskTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_actionLabel(action)),
                      if (metaText != null) Text(metaText),
                    ],
                  ),
                  trailing: Text(
                    time != null ? _formatTime(time) : '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSoft,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
