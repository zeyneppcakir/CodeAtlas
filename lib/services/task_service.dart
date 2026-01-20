import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Oturum bulunamadı. Tekrar giriş yap.');
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
    required DateTime dueDate, // artık zorunlu (sen zaten boş bırakmıyorsun)
  }) async {
    final uid = _uid;

    await _tasksRef(projectId).add({
      'title': title.trim(),
      'description': description?.trim(),
      'priority': priority,
      'dueDate': Timestamp.fromDate(dueDate),
      'ownerId': uid, // ✅ RULES ile uyumlu alan
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
