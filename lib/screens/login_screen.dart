import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  /// ✅ users/{email} doc'u oluştur/güncelle
  Future<void> _ensureUserDoc(User user) async {
    final email = user.email;
    if (email == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(email);

    await ref.set({
      'email': email,
      'uid': user.uid,
      'lastLogin': FieldValue.serverTimestamp(),
      // createdAt sadece ilk oluşturmada yazılsın
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'E-posta gerekli';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Geçerli bir e-posta gir';
    return null;
  }

  String? _passValidator(String? v) {
    final value = (v ?? '');
    if (value.isEmpty) return 'Şifre gerekli';
    if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
    return null;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı yok.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'invalid-credential':
        return 'E-posta/şifre hatalı.';
      case 'invalid-email':
        return 'E-posta formatı geçersiz.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Biraz sonra tekrar deneyin.';
      default:
        return e.message ?? 'Giriş başarısız.';
    }
  }

  Future<void> _loginEmail() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final user = cred.user;
      if (user != null) {
        await _ensureUserDoc(user);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _snack(_mapAuthError(e));
    } on FirebaseException catch (e) {
      debugPrint('FIRESTORE ERROR: ${e.code} - ${e.message}');
      _snack('Veritabanı hatası: ${e.code}');
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      _snack('Beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // kullanıcı vazgeçti

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);

      final user = cred.user;
      if (user != null) {
        await _ensureUserDoc(user);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Google ile giriş başarısız.');
    } on FirebaseException catch (e) {
      debugPrint('FIRESTORE ERROR: ${e.code} - ${e.message}');
      _snack('Veritabanı hatası: ${e.code}');
    } catch (e) {
      debugPrint('GOOGLE LOGIN ERROR: $e');
      _snack('Google giriş hatası oluştu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final emailErr = _emailValidator(_emailCtrl.text);
    if (emailErr != null) {
      _snack('Önce geçerli e-posta yazmalısın.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      _snack('Şifre sıfırlama bağlantısı e-postana gönderildi.');
    } on FirebaseAuthException catch (e) {
      _snack(_mapAuthError(e));
    } catch (_) {
      _snack('E-posta gönderilemedi.');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Form(
                              key: _formKey,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'CodeAtlas',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Giriş yap',
                                    style: TextStyle(
                                      color: AppColors.textSoft,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _emailValidator,
                                    decoration: const InputDecoration(
                                      labelText: 'E-posta',
                                      prefixIcon: Icon(Icons.mail_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passCtrl,
                                    obscureText: _obscure,
                                    validator: _passValidator,
                                    decoration: InputDecoration(
                                      labelText: 'Şifre',
                                      prefixIcon:
                                          const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                            () => _obscure = !_obscure),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed:
                                          _loading ? null : _resetPassword,
                                      child: const Text('Şifremi unuttum'),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _loading ? null : _loginEmail,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text('Giriş Yap'),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed:
                                        _loading ? null : _loginWithGoogle,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      side: const BorderSide(
                                          color: Colors.white24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Google ile giriş'),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Hesabın yok mu? ',
                                        style: TextStyle(
                                            color: AppColors.textSoft),
                                      ),
                                      TextButton(
                                        onPressed: _loading
                                            ? null
                                            : () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const RegisterScreen(),
                                                  ),
                                                ),
                                        child: const Text('Kayıt Ol'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.navy;
    canvas.drawRect(Offset.zero & size, bg);

    final dot = Paint()..color = Colors.white.withOpacity(0.06);
    const step = 22.0;
    const r = 1.2;

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), r, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
