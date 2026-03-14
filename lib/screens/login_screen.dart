import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  bool _handledRedirect = false;

  @override
  void initState() {
    super.initState();
    _handleRedirectResult();
  }

  Future<void> _handleRedirectResult() async {
    if (_handledRedirect) return;
    _handledRedirect = true;

    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      final user = result.user;

      if (user != null) {
        await _ensureUserDoc(user);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('REDIRECT RESULT ERROR: $e');
    }
  }

  Future<void> _ensureUserDoc(User user) async {
    final email = user.email;
    if (email == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(email);

    await ref.set({
      'email': email,
      'uid': user.uid,
      'lastLogin': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();

    if (email.isEmpty) {
      return 'E-posta gerekli';
    }

    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    if (!isValid) {
      return 'Geçerli bir e-posta gir';
    }

    return null;
  }

  String? _passValidator(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Şifre gerekli';
    }

    if (password.length < 6) {
      return 'Şifre en az 6 karakter olmalı';
    }

    return null;
  }

  Future<void> _loginEmail() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final user = credential.user;
      if (user != null) {
        await _ensureUserDoc(user);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('EMAIL LOGIN ERROR: ${e.code} - ${e.message}');
      _snack('${e.code}: ${e.message ?? "Giriş başarısız."}');
    } catch (e) {
      debugPrint('EMAIL LOGIN ERROR: $e');
      _snack('Beklenmeyen hata: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Web redirect akışı
  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);

    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});

      await FirebaseAuth.instance.signInWithRedirect(provider);
    } on FirebaseAuthException catch (e) {
      debugPrint('GOOGLE REDIRECT ERROR: ${e.code} - ${e.message}');
      _snack('${e.code}: ${e.message ?? "Google ile giriş başarısız."}');
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('GOOGLE REDIRECT ERROR: $e');
      _snack('Google giriş hatası: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final emailError = _emailValidator(_emailCtrl.text);
    if (emailError != null) {
      _snack('Önce geçerli bir e-posta yazmalısın.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      _snack('Şifre sıfırlama bağlantısı e-posta adresine gönderildi.');
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
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
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
                                        onPressed: _loading
                                            ? null
                                            : () => setState(
                                                  () => _obscure = !_obscure,
                                                ),
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
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Giriş Yap'),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed:
                                        _loading ? null : _loginWithGoogle,
                                    child: const Text('Google ile giriş'),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Hesabın yok mu? ',
                                        style: TextStyle(
                                          color: AppColors.textSoft,
                                        ),
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
    final backgroundPaint = Paint()..color = AppColors.navy;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final dotPaint = Paint()..color = Colors.white.withOpacity(0.06);
    const step = 22.0;
    const radius = 1.2;

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
