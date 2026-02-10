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
    final pid = projectId.trim();
    if (pid.isEmpty) throw Exception('ProjectId boş olamaz.');
    return _db.collection('projects').doc(pid).collection('tasks');
  }

  String _cleanTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) throw Exception('Task başlığı boş olamaz.');
    return t;
  }

  String? _cleanDescription(String? description) {
    final d = description?.trim();
    if (d == null || d.isEmpty) return null;
    return d;
  }

  // -------------------------
  // CREATE
  // -------------------------
  Future<void> addTask({
    required String projectId,
    required String title,
    String? description,
    required int priority,
    required DateTime dueDate,
  }) async {
    final uid = _uid;
    final pid = projectId.trim();
    final t = _cleanTitle(title);
    final d = _cleanDescription(description);

    try {
      await _tasksRef(pid).add({
        // (Hocanın isteği) task içinde hangi projeye ait olduğu bilgisi
        'projectId': pid,

        'title': t,
        'description': d, // null olabilir -> temiz

        'priority': priority,
        'dueDate': Timestamp.fromDate(dueDate),

        // task'ı kim oluşturdu (rules/izleme için faydalı)
        'ownerId': uid,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // -------------------------
  // UPDATE (full)
  // -------------------------
  Future<void> updateTask({
    required String projectId,
    required String taskId,
    required String title,
    String? description,
    required int priority,
    required DateTime dueDate,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    final t = _cleanTitle(title);
    final d = _cleanDescription(description);

    try {
      await _tasksRef(pid).doc(tid).update({
        'title': t,
        'description': d, // null olabilir
        'priority': priority,
        'dueDate': Timestamp.fromDate(dueDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // -------------------------
  // UPDATE (partial) - LLM için çok işe yarar
  // -------------------------
  Future<void> updateTaskFields({
    required String projectId,
    required String taskId,
    String? title,
    String? description,
    int? priority,
    DateTime? dueDate,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) data['title'] = _cleanTitle(title);
    if (description != null) {
      // description paramı geldi demek: boşsa null’a çekebiliriz
      data['description'] = _cleanDescription(description);
    }
    if (priority != null) data['priority'] = priority;
    if (dueDate != null) data['dueDate'] = Timestamp.fromDate(dueDate);

    if (data.length == 1) return; // sadece updatedAt var -> boş update yapma

    try {
      await _tasksRef(pid).doc(tid).update(data);
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // -------------------------
  // DELETE
  // -------------------------
  Future<void> deleteTask({
    required String projectId,
    required String taskId,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    try {
      await _tasksRef(pid).doc(tid).delete();
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // -------------------------
  // LISTEN (stream)
  // -------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> tasksStream({
    required String projectId,
    required String orderByField,
    required bool descending,
  }) {
    final pid = projectId.trim();

    // küçük koruma: yanlış field gelirse dueDate'e düş
    final safeOrder = (orderByField == 'dueDate' || orderByField == 'priority')
        ? orderByField
        : 'dueDate';

    return _tasksRef(pid)
        .orderBy(safeOrder, descending: descending)
        .snapshots();
  }

  // -------------------------
  // READ ONCE (LLM için lazım)
  // -------------------------
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getTasksOnce({
    required String projectId,
    String orderByField = 'dueDate',
    bool descending = false,
    int? limit,
  }) async {
    final pid = projectId.trim();
    final safeOrder = (orderByField == 'dueDate' || orderByField == 'priority')
        ? orderByField
        : 'dueDate';

    try {
      Query<Map<String, dynamic>> q =
          _tasksRef(pid).orderBy(safeOrder, descending: descending);
      if (limit != null && limit > 0) q = q.limit(limit);

      final snap = await q.get();
      return snap.docs;
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }
}
