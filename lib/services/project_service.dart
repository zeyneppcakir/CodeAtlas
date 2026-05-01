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
  // KULLANICI ARAMA
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // ÜYE EKLEME / DAVET AKIŞI
  // ---------------------------------------------------------------------------

  /// Proje içine üyeyi direkt aktif eklemek yerine önce pending davet oluşturur.
  /// Kullanıcı onaylayınca status => active olur.
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
      throw Exception('E-posta boş olamaz.');
    }

    final projectRef = _db.collection('projects').doc(projectId);
    final projectSnap = await projectRef.get();

    if (!projectSnap.exists) {
      throw Exception('Proje bulunamadı.');
    }

    final projectData = projectSnap.data();
    final ownerId = projectData?['ownerId'] as String?;
    final projectName =
        (projectData?['name'] ?? 'Adsız Proje').toString().trim();

    if (ownerId == null || ownerId != myUid) {
      throw Exception('Üye eklemek için proje sahibi olmalısın.');
    }

    final user = await findUserByEmail(targetEmail);
    if (user == null) {
      throw Exception(
          'Bu e-posta ile kayıtlı kullanıcı bulunamadı: $targetEmail');
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
      final existingStatus =
          (memberSnap.data()?['status'] ?? 'active').toString().trim();

      if (existingStatus == 'pending') {
        throw Exception('Bu kullanıcı için zaten bekleyen bir davet var.');
      }

      throw Exception('Bu kullanıcı zaten üye.');
    }

    final inviteRef = _db.collection('member_invites').doc();
    final inviteId = inviteRef.id;

    // ignore: avoid_print
    print(
      'ProjectService::addMemberByEmail -> projectId=$projectId targetUid=$targetUid email=$foundEmail inviteId=$inviteId',
    );

    final batch = _db.batch();

    batch.set(memberRef, {
      'uid': targetUid,
      'email': foundEmail,
      'displayName': displayName,
      'role': 'member',
      'status': 'pending',
      'projectId': projectId,
      'projectName': projectName,
      'inviteId': inviteId,
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': myUid,
    });

    batch.set(inviteRef, {
      'inviteId': inviteId,
      'projectId': projectId,
      'projectName': projectName,
      'targetUid': targetUid,
      'targetEmail': foundEmail,
      'targetDisplayName': displayName,
      'role': 'member',
      'status': 'pending',
      'createdBy': myUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Sadece aktif/onaylı üyeleri döndürür.
  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('members')
        .where('status', whereIn: ['active', 'approved'])
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  /// Bekleyen üyeleri ayrıca görmek istersen kullanılabilir.
  Stream<QuerySnapshot<Map<String, dynamic>>> pendingMembersStream(
    String projectId,
  ) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('members')
        .where('status', isEqualTo: 'pending')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  /// Giriş yapan kullanıcının bekleyen proje davetleri.
  Stream<QuerySnapshot<Map<String, dynamic>>> myPendingInvitesStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('member_invites')
        .where('targetUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Kullanıcı daveti kabul ederse hem invite hem member kaydı aktifleşir.
  Future<void> acceptInvite({
    required String inviteId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Oturum bulunamadı.');
    }

    final inviteRef = _db.collection('member_invites').doc(inviteId);
    final inviteSnap = await inviteRef.get();

    if (!inviteSnap.exists) {
      throw Exception('Davet bulunamadı.');
    }

    final data = inviteSnap.data();
    if (data == null) {
      throw Exception('Davet verisi alınamadı.');
    }

    final targetUid = (data['targetUid'] ?? '').toString().trim();
    final status = (data['status'] ?? 'pending').toString().trim();
    final projectId = (data['projectId'] ?? '').toString().trim();

    if (targetUid != uid) {
      throw Exception('Bu daveti kabul etme yetkin yok.');
    }

    if (status != 'pending') {
      throw Exception('Bu davet artık beklemede değil.');
    }

    if (projectId.isEmpty) {
      throw Exception('Davet proje bilgisi eksik.');
    }

    final memberRef = _db
        .collection('projects')
        .doc(projectId)
        .collection('members')
        .doc(uid);

    final batch = _db.batch();

    batch.update(inviteRef, {
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
    });

    batch.update(memberRef, {
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Kullanıcı daveti reddederse invite reddedilir ve member kaydı kaldırılır.
  Future<void> rejectInvite({
    required String inviteId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Oturum bulunamadı.');
    }

    final inviteRef = _db.collection('member_invites').doc(inviteId);
    final inviteSnap = await inviteRef.get();

    if (!inviteSnap.exists) {
      throw Exception('Davet bulunamadı.');
    }

    final data = inviteSnap.data();
    if (data == null) {
      throw Exception('Davet verisi alınamadı.');
    }

    final targetUid = (data['targetUid'] ?? '').toString().trim();
    final status = (data['status'] ?? 'pending').toString().trim();
    final projectId = (data['projectId'] ?? '').toString().trim();

    if (targetUid != uid) {
      throw Exception('Bu daveti reddetme yetkin yok.');
    }

    if (status != 'pending') {
      throw Exception('Bu davet artık beklemede değil.');
    }

    if (projectId.isEmpty) {
      throw Exception('Davet proje bilgisi eksik.');
    }

    final memberRef = _db
        .collection('projects')
        .doc(projectId)
        .collection('members')
        .doc(uid);

    final batch = _db.batch();

    batch.update(inviteRef, {
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    batch.delete(memberRef);

    await batch.commit();
  }
}
