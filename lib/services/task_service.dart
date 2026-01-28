import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Oturum bulunamadı. Tekrar giriş yap.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _tasksRef(String projectId) {
    return _db.collection('projects').doc(projectId).collection('tasks');
  }

  Future<void> addTask({
    required String projectId,
    required String title,
    String? description,
    required int priority,
    required DateTime dueDate,
  }) async {
    final uid = _uid;

    final t = title.trim();
    final d = description?.trim();

    await _tasksRef(projectId).add({
      // ✅ hocanın istediği: task içinde hangi projeye ait olduğu bilgisi
      'projectId': projectId,

      'title': t,
      if (d != null && d.isNotEmpty) 'description': d,

      'priority': priority,
      'dueDate': Timestamp.fromDate(dueDate),

      // (Zorunlu değil ama faydalı) task'ı kim oluşturdu
      'ownerId': uid,

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> tasksStream({
    required String projectId,
    required String orderByField, // 'dueDate' veya 'priority'
    required bool descending,
  }) {
    return _tasksRef(projectId)
        .orderBy(orderByField, descending: descending)
        .snapshots();
  }
}
