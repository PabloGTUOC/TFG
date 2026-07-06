import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseAvailable = true;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Keep the app bootable before `flutterfire configure` has been run.
    firebaseAvailable = false;
    debugPrint('Firebase init failed (run flutterfire configure): $e');
  }

  runApp(CareCoinsApp(firebaseAvailable: firebaseAvailable));
}

class CareCoinsApp extends StatelessWidget {
  final bool firebaseAvailable;
  const CareCoinsApp({super.key, required this.firebaseAvailable});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()
        ..firebaseAvailable = firebaseAvailable
        ..init(),
      child: MaterialApp(
        title: 'CareCoins',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Mirrors the Vue router guards: loading screen until auth is ready,
/// landing → login for guests, onboarding when the user has no family,
/// else the shell.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _showLogin = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.authReady) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Text('Loading CareCoins...',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ),
      );
    }
    if (app.user == null) {
      if (!_showLogin) {
        return LandingScreen(
            onSignIn: () => setState(() => _showLogin = true));
      }
      return Stack(
        children: [
          const LoginScreen(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                onPressed: () => setState(() => _showLogin = false),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
              ),
            ),
          ),
        ],
      );
    }
    if (!app.hasFamilies) return const OnboardingScreen();
    return const Shell();
  }
}
