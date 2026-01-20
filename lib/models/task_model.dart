import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final int priority; // 1-3
  final DateTime? dueDate;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    this.dueDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static TaskModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAtTs = data['createdAt'] as Timestamp?;
    final dueTs = data['dueDate'] as Timestamp?;

    return TaskModel(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      description: data['description'] as String?,
      priority: (data['priority'] ?? 2) as int,
      dueDate: dueTs?.toDate(),
      createdAt: (createdAtTs?.toDate()) ?? DateTime.now(),
    );
  }
}
