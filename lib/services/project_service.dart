import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// ✅ Proje ekle
  Future<void> addProject({
    required String name,
    required String primaryLanguage,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }

    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw Exception('Proje adı boş olamaz.');
    }

    try {
      await _db.collection('projects').add({
        'name': cleanedName,
        'ownerId': uid,
        'primaryLanguage': primaryLanguage,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }

  /// ✅ Kullanıcının projeleri
  Stream<QuerySnapshot<Map<String, dynamic>>> myProjectsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('projects')
        .where('ownerId', isEqualTo: uid)
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

      if (ownerId == null || ownerId != uid) {
        throw Exception('Bu projeyi silme yetkin yok.');
      }

      await ref.delete();
    } on FirebaseException catch (e) {
      throw Exception('Firestore hata: ${e.message ?? e.code}');
    }
  }
}
