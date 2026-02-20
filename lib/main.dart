import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CodeAtlasApp());
}

class CodeAtlasApp extends StatelessWidget {
  const CodeAtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CodeAtlas',
      theme: AppTheme.darkTheme,
      navigatorKey: navKey,
      scaffoldMessengerKey: messengerKey,
      // Eğer AppTheme.darkTheme Material3 içermiyorsa burada da açabiliriz:
      // theme: AppTheme.darkTheme.copyWith(useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

/// Kullanıcı girişliyse Home, değilse Login'e yönlendirir.
/// Çıkış yapınca otomatik Login'e döner.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return const HomeScreen();
      },
    );
  }
}
