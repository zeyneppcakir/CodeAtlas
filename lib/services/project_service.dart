import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ UID'yi her çağrıldığında logla (debug için)
  String? get _uid {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    // ignore: avoid_print
    print('ProjectService::_uid -> uid=$uid | email=$email');
    return uid;
  }

  /// ✅ Proje ekle
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

    // güvenli temizlik
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

  /// ✅ Kullanıcının projeleri
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

  /// ✅ DEBUG: Filtre olmadan tüm projeleri getir (sadece test için)
  Stream<QuerySnapshot<Map<String, dynamic>>> allProjectsStreamForDebug() {
    // ignore: avoid_print
    print('ProjectService::allProjectsStreamForDebug -> NO FILTER!');
    return _db
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ✅ Proje sil (owner kontrolü ile güvenli)
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

      final data = snap.data() as Map<String, dynamic>;
      final ownerId = data['ownerId'] as String?;

      // ignore: avoid_print
      print(
          'ProjectService::deleteProject -> uid=$uid ownerId=$ownerId projectId=$projectId');

      if (ownerId == null || ownerId != uid) {
        throw Exception('Bu projeyi silme yetkin yok.');
      }

      await ref.delete();
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }
}
