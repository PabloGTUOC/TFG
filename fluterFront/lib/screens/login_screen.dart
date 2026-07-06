import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of views/LoginView.vue: centered card, email+password, Google button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegistering = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    if (_email.text.isEmpty || _password.text.isEmpty) {
      app.setError('Email and password are required.');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isRegistering) {
        await app.register(_email.text.trim(), _password.text);
      } else {
        await app.login(_email.text.trim(), _password.text);
      }
    } catch (_) {
      // errors are surfaced via the state toasts
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    try {
      await context.read<AppState>().loginWithGoogle();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: VCard(
              title: _isRegistering ? 'Create CareCoins Account' : 'Welcome to CareCoins',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRegistering
                        ? 'Sign up to start sharing responsibly.'
                        : 'Sign in to access your dashboard.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  VInput(
                      controller: _email,
                      label: 'Email Address',
                      placeholder: 'hello@carecoins.app',
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  VInput(
                      controller: _password,
                      label: 'Password',
                      placeholder: '••••••••',
                      obscure: true,
                      enabled: !_loading),
                  const SizedBox(height: 24),
                  VButton(
                    block: true,
                    disabled: _loading,
                    onPressed: _submit,
                    child: Text(_loading
                        ? 'Processing...'
                        : (_isRegistering ? 'Sign Up' : 'Sign In')),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Text('or',
                          style: TextStyle(
                              fontSize: 13.6, color: AppColors.textSecondary)),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ]),
                  const SizedBox(height: 24),
                  VButton(
                    type: VButtonType.secondary,
                    block: true,
                    onPressed: _google,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GoogleMark(),
                        SizedBox(width: 10),
                        Text('Sign in with Google'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                          _isRegistering
                              ? 'Already have an account?'
                              : 'New to CareCoins?',
                          style: const TextStyle(
                              fontSize: 14.4, color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isRegistering = !_isRegistering),
                        child: Text(
                            _isRegistering ? 'Sign In instead' : 'Create an account',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    // Simple multicolour "G" mark stand-in for the inline SVG.
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      child: const Text('G',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
