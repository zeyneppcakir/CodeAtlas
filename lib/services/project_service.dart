import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    // ignore: avoid_print
    print('ProjectService::_uid -> uid=$uid | email=$email');
    return uid;
  }

  String _cleanEmail(String email) {
    return email.trim().toLowerCase();
  }

  Future<void> addProject({
    required String name,
    required String primaryLanguage,
    Map<String, int>? languageStats,
    int? fileCount,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }

    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw Exception('Proje adı boş olamaz.');
    }

    final cleanedStats = <String, int>{};
    if (languageStats != null) {
      languageStats.forEach((k, v) {
        final key = k.trim();
        if (key.isEmpty) return;
        if (v <= 0) return;
        cleanedStats[key] = v;
      });
    }

    int? cleanedFileCount = fileCount;
    if (cleanedFileCount != null && cleanedFileCount < 0) {
      cleanedFileCount = null;
    }

    try {
      // ignore: avoid_print
      print('ProjectService::addProject -> ownerId=$uid name=$cleanedName');

      await _db.collection('projects').add({
        'name': cleanedName,
        'ownerId': uid,
        'primaryLanguage': primaryLanguage,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (cleanedStats.isNotEmpty) 'languageStats': cleanedStats,
        if (cleanedFileCount != null) 'fileCount': cleanedFileCount,
      });
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myProjectsStream() {
    final uid = _uid;
    if (uid == null) {
      // ignore: avoid_print
      print('ProjectService::myProjectsStream -> UID NULL, stream empty');
      return const Stream.empty();
    }

    // ignore: avoid_print
    print('ProjectService::myProjectsStream -> querying ownerId=$uid');

    return _db
        .collection('projects')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allProjectsStreamForDebug() {
    // ignore: avoid_print
    print('ProjectService::allProjectsStreamForDebug -> NO FILTER!');
    return _db
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> getProjectById(String projectId) async {
    try {
      // ignore: avoid_print
      print('ProjectService::getProjectById -> projectId=$projectId');

      final snap = await _db.collection('projects').doc(projectId).get();
      if (!snap.exists) {
        throw Exception('Proje bulunamadı.');
      }

      final data = snap.data();
      if (data == null) {
        throw Exception('Proje verisi boş geldi.');
      }

      return data;
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  Future<void> deleteProject(String projectId) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }

    try {
      final ref = _db.collection('projects').doc(projectId);
      final snap = await ref.get();

      if (!snap.exists) {
        throw Exception('Proje bulunamadı (zaten silinmiş olabilir).');
      }

      final data = snap.data();
      final ownerId = data?['ownerId'] as String?;

      // ignore: avoid_print
      print(
        'ProjectService::deleteProject -> uid=$uid ownerId=$ownerId projectId=$projectId',
      );

      if (ownerId == null || ownerId != uid) {
        throw Exception('Bu projeyi silme yetkin yok.');
      }

      await ref.delete();
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  // ---------------------------------------------------------------------------
  // ÜYE EKLEME / ÜYE LİSTELEME
  // ---------------------------------------------------------------------------

  /// users koleksiyonunda email'e göre kullanıcı bulur
  /// dönüş: {'uid': ..., 'email': ..., 'displayName': ...}
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final normalized = _cleanEmail(email);
    if (normalized.isEmpty) return null;

    final q = await _db
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;

    final data = q.docs.first.data();

    final uid = (data['uid'] ?? '').toString().trim();
    if (uid.isEmpty) return null;

    return {
      'uid': uid,
      'email': (data['email'] ?? normalized).toString(),
      'displayName': (data['displayName'] ?? '').toString(),
    };
  }

  Future<String?> findUserIdByEmail(String email) async {
    final user = await findUserByEmail(email);
    return user?['uid'] as String?;
  }

  /// projects/{projectId}/members/{uid} şeklinde kaydeder
  Future<void> addMemberByEmail({
    required String projectId,
    required String email,
  }) async {
    final myUid = _uid;
    if (myUid == null) {
      throw Exception('Oturum yok. Lütfen tekrar giriş yap.');
    }

    final targetEmail = _cleanEmail(email);
    if (targetEmail.isEmpty) {
      throw Exception('Email boş olamaz.');
    }

    final projectRef = _db.collection('projects').doc(projectId);
    final projectSnap = await projectRef.get();

    if (!projectSnap.exists) {
      throw Exception('Proje bulunamadı.');
    }

    final ownerId = projectSnap.data()?['ownerId'] as String?;
    if (ownerId == null || ownerId != myUid) {
      throw Exception('Üye eklemek için proje sahibi olmalısın.');
    }

    final user = await findUserByEmail(targetEmail);
    if (user == null) {
      throw Exception(
          'Bu email ile kayıtlı kullanıcı bulunamadı: $targetEmail');
    }

    final targetUid = (user['uid'] ?? '').toString().trim();
    final foundEmail = _cleanEmail((user['email'] ?? targetEmail).toString());
    final displayName = (user['displayName'] ?? '').toString().trim();

    if (targetUid.isEmpty) {
      throw Exception('Kullanıcı UID bilgisi bulunamadı.');
    }

    if (targetUid == myUid) {
      throw Exception('Zaten proje sahibisin.');
    }

    final memberRef = projectRef.collection('members').doc(targetUid);
    final memberSnap = await memberRef.get();

    if (memberSnap.exists) {
      throw Exception('Bu kullanıcı zaten üye.');
    }

    // ignore: avoid_print
    print(
      'ProjectService::addMemberByEmail -> projectId=$projectId targetUid=$targetUid email=$foundEmail',
    );

    await memberRef.set({
      'uid': targetUid,
      'email': foundEmail,
      'displayName': displayName,
      'role': 'member',
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': myUid,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('members')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }
}
