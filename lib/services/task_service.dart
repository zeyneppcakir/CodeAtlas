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

  // ✅ activity log koleksiyonu
  CollectionReference<Map<String, dynamic>> _logsRef(String projectId) {
    final pid = projectId.trim();
    if (pid.isEmpty) throw Exception('ProjectId boş olamaz.');
    return _db.collection('projects').doc(pid).collection('activity_logs');
  }

  // ✅ status doğrulama
  String _cleanStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s != 'todo' && s != 'doing' && s != 'done') {
      throw Exception('Geçersiz status: $status (todo/doing/done olmalı)');
    }
    return s;
  }

  int _cleanPriority(int p) {
    if (p < 1) return 1;
    if (p > 3) return 3;
    return p;
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

  String? _cleanAssigneeId(String? assigneeId) {
    final a = assigneeId?.trim();
    if (a == null || a.isEmpty) return null;
    return a;
  }

  String? _cleanAssigneeEmail(String? assigneeEmail) {
    final a = assigneeEmail?.trim().toLowerCase();
    if (a == null || a.isEmpty) return null;
    return a;
  }

  // ✅ activity log yazıcı (log hatası uygulamayı kırmasın)
  Future<void> _log({
    required String projectId,
    required String action,
    String? taskId,
    String? taskTitle,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final uid = _auth.currentUser?.uid; // log için daha güvenli
      if (uid == null) return;

      await _logsRef(projectId).add({
        'action': action, // created/updated/deleted/status_changed/ai_generated
        if (taskId != null) 'taskId': taskId,
        if (taskTitle != null && taskTitle.trim().isNotEmpty)
          'taskTitle': taskTitle.trim(),
        'userId': uid,
        if (meta != null) 'meta': meta,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // sessiz geç
    }
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
    String status = 'todo',
    Map<String, dynamic>? ai,
    bool aiGenerated = false,

    // ✅ yeni
    String? assigneeId,
    String? assigneeEmail,
  }) async {
    final pid = projectId.trim();
    final t = _cleanTitle(title);
    final d = _cleanDescription(description);
    final s = _cleanStatus(status);
    final pr = _cleanPriority(priority);
    final cleanedAssigneeId = _cleanAssigneeId(assigneeId);
    final cleanedAssigneeEmail = _cleanAssigneeEmail(assigneeEmail);

    try {
      final uid = _uid;

      final doc = await _tasksRef(pid).add({
        'projectId': pid,
        'title': t,
        'description': d,
        'priority': pr,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': s,
        if (ai != null) 'ai': ai,
        'aiGenerated': aiGenerated,

        // ✅ atanan üye
        if (cleanedAssigneeId != null) 'assigneeId': cleanedAssigneeId,
        if (cleanedAssigneeEmail != null) 'assigneeEmail': cleanedAssigneeEmail,

        'ownerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _log(
        projectId: pid,
        action: 'created',
        taskId: doc.id,
        taskTitle: t,
        meta: {
          'status': s,
          'aiGenerated': aiGenerated,
          'priority': pr,
          if (cleanedAssigneeEmail != null)
            'assigneeEmail': cleanedAssigneeEmail,
        },
      );
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

    // ✅ yeni
    String? assigneeId,
    String? assigneeEmail,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    final t = _cleanTitle(title);
    final d = _cleanDescription(description);
    final pr = _cleanPriority(priority);
    final cleanedAssigneeId = _cleanAssigneeId(assigneeId);
    final cleanedAssigneeEmail = _cleanAssigneeEmail(assigneeEmail);

    try {
      await _tasksRef(pid).doc(tid).update({
        'title': t,
        'description': d,
        'priority': pr,
        'dueDate': Timestamp.fromDate(dueDate),

        // ✅ atanan üye güncelle
        'assigneeId': cleanedAssigneeId,
        'assigneeEmail': cleanedAssigneeEmail,

        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _log(
        projectId: pid,
        action: 'updated',
        taskId: tid,
        taskTitle: t,
        meta: {
          'priority': pr,
          if (cleanedAssigneeEmail != null)
            'assigneeEmail': cleanedAssigneeEmail,
        },
      );
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // -------------------------
  // UPDATE (partial)
  // -------------------------
  Future<void> updateTaskFields({
    required String projectId,
    required String taskId,
    String? title,
    String? description,
    int? priority,
    DateTime? dueDate,
    String? status,
    Map<String, dynamic>? ai,

    // ✅ yeni
    String? assigneeId,
    String? assigneeEmail,
    bool updateAssignee = false,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) data['title'] = _cleanTitle(title);

    if (description != null) {
      data['description'] = _cleanDescription(description);
    }

    if (priority != null) data['priority'] = _cleanPriority(priority);
    if (dueDate != null) data['dueDate'] = Timestamp.fromDate(dueDate);
    if (status != null) data['status'] = _cleanStatus(status);
    if (ai != null) data['ai'] = ai;

    // ✅ assignee partial update
    if (updateAssignee) {
      data['assigneeId'] = _cleanAssigneeId(assigneeId);
      data['assigneeEmail'] = _cleanAssigneeEmail(assigneeEmail);
    }

    if (data.length == 1) return; // sadece updatedAt -> boş update yok

    try {
      await _tasksRef(pid).doc(tid).update(data);

      await _log(
        projectId: pid,
        action: 'updated',
        taskId: tid,
        taskTitle: title,
        meta: {
          if (status != null) 'status': status,
          if (priority != null) 'priority': _cleanPriority(priority),
          if (ai != null) 'aiUpdated': true,
          if (updateAssignee)
            'assigneeEmail': _cleanAssigneeEmail(assigneeEmail),
        },
      );
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // ✅ status değiştir
  Future<void> setStatus({
    required String projectId,
    required String taskId,
    required String status,
    String? taskTitle,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    final s = _cleanStatus(status);

    try {
      await _tasksRef(pid).doc(tid).update({
        'status': s,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _log(
        projectId: pid,
        action: 'status_changed',
        taskId: tid,
        taskTitle: taskTitle,
        meta: {'status': s},
      );
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // ✅ LLM üretti: ai + aiGenerated
  Future<void> markAiGenerated({
    required String projectId,
    required String taskId,
    required Map<String, dynamic> ai,
    String? taskTitle,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    try {
      await _tasksRef(pid).doc(tid).update({
        'ai': ai,
        'aiGenerated': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _log(
        projectId: pid,
        action: 'ai_generated',
        taskId: tid,
        taskTitle: taskTitle,
        meta: {'aiGenerated': true},
      );
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
    String? taskTitle,
  }) async {
    final pid = projectId.trim();
    final tid = taskId.trim();
    if (tid.isEmpty) throw Exception('TaskId boş olamaz.');

    try {
      await _tasksRef(pid).doc(tid).delete();

      await _log(
        projectId: pid,
        action: 'deleted',
        taskId: tid,
        taskTitle: taskTitle,
      );
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
    String? statusFilter,
  }) {
    final pid = projectId.trim();

    final safeOrder = (orderByField == 'dueDate' || orderByField == 'priority')
        ? orderByField
        : 'dueDate';

    Query<Map<String, dynamic>> q =
        _tasksRef(pid).orderBy(safeOrder, descending: descending);

    final sf = statusFilter?.trim().toLowerCase();
    if (sf != null && sf.isNotEmpty && sf != 'all') {
      q = q.where('status', isEqualTo: _cleanStatus(sf));
    }

    return q.snapshots();
  }

  // -------------------------
  // READ ONCE
  // -------------------------
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getTasksOnce({
    required String projectId,
    String orderByField = 'dueDate',
    bool descending = false,
    int? limit,
    String? statusFilter,
  }) async {
    final pid = projectId.trim();

    final safeOrder = (orderByField == 'dueDate' || orderByField == 'priority')
        ? orderByField
        : 'dueDate';

    try {
      Query<Map<String, dynamic>> q =
          _tasksRef(pid).orderBy(safeOrder, descending: descending);

      final sf = statusFilter?.trim().toLowerCase();
      if (sf != null && sf.isNotEmpty && sf != 'all') {
        q = q.where('status', isEqualTo: _cleanStatus(sf));
      }

      if (limit != null && limit > 0) q = q.limit(limit);

      final snap = await q.get();
      return snap.docs;
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // ✅ activity logs stream
  Stream<QuerySnapshot<Map<String, dynamic>>> logsStream({
    required String projectId,
    int limit = 50,
  }) {
    final pid = projectId.trim();
    return _logsRef(pid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
